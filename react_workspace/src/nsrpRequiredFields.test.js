import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  collectMissingNsrpFields,
  isCompletePhilippineMobileNumber,
  isEligibleNsrpAge,
} from './nsrpRequiredFields.js';

const greenRequiredKeys = [
  'lastName', 'firstName', 'middleName', 'suffix', 'dateOfBirth', 'sex',
  'religion', 'presentAddress', 'city', 'height', 'email',
  'phone', 'civilStatus', 'employmentStatus', 'preferredOccupation',
  'preferredWorkLocation', 'languageProficiency', 'educationBackground',
  'workExperience', 'otherSkills', 'signature', 'signatureDate',
];

test('Philippine cellphone validation flags incomplete numbers but accepts N/A', () => {
  assert.equal(isCompletePhilippineMobileNumber('09171234567'), true);
  assert.equal(isCompletePhilippineMobileNumber('+639171234567'), true);
  assert.equal(isCompletePhilippineMobileNumber('639171234567'), true);
  assert.equal(isCompletePhilippineMobileNumber('9171234567'), true);
  assert.equal(isCompletePhilippineMobileNumber('N/A'), true);
  assert.equal(isCompletePhilippineMobileNumber('0917123'), false);
  assert.equal(isCompletePhilippineMobileNumber('08171234567'), false);
  assert.equal(isCompletePhilippineMobileNumber('09abc'), false);
});

test('NSRP completion requires a calculated age of at least 18', () => {
  assert.equal(isEligibleNsrpAge('18'), true);
  assert.equal(isEligibleNsrpAge(45), true);
  assert.equal(isEligibleNsrpAge('17'), false);
  assert.equal(isEligibleNsrpAge(''), false);
  assert.equal(isEligibleNsrpAge('unknown'), false);
});

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
    religion: 'Prefer not to say',
    presentAddress: true,
    city: 'Rodriguez',
    height: 'N/A',
    email: 'ana@example.com',
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
    religion: 'Prefer not to say',
    city: 'Rodriguez',
    height: 'N/A',
    email: 'ana@example.com',
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
test('civil status is single-select and incomplete cellphone values receive an orange warning', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /type="radio" name="nsrp-civil-status" value="Single" data-nsrp-group="civilStatus"/);
  assert.match(source, /type="radio" name="nsrp-civil-status" value="Married" data-nsrp-group="civilStatus"/);
  assert.match(source, /type="radio" name="nsrp-civil-status" value="Widowed" data-nsrp-group="civilStatus"/);
  assert.doesNotMatch(source, /type="checkbox" data-nsrp-group="civilStatus"/);
  assert.doesNotMatch(source, /value="Separated"|value="Live-in"|value="Others"/);
  assert.match(source, /How long have you been looking for work\? \(months\)/);
  assert.match(source, /Terminated\/laid off due to calamity/);
  assert.doesNotMatch(source, /Are you actively looking for work\?|Willing to work immediately\?/);
  assert.match(source, /aria-invalid=\{Boolean\(contactNumberWarning\)\}/);
  assert.match(source, /backgroundColor: '#fff7ed'/);
  assert.match(source, /Enter a complete Philippine mobile number/);
});

test('NSRP signature and date controls share a bottom-aligned row', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /flex justify-between items-end gap-8 px-8 mb-8/);
});

test('NSRP PDF export keeps exactly two original A4 sheets and numbers them physically', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  const styles = await readFile(new URL('./index.css', import.meta.url), 'utf8');
  assert.match(source, /const pageSpecs = \[\s*\{\s*id: 'peso-page-1'\s*\},\s*\{\s*id: 'peso-page-2', compact: true\s*\},\s*\];/s);
  assert.match(source, /if \(spec\.compact\) printPage\.classList\.add\('nsrp-print-compact'\)/);
  assert.match(source, /const fitScale = Math\.min\(/);
  assert.match(source, /pdfPageCount !== 2/);
  assert.doesNotMatch(source, /careerSummaryIndex|sliceHeight/);
  assert.match(styles, /\.nsrp-print-compact \.h-10/);
  assert.match(styles, /\.nsrp-print-compact \.text-xs/);
  assert.match(source, /Page \$\{pageNumber\} of \$\{pdfPageCount\}/);
});
test('NSRP instructions identify green-highlighted fields as required', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /For this digital form, green-highlighted fields\/sections are required/);
  assert.doesNotMatch(source, /Green labels are field headings, not the requirement indicator/);
});

