# PESO Mini-AI — Independent Live and Isolated QA Verification
**Date:** October 21, 2026 (Asia/Manila)  
**Project:** `C:\Users\Admin\Desktop\Prototype`  
**Decision:** Local/staging integration **PASS**; production-authenticated release sign-off **PENDING**.

## Objective

Verify the existing applicant/admin flows, managed Gemini 3.8 provider, source-evidence verification, existing Go Mini-AI inference, and Flutter results using the owner's authorized PC. Repair the replay defect without manufacturing production credentials or writing fictional applicants/jobs to the live MongoDB job collection.

## Key Requirements and Constraints

- Do not overwrite the other ChatGPT session's active code, restart port 3000, re-publish public job cards, alter real applicant profiles, retrain Go, or expose API keys/tokens/PII.
- Local QA identity is Firebase Auth Emulator `127.0.0.1:9099`; QA database is the loopback-only Mongo instance `127.0.0.1:27117/peso_e2e_browser_20261020`; test API is port 3003; Flutter QA preview is port 5243.
- Staging port 3002 has Gemini health/configuration, but port 3000 remains the previous runtime, started before adaptive job code was edited.
- Real Google calls are restricted to fictional text or a fictional one-page PDF. Standalone server-side provider checks are not a production-authenticated Flutter session.

## Architectural and Technical Decisions

- Use the production code's managed encrypted key pool via `createMongoGeminiKeyStore`, `decryptApiKey`, `createGeminiKeyRotator`, and `createGeminiProvider` but only in dedicated, limited test scripts that never print secrets.
- Keep provider-only testing distinct from emulator-authenticated UI/API testing.
- Test source-linked Gemini role extraction using a fictional PDF in memory, verify the source with local PDF.js before using role-specific qualifications in the existing Go adapter.
- Preserve model `mini_ai/data/model_v1.json`; compare SHA-256 against `mini_ai/data/experiments_20261020/model_v1_baseline.json`.

## Completed Work and Actual Evidence

### 1. Simulated quota replay defect — fixed in QA harness

- Fresh invocation of `node backend/scripts/qa-api-e2e.mjs` initially passed registration, job feed, saved NSRP/resume, and model matching, then returned HTTP 429 `gemini_rate_limited` during simulated Gemini extraction.
- Investigated **only** the local QA database. `geminiModelQuotas` held a model-`gemini-3.8-flash` simulated RPM restriction observed at 2026-10-20 18:29:02Z with `until` 18:29:32Z. It had already expired by inspection; this was NOT proof of a real Google rate limit.
- Added `backend/scripts/qa-inspect-local-model-quota.mjs` (read-only) and `backend/scripts/qa-run-api-repeatable.mjs` (pre- and post-run removal of only the QA `gemini-3.8-flash` quota entry, requiring the fixed loopback DB and at least two QA-tagged fictitious job records).
- The QA harness subsequently ran **twice consecutively**, each returning **15/15 PASS**, exit code 0. These include protected API endpoints, Firebase emulator identity, onboarding source persistence, real Go inference, mock Gemini extraction, job translation isolation, photo privacy, application/admin authorization, real XLSX generation, simulated 429, and post-failure recovery. Production quota records were not cleared.

### 2. Live Google Gemini provider — real network call

- Test: `node backend/scripts/qa-real-gemini-managed-probe.mjs`
- Result: `gemini-3.8-flash` HTTP 200, correct `OK` reply, exactly one attempt, 8,315 ms. The app's managed encrypted key configuration was used, without any key output.

### 3. Real Gemini applicant extraction -> evidence verification -> Go

- Test: `node backend/scripts/qa-real-gemini-to-go.mjs`
- Supplied **fictional** applicant text only. Gemini provider generated an actual JSON profile in 83,176 ms (one attempt). Source verification marked **3 skills supported, 0 rejected**, extraction status `verified`.
- Existing saved Go model returned `ready`, `modelVersion=peso-mini-ai-v1`, one result with the exact in-memory fictional job ID, medium evidence confidence and one review warning. **No applicant or job records were written.**

### 4. New PDF job -> Gemini Files API -> PDF.js -> existing Go

- Fixture: `docs/qa_browser/qa-fictitious-role-notice-20261021.pdf`, clearly marked as fictional/no real hiring. Built with local headless Chrome by `scripts/qa-make-fictitious-role-pdf.py`.
- Test: `node backend/scripts/qa-real-gemini-pdf-to-go.mjs`
- Verified local PDF.js text readability and one-page count, then uploaded the fixture to Gemini Files API for actual Gemini 3.8 Flash structured extraction.
- Result: document complete, no gaps, **1 employer notice**, **2 separate role cards** (EHS Staff/Welder), **2 role-specific proposed requirements**, **2/2 correlated against independent PDF text**, **0 cross-role requirement leaks**, **2/2 Go results**, model `peso-mini-ai-v1`. Exit code 0; live PDF provider call took 86,334 ms. The resulting notice/jobs existed **only in memory**, never in production MongoDB.
- Corroboration is *source-text correlation*, not actual employer approval. Real scans/ambiguous requirements still require human review.

