const MAX_ATTEMPTS_HARD_LIMIT = 3;
const DEFAULT_COOLDOWN_MS = 60_000;
const DEFAULT_RETRY_AFTER_SECONDS = 30;
const MAX_RETRY_AFTER_SECONDS = 86_400;
// The app's own client waits 245s for an extraction. One thinking-model attempt
// can now legitimately take up to 180s, so the rotator must not keep starting
// fresh attempts past that window: answering late is worse than answering with a
// clear, retryable failure.
const DEFAULT_TOTAL_BUDGET_MS = 210_000;
const MIN_ATTEMPT_SLICE_MS = 20_000;
const MAX_TOTAL_BUDGET_MS = 240_000;

function asStatus(error) {
  const number = Number(error?.status ?? error?.statusCode);
  return Number.isInteger(number) && number >= 100 && number <= 599 ? number : 0;
}

function normalizedProviderCode(error) {
  return String(error?.reason || error?.code || '').trim().toUpperCase();
}

function retryDelaySeconds(error) {
  const explicit = Number(error?.retryAfterSeconds);
  if (Number.isFinite(explicit) && explicit > 0) {
    return Math.max(1, Math.min(Math.ceil(explicit), MAX_RETRY_AFTER_SECONDS));
  }
  const header = error?.headers?.['retry-after'] ??
    error?.headers?.get?.('retry-after');
  if (header != null) {
    const seconds = Number(header);
    if (Number.isFinite(seconds) && seconds > 0) {
      return Math.max(1, Math.min(Math.ceil(seconds), MAX_RETRY_AFTER_SECONDS));
    }
    const date = Date.parse(String(header));
    if (Number.isFinite(date)) {
      return Math.max(1, Math.min(Math.ceil((date - Date.now()) / 1000), MAX_RETRY_AFTER_SECONDS));
    }
  }
  return DEFAULT_RETRY_AFTER_SECONDS;
}

/**
 * Classify provider failures without storing/returning raw upstream messages.
 * Unknown 403/project restrictions are permanent; they must not quarantine all keys.
 */
