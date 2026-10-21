const SAFE_TEST_CATEGORIES = new Set([
  'test_success',
  'invalid_key',
  'quota_limited',
  'transient_upstream_failure',
  'provider_permission_denied',
  'configuration_error',
  'unknown_upstream_failure',
  'encryption_error',
]);

function safeErrorResponse(error) {
  const message = String(error?.message || '');
  if (/GEMINI_KEY_ENCRYPTION_SECRET/i.test(message)) {
    return {
      status: 503,
      body: {
        ok: false,
        error: 'gemini_key_encryption_not_ready',
        message: 'Gemini key encryption is not configured. Ask an administrator to run secure setup.',
      },
    };
  }
  if (/managed key pool could not be activated|mongo|database|store unavailable/i.test(message)) {
    return {
      status: 503,
      body: {
        ok: false,
        error: 'gemini_key_store_unavailable',
        message: 'Gemini key management is temporarily unavailable.',
      },
    };
  }
  if (/required|label|length|single line|whitespace|invalid|provide a key/i.test(message)) {
    return {
      status: 400,
      body: {
        ok: false,
        error: 'invalid_gemini_key_request',
        message: 'The key-management request is invalid. Check the label, key input, and allowed fields.',
      },
    };
  }
  return {
    status: 500,
    body: {
      ok: false,
      error: 'gemini_key_manager_failed',
      message: 'Gemini key management could not complete the request.',
    },
  };
}

function isValidId(value) {
  return /^[a-f0-9]{24}$/i.test(String(value || ''));
}

function verifiedActor(req) {
  const uid = req.user?.uid || req.user?.sub;
  return typeof uid === 'string' && uid.trim() && uid.length <= 128 ? uid.trim() : null;
}

function objectBody(body) {
  return body != null && typeof body === 'object' && !Array.isArray(body);
}

function hasOnlyKeys(body, allowed) {
  return objectBody(body) && Object.keys(body).every((key) => allowed.includes(key));
}

function sendSafeError(res, error) {
  const response = safeErrorResponse(error);
  return res.status(response.status).json(response.body);
}

async function getStoreSafely(getStore) {
  const store = await getStore();
  if (!store || typeof store.listPublicKeys !== 'function') {
    throw new Error('Gemini key store is unavailable.');
  }
  return store;
}

/**
 * Create Admin-only key routes. Authentication, Mongo role checks, and Mongo
 * readiness are injected from the existing server to preserve its trust boundary.
 */
