// The quota API does not expose one universal per-key numeric free-tier limit.
// Detect observed provider failures and respect actual RetryInfo, with Pacific
// midnight as the fallback for an explicitly daily quota violation.
const PT = 'America/Los_Angeles';

export function nextPacificMidnight(now = new Date()) {
  const pieces = new Intl.DateTimeFormat('en-US', {
    timeZone: PT, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now);
  const get = key => Number(pieces.find(item => item.type === key)?.value);
  const utcWall = Date.UTC(get('year'), get('month') - 1, get('day') + 1, 0, 0, 0);
  // Compute the timezone offset at the NEXT reset (important on DST changes).
  const guess = new Date(utcWall + 8 * 60 * 60 * 1000);
  const label = new Intl.DateTimeFormat('en-US', {
    timeZone: PT, timeZoneName: 'shortOffset',
  }).formatToParts(guess).find(item => item.type === 'timeZoneName')?.value || '';
  const match = label.match(/GMT([+-])(\d{1,2})(?::(\d{2}))?/);
  const offset = match
    ? (match[1] === '-' ? -1 : 1) *
      (Number(match[2]) * 60 + Number(match[3] || 0))
    : -480;
  return new Date(utcWall - offset * 60_000);
}

export function inferGeminiQuotaScope(body) {
  const details = Array.isArray(body?.error?.details) ? body.error.details : [];
  const parts = [];
  for (const detail of details) {
    const violations = Array.isArray(detail?.violations) ? detail.violations : [];
    for (const violation of violations) {
      parts.push(String(violation.quotaId || ''), String(violation.quotaMetric || ''));
    }
  }
  const identifiers = parts.join(' ').toLowerCase();
  const scope = /per.?day|daily|requests.?per.?day|rpd/.test(identifiers)
    ? 'daily'
    : /per.?minute|rpm|tpm/.test(identifiers)
      ? 'minute'
      : 'unknown';
  const metric = /token/.test(identifiers)
    ? 'TPM' : /request/.test(identifiers)
      ? scope === 'daily' ? 'RPD' : 'RPM'
      : 'unspecified';
  return { scope, metric };
}

export function quotaWaitSeconds({ scope, providerRetrySeconds, now = new Date() }) {
  const retry = Number(providerRetrySeconds);
  if (Number.isFinite(retry) && retry > 0) {
    return Math.max(1, Math.min(86_400, Math.ceil(retry)));
  }
  if (scope === 'daily') {
    return Math.max(1, Math.min(86_400,
      Math.ceil((nextPacificMidnight(now).getTime() - now.getTime()) / 1000)));
  }
  return 60; // unknown/minute: conservative temporary cooldown; not a quota claim.
}
