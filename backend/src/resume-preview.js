/** Read-only HTML preview for a resume built from structured onboarding fields.
 * No remote scripts, images or external styles are loaded.
 */
const safe = (raw) => String(raw ?? '').replace(/[&<>"']/g, (ch) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[ch]));

function labelFor(raw) {
  return String(raw || '').replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/[_-]/g, ' ').trim().replace(/\s+/g, ' ');
}

function renderField(key, value, depth = 0) {
  if (value == null || value === '') return '';
  const label = safe(labelFor(key).slice(0, 70));
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    const text = String(value).trim().slice(0, 2400);
    return text ? '<div class="field"><dt>' + label +
      '</dt><dd>' + safe(text) + '</dd></div>' : '';
  }
  if (depth >= 2) return '';
  if (Array.isArray(value)) {
    const items = value.slice(0, 35).map((item) =>
      '<li>' + (item && typeof item === 'object'
        ? safe(Object.entries(item).slice(0, 9)
          .map(([k, v]) => labelFor(k) + ': ' + String(v ?? '').slice(0, 280)).join(' · '))
        : safe(String(item ?? '').slice(0, 280))) + '</li>').join('');
    return items ? '<section class="group"><h3>' + label +
      '</h3><ul>' + items + '</ul></section>' : '';
  }
  if (typeof value === 'object') {
    const fields = Object.entries(value).slice(0, 45)
      .map(([k, v]) => renderField(k, v, depth + 1)).filter(Boolean).join('');
    return fields ? '<section class="group"><h3>' + label +
      '</h3><dl>' + fields + '</dl></section>' : '';
  }
  return '';
}

export function hasStructuredResume(profile) {
  const resume = profile?.resumeData;
  if (!resume || typeof resume !== 'object' || Array.isArray(resume)) return false;
  const keys = Object.keys(resume).filter((key) =>
    !['documentType', 'fileName', 'fileExtension'].includes(key));
  return keys.some((key) => {
    const value = resume[key];
    if (value == null) return false;
    if (Array.isArray(value)) return value.length > 0;
    if (typeof value === 'object') {
      return Object.values(value).some((part) =>
        part != null && String(part).trim() !== '');
    }
    return String(value).trim() !== '';
  });
}

export function renderStructuredResume(profile) {
  if (!hasStructuredResume(profile)) throw new TypeError('No viewable structured resume');
  const resume = profile.resumeData;
  const name = profile.displayName ||
    [profile.firstName, profile.lastName].filter(Boolean).join(' ') ||
    'Applicant Resume';
  const title = profile.professionalTitle || resume.jobTitle || resume.professionalTitle || '';
  const htmlFields = Object.entries(resume).filter(([key]) =>
    !['documentType', 'fileName', 'fileExtension'].includes(key))
    .slice(0, 55)
    .map(([key, value]) => renderField(key, value)).join('');

  return '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>Applicant Resume · PESO</title>' +
    '<style>*{box-sizing:border-box}body{margin:0;background:#f1f7f3;' +
    'font:15px/1.6 system-ui,sans-serif;color:#19362b}.sheet{max-width:790px;' +
    'margin:30px auto;background:white;border:1px solid #d9e6df;border-radius:16px;' +
    'padding:40px;box-shadow:0 10px 28px #152b1d11}h1{font-size:29px;margin:0}' +
    'h2{font-size:15px;font-weight:600;color:#37664b;margin:4px 0 15px}' +
    'h3{font-size:18px;color:#236349;margin:20px 0 7px;border-bottom:1px solid #dfebe2}' +
    'p.note{font-size:12px;color:#66766c}.field{display:grid;grid-template-columns:' +
    '180px 1fr;gap:10px;padding:5px 0;border-bottom:1px solid #edf2ef}' +
    'dt{font-weight:650;text-transform:capitalize}dd{margin:0;white-space:pre-wrap;' +
    'overflow-wrap:anywhere}li{margin:4px 0}@media(max-width:600px){.sheet{margin:0;' +
    'border-radius:0;padding:18px}.field{display:block}dt{margin:6px 0 0}}' +
    '@media print{body{background:#fff}.sheet{box-shadow:none;border:0;margin:0}}</style>' +
    '</head><body><main class="sheet"><h1>' + safe(name) + '</h1>' +
    '<h2>' + safe(title) + '</h2>' +
    '<p class="note">PESO JobKonek · Private administrator preview of the applicant-built resume.' +
    ' Print or save as PDF from your browser if needed.</p><section class="group"><dl>' +
    htmlFields + '</dl></section></main></body></html>';
}
