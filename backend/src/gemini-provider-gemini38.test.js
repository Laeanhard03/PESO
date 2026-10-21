import assert from 'node:assert/strict';
import test from 'node:test';

import { createGeminiProvider } from './gemini-provider.js';

const unsupportedSamplingParameters = ['temperature', 'topP', 'topK', 'candidateCount'];

test('Gemini 3.8 requests omit deprecated sampling parameters for query, profile extraction, and key tests', async () => {
  const cases = [
    { operation: 'query', payload: { prompt: 'A minimal compatibility test.' } },
    { operation: 'profile_extraction', payload: { parts: [{ text: 'Extract only supported facts.' }] } },
    { operation: 'key_test', payload: {} },
  ];

  for (const item of cases) {
    let capturedUrl = '';
    let capturedBody = null;
    const provider = createGeminiProvider({
      fetchImpl: async (url, options) => {
        capturedUrl = url;
        capturedBody = JSON.parse(options.body);
        const text = item.operation === 'profile_extraction'
          ? JSON.stringify({ fullName: 'Example User' })
          : 'OK';
        return {
          ok: true,
          status: 200,
          headers: { get: () => null },
          json: async () => ({
            candidates: [{ content: { parts: [{ text }] } }],
          }),
        };
      },
    });

    const result = await provider({
      apiKey: 'fake-key-for-gemini-38-compatibility-test',
      model: 'gemini-3.8-flash',
      operation: item.operation,
      payload: item.payload,
    });

    assert.ok(capturedBody, item.operation + ' request body captured');
    assert.equal(
      capturedUrl,
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
    );
    for (const parameter of unsupportedSamplingParameters) {
      assert.equal(
        Object.hasOwn(capturedBody.generationConfig, parameter),
        false,
        item.operation + ' must not send deprecated ' + parameter,
      );
    }
    assert.ok(result.text || result.profile, item.operation + ' parses a successful response');
  }
});

test('Gemini 3.8 key test gives the model enough output budget and low thinking effort', async () => {
  let body;
  const provider = createGeminiProvider({
    fetchImpl: async (_url, options) => {
      body = JSON.parse(options.body);
      return {
        ok: true,
        status: 200,
        headers: { get: () => null },
        json: async () => ({
          candidates: [{ content: { parts: [{ text: 'OK' }] } }],
        }),
      };
    },
  });

  await provider({
    apiKey: 'fake-key-for-gemini-38-connectivity-test',
    model: 'gemini-3.8-flash',
    operation: 'key_test',
    payload: {},
  });

  assert.ok(body.generationConfig.maxOutputTokens >= 32);
  assert.equal(body.generationConfig.thinkingConfig?.thinkingLevel, 'low');
});