export function classifyGeminiFailure(error) {
  const status = asStatus(error);
  const code = normalizedProviderCode(error);
  const name = String(error?.name || '');
  const message = String(error?.message || '');

  if (status === 429 || code.includes('RESOURCE_EXHAUSTED') ||
      code === 'QUOTA_EXCEEDED' || code === 'RATE_LIMIT_EXCEEDED') {
    // A spent provider/project quota must not be bypassed by rotating keys
    // (see ADMIN_API.md). The key is recorded as cooling without a cooldown so
    // the same key can still serve a fallback model, whose quota is separate.
    return {
      category: 'quota_limited',
      action: 'stop',
      statusCode: 429,
      publicCode: 'gemini_rate_limited',
      retryAfterSeconds: retryDelaySeconds(error),
      quotaScope: ['daily', 'minute'].includes(error?.quotaScope) ? error.quotaScope : 'unknown',
      quotaMetric: ['RPM', 'TPM', 'RPD'].includes(error?.quotaMetric) ? error.quotaMetric : 'unspecified',
      message: 'Gemini rate or quota limit reached. Wait before retrying.',
    };
  }

  const invalidKeyCode = [
    'API_KEY_INVALID',
    'INVALID_API_KEY',
    'API_KEY_NOT_VALID',
    'API_KEY_INVALID_CREDENTIALS',
  ].some((item) => code.includes(item));
  const explicitlyInvalidKey = /api key (is )?not valid|invalid api key/i.test(message) &&
    (status === 400 || status === 401 || status === 403);
  if (status === 401 || invalidKeyCode || explicitlyInvalidKey) {
    return {
      category: 'invalid_key',
      action: 'failover',
      health: 'attention_required',
      statusCode: 503,
      publicCode: 'gemini_key_needs_attention',
      message: 'A configured Gemini key needs administrator attention.',
    };
  }

  // Provider-internal response problems (a truncated, empty, or unparseable
  // model answer) are not credential failures. They must be reported before the
  // generic 5xx branch, otherwise a truncated answer is mistaken for a dead key
  // and the healthy key is parked in cooldown.
  const providerCode = code;
  const responseTruncated = providerCode.includes('RESPONSE_TRUNCATED');
  const unusableResponse = responseTruncated ||
    ['EMPTY_UPSTREAM_RESPONSE', 'INVALID_UPSTREAM_RESPONSE', 'INVALID_RESPONSE']
      .some((item) => providerCode.includes(item));
  if (unusableResponse) {
    return {
      category: 'invalid_request',
      action: 'stop',
      statusCode: 502,
      publicCode: responseTruncated ? 'gemini_response_incomplete' : 'gemini_response_unusable',
      message: responseTruncated
        ? 'Gemini stopped before finishing its answer, so no result could be read. Please retry; if this repeats, the model output budget needs review.'
        : 'Gemini returned an unusable response, so no result could be read. Please retry.',
    };
  }

  const networkCodes = new Set([
    'ETIMEDOUT',
    'ECONNRESET',
    'ECONNREFUSED',
    'EHOSTUNREACH',
    'ENETUNREACH',
    'EAI_AGAIN',
    'UND_ERR_CONNECT_TIMEOUT',
    'UND_ERR_HEADERS_TIMEOUT',
    'ABORT_ERR',
  ]);
  const isNetworkFailure = networkCodes.has(code) ||
    name === 'AbortError' || name === 'TimeoutError';
  if (isNetworkFailure || status === 408 || (status >= 500 && status <= 599)) {
    return {
      category: 'transient_upstream_failure',
      action: 'failover',
      health: 'cooling_down',
      statusCode: 503,
      publicCode: 'gemini_temporarily_unavailable',
      message: 'Gemini is temporarily unavailable. Trying another configured key when possible.',
    };
  }

  if (status >= 400 && status < 500) {
    // Only 401/403 justify a credentials/permission message. Any other 4xx is a
    // rejected request (for example an unknown model name or an unsupported
    // attachment), and blaming the API keys there sends operators down the
    // wrong path.
    const permissionProblem = status === 401 || status === 403;
    return {
      category: permissionProblem ? 'provider_permission_denied' : 'invalid_request',
      action: 'stop',
      statusCode: status,
      publicCode: permissionProblem ? 'gemini_configuration_error' : 'invalid_upstream_request',
      message: permissionProblem
        ? 'Gemini credentials or project permissions need administrator attention.'
        : 'Gemini rejected the request (HTTP ' + status + '). Check the configured model, the supplied text, and the supported file types.',
    };
  }

  return {
    category: 'unknown_upstream_failure',
    action: 'stop',
    statusCode: 502,
    publicCode: 'gemini_request_failed',
    message: 'Gemini could not complete the request. Please try again later.',
  };
}

function safeFailure(failure, attempts, extra = {}) {
  return {
    ok: false,
    statusCode: failure.statusCode || 502,
    code: failure.publicCode || 'gemini_request_failed',
    message: failure.message || 'Gemini could not complete the request. Please try again later.',
    attempts,
    ...(failure.retryAfterSeconds != null
      ? { retryAfterSeconds: failure.retryAfterSeconds }
      : {}),
    ...extra,
  };
}

function toDate(timestamp) {
  return new Date(timestamp);
}

/**
 * Shared bounded rotator. The store implements:
 * getPoolSettings(), reserveNextKey({excludeIds, now}), markUsed(id, at),
 * markSuccess(id, at), and markFailure(id, failure).
 * Provider details and storage are injected so tests never call Google.
 */
