# PESO JobKonek — QA continuation checkpoint (2026-10-21)

## Objective
Complete authenticated applicant/admin E2E checks with fictional users, repair private live-register bookmark access, and verify auto-refresh without modifying the production job feed.

## Key Requirements & Constraints
- Preserve the original API on port 3000 and the previous staged port 3001. Do not restart or republish 325 public jobs.
- No test applicant data in production. All QA writes must use local MongoDB (127.0.0.1:27117) and Firebase Auth emulator (127.0.0.1:9099).
- Never leak real API keys, account credentials, ID tokens, or applicant private records in logs or URLs.
- Do not equate fake Gemini extraction with a verified real provider call. Do not report synthetic job-matching outcomes as actual employment accuracy.

## Architectural & Technical Decisions
- QA backend is port 3003 using backend/scripts/qa-e2e-sandbox-server.mjs, explicitly forced to the local Mongo database peso_e2e_browser_20261020, test Firebase identity, no job auto-sync, and simulated Gemini.
- Latest isolated Flutter web build is a static copy under C:\Users\Admin\AppData\Local\Temp\peso-e2e-web-20261021, served at http://127.0.0.1:5243/. It targets QA API 3003 with PESO_E2E_AUTH_EMULATOR=true. Never use this build with production identities.
- The standalone private register is reachable at http://127.0.0.1:5243/?liveApplicants=1 for isolated QA.
- Browser Firebase emulator persistence remained unreliable across tabs: the saved local auth state disappeared during new-tab initialization, despite LOCAL persistence. Rather than passing secrets in links, the private register now provides direct Firebase email/password or Google sign-in and independently verifies the MongoDB admin role with AuthService.getCurrentUserRole(). A non-admin never sees the register. Normal production builds have no emulator flag.
- The register is an authenticated Excel-style web view with an automatic 30-second API polling loop; the XLSX download is a snapshot. It is NOT a Microsoft-hosted live Excel Online workbook.

## Completed Work
- User registration -> upload fictional resume PDF -> NSRP form -> required-field feedback -> saved source files -> simulated Gemini extraction -> Go match -> welcome language -> dashboard passed in the prior isolated browser suite: 15/15.
- Confirmed protected backend integration across synthetic users, translation/cache, private artifact access, job application, admin views, generated XLSX, and synthetic quota 429 with saved-source fallback: 15/15.
- Fixed extraction-to-NSRP trust boundary: resume-derived names/contacts cannot replace registered identity; tests cover conflicting fictional extraction.
- Returning applicant sign-in loaded saved AI profile, NSRP data, fictional PDF, skills and language preferences. Tagalog selection persisted through logout/relogin during prior verification.
- Verified admin second gate via Firebase plus Mongo role and tested in-app View Excel Online dialog with fictional records.
- Repaired standalone bookmarked private register by providing a first-class admin sign-in fallback if Firebase does not restore across tabs. Guest and regular applicant denied, admin authorized, populated rows, manual refresh passed.
- Latest black-box bookmark Chrome test: 9/9 PASS, including repeated successful /api/admin/users queries after the automatic 30-second refresh interval. Screenshot examples: docs/qa_browser/qa_bookmark_login.png, qa_bookmark_nonadmin_denied.png, qa_bookmark_admin_loaded.png.
- Latest real applicant UI simulation: finished 9/9 career-readiness questions, received HTTP 200 from Go /api/ai/job-match, saw the model-backed alignment status on the Outcomes tab, and received HTTP 200 persisting /api/profile/outcomes. Screenshot: docs/qa_browser/qa_job_eval_report.png. This is fictional QA evidence, NOT production hiring accuracy.
- Corrected misleading onboarding copy in lib/peso_ui/User/job_readiness_dialog.dart: the initial questionnaire preview is local, and the trained Go match runs after View full report. Targeted 9/9 Flutter readiness tests and Flutter analysis PASS. Rebuilt Flutter web release and copied to the isolated port 5243 preview with matching SHA256. Chrome confirmed corrected copy and all 9 questions for fictional QA Construction Assistant, Go /api/ai/job-match 200, /api/profile/outcomes 200, and a separate saved matching report visible alongside the earlier data-entry result (28/100 construction vs 51/100 data-entry; both synthetic-trained guidance, NOT hiring decisions). Screenshot docs/qa_browser/qa_job_eval_construction_report.png.
- Backend npm run check: 210/210 PASS; docs/qa_browser/qa_post_bookmark_backend.log.
- Flutter test --no-pub: 138/138 PASS; docs/qa_browser/qa_post_bookmark_flutter_tests.log.
- Go go test -count=1 ./...: PASS; docs/qa_browser/qa_post_bookmark_go.log.
- Flutter release web build with QA flag: PASS; docs/qa_browser/qa_bookmark_build.log.
- React production build: PASS (exit 0) with bundle-size warning only; docs/qa_browser/qa_post_bookmark_react.log.
- Gemini key configuration on separately staged backend port 3002 was detected, but older running backends 3000/3001 were not replaced.

