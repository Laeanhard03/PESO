import assert from 'node:assert/strict';
import test from 'node:test';

import { createGeminiProvider } from './gemini-provider.js';

function jsonResponse(status, body, headers = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: (name) => headers[name.toLowerCase()] ?? null },
    json: async () => body,
  };
}

test('query provider sends bearer-free API key header and returns only text', async () => {
  let captured;
  const providerCall = createGeminiProvider({
    timeoutMs: 1000,
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return jsonResponse(200, {
        candidates: [{ content: { parts: [{ text: 'Hello from mocked Gemini.' }] } }],
      });
    },
  });
  const result = await providerCall({
    apiKey: 'fake-provider-key-never-a-real-key',
    model: 'gemini-test',
    operation: 'query',
    payload: { prompt: 'What is a mock test?' },
  });
  assert.equal(result.text, 'Hello from mocked Gemini.');
  assert.equal(captured.options.headers['x-goog-api-key'], 'fake-provider-key-never-a-real-key');
  assert.equal(captured.options.headers.authorization, undefined);
  const body = JSON.parse(captured.options.body);
  assert.equal(body.contents[0].parts[0].text, 'What is a mock test?');
  assert.equal(body.generationConfig.maxOutputTokens, 1024);
  assert.equal(JSON.stringify(result).includes('fake-provider-key'), false);
});

test('profile operation returns parsed JSON and retains bounded structured attachments', async () => {
  let captured;
  const providerCall = createGeminiProvider({
    fetchImpl: async (_url, options) => {
      captured = JSON.parse(options.body);
      return jsonResponse(200, {
        candidates: [{ content: { parts: [{ text: JSON.stringify({ fullName: 'Example User', skills: ['typing'] }) }] } }],
      });
    },
  });
  const result = await providerCall({
    apiKey: 'fake-provider-key-for-profile-test',
    model: 'gemini-test',
    operation: 'profile_extraction',
    payload: { parts: [{ text: 'Only infer facts from the supplied resume.' }, { inlineData: { mimeType: 'application/pdf', data: 'ZmFrZQ==' } }] },
  });
  assert.deepEqual(result.profile, { fullName: 'Example User', skills: ['typing'] });
  assert.equal(captured.generationConfig.responseMimeType, 'application/json');
  assert.equal(captured.contents[0].parts[1].inlineData.data, 'ZmFrZQ==');
});

test('document reading operation attaches a Files API reference and returns parsed job notices', async () => {
  let captured;
  const providerCall = createGeminiProvider({
    fetchImpl: async (_url, options) => {
      captured = JSON.parse(options.body);
      return jsonResponse(200, {
        candidates: [{
          content: {
            parts: [{ text: JSON.stringify({
              pages: [{ page: 3, summary: 'Walk-in hiring poster.' }],
              listings: [{ page: 3, company: 'Acme', roles: ['Clerk'], category: 'walk_in_application' }],
            }) }],
          },
          finishReason: 'STOP',
        }],
      });
    },
  });
  const result = await providerCall({
    apiKey: 'fake-provider-key-for-document-test',
    model: 'gemini-3.8-flash',
    operation: 'public_pdf_jobs',
    payload: {
      parts: [
        { text: 'Read pages 3 to 3 of 9.' },
        { fileData: { mimeType: 'application/pdf', fileUri: 'https://generativelanguage.googleapis.com/v1beta/files/abc123' } },
      ],
    },
  });

  assert.equal(result.document.listings[0].company, 'Acme');
  assert.equal(captured.generationConfig.responseMimeType, 'application/json');
  assert.equal(captured.generationConfig.thinkingConfig.thinkingLevel, 'low');
  assert.equal(captured.contents[0].parts[1].fileData.fileUri,
    'https://generativelanguage.googleapis.com/v1beta/files/abc123');
});