test('digital NSRP uses the September 2020 Form 1 title and two-page numbering', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  assert.match(source, /NSRP Form 1/);
  assert.match(source, /September 2020/);
  assert.match(source, /NATIONAL SKILLS REGISTRATION PROGRAM/);
  assert.match(source, /JOBSEEKER REGISTRATION FORM/);
  assert.match(source, /Page 1 of 2/);
  assert.match(source, /Page 2 of 2/);
  assert.match(source, /h-20 w-full flex flex-col justify-end/);
  assert.match(source, /h-7 border-b border-black outline-none text-center/);
  assert.doesNotMatch(source, /January 2017|PESO EMPLOYMENT INFORMATION SYSTEM|OM-25-001/);
  assert.doesNotMatch(source, /PLACE OF BIRTH|CITIZENSHIP|PAG-IBIG NO\.|PHILHEALTH NO\./);
  assert.doesNotMatch(source, /AGE \(calculated\)|Are you actively looking for work\?|Willing to work immediately\?/);
  assert.match(source, /CONTACT NUMBER\/S/);
  assert.match(source, /TIN NO\./);
  assert.match(source, /HEIGHT \(FT\.\)/);
  assert.match(source, /E-MAIL/);
});

test('digital NSRP contains the official education, training, eligibility, work and PESO-only sections', async () => {
  const source = await readFile(new URL('./App.jsx', import.meta.url), 'utf8');
  for (const label of [
    'Currently in school?',
    'Secondary (Non-K12)',
    'Secondary (K-12)',
    'Senior High Strand',
    'Graduate Studies/Post-graduate',
    'SCHOOL / COURSE',
    'TRAINING / VOCATIONAL COURSE',
    'HOURS OF TRAINING',
    'TRAINING INSTITUTION',
    'SKILLS ACQUIRED',
    'CAREER SERVICE / BOARD / BAR',
    'LICENSE NUMBER',
    'DATE TAKEN',
    'NUMBER OF',
    'OTHER SKILLS ACQUIRED WITHOUT CERTIFICATE',
    'DILEEP',
    'TESDA Training',
    'Referred to:',
  ]) {
    assert.ok(source.includes(label), 'Expected official NSRP field: ' + label);
  }
  assert.doesNotMatch(source, /APPLICANT CAREER INFORMATION/);
  assert.ok(source.indexOf('HOURS OF TRAINING') < source.indexOf('TRAINING INSTITUTION'));
  assert.ok(source.indexOf('TRAINING INSTITUTION') < source.indexOf('SKILLS ACQUIRED'));
  assert.ok(source.indexOf('LICENSE NUMBER') < source.indexOf('DATE TAKEN'));
  assert.ok(source.indexOf('DATE TAKEN') < source.indexOf('VALID UNTIL'));
});

test('resume completion requires a verified applicant photo and does not inject sample-content warnings', async () => {
  const source = await readFile(new URL('./ResumeApp.jsx', import.meta.url), 'utf8');
  assert.match(source, /isVerifiedResumePhoto\(photo, photoValidation\.status\)/);
  assert.match(source, /A verified profile photo is required before generating your resume/);
  assert.match(source, /disabled=\{isProcessing \|\| isPhotoChecking \|\| !hasVerifiedPhoto\}/);
  assert.match(source, /aria-describedby="resume-photo-requirement"/);
  assert.match(source, /const hasVerifiedPhoto = isVerifiedResumePhoto\(photo, photoValidation\.status\)/);
  assert.match(source, /previousPhotoStillVerified/);
  assert.match(source, /Your previous verified photo was kept/);
  assert.match(source, /Add Profile Photo/);
  assert.doesNotMatch(source, /TEMPLATE EXAMPLE CONTENT|sampleWarningNode|template warning|Replace the sample name|sample name and contact details/i);
});

test('resume export stays blocked until the applicant has a verified photo and education details', async () => {
  const source = await readFile(new URL('./ResumeApp.jsx', import.meta.url), 'utf8');
  const photoGuard = source.indexOf('if (isPhotoChecking || !hasVerifiedPhoto)');
  const educationValidation = source.indexOf('const missing = validateApplicantEssentials(essentialSnapshot, { nsrp: false });');
  const processingStart = source.indexOf('setIsProcessing(true);', educationValidation);

  assert.ok(photoGuard >= 0, 'photo verification must guard resume export');
  assert.ok(educationValidation > photoGuard, 'education validation must run before export');
  assert.ok(processingStart > educationValidation, 'PDF generation must not start before education validation');
  assert.match(source, /education: careerEducation/);
  assert.match(source, /<select aria-label="Resume highest education" aria-required="true"/);
  assert.match(source, /Choose your education/);
});
