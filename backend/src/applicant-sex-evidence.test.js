import test from 'node:test';
import assert from 'node:assert/strict';
import { explicitSexFromResumeText, verifyUploadedResumeSex } from './applicant-sex-evidence.js';

test('verified sex requires an explicit labeled value', () => {
  assert.equal(explicitSexFromResumeText('Resume. Sex: Female; phone: 09').sex, 'Female');
  assert.equal(explicitSexFromResumeText('Gender - Other; City: Montalban').sex, 'Other');
  assert.equal(explicitSexFromResumeText('John Male\nProfessional engineer'), null);
  assert.equal(explicitSexFromResumeText('female portrait photograph'), null);
});

test('unsupported and malformed uploaded documents fail closed', async () => {
  assert.equal(await verifyUploadedResumeSex([], () => Buffer.from([])), null);
  assert.equal(await verifyUploadedResumeSex([{
    category: 'resume_upload', mimeType: 'image/jpeg',
  }], () => Buffer.from('photo')), null);
  assert.equal(await verifyUploadedResumeSex([{
    category: 'resume_upload', mimeType: 'application/pdf',
  }], () => Buffer.from('not pdf')), null);
});
