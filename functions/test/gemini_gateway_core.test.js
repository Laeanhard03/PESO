'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const core = require('../lib/gemini_gateway_core');

test('accepts a concise query payload', () => {
  assert.equal(core.validatePayload({ operation: 'query', prompt: 'Suggest three resume improvements.' }), null);
});
test('rejects missing, blank, and oversized queries', () => {
  assert.match(core.validatePayload({ operation: 'query', prompt: '   ' }), /question/i);
  assert.match(core.validatePayload({ operation: 'query', prompt: 'x'.repeat(core.MAX_QUERY_CHARS + 1) }), /too long/i);
});
test('rejects unknown operations and malformed bodies', () => {
  assert.match(core.validatePayload(null), /JSON object/i);
  assert.match(core.validatePayload({ operation: 'switch_keys', prompt: 'hello' }), /Unsupported operation/i);
});
test('accepts a small supported PDF attachment', () => {
  assert.equal(core.validatePayload({ operation: 'profile_extraction', rawText: '', artifacts: [{ mimeType: 'application/pdf', base64: 'JVBERg==' }] }), null);
});
test('rejects unsupported file types and malformed base64', () => {
  assert.match(core.validatePayload({ operation: 'profile_extraction', artifacts: [{ mimeType: 'application/x-msdownload', base64: 'AAAA' }] }), /Only PDF/i);
  assert.match(core.validatePayload({ operation: 'profile_extraction', artifacts: [{ mimeType: 'application/pdf', base64: '%%%=' }] }), /base64/i);
});
test('requires profile text or at least one attachment', () => {
  assert.match(core.validatePayload({ operation: 'profile_extraction', rawText: ' ', artifacts: [] }), /Provide resume text/i);
});
test('limits attachment counts and bytes', () => {
  const valid = { mimeType: 'image/png', base64: 'AAAA' };
  assert.match(core.validatePayload({ operation: 'profile_extraction', artifacts: [valid, valid, valid, valid] }), /three/i);
  const tooBig = 'A'.repeat(Math.ceil((core.MAX_ARTIFACT_BYTES + 1) * 4 / 3 / 4) * 4);
  assert.match(core.validatePayload({ operation: 'profile_extraction', artifacts: [{ mimeType: 'image/png', base64: tooBig }] }), /4 MB/i);
});
test('only transient 5xx statuses are retryable', () => {
  assert.equal(core.isTransientUpstreamStatus(503), true);
  assert.equal(core.isTransientUpstreamStatus(504), true);
  assert.equal(core.isTransientUpstreamStatus(429), false);
  assert.equal(core.isTransientUpstreamStatus(403), false);
});
test('jittered exponential backoff is bounded', () => {
  assert.equal(core.backoffDelayMs(0, 0), 500);
  assert.equal(core.backoffDelayMs(1, 1), 1350);
  assert.ok(core.backoffDelayMs(99, 1) <= 6350);
});
test('parses and clamps Retry-After guidance', () => {
  assert.equal(core.retryAfterSeconds('12'), 12);
  assert.equal(core.retryAfterSeconds('0'), 1);
  assert.equal(core.retryAfterSeconds('999'), 120);
  assert.equal(core.retryAfterSeconds(null), 30);
});
