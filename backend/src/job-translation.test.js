import test from 'node:test';
import assert from 'node:assert/strict';
import { safeTranslationLanguage, jobTranslationSource, readSafeTranslation, translationPrompt } from './job-translation.js';

test('translation is display only and rejects unexpected language', () => {
  assert.equal(safeTranslationLanguage('Tagalog'), 'Tagalog');
  assert.equal(safeTranslationLanguage('Taglish'), 'Taglish');
  assert.equal(safeTranslationLanguage('English'), null);
  assert.equal(safeTranslationLanguage('__proto__'), null);
});
test('translations preserve one-to-one requirement array', () => {
  const original = jobTranslationSource({ title: 'Welder', description: 'Experience needed',
    requirements: ['TESDA NC II', '2 years experience'] });
  assert.equal(readSafeTranslation(JSON.stringify({
    title: 'Manghihinang', description: 'Kailangan ng karanasan',
    requirements: ['TESDA NC II', '2 taon na karanasan'],
  }), original)?.requirements.length, 2);
  assert.equal(readSafeTranslation(JSON.stringify({
    title: 'Manghihinang', description: 'Iba', requirements: ['One'],
  }), original), null);
  assert.equal(readSafeTranslation('not json', original), null);
  assert.match(translationPrompt(original, 'Tagalog'), /untrusted quoted data/);
});
test('content fingerprint invalidates outdated job translations', () => {
  const old = jobTranslationSource({ title: 'Cashier', description: 'Full time' });
  const updated = jobTranslationSource({ title: 'Cashier', description: 'Part time' });
  assert.notEqual(old.sourceHash, updated.sourceHash);
});


test('translation rejects altered numeric and official certification requirements', () => {
  const source = jobTranslationSource({ title: 'Welder II', description: '2 years and TESDA NC II',
    requirements: ['At least 2 years', 'TESDA NC II'] });
  assert.equal(readSafeTranslation(JSON.stringify({
    title: 'Manghihinang II', description: '3 taon at TESDA NC II',
    requirements: ['Hindi bababa sa 2 taon', 'TESDA NC II'],
  }), source), null);
  assert.equal(readSafeTranslation(JSON.stringify({
    title: 'Manghihinang II', description: '2 taon at TESDA NC II',
    requirements: ['Hindi bababa sa 2 taon', 'TESDA NC III'],
  }), source), null);
});
test('public PDF description marker is never sent to the translator', () => {
  const source = jobTranslationSource({ title: 'Cashier',
    description: '[PESO_PUBLIC_PDF_LISTING|title=Source|url=https://example.com/a.pdf|pages=1-2] Open position' });
  assert.equal(source.description, 'Open position');
});
