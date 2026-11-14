import assert from 'node:assert/strict';
import test from 'node:test';
import {
  hasSuitablePortraitFace,
  isVerifiedResumePhoto,
  optimizeResumePhoto,
  validatePhotoFile,
  validateResumePhoto,
} from './resumePhotoValidation.js';

const imageFile = (type = 'image/jpeg', size = 120_000) => ({ type, size });
const face = ({
  score = 0.92,
  topLeft = [100, 100],
  bottomRight = [180, 205],
} = {}) => ({ probability: [score], topLeft, bottomRight });

test('resume generation requires a previously verified JPG or PNG data URL', () => {
  assert.equal(isVerifiedResumePhoto('data:image/jpeg;base64,AAAA', 'success'), true);
  assert.equal(isVerifiedResumePhoto('data:image/png;base64,AAAA', 'success'), true);
  assert.equal(isVerifiedResumePhoto(null, 'success'), false);
  assert.equal(isVerifiedResumePhoto('data:image/gif;base64,AAAA', 'success'), false);
  assert.equal(isVerifiedResumePhoto('data:image/jpeg;base64,AAAA', 'checking'), false);
  assert.equal(isVerifiedResumePhoto('data:image/jpeg;base64,AAAA', 'error'), false);
});

test('accepts JPG and PNG uploads up to 5 MiB and rejects larger or unsupported files', () => {
  assert.equal(validatePhotoFile(imageFile('image/jpeg')).valid, true);
  assert.equal(validatePhotoFile(imageFile('image/png')).valid, true);
  assert.equal(validatePhotoFile(imageFile('image/jpeg', 5 * 1024 * 1024)).valid, true);
  assert.equal(validatePhotoFile(imageFile('image/jpeg', 5 * 1024 * 1024 + 1)).valid, false);
  assert.equal(validatePhotoFile(imageFile('image/gif')).valid, false);
});

test('optimizes a valid large upload below the encrypted resume-draft limit', async () => {
  let disposed = false;
  const attempts = [];
  const result = await optimizeResumePhoto(imageFile('image/jpeg', 4_500_000), {
    loadImage: async () => ({
      image: { naturalWidth: 4000, naturalHeight: 3000 },
      dispose: () => { disposed = true; },
    }),
    encodeImage: async (image, width, height, quality) => {
      attempts.push({ width, height, quality });
      const size = width === 1600 ? 2_200_000 : 1_500_000;
      return new Blob([new Uint8Array(size)], { type: 'image/jpeg' });
    },
  });
  assert.equal(result.valid, true);
  assert.ok(result.blob.size <= 1_900_000);
  assert.ok(result.blob.size > 0);
  assert.ok(attempts.length >= 5);
  assert.ok(attempts[0].width <= 1600 && attempts[0].height <= 1600);
  assert.equal(disposed, true);
});

test('rejects an oversized upload before decoding it for optimization', async () => {
  let decoded = false;
  const result = await optimizeResumePhoto(imageFile('image/jpeg', 5 * 1024 * 1024 + 1), {
    loadImage: async () => { decoded = true; return { image: {} }; },
  });
  assert.equal(result.valid, false);
  assert.equal(decoded, false);
});

test('rejects a logo or mascot when no face is detected', () => {
  assert.equal(hasSuitablePortraitFace([], 348, 261), false);
});

test('requires one clear, high-confidence, prominent face', () => {
  assert.equal(hasSuitablePortraitFace([face()], 400, 600), true);
  assert.equal(hasSuitablePortraitFace([
    face(),
    face({ score: 0.88, topLeft: [8, 12], bottomRight: [24, 32] }),
  ], 400, 600), false);
  assert.equal(hasSuitablePortraitFace([face({ score: 0.65 })], 400, 600), false);
  assert.equal(hasSuitablePortraitFace([face({ topLeft: [10, 10], bottomRight: [32, 35] })], 400, 600), false);
  assert.equal(hasSuitablePortraitFace([face(), face({ topLeft: [210, 100], bottomRight: [290, 205] })], 400, 600), false);
  assert.equal(hasSuitablePortraitFace([face()], 0, 600), false);
});

test('returns a useful message when no portrait face is present', async () => {
  const result = await validateResumePhoto(imageFile(), {
    loadImage: async () => ({
      image: { naturalWidth: 348, naturalHeight: 261 },
      dispose() {},
    }),
    loadModel: async () => ({ estimateFaces: async () => [] }),
  });
  assert.equal(result.valid, false);
  assert.match(result.message, /mascots, cartoons/);
});

test('keeps validation fail-closed when the detector cannot load', async () => {
  const result = await validateResumePhoto(imageFile(), {
    loadImage: async () => ({
      image: { naturalWidth: 400, naturalHeight: 600 },
      dispose() {},
    }),
    loadModel: async () => { throw new Error('model unavailable'); },
  });
  assert.equal(result.valid, false);
  assert.match(result.message, /previous photo was kept/);
});

test('does not initialize face detection for unsupported or oversized files', async () => {
  let initialized = false;
  const loadModel = async () => { initialized = true; return { estimateFaces: async () => [] }; };
  const unsupported = await validateResumePhoto(imageFile('image/gif'), { loadModel });
  const oversized = await validateResumePhoto(imageFile('image/jpeg', 5 * 1024 * 1024 + 1), { loadModel });
  assert.equal(unsupported.valid, false);
  assert.equal(oversized.valid, false);
  assert.equal(initialized, false);
});