### 5. Actual Chrome QA user and admin UI

- Python Playwright was already installed at `%TEMP%\peso-playwright`. First browser replay failed before login because PowerShell's `cp1252` stdout encoding could not print a peso sign; reran with `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1`. No app code changes were required.
- `python scripts/qa-browser-job-evaluation.py`: PASS, exit 0; returning fictional applicant signed in; nine-question readiness dialog completed; POST `/api/ai/job-match` HTTP 200 with real Go model; POST `/api/profile/outcomes` HTTP 200; model-backed advisory alignment and review warning visibly rendered; browser JavaScript errors: **none**.
- `python scripts/qa-browser-bookmark-auth.py`: **9/9 PASS**, exit 0; anonymous bookmark concealed applicant rows, non-admin denied, admin signed in, appropriate rows/columns rendered, manual refresh passed and automatic 30-second polling produced a subsequent authorized API query. This is an Excel-style private live web view, **not** a Microsoft-hosted Excel Online workbook.

### 6. Regression and runtime health

- `cd backend; npm run check`: **210/210 PASS**, exit code 0. Log: `docs/qa_browser/qa_verified_backend_20261021.log`.
- `cd mini_ai; go test -count=1 ./...` and `go vet ./...`: PASS, exit 0.
- `flutter test --no-pub test/notice_role_selection_test.dart test/ai_onboarding_fallback_test.dart test/job_readiness_preview_test.dart`: **17/17 PASS**, exit 0. Log: `docs/qa_browser/qa_verified_flutter_focused_20261021.log`.
- Five new QA Node scripts passed `node --check` with exit 0.
- Original port 3000, controlled staging port 3002, and isolated QA port 3003 each returned healthy `/api/health`.
- Original Node port 3000 process began 2026-10-20 19:46:58; adaptive reader/evidence source was last edited around 21:57–22:06. Thus port 3000 **cannot be assumed to be running the new adaptive code**. Staging port 3002 began 23:40:30, after the code edits. QA port 3003 began 00:10:45.
- Original production model and preserved baseline hashes equal: `C7F34B0DEAEBE793331273927A275341DAB441BE562EE131250282C5902E41EB`.

## Remaining External / Release Blockers

- Still no owner-authenticated *production* Firebase -> real Gemini extraction -> persisted verified facts -> Go -> browser profile report -> logout/login acceptance. QA Firebase identities are fictional emulator accounts; the live real-Gemini scripts are standalone, in-memory system probes.
- Port 3000 has **not been restarted or cut over**, because normal startup can re-publish/renew real public PDF hiring records and the other session has been editing the backend. Controlled deployment should pin `PESO_SKIP_AUTOMATIC_JOB_SYNC=1` where appropriate, compare record counts/provenance, and provide rollback.
- This does not establish real-world hiring accuracy, definitive mandatory requirements for official scanned notices, accuracy of all translations, Microsoft-hosted Excel Online synchronization, or production OAuth session restoration.
- No new model was trained or promoted. Real requirement accuracy still needs employer/PESO-reviewed examples.

## Relevant Files and Reproduction

- `backend/scripts/qa-inspect-local-model-quota.mjs`
- `backend/scripts/qa-run-api-repeatable.mjs`
- `backend/scripts/qa-real-gemini-managed-probe.mjs`
- `backend/scripts/qa-real-gemini-to-go.mjs`
- `backend/scripts/qa-real-gemini-pdf-to-go.mjs`
- `scripts/qa-make-fictitious-role-pdf.py`
- `docs/qa_browser/qa_verified_browser_replay_20261021.log`, `qa_verified_admin_browser_20261021.log`, `qa_verified_backend_20261021.log`, `qa_verified_flutter_focused_20261021.log`
- Existing screenshots/results: `docs/qa_browser/qa_job_eval_report.png`, `qa_bookmark_admin_loaded.png`, `qa-bookmark-auth-results.json`
- Prior checkpoints preserved: `docs/MINI_AI_CHECKPOINT_2026-10-20.md`, `docs/PESO_QA_CHECKPOINT_2026-10-21.md`

### Final read-only live public-job integrity check

After all QA and real-provider tests, `node backend/scripts/qa-notice-linkage.mjs` exited 0 and still found **325 visible postings (81 notices, 244 roles), all 81 notices source-linked, 244 role assignments**. JCRCC's 16-role technical smoke still returned 16 Go results from `peso-mini-ai-v1`. This verifies the expected live-feed totals remained unchanged during our QA, though totals alone are not a database-level proof that no other concurrent process wrote records.
