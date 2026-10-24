const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function configurationError(code, message) {
  return Object.assign(new Error(message), { code });
}

export function resolveAdminReportEmailConfig(env = process.env) {
  const host = String(env.PESO_SMTP_HOST || 'smtp.gmail.com').trim();
  const rawPort = String(env.PESO_SMTP_PORT || '465').trim();
  const port = Number(rawPort);
  const user = String(env.PESO_SMTP_USER || '').trim();
  const pass = String(env.PESO_SMTP_PASS || '');
  const from = String(env.PESO_SMTP_FROM || user).trim();
  const to = String(env.PESO_REPORT_EMAIL || '').trim();

  if (!host || !user || !pass) {
    throw configurationError(
      'email_delivery_not_configured',
      'Configure PESO_SMTP_USER and PESO_SMTP_PASS before emailing applicant reports. Gmail SMTP host/port default to smtp.gmail.com:465; set PESO_SMTP_HOST to override.',
    );
  }
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw configurationError('email_configuration_invalid', 'PESO_SMTP_PORT must be a valid TCP port.');
  }
  if (!to) {
    throw configurationError(
      'email_delivery_not_configured',
      'Set PESO_REPORT_EMAIL to the approved PESO mailbox before sending applicant data.',
    );
  }  if (!EMAIL_PATTERN.test(from) || !EMAIL_PATTERN.test(to)) {
    throw configurationError('email_configuration_invalid', 'The configured sender or PESO report recipient is invalid.');
  }

  const secureValue = String(env.PESO_SMTP_SECURE || '').trim().toLowerCase();
  const secure = secureValue === 'true' ? true
    : secureValue === 'false' ? false
    : port === 465;

  return { host, port, secure, auth: { user, pass }, from, to };
}

export async function sendAdminWorkbookEmail({ workbook, mailer, env = process.env, now = new Date() } = {}) {
  if (!(Buffer.isBuffer(workbook) || workbook instanceof Uint8Array) || workbook.length === 0) {
    throw configurationError('email_workbook_invalid', 'The Excel report is empty or unavailable.');
  }
  if (!mailer || typeof mailer.createTransport !== 'function') {
    throw configurationError('email_transport_unavailable', 'The email transport is unavailable.');
  }

  const config = resolveAdminReportEmailConfig(env);
  const transport = mailer.createTransport({
    host: config.host, port: config.port, secure: config.secure, auth: config.auth,
  });
  const date = new Date(now).toISOString().slice(0, 10);
  await transport.sendMail({
    from: config.from,
    to: config.to,
    subject: 'PESO JobKonek applicant and application Excel report - ' + date,
    text: 'The current PESO JobKonek Excel report is attached for authorized PESO administration. Handle applicant information as confidential personal data.',
    attachments: [{
      filename: 'peso-jobkonek-applicant-report-' + date + '.xlsx',
      content: Buffer.from(workbook),
      contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    }],
  });
  return { recipient: config.to, sentAt: new Date(now).toISOString() };
}
