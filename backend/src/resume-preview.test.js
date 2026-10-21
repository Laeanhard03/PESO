import assert from 'node:assert/strict';
import test from 'node:test';

import { hasStructuredResume, renderStructuredResume } from './resume-preview.js';

test('structured resume preview preserves user fields and escapes HTML', () => {
  const profile = {
    displayName: 'Jane <script>alert(1)</script>',
    professionalTitle: 'Data analyst',
    resumeData: {
      summary: 'Learning <b>spreadsheets</b> and operations',
      experience: [{ company: 'Alpha & Beta', years: 2 }],
      skills: ['Reporting', 'Word processing'],
    },
  };
  assert.equal(hasStructuredResume(profile), true);
  const markup = renderStructuredResume(profile);
  assert.ok(markup.includes('Jane &lt;script&gt;'));
  assert.ok(!markup.includes('<script>alert'));
  assert.ok(markup.includes('Alpha &amp; Beta'));
  assert.ok(markup.includes('Learning &lt;b&gt;spreadsheets&lt;/b&gt;'));
  assert.ok(markup.includes('PESO JobKonek'));
});

test('a mere uploaded-resume filename does not create an invented resume preview', () => {
  assert.equal(hasStructuredResume({ resumeData: {
    documentType: 'Uploaded Resume',
    fileName: 'resume.pdf',
    fileExtension: 'pdf',
  } }), false);
  assert.equal(hasStructuredResume({ resumeData: {} }), false);
  assert.equal(hasStructuredResume({ resumeData: { projects: {} } }), false);
});
