import test from 'node:test';
import assert from 'node:assert/strict';

import { extractPdfPagesWithOcr } from './public-pdf-extraction.js';

test('text-based PDFs do not invoke OCR', async () => {
  let ocrCalls = 0;
  const pages = [{ pageNumber: 1, text: 'Extracted selectable PDF text '.repeat(20) }];
  const result = await extractPdfPagesWithOcr(Buffer.from('%PDF-test'), {
    textExtractor: async () => pages,
    ocrExtractor: async () => { ocrCalls += 1; return []; },
    minExtractedChars: 100,
  });
  assert.deepEqual(result, pages);
  assert.equal(ocrCalls, 0);
});

test('scanned or text-poor PDFs use the OCR fallback', async () => {
  let ocrCalls = 0;
  const result = await extractPdfPagesWithOcr(Buffer.from('%PDF-scan'), {
    textExtractor: async () => [{ pageNumber: 1, text: '' }],
    ocrExtractor: async () => {
      ocrCalls += 1;
      return [{ pageNumber: 1, text: 'OCR extracted applicant information and requirements.' }];
    },
  });
  assert.equal(ocrCalls, 1);
  assert.match(result[0].text, /applicant information/);
});

test('OCR failure is propagated without claiming extraction succeeded', async () => {
  const error = Object.assign(new Error('ocr unavailable'), { code: 'ocr_language_data_unavailable' });
  await assert.rejects(
    () => extractPdfPagesWithOcr(Buffer.from('%PDF-scan'), {
      textExtractor: async () => [{ pageNumber: 1, text: '' }],
      ocrExtractor: async () => { throw error; },
    }),
    (caught) => caught === error,
  );
});
