import assert from 'node:assert/strict';
import test from 'node:test';

import { validateAdminPdfUrl, inspectAdminPdfUrl } from './pdf-link-policy.js';

test('official government HTTPS PDF is accepted', () => {
  assert.equal(
    validateAdminPdfUrl('https://montalban.gov.ph/wp-content/uploads/jobs.pdf'),
    'https://montalban.gov.ph/wp-content/uploads/jobs.pdf',
  );
});
test('untrusted and local URLs are rejected', () => {
  for (const invalid of [
    'http://montalban.gov.ph/jobs.pdf',
    'https://localhost/jobs.pdf',
    'https://example.com/jobs.pdf',
    'https://montalban.gov.ph/jobs.html',
    'https://admin:secret@montalban.gov.ph/jobs.pdf',
  ]) {
    assert.throws(() => validateAdminPdfUrl(invalid), /PDF|HTTPS|approved|URL/i);
  }
});
test('configured allowlist hosts can accept external public PDF', () => {
  assert.equal(
    validateAdminPdfUrl('https://recruitment.example.com/docs/jobs.pdf', ['example.com']),
    'https://recruitment.example.com/docs/jobs.pdf',
  );
});
test('PDF availability preflight enforces response content and size', async () => {
  const result = await inspectAdminPdfUrl('https://montalban.gov.ph/jobs.pdf', {
    fetchImpl: async () => new Response(null, {
      status: 200,
      headers: { 'content-type': 'application/pdf', 'content-length': '1600' },
    }),
  });
  assert.equal(result.declaredBytes, 1600);
  await assert.rejects(
    inspectAdminPdfUrl('https://montalban.gov.ph/jobs.pdf', {
      fetchImpl: async () => new Response('HTML', {
        status: 200, headers: { 'content-type': 'text/html' },
      }),
    }),
    /PDF/,
  );
});


test('document servers that reject HEAD can be checked with a bounded GET', async () => {
  const methods = [];
  const result = await inspectAdminPdfUrl('https://montalban.gov.ph/jobs.pdf', {
    fetchImpl: async (_url, options) => {
      methods.push(options.method);
      assert.equal(options.redirect, 'manual');
      if (options.method === 'HEAD') {
        return new Response(null, { status: 405 });
      }
      assert.equal(options.headers.Range, 'bytes=0-1023');
      return new Response(new Uint8Array([37, 80, 68, 70]), {
        status: 206,
        headers: { 'content-type': 'application/pdf' },
      });
    },
  });
  assert.deepEqual(methods, ['HEAD', 'GET']);
  assert.equal(result.contentType, 'application/pdf');
});



test('official 47.7 MB LRA PDF is accepted but documents beyond 64 MB remain blocked', async () => {
  const lraUrl = 'https://dev.montalban.gov.ph/wp-content/uploads/2020/07/PARA-SA-MONTALBENO.pdf';
  const lra = await inspectAdminPdfUrl(lraUrl, {
    fetchImpl: async (_url, options) => {
      assert.equal(options.method, 'HEAD');
      assert.equal(options.redirect, 'manual');
      return new Response(null, {
        status: 200,
        headers: { 'content-type': 'application/pdf', 'content-length': '47711697' },
      });
    },
  });
  assert.equal(lra.declaredBytes, 47711697);
  await assert.rejects(
    inspectAdminPdfUrl(lraUrl, {
      fetchImpl: async () => new Response(null, {
        status: 200,
        headers: { 'content-type': 'application/pdf', 'content-length': String(65 * 1024 * 1024) },
      }),
    }),
    { code: 'pdf_too_large' },
  );
});
