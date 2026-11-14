import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');

test('NSRP native dropdowns commit on the first input event and retain change fallback', () => {
  assert.match(source, /const commitSelectValue = \(event, updateState\) =>/);
  assert.ok(source.includes('onInput={event => commitSelectValue(event, setSex)}'));
  assert.ok(source.includes('onChange={event => commitSelectValue(event, setSex)}'));
  assert.ok(source.includes('onInput={event => commitSelectValue(event, setReligion)}'));
  assert.ok(source.includes('onChange={event => commitSelectValue(event, setReligion)}'));

  for (const field of ['education', 'experience', 'skillsStage']) {
    assert.ok(source.includes(`onInput={event => commitCareerChoice('${field}',`));
    assert.ok(source.includes(`onChange={event => commitCareerChoice('${field}',`));
  }
});

test('NSRP DOB fallback stays editable but is excluded from drafts, saved entries, and PDF', () => {
  assert.match(source, /data-nsrp-date-fallback="true"/);
  assert.match(source, /!control\.hasAttribute\('data-nsrp-date-fallback'\)/);
  assert.equal((source.match(/getNsrpControls\(document\)/g) || []).length, 3);
  assert.match(source, /filter\(source => !source\.hasAttribute\('data-nsrp-date-fallback'\)\)/);
  assert.match(source, /filter\(target => !target\.hasAttribute\('data-nsrp-date-fallback'\)\)/);
  assert.match(source, /controlSchemaVersion: 2/);
  assert.match(source, /includeDateFallback: true/);
  assert.match(source, /replacement\.style\.textAlign = computed\.textAlign/);
  assert.match(source, /replacement\.style\.borderBottom = computed\.borderBottom/);
  assert.match(source, /replacement\.style\.verticalAlign = computed\.verticalAlign/);
});