export function createGeminiKeyRouter({
  express,
  requireAuth,
  requireAdmin,
  requireMongo,
  getStore,
  testKey,
  getModel = () => '',
}) {
  if (!express || typeof express.Router !== 'function' ||
      typeof requireAuth !== 'function' ||
      typeof requireAdmin !== 'function' ||
      typeof requireMongo !== 'function' ||
      typeof getStore !== 'function' ||
      typeof testKey !== 'function') {
    throw new TypeError('Gemini key routes require Express, auth/admin/Mongo guards, a store, and a test adapter.');
  }

  const router = express.Router();
  const guarded = [requireAuth, requireAdmin, requireMongo];

  router.get('/admin/gemini-keys', ...guarded, async (_req, res) => {
    try {
      const store = await getStoreSafely(getStore);
      const [keys, settings] = await Promise.all([
        store.listPublicKeys(),
        store.getPoolSettings(),
      ]);
      const legacyApiKey = String(process.env.GEMINI_API_KEY || '').trim();
      const legacyFallbackConfigured = Boolean(
        legacyApiKey && !legacyApiKey.includes('PASTE_NEW_GEMINI_KEY_HERE'),
      );
      const model = String(getModel() || '');
      const quota = typeof store.getModelQuotaStatus === 'function'
        ? await store.getModelQuotaStatus(model) : null;
      return res.json({
        ok: true,
        keys,
        model,
        modelQuota: quota,
        managedPoolActivated: settings.managedPoolActivated === true,
        legacyFallbackConfigured,
      });
    } catch (error) {
      return sendSafeError(res, error);
    }
  });

  router.post('/admin/gemini-keys', ...guarded, async (req, res) => {
    try {
      if (!hasOnlyKeys(req.body, ['label', 'apiKey']) ||
          typeof req.body.label !== 'string' ||
          typeof req.body.apiKey !== 'string') {
        return res.status(400).json({
          ok: false,
          error: 'invalid_gemini_key_request',
          message: 'Supply only a key label and API key.',
        });
      }
      const actorUid = verifiedActor(req);
      if (!actorUid) {
        return res.status(401).json({ ok: false, error: 'authentication_required' });
      }
      const store = await getStoreSafely(getStore);
      const key = await store.createKey({
        label: req.body.label,
        apiKey: req.body.apiKey,
        actorUid,
      });
      return res.status(201).json({ ok: true, key });
    } catch (error) {
      return sendSafeError(res, error);
    }
  });

  router.put('/admin/gemini-keys/:id', ...guarded, async (req, res) => {
    try {
      if (!isValidId(req.params.id)) {
        return res.status(400).json({ ok: false, error: 'invalid_gemini_key_id' });
      }
      if (!hasOnlyKeys(req.body, ['label', 'apiKey']) ||
          !Object.keys(req.body).length) {
        return res.status(400).json({
          ok: false,
          error: 'invalid_gemini_key_request',
          message: 'Supply only a replacement label and/or API key.',
        });
      }
      for (const field of Object.keys(req.body)) {
        if (field === 'label' && typeof req.body.label !== 'string') {
          return res.status(400).json({ ok: false, error: 'invalid_gemini_key_label' });
        }
        if (field === 'apiKey' && typeof req.body.apiKey !== 'string') {
          return res.status(400).json({ ok: false, error: 'invalid_gemini_key_input' });
        }
      }
      const actorUid = verifiedActor(req);
      if (!actorUid) return res.status(401).json({ ok: false, error: 'authentication_required' });
      const store = await getStoreSafely(getStore);
      const key = await store.updateKey(req.params.id, { ...req.body, actorUid });
      if (!key) return res.status(404).json({ ok: false, error: 'gemini_key_not_found' });
      return res.json({ ok: true, key });
    } catch (error) {
      return sendSafeError(res, error);
    }
  });

  router.patch('/admin/gemini-keys/:id/status', ...guarded, async (req, res) => {
    try {
      if (!isValidId(req.params.id)) {
        return res.status(400).json({ ok: false, error: 'invalid_gemini_key_id' });
      }
      if (!hasOnlyKeys(req.body, ['enabled']) || typeof req.body.enabled !== 'boolean') {
        return res.status(400).json({
          ok: false,
          error: 'invalid_gemini_key_status',
          message: 'Supply only an enabled boolean.',
        });
      }
      const actorUid = verifiedActor(req);
      if (!actorUid) return res.status(401).json({ ok: false, error: 'authentication_required' });
      const store = await getStoreSafely(getStore);
      const key = await store.setEnabled(req.params.id, req.body.enabled, actorUid);
      if (!key) return res.status(404).json({ ok: false, error: 'gemini_key_not_found' });
      return res.json({ ok: true, key });
    } catch (error) {
      return sendSafeError(res, error);
    }
  });

  router.delete('/admin/gemini-keys/:id', ...guarded, async (req, res) => {
    try {
      if (!isValidId(req.params.id)) {
        return res.status(400).json({ ok: false, error: 'invalid_gemini_key_id' });
      }
      const actorUid = verifiedActor(req);
      if (!actorUid) return res.status(401).json({ ok: false, error: 'authentication_required' });
      const store = await getStoreSafely(getStore);
      const deleted = await store.deleteKey(req.params.id, actorUid);
      if (!deleted) return res.status(404).json({ ok: false, error: 'gemini_key_not_found' });
      return res.json({ ok: true, deleted: true });
    } catch (error) {
      return sendSafeError(res, error);
    }
  });

  router.post('/admin/gemini-keys/:id/test', ...guarded, async (req, res) => {
    try {
      if (!isValidId(req.params.id)) {
        return res.status(400).json({ ok: false, error: 'invalid_gemini_key_id' });
      }
      if (!hasOnlyKeys(req.body, ['confirm']) || req.body.confirm !== true) {
        return res.status(400).json({
          ok: false,
          error: 'key_test_confirmation_required',
          message: 'Confirm that this single Gemini request may consume provider quota or incur usage.',
        });
      }
      const actorUid = verifiedActor(req);
      if (!actorUid) return res.status(401).json({ ok: false, error: 'authentication_required' });
      const store = await getStoreSafely(getStore);
      const record = await store.getKeyRecord(req.params.id);
      if (!record) return res.status(404).json({ ok: false, error: 'gemini_key_not_found' });
      const result = await testKey({
        store,
        keyId: req.params.id,
        actorUid,
      });
      const category = SAFE_TEST_CATEGORIES.has(result?.category)
        ? result.category
        : (result?.passed === true ? 'test_success' : 'test_failed');
      return res.json({
        ok: true,
        test: {
          passed: result?.passed === true,
          category,
          retryAfterSeconds: Number.isInteger(result?.retryAfterSeconds)
            ? Math.max(1, Math.min(86_400, result.retryAfterSeconds))
            : null,
          testedAt: typeof result?.testedAt === 'string' ? result.testedAt : null,
        },
      });
    } catch (error) {
      return sendSafeError(res, error);
    }
  });

  return router;
}
