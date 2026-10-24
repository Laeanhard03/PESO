import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { collectMissingNsrpFields } from './nsrpRequiredFields.js';

const greenRequiredKeys = [
  'lastName', 'firstName', 'middleName', 'suffix', 'dateOfBirth', 'sex',
  'placeOfBirth', 'religion', 'presentAddress', 'city', 'height', 'email',
  'landline', 'phone', 'civilStatus', 'employmentStatus', 'preferredOccupation',
  'preferredWorkLocation', 'languageProficiency', 'educationBackground',
  'workExperience', 'otherSkills', 'signature', 'signatureDate',
];

test('NSRP requires the green-highlighted fields/sections, not unhighlighted subfields', () => {
  const missing = collectMissingNsrpFields({});
  assert.deepEqual(missing.map(item => item.key), greenRequiredKeys);
  assert.equal(missing.some(item => ['houseStreet', 'village', 'barangay', 'province', 'age'].includes(item.key)), false);
});

test('accepts populated green fields, selected group choices, and N/A where applicable', () => {
  const input = {
    lastName: 'Santos',
    firstName: 'Ana',
    middleName: 'N/A',
    suffix: 'N/A',
    dateOfBirth: true,
    sex: true,
    placeOfBirth: 'Montalban, Rizal',
    religion: 'Prefer not to say',
    presentAddress: true,
    city: 'Rodriguez',
    height: 'N/A',
    email: 'ana@example.com',
    landline: 'N/A',
    phone: '09171234567',
    civilStatus: true,
    employmentStatus: true,
    preferredOccupation: 'Open to opportunities',
    preferredWorkLocation: 'N/A',
    languageProficiency: true,
    educationBackground: 'N/A',
    workExperience: 'N/A',
    otherSkills: true,
    signature: true,
    signatureDate: '2026-10-24',
  };
  assert.deepEqual(collectMissingNsrpFields(input), []);
});

test('green field sections stay missing until entered or explicitly marked N/A', () => {
  const missing = collectMissingNsrpFields({
    lastName: 'Santos',
    firstName: 'Ana',
    dateOfBirth: true,
    sex: true,
    middleName: 'N/A',
    suffix: 'N/A',
    placeOfBirth: 'Rodriguez',
    religion: 'Prefer not to say',
    city: 'Rodriguez',
    height: 'N/A',
    email: 'ana@example.com',
    landline: 'N/A',
    phone: 'N/A',
    civilStatus: false,
    employmentStatus: false,
    preferredOccupation: '',
    preferredWorkLocation: false,
    languageProficiency: false,
    educationBackground: '',
    workExperience: '',
    otherSkills: false,
    signature: false,
    signatureDate: '',
  });
  assert.deepEqual(missing.map(item => item.key), [
    'presentAddress', 'civilStatus', 'employmentStatus', 'preferredOccupation',
    'preferredWorkLocation', 'languageProficiency', 'educationBackground',
    'workExperience', 'otherSkills', 'signature', 'signatureDate',
  ]);
});

test('NSRP form connects each green required field/section to submit validation and red highlighting', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  for (const key of greenRequiredKeys) {
    assert.ok(
      source.includes('data-applicant-field="' + key + '"') ||
      source.includes('data-nsrp-required="' + key + '"') ||
      source.includes('data-nsrp-group="' + key + '"') ||
      source.includes(key + ':'),
      'Expected NSRP field/group wiring for ' + key,
    );
  }
  assert.match(source, /collectMissingNsrpFields\(/);
  assert.match(source, /data-nsrp-required.*data-nsrp-group/s);
  assert.match(source, /Please complete the green-highlighted required fields/);
});
test('only green-highlighted NSRP fields block form completion; supplemental career data is optional', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /Only green-highlighted NSRP fields\/sections block completion/);
  assert.match(source, /OPTIONAL FOR BETTER JOB SUGGESTIONS/);
  assert.doesNotMatch(source, /if \(missing\.length\) \{/);
  assert.match(source, /if \(officialMissing\.length\) \{/);
  assert.doesNotMatch(source, /Please complete your name, an email or mobile number, city and one preferred occupation/);
});
test('NSRP PDF pagination keeps certification intact and numbers physical pages', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /const careerSummaryIndex = pageTwoChildren\.findIndex/);
  assert.match(source, /startsWith\('APPLICANT CAREER INFORMATION'\)/);
  assert.match(source, /pageSpecs\.push\(\{ id: 'peso-page-2', start: 0, end: careerSummaryIndex/s);
  assert.match(source, /pageSpecs\.push\(\{ id: 'peso-page-2', start: careerSummaryIndex, end: pageTwoChildren\.length/s);
  assert.ok(source.includes('pdf.text(`Page ${pageNumber} of ${pdfPageCount}`'), 'Expected page footer to use the final physical page count.');
});
test('NSRP instructions identify green-highlighted fields as required', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /Green-highlighted fields\/sections are required/);
  assert.match(source, /Complete every green-highlighted field or section/);
  assert.doesNotMatch(source, /Green labels are field headings, not the requirement indicator/);
});