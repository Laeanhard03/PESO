import assert from 'node:assert/strict';
import test from 'node:test';
import { resolveAdminReportEmailConfig, sendAdminWorkbookEmail } from './admin-report-email.js';

const env = {
  PESO_SMTP_HOST: 'smtp.example.test',
  PESO_SMTP_PORT: '587',
  PESO_SMTP_USER: 'reports@example.test',
  PESO_SMTP_PASS: 'test',
  PESO_SMTP_FROM: 'reports@example.test',
  PESO_REPORT_EMAIL: 'peso.rod@gmail.com',
};

test('email delivery is disabled when SMTP is not configured', () => {
  assert.throws(() => resolveAdminReportEmailConfig({}), error => {
    assert.equal(error.code, 'email_delivery_not_configured');
    return true;
  });
});

test('rejects email delivery until a PESO-approved recipient is explicitly configured', () => {
  assert.throws(
    () => resolveAdminReportEmailConfig({ ...env, PESO_REPORT_EMAIL: '' }),
    error => error.code === 'email_delivery_not_configured' &&
      /approved PESO mailbox/.test(error.message),
  );
});
test('rejects invalid SMTP port or report recipient', () => {
  assert.throws(() => resolveAdminReportEmailConfig({ ...env, PESO_SMTP_PORT: '70000' }), /valid TCP port/);
  assert.throws(() => resolveAdminReportEmailConfig({ ...env, PESO_REPORT_EMAIL: 'not-an-email' }), /recipient is invalid/);
});

test('secure transport defaults to port 465 unless explicitly overridden', () => {
  assert.equal(resolveAdminReportEmailConfig({ ...env, PESO_SMTP_PORT: '465' }).secure, true);
  assert.equal(resolveAdminReportEmailConfig({ ...env, PESO_SMTP_PORT: '465', PESO_SMTP_SECURE: 'false' }).secure, false);
  assert.equal(resolveAdminReportEmailConfig({ ...env, PESO_SMTP_PORT: '587' }).secure, false);
});

test('defaults to Gmail SMTP settings when account credentials are supplied', () => {
  const config = resolveAdminReportEmailConfig({
    PESO_SMTP_USER: 'my-account@gmail.com',
    PESO_SMTP_PASS: 'test-app-password',
    PESO_REPORT_EMAIL: 'peso.rod@gmail.com',
  });
  assert.equal(config.host, 'smtp.gmail.com');
  assert.equal(config.port, 465);
  assert.equal(config.secure, true);
  assert.equal(config.auth.user, 'my-account@gmail.com');
  assert.equal(config.from, 'my-account@gmail.com');
  assert.equal(config.to, 'peso.rod@gmail.com');
});
test('sends the workbook as an Excel attachment to the configured PESO address', async () => {
  let transportOptions;
  let message;
  const mailer = {
    createTransport(options) {
      transportOptions = options;
      return { async sendMail(value) { message = value; return { messageId: 'test-message-id' }; } };
    },
  };
  const workbook = Buffer.from('xlsx-test-bytes');
  const now = new Date('2026-10-24T00:00:00.000Z');
  const result = await sendAdminWorkbookEmail({ workbook, mailer, env, now });
  assert.equal(transportOptions.host, env.PESO_SMTP_HOST);
  assert.equal(transportOptions.port, 587);
  assert.equal(transportOptions.secure, false);
  assert.equal(transportOptions.auth.user, env.PESO_SMTP_USER);
  assert.equal(transportOptions.auth.pass, env.PESO_SMTP_PASS);
  assert.equal(message.to, 'peso.rod@gmail.com');
  assert.equal(message.from, env.PESO_SMTP_FROM);
  assert.match(message.subject, /2026-10-24/);
  assert.equal(message.attachments.length, 1);
  assert.equal(message.attachments[0].filename, 'peso-jobkonek-applicant-report-2026-10-24.xlsx');
  assert.equal(message.attachments[0].contentType, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  assert.deepEqual(message.attachments[0].content, workbook);
  assert.equal(result.recipient, 'peso.rod@gmail.com');
  assert.equal(result.sentAt, now.toISOString());
});

test('does not attempt delivery for an empty workbook', async () => {
  let transportCreated = false;
  const mailer = { createTransport() { transportCreated = true; return { sendMail() {} }; } };
  await assert.rejects(() => sendAdminWorkbookEmail({ workbook: Buffer.alloc(0), mailer, env }), /empty or unavailable/);
  assert.equal(transportCreated, false);
});
