# PESO JobKonek - Real Browser + Integration QA Report

## Objective
Experience PESO as first-time applicant, returning applicant and administrator; inject fictional records and verify UI, APIs, database persistence, security and failure recovery. Original live records must be preserved.

## Key Requirements & Constraints
- All E2E traffic went to test-only Firebase Auth Emulator (127.0.0.1:9099) and MongoDB (127.0.0.1:27117, database peso_e2e_browser_20261020), with a QA API on 127.0.0.1:3003.
- Two fictional job listings, fictional admin/applicants and mock Gemini responses were used. NEVER use the QA data as employment decisions. No real Gemini credentials or production applicant data used.
- Production-like API ports 3000/3001/3002 remained online, untouched. No automated public job renewal performed on those processes.

## Architectural & Technical Decisions
- Browser: Chrome + Python Playwright, through existing Flutter QA web preview and React NSRP iframe.
- Backend: existing Node service and real local Go model v1 running against local fake jobs, real local Mongo GridFS with authentication / owner access checks.
- Gemini: deterministic simulated provider for testing including forced 429 RPM/quota behavior, not a real Google API response.
- QA Firebase auth flag in lib/main.dart uses an explicit compile-time opt-in and is restricted to loopback browser origins.

## Completed Work & Verifications
- Backend full tests: 210/210 PASS, latest command npm run check.
- Flutter focused final regressions: 29/29 PASS (registration identity, fallback, admin UI, documents, qualifications, readiness). Dart changed-file analyzer: no issues, and git diff --check clean.
- Isolated authenticated API E2E: 15/15 PASS, twice, including sign-up, NSRP/resume storage, real Go inference, mocked AI extraction, Tagalog translation/cache, unchanged original requirements, profile photo/cross-user isolation, job application and admin gate, signed XLSX export, mock Gemini 429, saved source survival.
- Full headless Chrome newcomer registration/onboarding: 15/15 PASS. New account, upload fictional PDF resume, NSRP form, required-field notification with five highlights, correction clears highlights, actual PDF generated, source data saved, mock AI processing completed, first-time language modal and English selection, two jobs visible, search finds construction vacancy regardless of AI match.
- React NSRP missing-field highlight manually browser-confirmed (five missing to zero); independent browser test passed.
- Returning fictional applicant browser login succeeded; 'Welcome back' correct, AI profile restored across sign-out/sign-in, two private files shown, authenticated embedded two-page NSRP PDF viewer loaded with HTTP 200.
- Private admin spreadsheet anonymous visitor protected by lock screen. QA applicant API gets 403 while QA admin API gets 200 and signed XLSX is valid.
- QA admin login through protected Admin gate loaded fictional dashboard and `/api/admin/users` HTTP200 with 10 fictional applicant records.

## Bugs Found and Fixed
1. AI-extracted resume name incorrectly overwrote the name registered by the applicant and created spurious middle name in NSRP. Fixed using registration_identity_merge.dart: registered identity and contacts are authoritative, AI only proposes truly missing fields. Browser verified, three dedicated regressions added.
2. Bookmarked admin spreadsheet role check was too eager before restored Firebase auth state. Updated admin_live_applicants_page.dart to await first authStateChanges event up to ten seconds, then perform the same server-authoritative MongoDB role check. Source tested by analyzer; signed-in bookmark acceptance NOT yet demonstrated due to emulator harness issue below.

## Open Issues / Limitations
- IMPORTANT: Authenticated LIVE spreadsheet bookmark after a full browser reload remains unverified in isolated QA. In release-mode emulator builds on 127.0.0.1, the installed firebase_auth_web 6.3.0 reconnects to the Google production lookup endpoint rather than emulator on reload; Firebase's emulator session disappears. Observed IndexedDB user record 1 -> 0 and external accounts:lookup HTTP400. Debug/localhost workaround browser automation intermittently times out at initial Flutter screen, so it did not conclusively verify the bookmark. Do not claim it fixed or deployed.
- Upstream firebase_auth_web 6.3.1 contains a correction but requires Firebase core 5.x, incompatible with the project's current firebase_core 4.15.0. No incompatible upgrade/override was applied. Review full FlutterFire compatible release set separately with validation before upgrading.
- No real Firebase/cloud OAuth owner-user journey, real Google Gemini extraction/quota/project dashboard validation, true Microsoft Excel Online workbook sync, real employer PDF evidence review, or production deployment acceptance performed.
- Existing Excel-style live private web register auto-refreshes every 30 seconds. Signed XLSX export is generated from current API records; neither feature is a Microsoft-hosted always-synced workbook.
- Go AI scores are technical advisory outputs; synthetic training metrics do not establish genuine hiring accuracy.
- Browser was tested on desktop dimensions; all-device real production visual acceptance remains outstanding.

## Active Work & Next Moves
1. Verify live Excel bookmark on an owner-controlled valid real Firebase administrator session without modifying user records; if failing on real auth, capture sanitized auth/network trace and fix.
2. When a compatible Firebase package set is selected, test auth reload across localhost, 127.0.0.1 and deployed origins; keep server role checks fail-closed.
3. Test real Gemini 3.8 calls/quota only when explicitly authorized, then verify translation fidelity and profile onboarding fallback during real provider failures.
4. If needing a Microsoft 365-hosted workbook, implement a separate Microsoft Graph/Excel Online integration; never publish protected applicants to a public document.

## Relevant Files & Context
- docs/qa_browser/qa-api-e2e-results.json; docs/qa_browser/qa-browser-complete-results.json; screenshot PNG files.
- docs/qa_browser/qa_final_backend_check.log; qa_final_api_e2e.log; qa_final_flutter_tests.log; qa_final_flutter_analyze.log.
- backend/scripts/qa-e2e-sandbox-server.mjs; backend/scripts/qa-api-e2e.mjs.
- scripts/qa-browser-complete.py; scripts/qa-browser-returning-login.py; scripts/qa-admin-browser-authorized.py; scripts/qa-admin-browser-guard.py; scripts/qa-nsrp-validation-browser.py.
- lib/main.dart; lib/peso_logic/registration_identity_merge.dart; lib/peso_ui/Login_register_pages/auth_ui.dart; lib/peso_ui/Admin/admin_live_applicants_page.dart; test/registration_identity_merge_test.dart.
- docs/PESO_BROWSER_E2E_CHECKPOINT_2026-10-21.md; docs/PESO_SESSION_CONTINUATION_2026-10-20.md.
