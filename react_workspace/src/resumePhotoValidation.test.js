import assert from 'node:assert/strict';
import test from 'node:test';
import {
  hasSuitablePortraitFace,
  validatePhotoFile,
  validateResumePhoto,
} from './resumePhotoValidation.js';

const imageFile = (type = 'image/jpeg', size = 120_000) => ({ type, size });
const face = ({
  score = 0.92,
  topLeft = [100, 100],
  bottomRight = [180, 205],
} = {}) => ({ probability: [score], topLeft, bottomRight });

test('accepts JPG and PNG metadata within the existing 2 MB limit', () => {
  assert.equal(validatePhotoFile(imageFile('image/jpeg')).valid, true);
  assert.equal(validatePhotoFile(imageFile('image/png')).valid, true);
  assert.equal(validatePhotoFile(imageFile('image/jpeg', 2_000_001)).valid, false);
  assert.equal(validatePhotoFile(imageFile('image/gif')).valid, false);
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
  const result = await validateResumePhoto(imageFile('image/gif'), {
    loadModel: async () => { initialized = true; return { estimateFaces: async () => [] }; },
  });
  assert.equal(result.valid, false);
  assert.equal(initialized, false);
});
