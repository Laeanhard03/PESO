import assert from 'node:assert/strict';
import test from 'node:test';
import { sanitizeLandingSiteContent } from './landing-site-content.js';

test('accepts safe HTTPS gallery and partner items and returns only allowed fields', () => {
  const result = sanitizeLandingSiteContent({
    gallery: [{ id: 'job-fair-1', title: 'Job Fair', imageUrl: 'https://cdn.example.org/job-fair.jpg', caption: 'PESO activity', ignored: 'drop me' }],
    partners: [{ id: 'partner-1', name: 'Example Employer', logoUrl: 'https://cdn.example.org/logo.png', websiteUrl: 'https://employer.example.org', ignored: true }],
  });
  assert.deepEqual(result.gallery[0], {
    id: 'job-fair-1', title: 'Job Fair',
    imageUrl: 'https://cdn.example.org/job-fair.jpg', caption: 'PESO activity',
  });
  assert.deepEqual(result.partners[0], {
    id: 'partner-1', name: 'Example Employer',
    logoUrl: 'https://cdn.example.org/logo.png',
    websiteUrl: 'https://employer.example.org/',
  });
});

test('rejects HTTP, data URLs, credentials and invalid website URLs', () => {
  for (const imageUrl of [
    'http://cdn.example.org/photo.jpg',
    'data:image/png;base64,AAAA',
    'javascript:alert(1)',
    'https://user:pass@cdn.example.org/photo.jpg',
    'not a url',
  ]) {
    assert.throws(() => sanitizeLandingSiteContent({
      gallery: [{ title: 'Bad', imageUrl }], partners: [],
    }), /HTTPS/);
  }
  assert.throws(() => sanitizeLandingSiteContent({
    gallery: [], partners: [{ name: 'Partner', logoUrl: 'https://cdn.example.org/logo.png', websiteUrl: 'http://example.org' }],
  }), /website URLs/);
});

test('rejects missing labels, malformed lists and item counts above the limit', () => {
  assert.throws(() => sanitizeLandingSiteContent({ gallery: 'not a list', partners: [] }), /must be a list/);
  assert.throws(() => sanitizeLandingSiteContent({
    gallery: [{ title: '', imageUrl: 'https://cdn.example.org/photo.jpg' }], partners: [],
  }), /needs a title/);
  assert.throws(() => sanitizeLandingSiteContent({
    gallery: Array.from({ length: 31 }, (_, i) => ({ title: String(i), imageUrl: 'https://cdn.example.org/photo.jpg' })),
    partners: [],
  }), /at most 30/);
});

test('empty lists intentionally restore the bundled public content', () => {
  assert.deepEqual(sanitizeLandingSiteContent({ gallery: [], partners: [] }), { gallery: [], partners: [], galleryConfigured: false });
});

test('bundled gallery photo links are accepted and deleting all can remain empty', () => {
  const gallery = [{id:'bundled-0', title:'Recruitment', imageUrl:'asset:lib/assets/peso_gallery/peso_local_recruitment_one.jpg', caption:''}];
  assert.deepEqual(sanitizeLandingSiteContent({gallery,partners:[]}).gallery[0],gallery[0]);
  assert.equal(sanitizeLandingSiteContent({gallery:[],partners:[],galleryConfigured:true}).galleryConfigured,true);
  assert.throws(() => sanitizeLandingSiteContent({gallery:[{title:'Unsafe',imageUrl:'asset:lib/assets/secret.jpg'}],partners:[]}),/URLs/);
});