test('document reading rejects a non-Gemini file reference', async () => {
  const providerCall = createGeminiProvider({
    fetchImpl: async () => jsonResponse(200, { candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
  });

  await assert.rejects(
    () => providerCall({
      apiKey: 'fake-provider-key-for-document-test',
      model: 'gemini-3.8-flash',
      operation: 'public_pdf_jobs',
      payload: {
        parts: [{ fileData: { mimeType: 'application/pdf', fileUri: 'https://example.test/secret.pdf' } }],
      },
    }),
    (error) => error.code === 'invalid_request' && error.status === 400,
  );
});

test('key connectivity test requests a tiny fixed output and no user-provided prompt', async () => {
  let captured;
  let capturedUrl;
  const providerCall = createGeminiProvider({
    fetchImpl: async (url, options) => {
      capturedUrl = url;
      captured = JSON.parse(options.body);
      return jsonResponse(200, {
        candidates: [{ content: { parts: [{ text: 'OK' }] } }],
      });
    },
  });
  const result = await providerCall({
    apiKey: 'fake-provider-key-for-connectivity-test',
    model: 'gemini-3.8-flash',
    operation: 'key_test',
    payload: {},
  });
  assert.equal(result.text, 'OK');
  assert.equal(capturedUrl, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent');
  assert.equal(captured.generationConfig.maxOutputTokens, 64);
  assert.equal(captured.generationConfig.thinkingConfig.thinkingLevel, 'low');
  assert.match(captured.contents[0].parts[0].text, /connectivity/i);
});

test('429 response is structured for quota-safe stop and preserves Retry-After', async () => {
  const providerCall = createGeminiProvider({
    fetchImpl: async () => jsonResponse(429, {
      error: { status: 'RESOURCE_EXHAUSTED', message: 'Never reveal provider body.' },
    }, { 'retry-after': '31' }),
  });
  await assert.rejects(providerCall({
    apiKey: 'fake-key-for-rate-limit-test',
    model: 'gemini-test',
    operation: 'query',
    payload: { prompt: 'hi' },
  }), (error) => {
    assert.equal(error.status, 429);
    assert.equal(error.code, 'RESOURCE_EXHAUSTED');
    assert.equal(error.retryAfterSeconds, 31);
    assert.equal(error.message.includes('Never reveal'), false);
    return true;
  });
});

test('429 RetryInfo in the response body supplies the retry window when headers are absent', async () => {
  const providerCall = createGeminiProvider({
    fetchImpl: async () => jsonResponse(429, {
      error: {
        status: 'RESOURCE_EXHAUSTED',
        message: 'Quota exceeded for model gemini-3.8-flash. Never echo this provider detail.',
        details: [
          { '@type': 'type.googleapis.com/google.rpc.QuotaFailure', quotaId: 'generate_content_free_tier_requests' },
          { '@type': 'type.googleapis.com/google.rpc.RetryInfo', retryDelay: '78380s' },
        ],
      },
    }),
  });
  await assert.rejects(providerCall({
    apiKey: 'fake-key-for-retryinfo-test',
    model: 'gemini-test',
    operation: 'query',
    payload: { prompt: 'hi' },
  }), (error) => {
    assert.equal(error.status, 429);
    assert.equal(error.retryAfterSeconds, 78380);
    assert.equal(error.message.includes('Never echo'), false);
    return true;
  });
});

test('invalid key response produces a stable category without raw response body', async () => {
  const providerCall = createGeminiProvider({
    fetchImpl: async () => jsonResponse(400, {
      error: { status: 'INVALID_ARGUMENT', message: 'API key not valid. Never echo this provider detail.' },
    }),
  });
  await assert.rejects(providerCall({
    apiKey: 'fake-key-for-invalid-key-test',
    model: 'gemini-test',
    operation: 'query',
    payload: { prompt: 'hi' },
  }), (error) => {
    assert.equal(error.code, 'API_KEY_INVALID');
    assert.equal(error.status, 400);
    assert.equal(error.message.includes('Never echo'), false);
    return true;
  });
});

test('network failures are sanitized while remaining recognizable as transient', async () => {
  const providerCall = createGeminiProvider({
    fetchImpl: async () => {
      const error = new Error('sensitive url?key=not-for-tests');
      error.code = 'ETIMEDOUT';
      throw error;
    },
  });
  await assert.rejects(providerCall({
    apiKey: 'fake-key-for-network-test',
    model: 'gemini-test',
    operation: 'query',
    payload: { prompt: 'hi' },
  }), (error) => {
    assert.equal(error.code, 'ETIMEDOUT');
    assert.equal(error.message.includes('not-for-tests'), false);
    return true;
  });
});

test('provider returns a safe error for malformed JSON and absent candidate text', async () => {
  const malformed = createGeminiProvider({
    fetchImpl: async () => jsonResponse(200, {
      candidates: [{ content: { parts: [{ text: '{invalid' }] } }],
    }),
  });
  await assert.rejects(malformed({
    apiKey: 'fake-key-for-json-test',
    model: 'gemini-test',
    operation: 'profile_extraction',
    payload: { parts: [{ text: 'test' }] },
  }), (error) => {
    assert.equal(error.status, 422);
    assert.equal(error.code, 'invalid_response');
    return true;
  });
});


test('public job translation uses a JSON budget without accessing applicant files', async () => {
  let captured;
  const call = createGeminiProvider({
    fetchImpl: async (_url, options) => {
      captured = JSON.parse(options.body);
      return jsonResponse(200, {
        candidates: [{ content: { parts: [{ text: '{"title":"Manghihinang","description":"2 taon","requirements":["TESDA NC II"]}' }] } }],
      });
    },
  });
  const result = await call({
    apiKey: 'fake-translation-only-key',
    model: 'gemini-3.8-flash',
    operation: 'job_translation',
    payload: { prompt: 'Translate this public vacancy, not any applicant personal information.' },
  });
  assert.equal(result.text.includes('Manghihinang'), true);
  assert.equal(captured.generationConfig.maxOutputTokens, 8192);
  assert.equal(captured.generationConfig.responseMimeType, 'application/json');
  assert.equal(captured.generationConfig.thinkingConfig.thinkingLevel, 'low');
  assert.deepEqual(Object.keys(captured.contents[0].parts[0]), ['text']);
  await assert.rejects(call({
    apiKey: 'fake-translation-only-key', model: 'gemini-3.8-flash',
    operation: 'job_translation',
    payload: { prompt: 'A'.repeat(30_001) },
  }), (err) => err.status === 400);
});
