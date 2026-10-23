# PESO JobKonek prototype privacy notice — approval checklist

Date: 2026-10-23
Source file: `lib/peso_ui/Login_register_pages/privacy_notice.dart`
Consent endpoint: `PUT /api/account/privacy-consent`
Current version: `prototype-2026-10-23`

## Implemented in code

- Separate acceptance for Terms and Conditions / Privacy Notice and affirmative processing consent, including the NSRP fields users submit.
- The email-registration and Google-registration paths are blocked until both checkboxes are accepted.
- Email registration carries both consent timestamps through verification; consent is persisted after the verification step.
- The authenticated backend records both timestamps and a server timestamp, stores the consent flags, and pins the record to the server's current notice version.
- Missing consent flags are rejected with `400 consent_required`; stale policy versions are rejected with `409 privacy_policy_version_mismatch`.
- The notice describes categories of data, purposes, AI processing, recipient classes, hosting/processor categories, security, rights, and the retention-schedule dependency.
- The UI warns users not to submit real applicant data to this unapproved prototype.

## Public sources used

- National Privacy Commission, **The Rights of Data Subjects**: https://privacy.gov.ph/data-subject-rights/ . It lists rights including being informed, access, objection, rectification, erasure/blocking, portability, damages and filing a complaint.
- National Privacy Commission, **Right to Be Informed**: https://privacy.gov.ph/the-right-to-be-informed/ . It says notices should disclose data categories, purposes, legal basis where applicable, method/scope, recipients, automated processing/profiling, controller identity/contact, retention period, and data-subject rights.
- CALABARZON Development Council directory PDF: https://calabarzon.depdev.gov.ph/wp-content/uploads/2025/09/CGRP-Directory_aoAug2925.pdf . It lists `municipalityofmontalban@gmail.com` as a general contact for the Municipal Government of Rodriguez (Montalban). It is **not** a verified DPO contact.

## Still requires a real-world approval owner

These are not facts the prototype can safely invent. The responsible LGU must confirm them before production use:

1. The exact Personal Information Controller / service operator and its representative.
2. The designated Data Protection Officer's name and direct contact details, plus a privacy-request and complaint workflow.
3. The approved lawful basis for each processing purpose, especially the sensitive personal information in NSRP Form 1.
4. The exact records-retention and disposal schedule for account, residency-review, resume, NSRP, application, AI, audit and backup records.
5. Current provider list, hosting/storage regions, international transfers, processor agreements and retention/deletion behavior for Firebase/Google, MongoDB hosting, Vercel and Google Gemini.
6. An approved incident/breach response and a review of whether separate notices/consents are needed for minors, optional AI processing, or employer referrals.
7. Legal review of the terms and the final notice before the prototype warning is removed.

Until those decisions are approved and reflected in a new policy version, keep the notice labelled as a prototype and do not use it to collect real jobseeker data. No production database records were changed for this checklist.
