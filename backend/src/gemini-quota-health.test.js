import test from 'node:test';
import assert from 'node:assert/strict';
import { nextPacificMidnight, inferGeminiQuotaScope, quotaWaitSeconds } from './gemini-quota-health.js';

test('RPD reset honors DST in Philippine local time (UTC+8)', () => {
  assert.equal(nextPacificMidnight(new Date('2026-07-02T03:00:00Z')).toISOString(),
    '2026-07-02T07:00:00.000Z'); // 15:00 PHT during PDT
  assert.equal(nextPacificMidnight(new Date('2026-11-05T03:00:00Z')).toISOString(),
    '2026-11-05T08:00:00.000Z'); // 16:00 PHT during PST
});
test('quota failure uses exact metric when included and does not assume 1500 RPD', () => {
  const response = { error: { details: [{ violations: [{
    quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
    quotaMetric: 'generativelanguage.googleapis.com/generate_content_free_tier_requests',
  }] }] } };
  assert.deepEqual(inferGeminiQuotaScope(response), { scope: 'daily', metric: 'RPD' });
  assert.deepEqual(inferGeminiQuotaScope({ error: { details: [] } }),
    { scope: 'unknown', metric: 'unspecified' });
  assert.equal(quotaWaitSeconds({ scope: 'minute', providerRetrySeconds: 23 }), 23);
  assert.ok(quotaWaitSeconds({ scope: 'daily', now: new Date('2026-11-05T03:00:00Z') }) > 60);
});
