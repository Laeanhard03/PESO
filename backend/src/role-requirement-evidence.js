/**
 * Validate Gemini-suggested role qualifications against independent PDF.js
 * text. Gemini output is untrusted: its self-declared verified/mandatory flags
 * have no authority. In scanned/image-only PDFs a source review is required.
 *
 * This module must not import applicant profiles, Gemini keys, or ML training.
 */
const MAX_PER_NOTICE = 60;
const MAX_REQUIREMENT = 200;
const MAX_QUOTE = 420;

function bounded(value, max) {
  return typeof value === 'string'
    ? value.normalize('NFKC').replace(/\s+/gu, ' ').trim().slice(0, max)
    : '';
}
function canonical(value) {
  return bounded(value, 1200).normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ').trim();
}
function evidenceText(value) {
  return typeof value === 'string'
    ? value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9]+/g, ' ').replace(/\s+/g, ' ').trim()
    : '';
}
// Conservative: protected and sensitive hiring criteria are never promoted.
const PROTECTED = /\b(?:male|female|men|women|man|woman|boys?|girls?|ladies|gentlemen|gender|sex|marital|civil status|religion|aged?|birth\s*date|date of birth|pregnan\w*|pwd|person with disability|years? old|yrs? old|must be single)\b|\b[fm]\s*\/\s*[fm]\b/i;
const MANDATORY = /\b(?:required|must|mandatory|minimum|at least|shall|needs? to)\b/i;
// Negation or ambiguous qualifiers are grounds for human review, never a gap.
const NEGATED_MANDATORY = /\b(?:not|no)\s+(?:\w+\s+){0,2}(?:required|mandatory|necessary|needed)\b/i;
const PREFERRED = /\b(?:preferred|preferably|advantage|a plus|desirable|optional)\b/i;

function uniqueRoles(roles) {
  const roleMap = new Map();
  for (const role of Array.isArray(roles) ? roles : []) {
    const title = bounded(role, 160);
    if (title && !roleMap.has(canonical(title))) roleMap.set(canonical(title), title);
  }
  return roleMap;
}
function explicitRoleLead(quote, role) {
  // "ROLE: requirement" or "ROLE - requirement", not a neighboring role's
  // requirements mentioned later in the same notice.
  const normalizedQuote = bounded(quote, MAX_QUOTE);
  const escaped = role.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    .replace(/\s+/g, '\\s+');
  const pattern = new RegExp('^\\s*' + escaped + '\\s*[:\\-\\u2013\\u2014]\\s*', 'i');
  return pattern.test(normalizedQuote);
}
function pageTextByNumber(pages) {
  const source = new Map();
  for (const entry of Array.isArray(pages) ? pages : []) {
    const page = Number(entry?.pageNumber);
    if (!Number.isInteger(page) || page <= 0) continue;
    const text = String(entry?.text || '');
    if (text.length && text.length <= 250000) source.set(page, evidenceText(text));
  }
  return source;
}

/**
 * Extra roleRequirements proposed by Gemini are only promoted when role,
 * requirement, exact page, explicit qualifier, and independent PDF source
 * quote all agree. Unknown classifications remain pending human source review.
 */
export function inspectRoleRequirements(listing, {
  start = 1, end = start, independentPages = [],
} = {}) {
  const roles = uniqueRoles(listing?.roles);
  const sourceText = pageTextByNumber(independentPages);
  const proposed = Array.isArray(listing?.roleRequirements)
    ? listing.roleRequirements.slice(0, MAX_PER_NOTICE)
    : [];
  const output = [];
  const seen = new Set();
  for (const item of proposed) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
    const role = roles.get(canonical(item.role));
    const requirement = bounded(item.requirement, MAX_REQUIREMENT);
    const quote = bounded(item.evidenceQuote, MAX_QUOTE);
    const page = Number(item.page);
    if (!role || !requirement || !Number.isInteger(page) ||
        page < start || page > end) continue;
    const key = canonical(role) + '|' + canonical(requirement) + '|' + page;
    if (seen.has(key)) continue;
    seen.add(key);
    const suggested = String(item.kind || '').toLowerCase();
    const kind = ['mandatory', 'preferred'].includes(suggested) ? suggested : 'unknown';
    let status = 'needs_source_review';
    const isProtected = PROTECTED.test(requirement) || PROTECTED.test(quote);
    // Reject a Gemini quote spanning multiple role headings; otherwise a
    // requirement from a following role could be attributed to the first.
    const otherRoleHeading = [...roles.values()].some((candidate) =>
      candidate !== role && quote.toLowerCase().includes(candidate.toLowerCase() + ':'));
    if (isProtected) status = 'excluded_protected';
    else if (otherRoleHeading) status = 'needs_source_review';
    else if (!quote || !explicitRoleLead(quote, role) ||
        !evidenceText(quote).includes(evidenceText(requirement))) {
      status = 'needs_source_review';
    } else if (kind === 'mandatory' &&
        MANDATORY.test(quote) && !NEGATED_MANDATORY.test(quote) &&
        !PREFERRED.test(requirement) && !PREFERRED.test(quote)) {
      if (sourceText.get(page)?.includes(evidenceText(quote))) {
        status = 'source_text_correlated';
      }
    } else if (kind === 'preferred' &&
        PREFERRED.test(quote) && !MANDATORY.test(requirement)) {
      if (sourceText.get(page)?.includes(evidenceText(quote))) {
        status = 'source_text_correlated';
      }
    }
    output.push({
      role, requirement, page, kind, status,
      // Evidence is public employer source text, not applicant information.
      evidenceQuote: quote,
    });
  }
  return output;
}

export function attributedRequirementsForRole(listing, role) {
  const expected = canonical(role);
  const rows = (Array.isArray(listing?.roleRequirements) ? listing.roleRequirements : [])
    .filter(row => canonical(row?.role) === expected &&
      row?.status === 'source_text_correlated' && row?.kind !== 'unknown');
  const active = new Set();
  const accepted = [];
  const pending = [];
  for (const item of (Array.isArray(listing?.roleRequirements) ? listing.roleRequirements : [])) {
    if (canonical(item?.role) !== expected) continue;
    const text = bounded(item?.requirement, MAX_REQUIREMENT);
    if (!text) continue;
    if (item?.status !== 'source_text_correlated' || item?.kind === 'unknown') {
      if (!PROTECTED.test(text)) pending.push(text);
      continue;
    }
    if (!rows.includes(item) || PROTECTED.test(text) || PROTECTED.test(item?.evidenceQuote)) continue;
    const qualifier = item.kind === 'preferred' ? ' preferred' : ' required';
    const fullText = role + ': ' + text + qualifier;
    if (!active.has(canonical(fullText))) {
      active.add(canonical(fullText));
      accepted.push(fullText);
    }
  }
  return { accepted, pending, candidates: rows.length, reviewNeeded: pending.length > 0 };
}