export function createGeminiKeyRotator({
  store,
  decryptKey,
  providerCall,
  legacyApiKey = '',
  // Optional second model used when every eligible key is out of quota for the
  // primary model. Quotas are per model, so this keeps the app usable when the
  // primary model's daily free-tier budget is spent.
  fallbackModel = '',
  now = () => Date.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  maxAttempts = MAX_ATTEMPTS_HARD_LIMIT,
  cooldownMs = DEFAULT_COOLDOWN_MS,
  totalBudgetMs = DEFAULT_TOTAL_BUDGET_MS,
}) {
  if (!store || typeof store.getPoolSettings !== 'function' ||
      typeof store.reserveNextKey !== 'function' ||
      typeof store.markUsed !== 'function' ||
      typeof store.markSuccess !== 'function' ||
      typeof store.markFailure !== 'function') {
    throw new TypeError('A complete Gemini key-store adapter is required.');
  }
  if (typeof decryptKey !== 'function' || typeof providerCall !== 'function') {
    throw new TypeError('Gemini key decryption and provider adapters are required.');
  }
  const attemptsLimit = Math.max(1, Math.min(
    MAX_ATTEMPTS_HARD_LIMIT,
    Number.isInteger(maxAttempts) ? maxAttempts : MAX_ATTEMPTS_HARD_LIMIT,
  ));
  const safeCooldown = Math.max(1000, Math.min(
    15 * 60_000,
    Number.isFinite(cooldownMs) ? cooldownMs : DEFAULT_COOLDOWN_MS,
  ));
  const safeBudget = Math.max(MIN_ATTEMPT_SLICE_MS, Math.min(
    MAX_TOTAL_BUDGET_MS,
    Number.isFinite(totalBudgetMs) ? totalBudgetMs : DEFAULT_TOTAL_BUDGET_MS,
  ));
  const safeFallbackModel = typeof fallbackModel === 'string' ? fallbackModel.trim() : '';

  async function callLegacyOnce(request) {
    const model = String(request?.model || '');
    if (model && typeof store.getModelQuotaStatus === 'function') {
      try {
        const previous = await store.getModelQuotaStatus(model, toDate(now()));
        if (previous?.retryAfterSeconds > 0) {
          return safeFailure({
            category: 'quota_limited',
            statusCode: 429,
            publicCode: 'gemini_rate_limited',
            retryAfterSeconds: previous.retryAfterSeconds,
            message: 'Gemini quota is temporarily exhausted for this model. Please retry after the reset.',
          }, 0);
        }
      } catch {
        return safeFailure({
          statusCode: 503,
          publicCode: 'gemini_key_store_unavailable',
          message: 'Gemini quota monitoring is temporarily unavailable.',
        }, 0);
      }
    }
    const key = typeof legacyApiKey === 'string' ? legacyApiKey.trim() : '';
    if (!key) {
      return safeFailure({
        statusCode: 503,
        publicCode: 'gemini_not_configured',
        message: 'No usable Gemini API key is configured.',
      }, 0);
    }
    try {
      const result = await providerCall({ ...request, apiKey: key, keyId: 'legacy-env' });
      return { ok: true, result, attempts: 1, keyId: 'legacy-env' };
    } catch (error) {
      const failure = classifyGeminiFailure(error);
      if (failure.category === 'quota_limited' &&
          model && typeof store.markModelQuota === 'function') {
        try {
          await store.markModelQuota({
            model,
            retryAfterSeconds: failure.retryAfterSeconds,
            scope: failure.quotaScope,
            metric: failure.quotaMetric,
            at: toDate(now()),
          });
        } catch {
          // Preserve provider response even if quota bookkeeping is unavailable.
        }
      }
      return safeFailure(failure, 1);
    }
  }

  async function runPool(request) {
    let settings;
    try {
      settings = await store.getPoolSettings();
    } catch {
      return safeFailure({
        statusCode: 503,
        publicCode: 'gemini_key_store_unavailable',
        message: 'Gemini key management is temporarily unavailable.',
      }, 0);
    }

    if (settings?.managedPoolActivated !== true) {
      return callLegacyOnce(request);
    }

    if (typeof store.getModelQuotaStatus === 'function' && request?.model) {
      try {
        const quota = await store.getModelQuotaStatus(
          String(request.model), toDate(now()));
        if (quota?.retryAfterSeconds > 0) {
          return safeFailure({
            category: 'quota_limited',
            statusCode: 429,
            publicCode: 'gemini_rate_limited',
            retryAfterSeconds: quota.retryAfterSeconds,
            message: 'Gemini quota is temporarily exhausted for this model. Please retry after the reset.',
          }, 0);
        }
      } catch {
        return safeFailure({
          statusCode: 503, publicCode: 'gemini_key_store_unavailable',
          message: 'Gemini quota monitoring is temporarily unavailable.',
        }, 0);
      }
    }

    const attemptedIds = new Set();
    let attempts = 0;
    let lastFailure = null;
    let budgetExhausted = false;
    const startedAt = Number(now());

    while (attempts < attemptsLimit) {
      if (attempts > 0 &&
          Math.max(0, Number(now()) - startedAt) + MIN_ATTEMPT_SLICE_MS > safeBudget) {
        budgetExhausted = true;
        break;
      }
      let record;
      try {
        record = await store.reserveNextKey({
          excludeIds: [...attemptedIds],
          now: toDate(now()),
          model: String(request?.model || ''),
        });
      } catch {
        return safeFailure({
          statusCode: 503,
          publicCode: 'gemini_key_store_unavailable',
          message: 'Gemini key management is temporarily unavailable.',
        }, attempts);
      }
      if (!record) break;

      const keyId = String(record._id || '');
      if (!keyId || attemptedIds.has(keyId)) {
        // Never call a duplicate/malformed key record in one logical request.
        break;
      }
      attemptedIds.add(keyId);
      attempts += 1;

      let apiKey;
      try {
        apiKey = await decryptKey(record);
        if (typeof apiKey !== 'string' || !apiKey) {
          throw new Error('Invalid decrypted key.');
        }
      } catch (decryptError) {
        const configMessage = String(decryptError?.message || '');
        if (/GEMINI_KEY_ENCRYPTION_SECRET|encryption secret.*required|exactly 32 bytes|must be base64/i.test(configMessage)) {
          return safeFailure({
            category: 'configuration_error',
            action: 'stop',
            statusCode: 503,
            publicCode: 'gemini_key_encryption_not_configured',
            message: 'Gemini key encryption is not configured. Ask an administrator to complete secure setup.',
          }, attempts);
        }
        const at = toDate(now());
        try {
          await store.markFailure(keyId, {
            category: 'encryption_error',
            health: 'configuration_error',
            cooldownUntil: null,
            at,
          });
        } catch {
          // Keep the public result generic; never serialize storage exceptions.
        }
        lastFailure = {
          category: 'encryption_error',
          action: 'failover',
          statusCode: 503,
          publicCode: 'gemini_key_unavailable',
          message: 'A configured Gemini key cannot be used. Trying another configured key when possible.',
        };
        continue;
      }

      const attemptedAt = toDate(now());
      try {
        await store.markUsed(keyId, attemptedAt);
      } catch {
        return safeFailure({
          statusCode: 503,
          publicCode: 'gemini_key_store_unavailable',
          message: 'Gemini key management is temporarily unavailable.',
        }, attempts);
      }

      try {
        const result = await providerCall({ ...request, apiKey, keyId });
        await store.markSuccess(keyId, toDate(now()), String(request?.model || ''));
        return { ok: true, result, attempts, keyId };
      } catch (error) {
        const failure = classifyGeminiFailure(error);
        lastFailure = failure;
        if (failure.action !== 'failover') {
          if (failure.category === 'quota_limited') {
            // Record the spent quota for the admin UI, but keep the key eligible
            // (no cooldown): a cooldown is per key, and parking it would also
            // block the fallback model, which has its own quota.
            try {
              await store.markFailure(keyId, {
                category: failure.category,
                health: 'cooling_down',
                cooldownUntil: null,
                quotaUntil: toDate(now() + failure.retryAfterSeconds * 1000),
                quotaModel: String(request?.model || ''),
                quotaScope: failure.quotaScope,
                quotaMetric: failure.quotaMetric,
                retryAfterSeconds: failure.retryAfterSeconds,
                at: toDate(now()),
              });
              if (typeof store.markModelQuota === 'function') {
                await store.markModelQuota({
                  model: String(request?.model || ''),
                  retryAfterSeconds: failure.retryAfterSeconds,
                  scope: failure.quotaScope,
                  metric: failure.quotaMetric,
                  at: toDate(now()),
                });
              }
            } catch {
              // Do not mask the safe provider limit result with storage detail.
            }
          }
          return safeFailure(failure, attempts);
        }

        // Quota never reaches this branch (it stops the request), so this is a
        // transient/key failure: cool the key down for the provider's stated
        // window when it gave one, otherwise for the default cooldown.
        const cooldownUntil = failure.health === 'cooling_down'
          ? toDate(now() + (failure.retryAfterSeconds
              ? failure.retryAfterSeconds * 1000
              : safeCooldown))
          : null;
        try {
          await store.markFailure(keyId, {
            category: failure.category,
            health: failure.health || 'attention_required',
            cooldownUntil,
            ...(failure.retryAfterSeconds ? { retryAfterSeconds: failure.retryAfterSeconds } : {}),
            at: toDate(now()),
          });
        } catch {
          return safeFailure({
            statusCode: 503,
            publicCode: 'gemini_key_store_unavailable',
            message: 'Gemini key management is temporarily unavailable.',
          }, attempts);
        }

        if (attempts < attemptsLimit) {
          await sleep(Math.min(250 * (2 ** (attempts - 1)), 1000));
        }
      }
    }

    if (budgetExhausted && lastFailure?.action === 'failover') {
      return safeFailure({
        statusCode: 503,
        publicCode: 'gemini_request_timed_out',
        message: 'Gemini did not finish before the request deadline. Please try again in a moment.',
        retryAfterSeconds: DEFAULT_RETRY_AFTER_SECONDS,
      }, attempts);
    }

    return safeFailure(lastFailure && lastFailure.action === 'failover'
      ? {
          statusCode: 503,
          publicCode: 'gemini_pool_exhausted',
          message: 'Configured Gemini keys are temporarily unavailable. Try again later or ask an administrator to review key status.',
        }
      : {
          statusCode: 503,
          publicCode: 'gemini_no_eligible_key',
          message: 'No enabled Gemini key is currently available.',
        }, attempts);
  }

  /**
   * Keys are rotated for key-specific failures, but a spent free-tier quota is
   * per model. When the pool ends in a quota/exhaustion result, retry once with
   * the configured fallback model so one exhausted model does not take the
   * whole app (registration, matching, document Q&A) down for the day.
   */
  function exhaustionResult(result) {
    return result?.code === 'gemini_rate_limited' ||
      result?.code === 'gemini_pool_exhausted' ||
      result?.code === 'gemini_no_eligible_key';
  }

  async function generate(request) {
    const primary = await runPool(request);
    if (primary?.ok) return primary;
    const requestedModel = String(request?.model || '').trim();
    if (!safeFallbackModel || safeFallbackModel === requestedModel) return primary;
    if (!exhaustionResult(primary)) return primary;
    const secondary = await runPool({ ...request, model: safeFallbackModel });
    if (secondary?.ok) {
      return {
        ...secondary,
        model: safeFallbackModel,
        fallbackModel: safeFallbackModel,
        fallbackAttempted: true,
      };
    }
    return {
      ...primary,
      fallbackAttempted: true,
      fallbackModel: safeFallbackModel,
      fallbackCode: secondary?.code || null,
    };
  }

  /**
   * Run a non-generation Gemini call (for example a Files API upload or delete)
   * with one currently usable key. Health is not touched: an upload hiccup is not
   * evidence that a key is bad, and marking it would quarantine a healthy key.
   */
  async function withApiKey(fn) {
    if (typeof fn !== 'function') throw new TypeError('A keyed operation is required.');
    let settings;
    try {
      settings = await store.getPoolSettings();
    } catch {
      throw new Error('Gemini key management is temporarily unavailable.');
    }
    if (settings?.managedPoolActivated !== true) {
      const key = typeof legacyApiKey === 'string' ? legacyApiKey.trim() : '';
      if (!key) throw new Error('No usable Gemini API key is configured.');
      return fn(key);
    }
    const record = await store.reserveNextKey({ now: toDate(now()) });
    if (!record) throw new Error('No enabled Gemini key is currently available.');
    const apiKey = await decryptKey(record);
    if (typeof apiKey !== 'string' || !apiKey) throw new Error('A configured Gemini key cannot be used.');
    return fn(apiKey);
  }

  return Object.freeze({ generate, withApiKey });
}

export const GEMINI_ROTATOR_LIMITS = Object.freeze({
  maxAttempts: MAX_ATTEMPTS_HARD_LIMIT,
  defaultCooldownMs: DEFAULT_COOLDOWN_MS,
  maxCooldownMs: 15 * 60_000,
  defaultRetryAfterSeconds: DEFAULT_RETRY_AFTER_SECONDS,
  defaultTotalBudgetMs: DEFAULT_TOTAL_BUDGET_MS,
  minAttemptSliceMs: MIN_ATTEMPT_SLICE_MS,
});
