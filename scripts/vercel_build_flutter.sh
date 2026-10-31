#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="${HOME}/.cache/peso-flutter-sdk/flutter"
if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  echo "Pinned Flutter SDK missing; run scripts/vercel_install_flutter.sh first." >&2
  exit 1
fi
export PATH="${FLUTTER_ROOT}/bin:${PATH}"

# The NSRP and resume screens are bundled inside this Flutter website.
# GitHub main pushes deploy this one frontend through the peso Vercel project.
# Relative workspace URL follows the current preview or production domain.
DART_DEFINES=(
  --dart-define=PESO_NSRP_WORKSPACE_URL=/nsrp/
)

# This single Vercel project serves both Flutter and the Express API.
# Use the browser's current HTTPS origin for /api requests in production and
# preview deployments. Never use a stale external backend environment value.
# Local, non-Vercel builds may still override the API for development.
if [[ -z "${VERCEL_ENV:-}" && -n "${PESO_API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define="PESO_API_BASE_URL=${PESO_API_BASE_URL%/}")
fi

flutter build web --release "${DART_DEFINES[@]}"

# Bundle the existing NSRP form and resume editor inside the Flutter website.
# Vite's nested base keeps assets and its image worker under /nsrp/.
# Enforce the official two-sheet NSRP Form 1 PDF export in the production build.
# The editable form remains unchanged; only the export clone for sheet 2 is compacted.
node --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import fs from 'node:fs';

const replaceOnce = (source, before, after, label) => {
  const count = source.split(before).length - 1;
  assert.equal(count, 1, label + ': expected one source match, found ' + count);
  return source.replace(before, after);
};

const appPath = 'react_workspace/src/App.jsx';
let app = fs.readFileSync(appPath, 'utf8').replace(/\r\n/g, '\n');
if (!app.includes("if (spec.compact) printPage.classList.add('nsrp-print-compact');")) {
  const oldSpecs = [
    "      const formPageTwo = document.getElementById('peso-page-2');",
    '      const pageTwoChildren = formPageTwo ? Array.from(formPageTwo.children) : [];',
    "      const careerSummaryIndex = pageTwoChildren.findIndex((element) =>",
    "        (element.innerText || '').trim().startsWith('APPLICANT CAREER INFORMATION'),",
    '      );',
    "      const pageSpecs = [{ id: 'peso-page-1' }];",
    '      if (formPageTwo && careerSummaryIndex > 0) {',
    '        // Keep official data sections intact and begin certification on its own page.',
    "        pageSpecs.push({ id: 'peso-page-2', start: 0, end: careerSummaryIndex, paddingBottom: '8px' });",
    "        pageSpecs.push({ id: 'peso-page-2', start: careerSummaryIndex, end: pageTwoChildren.length, paddingTop: '16px' });",
    '      } else {',
    "        pageSpecs.push({ id: 'peso-page-2' });",
    '      }',
  ].join('\n');
  const newSpecs = [
    '      // The official NSRP Form 1 has two original sheets. Keep those as the',
    '      // only PDF pages; do not split page 2 at the supplemental career summary.',
    '      const pageSpecs = [',
    "        { id: 'peso-page-1' },",
    "        { id: 'peso-page-2', compact: true },",
    '      ];',
  ].join('\n');
  app = replaceOnce(app, oldSpecs, newSpecs, 'original NSRP page specification');
  app = replaceOnce(
    app,
    '        if (!page) continue;',
    "        if (!page) throw new Error('Missing NSRP source page: ' + spec.id);",
    'NSRP source-page guard',
  );
  app = replaceOnce(
    app,
    "        printPage.removeAttribute('id');",
    "        printPage.removeAttribute('id');\n        if (spec.compact) printPage.classList.add('nsrp-print-compact');",
    'compact print clone',
  );
  for (const line of [
    '        if (spec.paddingBottom) printPage.style.paddingBottom = spec.paddingBottom;',
    '        if (spec.paddingTop) printPage.style.paddingTop = spec.paddingTop;',
  ]) {
    app = replaceOnce(app, line + '\n', '', 'obsolete split-page padding');
  }
  const splitPattern = /        if \(spec\.start != null \|\| spec\.end != null\) \{\n[\s\S]*?        \}\n/g;
  const splitMatches = app.match(splitPattern) || [];
  assert.equal(splitMatches.length, 1, 'Expected one artificial second-sheet split block.');
  app = app.replace(splitPattern, '');
  const oldSlice = [
    '          const sliceHeight = Math.floor(image.width * pdfHeight / pdfWidth);',
    '          for (let top = 0; top < image.height; top += sliceHeight) {',
    '            const segmentHeight = Math.min(sliceHeight, image.height - top);',
    '            const segment = document.createElement(\'canvas\');',
    '            segment.width = image.width;',
    '            segment.height = segmentHeight;',
    '            segment.getContext(\'2d\').drawImage(',
    '              image, 0, top, image.width, segmentHeight,',
    '              0, 0, image.width, segmentHeight,',
    '            );',
    '            if (pdfPageCount > 0) pdf.addPage();',
    "            pdf.addImage(segment.toDataURL('image/jpeg', 0.89), 'JPEG',",
    '              0, 0, pdfWidth, segmentHeight * pdfWidth / image.width);',
    '            pdfPageCount++;',
    '          }',
  ].join('\n');
  const newSlice = [
    '          if (!image.width || !image.height) {',
    "            throw new Error('An NSRP form sheet rendered with empty dimensions.');",
    '          }',
    '          // One original form sheet maps to one A4 page. Preserve the aspect',
    '          // ratio and center it instead of slicing small overflow into a blank page.',
    '          const fitScale = Math.min(',
    '            pdfWidth / image.width,',
    '            pdfHeight / image.height,',
    '          );',
    '          const renderedWidth = image.width * fitScale;',
    '          const renderedHeight = image.height * fitScale;',
    '          const left = (pdfWidth - renderedWidth) / 2;',
    '          const top = (pdfHeight - renderedHeight) / 2;',
    '          if (pdfPageCount > 0) pdf.addPage();',
    '          pdf.addImage(',
    "            image.toDataURL('image/jpeg', 0.89),",
    "            'JPEG',",
    '            left,',
    '            top,',
    '            renderedWidth,',
    '            renderedHeight,',
    '          );',
    '          pdfPageCount++;',
  ].join('\n');
  app = replaceOnce(app, oldSlice, newSlice, 'NSRP A4 page rendering');
  app = replaceOnce(
    app,
    "      if (pdfPageCount === 0) throw new Error('NSRP pages could not be rendered.');",
    "      if (pdfPageCount !== 2) throw new Error('NSRP Form 1 must contain exactly 2 pages; rendered ' + pdfPageCount + '.');",
    'exactly-two-page invariant',
  );
  assert.doesNotMatch(app, /careerSummaryIndex|sliceHeight|spec\.start|spec\.end/);
  fs.writeFileSync(appPath, app, 'utf8');
}

const cssPath = 'react_workspace/src/index.css';
let css = fs.readFileSync(cssPath, 'utf8');
if (!css.includes('.nsrp-print-compact')) {
  css += [
    '',
    '/* Print-only compact layout for the second original NSRP sheet.',
    '   Applied only to the export clone; the editable on-screen form is unchanged. */',
    '.nsrp-print-compact {',
    '  padding: 18px 28px !important;',
    '  font-size: 11px !important;',
    '}',
    '.nsrp-print-compact,',
    '.nsrp-print-compact * {',
    '  line-height: 1.08 !important;',
    '}',
    '.nsrp-print-compact .p-8 { padding: 18px 28px !important; }',
    '.nsrp-print-compact .p-4 { padding: 8px !important; }',
    '.nsrp-print-compact .p-2 { padding: 5px !important; }',
    '.nsrp-print-compact .p-1 { padding: 3px !important; }',
    '.nsrp-print-compact .mb-4 { margin-bottom: 8px !important; }',
    '.nsrp-print-compact .mb-3 { margin-bottom: 6px !important; }',
    '.nsrp-print-compact .mb-8 { margin-bottom: 10px !important; }',
    '.nsrp-print-compact .mt-4 { margin-top: 6px !important; }',
    '.nsrp-print-compact .mt-3 { margin-top: 6px !important; }',
    '.nsrp-print-compact .mt-2 { margin-top: 4px !important; }',
    '.nsrp-print-compact .gap-y-2 { row-gap: 6px !important; }',
    '.nsrp-print-compact .gap-2 { gap: 6px !important; }',
    '.nsrp-print-compact .gap-4 { gap: 10px !important; }',
    '.nsrp-print-compact .h-8 { height: 24px !important; }',
    '.nsrp-print-compact .h-10 { height: 30px !important; }',
    '.nsrp-print-compact .h-20 { height: 56px !important; }',
    '.nsrp-print-compact input[type="checkbox"] {',
    '  width: 14px !important;',
    '  height: 14px !important;',
    '}',
    '.nsrp-print-compact .text-sm { font-size: 11px !important; }',
    '.nsrp-print-compact .text-xs { font-size: 10px !important; }',
    '.nsrp-print-compact [class~="text-[10px]"] { font-size: 9px !important; }',
    '.nsrp-print-compact [class~="text-[9px]"] { font-size: 8px !important; }',
    '.nsrp-print-compact [class~="text-[8px]"] { font-size: 7px !important; }',
    '',
  ].join('\n');
  fs.writeFileSync(cssPath, css, 'utf8');
}

const testPath = 'react_workspace/src/nsrpRequiredFields.test.js';
let tests = fs.readFileSync(testPath, 'utf8').replace(/\r\n/g, '\n');
const oldTestPattern = /test\('NSRP PDF pagination keeps certification intact and numbers physical pages', async \(\) => \{\n[\s\S]*?\n\}\);/g;
const testMatches = tests.match(oldTestPattern) || [];
if (testMatches.length === 1) {
  const dollar = String.fromCharCode(36);
  const newTest = [
    "test('NSRP PDF export keeps exactly two original A4 sheets and numbers them physically', async () => {",
    "  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');",
    "  const styles = await readFile(new URL('./index.css', import.meta.url), 'utf8');",
    "  assert.match(source, /const pageSpecs = \\[\\s*\\{\\s*id: 'peso-page-1'\\s*\\},\\s*\\{\\s*id: 'peso-page-2', compact: true\\s*\\},\\s*\\];/s);",
    "  assert.match(source, /if \\(spec\\.compact\\) printPage\\.classList\\.add\\('nsrp-print-compact'\\)/);",
    "  assert.match(source, /const fitScale = Math\\.min\\(/);",
    "  assert.match(source, /pdfPageCount !== 2/);",
    "  assert.doesNotMatch(source, /careerSummaryIndex|sliceHeight/);",
    "  assert.match(styles, /\\.nsrp-print-compact \\.h-10/);",
    "  assert.match(styles, /\\.nsrp-print-compact \\.text-xs/);",
    "  assert.ok(source.includes('Page ' + dollar + '{pageNumber} of ' + dollar + '{pdfPageCount}'));",
    "});",
  ].join('\n');
  tests = tests.replace(oldTestPattern, newTest);
  fs.writeFileSync(testPath, tests, 'utf8');
} else if (!tests.includes('keeps exactly two original A4 sheets')) {
  throw new Error('Expected one original NSRP pagination test, found ' + testMatches.length);
}

console.log('NSRP export build guard: exactly two original sheets.');
NODE

npm test --prefix react_workspace
npm run lint --prefix react_workspace

npm run build --prefix react_workspace -- --base=/nsrp/
mkdir -p build/web/nsrp
cp -R react_workspace/dist/. build/web/nsrp/