## Active Work & Next Moves
1. Confirm the latest React build result and review the final git diff for unintended changes.
2. Optionally run a controlled live Gemini probe with fictional text, without logging keys or touching real applicant records; real provider quota and successful extraction are not yet proven.
3. Test real deployment/cutover and production authenticated Google flows only with an approved release plan. Do not restart port 3000 automatically.
4. Full app translation is not verified as complete: the Tagalog selection still leaves some UI copy in English (for example, career-readiness question dialog and Outcomes subtitle). Use a systematic localized-strings audit / Flutter l10n migration, not ad-hoc partial translations.
5. A true Microsoft Excel Online workbook that auto-refreshes from PESO requires a Microsoft 365 Graph/Excel integration and owner-managed permissions; existing private live web register is not that workbook.
6. Verify real-world job feed, multi-role hiring notices, editable qualifications, avatars, and reporting under an authorized production-like dataset; isolated tests do not establish live data freshness or actual matching quality.
7. Preserve all pre-existing uncommitted project work. The QA source is intentionally separate from production configuration.

## Relevant Files & Context
- lib/main.dart — localhost-only opt-in Firebase emulator and test-only LOCAL persistence.
- lib/peso_ui/Admin/admin_live_applicants_page.dart — bookmark login fallback with backend admin-role authorization.
- lib/peso_ui/Admin/admin_excel_live_preview.dart — 30s polling, paginated authorized admin table, downloadable XLSX.
- lib/peso_logic/registration_identity_merge.dart — registration identity precedence.
- lib/peso_ui/Login_register_pages/auth_ui.dart — corrected NSRP prefill handoff.
- backend/scripts/qa-e2e-sandbox-server.mjs — QA-only local backend.
- backend/scripts/qa-api-e2e.mjs — authenticated API scenarios.
- scripts/qa-browser-complete.py — first-time registration/browser smoke.
- scripts/qa-browser-bookmark-auth.py — guest/non-admin/admin/refresh browser checks.
- scripts/qa-browser-job-evaluation.py — 9-question browser walkthrough, Go inference and saved outcome.
- lib/peso_ui/User/job_readiness_dialog.dart — accurate local preview vs Go model copy.
- docs/qa_browser/qa-bookmark-auth-results.json — latest test results.
- docs/PESO_SESSION_CONTINUATION_2026-10-20.md — prior checkpoint.
- Source root: C:\Users\Admin\Desktop\Prototype.

## 2026-10-21 — Independent live-provider and browser QA follow-up

Full evidence and reproduction steps: `docs/PESO_LIVE_INTEGRATION_QA_2026-10-21.md`.

- Remote command execution restored and local services confirmed healthy. QA-only persisted mock RPM 429 diagnosed in `geminiModelQuotas` (30-second record at 02:29 PHT; not a real Google API exhaustion). Added guarded, local-only pre/post cleanup wrapper `backend/scripts/qa-run-api-repeatable.mjs`; replay passed **15/15 twice consecutively**.
- Real encrypted managed Gemini provider `gemini-3.8-flash` key test succeeded (HTTP200, one attempt, expected OK, 8.3s).
- Real Gemini extraction of entirely fictional applicant text succeeded (83.2s): 3 source-supported skills, none rejected; actual Go inference `ready`, model `peso-mini-ai-v1`, exact in-memory job ID, medium confidence with review flag; no profile/job writes.
- Real PDF Files API integration succeeded (86.3s), **one fictional hiring notice, two roles, two independent PDF.js-correlated role requirements, zero cross-role leaks, two real Go results**. Generated fixture remains in `docs/qa_browser`; never published to public Mongo.
- Chrome fictional returning applicant successfully completed nine-question job assessment; Go `/api/ai/job-match` HTTP200, saved `/api/profile/outcomes` HTTP200, report visible, no browser JS errors. Browser test needed `PYTHONIOENCODING=utf-8` to handle the peso glyph, not an app code change.
- Chrome private register guest/applicant/admin authorization and auto-refresh **9/9 PASS**. Backend `npm run check` **210/210 PASS**; Flutter focused tests **17/17 PASS**; Go tests/vet PASS; local/staged health PASS.
- Production model SHA256 `C7F34B0DEAEBE793331273927A275341DAB441BE562EE131250282C5902E41EB` matches preserved baseline; **no retraining or promotion**.
- Port 3000 remains old running process, not silently restarted; staging 3002 has been running since after adaptive source edits. User-authenticated production Firebase + real Gemini + visible Flutter + logout/login acceptance remains pending. Do not mistake emulator tests and standalone provider tests for one complete production transaction.
