# PESO Excel Email Delivery

The Admin 'Email Excel to PESO' action sends a fresh workbook generated from the live MongoDB register. It is a manual, authenticated action; the application does not send applicant reports automatically on a timer.

## Required private backend environment

Configure these variables on the backend hosting environment (for example, the Vercel project's private Production Environment Variables). Do not put SMTP credentials in Flutter, React, source control, or client-side environment variables.

- PESO_SMTP_HOST ? SMTP server hostname.
- PESO_SMTP_PORT ? SMTP port; defaults to 465 for Gmail implicit TLS.
- PESO_SMTP_USER ? SMTP account user.
- PESO_SMTP_PASS ? SMTP account password or provider-issued SMTP credential.
- PESO_SMTP_FROM ? optional verified sender address; defaults to PESO_SMTP_USER.
- PESO_SMTP_SECURE ? optional true/false; when omitted, port 465 uses implicit TLS and other ports do not.
- PESO_REPORT_EMAIL - required PESO-approved report recipient. The email action stays disabled until explicitly configured.

After adding or changing the variables, redeploy/restart the backend and test using a non-sensitive QA register first. SMTP providers may require a verified sender address or app-specific credential.

## Gmail account configuration

For a Gmail sender account, the code defaults to **smtp.gmail.com**, port **465**, with implicit TLS. Configure these variables privately on the backend host:

- **PESO_SMTP_USER**: your complete Gmail address (the account that sends the report).
- **PESO_SMTP_PASS**: a Google App Password created for this app; do not use your normal Google password.
- **PESO_SMTP_FROM**: optional; normally the same Gmail address as PESO_SMTP_USER.
- **PESO_REPORT_EMAIL**: required destination. Confirm the address with PESO management before enabling report delivery.

Google requires 2-Step Verification for App Passwords. Visit [Google's official App Password instructions](https://support.google.com/mail/answer/185833?hl=en) while signed into the intended Gmail account, enable 2-Step Verification if needed, and create an app password. If your account is Google Workspace, account policy may disable this option. Keep the generated passcode private and enter it directly into your local private environment or Vercel's sensitive environment-variable field; never paste it into source code, a task note, or this chat.

A SMTP-only starting template is in backend/.env.smtp.example; the existing general backend/.env.example file is left unchanged. Copy it to a private .env only for local development, then replace the placeholder sender and app-password values. For production, set the variables on the backend project's Vercel Environment Variables and redeploy after they are saved. Do not commit .env.
## Access and behavior

POST /api/admin/applications/email-report requires a verified Firebase identity with the MongoDB-backed IT Admin role and a healthy MongoDB connection. The server rebuilds the XLSX from live records, attaches it to the email, and responds with success only after sendMail resolves. Missing configuration returns a service-unavailable response; a provider failure returns a generic delivery error without echoing credential values or raw provider details.

The attached workbook contains applicant personal information and screening/application answers. Treat it as confidential, restrict mailbox access, and retain it only according to PESO/LGU records and privacy policies. This code change did not send any report or alter deployment settings.
