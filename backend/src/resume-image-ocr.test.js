import test from 'node:test';
import assert from 'node:assert/strict';

import { extractResumeImageTexts, RESUME_IMAGE_OCR_LIMITS } from './resume-image-ocr.js';

function fakeWorkerFactory(recognize, calls = {}) {
  return async (language, oem, options) => {
    calls.language = language;
    calls.oem = oem;
    calls.options = options;
    return {
      recognize,
      async terminate() { calls.terminated = true; },
    };
  };
}

test('resume image OCR returns independently transcribed text and confidence', async () => {
  const calls = {};
  const result = await extractResumeImageTexts([
    { bytes: Buffer.from('synthetic-image'), mimeType: 'image/jpeg' },
  ], {
    cachePath: 'unused-test-cache',
    imageDecoder: async () => ({ width: 2400, height: 3200 }),
    imageEncoder: async (_image, width, height) => {
      assert.equal(width, 2100);
      assert.equal(height, 2800);
      return Buffer.from('prepared-image');
    },
    workerFactory: fakeWorkerFactory(async (bytes) => {
      assert.equal(bytes.toString(), 'prepared-image');
      return { data: { text: 'Data Entry, MS Excel, Bachelor of Science in Information Technology', confidence: 94.5 } };
    }, calls),
  });

  assert.equal(result.length, 1);
  assert.equal(result[0].status, 'readable');
  assert.equal(result[0].confidence, 94.5);
  assert.equal(result[0].preparedBytes.toString(), 'prepared-image');
  assert.match(result[0].text, /MS Excel/);
  assert.equal(calls.language, 'eng+fil');
  assert.equal(calls.terminated, true);
});

test('low-confidence and empty OCR results are never promoted as readable evidence', async () => {
  const result = await extractResumeImageTexts([
    { bytes: Buffer.from('image-one'), mimeType: 'image/jpeg' },
    { bytes: Buffer.from('image-two'), mimeType: 'image/png' },
  ], {
    cachePath: 'unused-test-cache',
    imageDecoder: async () => ({ width: 1000, height: 1000 }),
    imageEncoder: async () => Buffer.from('prepared'),
    workerFactory: fakeWorkerFactory(async () => {
      const current = resultIndex++;
      return current === 0
        ? { data: { text: 'This is readable text from the document.', confidence: 31 } }
        : { data: { text: '', confidence: 0 } };
    }),
  });
  assert.equal(result[0].status, 'low_confidence');
  assert.equal(result[1].status, 'no_text');
});

let resultIndex = 0;

test('image OCR rejects empty and oversized images before starting a worker', async () => {
  let workerStarted = false;
  await assert.rejects(() => extractResumeImageTexts([
    { bytes: Buffer.alloc(0), mimeType: 'image/jpeg' },
  ], { workerFactory: async () => { workerStarted = true; } }), /resume_ocr_image_size_invalid/);
  await assert.rejects(() => extractResumeImageTexts([
    { bytes: Buffer.alloc(RESUME_IMAGE_OCR_LIMITS.maxImageBytes + 1), mimeType: 'image/jpeg' },
  ], { workerFactory: async () => { workerStarted = true; } }), /resume_ocr_image_size_invalid/);
  assert.equal(workerStarted, false);
});

test('a single malformed image does not prevent OCR of other uploaded pages', async () => {
  let recognized = 0;
  const result = await extractResumeImageTexts([
    { bytes: Buffer.from('bad-image'), mimeType: 'image/jpeg' },
    { bytes: Buffer.from('good-image'), mimeType: 'image/jpeg' },
  ], {
    cachePath: 'unused-test-cache',
    imageDecoder: async (bytes) => {
      if (bytes.toString() === 'bad-image') throw new Error('invalid image');
      return { width: 1200, height: 1600 };
    },
    imageEncoder: async () => Buffer.from('prepared'),
    workerFactory: fakeWorkerFactory(async () => {
      recognized++;
      return { data: { text: 'Employment history and office administration experience.', confidence: 88 } };
    }),
  });
  assert.equal(result[0].status, 'image_ocr_failed');
  assert.equal(result[1].status, 'readable');
  assert.equal(recognized, 1);
});
