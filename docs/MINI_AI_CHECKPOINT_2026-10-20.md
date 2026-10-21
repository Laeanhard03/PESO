# PESO Mini-AI implementation checkpoint — 2026-10-20

## Objective
Build a real CPU-trained Go applicant/job matching model from actual existing public-PDF job records, connect secure backend inference to the existing Flutter readiness UI, preserve Firebase/MongoDB/Gemini.

## Baseline and source evidence
- Verified live Mongo Atlas connection and read-only counts: 333 job postings; 325 active Gemini-imported walk-in cards; 8 retired legacy PDF cards; 3 indexed official public PDF sources; 11 profiles; 0 submitted applications at inspection.
- Indexed government sources: `montalban-walk-in-official` 13 pages (18 notices), `montalban-para-sa-montalbeno` 64 pages (63 notices), development mirror 13 pages (18 notices).
- Export `mini_ai/data/source_jobs_v1.json`: 325 active source-backed cards (244 individual role cards), all with provenance URLs, generated with `node backend/scripts/export-ai-source-jobs.mjs`. Read-only; Mongo originals unchanged.
- Data quality: Gemini notice qualifications can bleed across multiple role cards; filtered by role prefixes in Go when available. OCR and source freshness need human review. Sex-based job requirements excluded from scoring.

## Implemented files
- `mini_ai/features.go`: canonical skills, source-role-specific requirements filtering, safe model features and explanations.
- `mini_ai/dataset.go`: reproducible synthetic job/applicant/pair generator with source-family split isolation.
- `mini_ai/train.go`: trainable logistic CPU model, baseline, F1/precision/recall/category metrics, training-size ablation and benchmark.
- `mini_ai/main.go`, `main_test.go`, `go.mod`.
- `mini_ai/data/v1/synthetic_jobs_v1.jsonl`, `synthetic_applicants_v1.jsonl`, `synthetic_pairs_v1.jsonl`, manifest; `mini_ai/data/model_v1.json`, `evaluation_v1.json`.
- `mini_ai/bin/peso-mini-ai.exe` is a local build artifact.
- `backend/src/mini-ai-service.js`: profile normalization from AI+NSRP+resume schemas, model runner via stdin, job filtering and safe unavailable state; includes evidence extraction/validation helpers. Existing secure Gemini profile-extraction endpoint remains, is not replaced.
- `backend/server.js`: authenticated POST /api/ai/job-match using actual Mongo jobs/profile; persists small latestAiJobMatch only after valid inference.
- `lib/peso_services/peso_api_client.dart`: evaluateJobMatch request.
- `lib/peso_ui/User/user_ui.dart`: submits completed questionnaire to model and merges actual explanation into existing outcomes; rule-based preview fallback if unavailable.
- `lib/peso_ui/User/readiness_report_card.dart`: visual trained model alignment/uncertainty and synthetic-data disclaimer.

## Repro commands
```powershell
cd C:\Users\Admin\Desktop\Prototype
node backend\scripts\export-ai-source-jobs.mjs
cd mini_ai
go test ./...
go build -o bin\peso-mini-ai.exe .
.\bin\peso-mini-ai.exe generate -source data\source_jobs_v1.json -out data\v1 -seed 20261020 -jobs 480 -applicants 1400 -pairs 7200 -lra-rate 0.2
.\bin\peso-mini-ai.exe train -data data\v1\synthetic_pairs_v1.jsonl -model data\model_v1.json -report data\evaluation_v1.json
.\bin\peso-mini-ai.exe benchmark -model data\model_v1.json -count 50000
cd ..\backend
npm test
```

## Verified numbers
- 480 synthetic jobs (385 walk-in and 95 local recruitment); 1,400 synthetic applicants; 7,200 pairs; 500 positive, 4,965 development, 1,735 uncertain.
- Go tests pass after fixing data split fixture.
- Logistic held-out test: baseline F1 0.800; learned F1 0.9863 on 544 scored test pairs, 228 uncertain cases not included in binary metrics. Learned precision 0.973, recall 1, FP 1, FN 0. Validation F1 0.8829. These are SYNTHETIC-rubric only, NOT real hiring accuracy.
- 50,000 pure-model inference benchmark: 0.0226 microseconds/evaluation excluding subprocess and I/O; zero reported heap allocation delta.
- Backend preexisting+integration regression suite: 169/169 pass.
- Go executable smoke inference through Node adapter returned a real model result.
- Flutter focused test first failed due to accidental `const Text` with dynamic expression; corrected and rerun is pending until verified.
- Firebase/OAuth live sign-in, successful production Gemini requests, and end-to-end browser use of new job matching are NOT verified.

## Constraints and remaining work
- No human-reviewed real applicant-job pairs; report synthetic performance only, never hiring decision.
- The new endpoint works on stored profile data (including previously securely Gemini-extracted profile); automatic on-registration model precomputation not yet implemented. Gemini evidence verification helpers exist, but are not yet wired to the existing Gemini extraction endpoint.
- Real scoring requires backend process restart so new code loads. Use existing PESO desktop launcher, avoid conflicting API processes.
- Need add route-specific mocked tests; verify UI with Flutter tests, full release build and authenticated real-browser flow.
- Avoid changing existing uncommitted work. Do not save synthetic vacancies into MongoDB jobPostings or mix them into public feed. Never expose secrets/PII in reports.

## Final verification supplement
- Added backend mocked/integration mini-AI suite `backend/src/mini-ai-service.test.js`, 5/5 passing. Full backend `npm test`: **174/174 pass**, rerun after Gemini profile extraction hook.
- Existing `POST /api/ai/profile` now invokes saved Go model as a *best effort* after Gemini successfully saves profile, stores small `latestAiJobMatch` results in Mongo; extraction and authentication remain functional when Go unavailable.
- Live backend restarted via official local runner; `GET http://127.0.0.1:3000/api/health` returned `ok=true,mongoDbConnected=true`; unauthorized `POST /api/ai/job-match` returned 401, confirming route mounted and protected. Authenticated real end-to-end not yet verified.
- Flutter release `flutter build web --release --no-pub` **success** (`Built build\\web`); four changed Flutter UI/client files `flutter analyze --no-pub ...` **No issues found** after fixing two brace warnings.
- Focused Flutter 11/11 tests passed before final guided-dialog label cleanup; final rerun currently in progress.
- The source snapshot is a read-only Mongo export, not a direct PDF visual reread. Existing API Gemini extraction uses secure managed rotating keys, but real upstream requests not explicitly tested during this run.
- Important remaining limitation: online authenticated real-user registration/onboarding-to-model-to-UI visual testing not demonstrated; no human-reviewed genuine applicant-job labels, thus published F1 is synthetic only. Version 1 source requirements still need human QA, especially OCR cross-role bleed.

## Independent QA follow-up — 2026-10-20 (source-safety and mirror leakage)

Scope: inspection and targeted edits of existing implementation; no synthetic records inserted into live MongoDB, no applicant labels collected or manufactured. Other uncommitted code was left in place.

### Fixes and safeguards
- `mini_ai/features.go`: protected sex/gender, age, marital-status and related demographic phrases are excluded from requirements and features, including exact ingested `MALE NOT MORE THAN 35 YRS OLD.`; original excluded text is returned separately in `excludedRequirements` with a human-review signal. Existing legacy multi-role importer records are treated as unscoped and never promoted to mandatory conditions without explicit role-prefix attribution. Single-role explicit scope remains usable.
- `mini_ai/train.go`: training rejects any canonical family or applicant appearing in multiple splits. The evaluation artifact now reports cross-split audit counters. Protected requirement review notes are appended only after scoring/confidence calculation.
- `mini_ai/dataset.go`: source family uses normalized source document identity (content hash when available, otherwise canonicalized official/dev PDF URL, company and page range) independent of source ID/fingerprint; mirror-equivalent role templates are deduplicated before generation. Avoid using mirror-specific Mongo identifiers as split keys.
- `backend/src/public-pdf-ai-listings.js`: new role records carry `requirementScope`, `sourceRoleCount`, `unattributedRequirements`. On multi-role notices, ambiguous qualifications remain on the notice/review data only, not each role's mandatory criteria. Prior Mongo role records are protected by the Go fail-closed inference path, without a bulk live-data rewrite.
- `backend/src/mini-ai-service.js`: notice/aggregate cards are excluded from model matching; scope and review metadata are forwarded to Go. Gemini's unverified output is not used as trusted profile qualification facts.
- `backend/server.js`: `/api/ai/profile` now invokes `verifyGeminiFacts` on the textual evidence, persists `aiMatchingExtraction` and passes it to best-effort inference. Binary-only resumes, without verifiable submitted text, are marked `needs_review`; OCR/model failure must not stop ordinary registration.

### Independent reproducible commands and observed evidence
Run these from `C:\Users\Admin\Desktop\Prototype` in PowerShell:
```powershell
cd mini_ai
gofmt -w features.go dataset.go train.go main_test.go qa_regression_test.go
go test -count=1 ./...
go build -o bin\peso-mini-ai-qa.exe .
.\bin\peso-mini-ai-qa.exe generate -source data\source_jobs_v1.json -out data\qa_20261020 -seed 20261020 -jobs 480 -applicants 1400 -pairs 7200 -lra-rate 0.2
.\bin\peso-mini-ai-qa.exe train -data data\qa_20261020\synthetic_pairs_v1.jsonl -model data\qa_20261020\model_qa.json -report data\qa_20261020\evaluation_qa.json
cd ..\backend
npm test
node --check server.js
cd ..
flutter test test/job_readiness_preview_test.dart test/job_posting_category_test.dart
flutter analyze --no-pub lib/peso_services/peso_api_client.dart lib/peso_ui/User/user_ui.dart lib/peso_ui/User/readiness_report_card.dart lib/peso_ui/User/job_readiness_dialog.dart
flutter build web --release --no-pub
```
- Fresh Go `go test -count=1 ./...`: PASS (`ok peso-mini-ai 2.233s`), including new age/gender, two-role, legacy-role, mirror URL and cross-split-leakage regressions.
- Clean QA Go executable: built; generated 480 jobs, 1,400 applicants, 7,200 pairs. Actual manifestation: 244 raw source role rows, 244 distinct templates, 0 duplicates in this current snapshot (regression fixture separately proves mirror copies deduplicate). 71 generated canonical notice families; 0 cross-split family/role/applicant overlaps. Manifest: `mini_ai/data/qa_20261020/dataset_manifest_v1.json`.
- QA-only model trained and evaluated; baseline synthetic test F1 **0.8471**, learned synthetic test F1 **0.9859**, 444 scored test pairs and 260 uncertain test cases withheld. Evaluation: `mini_ai/data/qa_20261020/evaluation_qa.json`; QA model: `mini_ai/data/qa_20261020/model_qa.json`. These are **synthetic label recovery metrics only, NOT real-world hiring performance or suitability accuracy**.
- Backend full pre-final-hook suite **174/174 PASS**. After last profile-hook edit, targeted mini-AI/listing suite **16/16 PASS**, plus explicit two-role regression **12/12 PASS** on listing suite. Final full-suite rerun is recommended.
- Flutter focused test combination **11/11 PASS**, four-file analyzer **No issues found**.
- API health from running local service: `ok=true`, `mongoDbConnected=true`; unauthorized POST `/api/ai/job-match`: HTTP **401**. Does not establish authenticated model path success.
- Static `node --check` returned success for inspected backend files.

### Release disposition: NOT YET DEPLOYMENT-READY
Remaining blockers: authenticated owner-controlled browser journey (successful Gemini natural-language extraction to stored verified facts to actual Go inference to visible Flutter report) was not safely verified; binary-resume evidence cannot independently be checked without text extraction; human-reviewed employer qualification attribution and real applicant/job evaluation data are absent; stale historical public PDF job openings need employer confirmation. The currently deployed/running backend must be restarted to load the latest source edits. QA model lives under a separate output folder and is **not promoted to production**; production model and original synthetic manifest were not overwritten. Release requires an owner-signed-in end-to-end test, privacy/fairness and representative human-reviewed qualification audit, and controlled artifact promotion/release rollback.

### Final verification addendum
- After the last Gemini profile route edit and extra two-role regression: backend `npm test` **175/175 passed** (0 failed).
- Flutter release web build: **PASS**, `flutter build web --release --no-pub`, `Built build\\web` (127.9 seconds compilation).
- Targeted JavaScript syntax checks completed without errors. Live `/api/health` and unauthenticated 401 evidence above was against the running server instance; edited backend source requires controlled restart and authenticated sign-in test before release.
- No claim of real-user model validation, source-PDF visual confirmation, or live Gemini success is made. The QA model and QA manifest are deliberately separate from live artifacts.

## 2026-10-20 onboarding failure recovery verification

**Scope:** Existing Flutter onboarding/UI only; Go model, dataset, source split and backend not rebuilt or restarted. Unrelated uncommitted work preserved.

- Updated `lib/peso_ui/Reusable_Designs/ai_processing_ui.dart`: separate source-first save, document-save and best-effort Gemini extraction; a Gemini outage or invalid extraction no longer blocks navigation to the existing `UserProfile`. The source save outcome is preserved as `sourceSaved`, AI result as null on failure, and a visible non-blocking toast distinguishes saved vs failed persistence. No empty `aiProfile` is written on extraction failure. New `AIProcessingServices` injection seams permit offline deterministic widget tests.
- Added `lib/peso_logic/onboarding_ai_evidence.dart`: conservative labeled, job-relevant evidence extracted from submitted resume fields and NSRP entries and optional labeled text, excluding identity/contact/government numbers and demographic labels before Gemini extraction. Raw source forms remain privately stored.
- Updated existing `UserProfile` and `UserAiProfileTab`: initial resume and NSRP maps remain available even if the profile GET API is unavailable; AI-unavailable state is visibly differentiated from generated AI profile, with blank non-invented AI fields and retry using the same evidence-filtering flow. Existing profile tab displays saved resume/NSRP entries.
- Added `test/ai_onboarding_fallback_test.dart`: extraction success, failure fallback/no empty AI save, source-first persistence, source-save failure status and source evidence redaction. Existing responsive profile/orb tests retained.
- Initial combined Flutter focused tests (before source-save-failure regression addition): **5/5 PASS**. Initial expanded run uncovered a short-viewport render overflow in the new source-save-failure test; retest on 390x844 viewport was launched after applying matching viewport settings.
- Dart analyzer on four changed Dart files: **No issues found** (after fixing one curly-braces lint).
- Web release build: **PASS**: `flutter build web --release --no-pub`; real output `Built build\\web`, `WEB_BUILD_EXIT_CODE=0`; 263.1 seconds compilation.
- `git diff --check` returned exit 0 for the three edited tracked UI files (only Windows LF/CRLF warnings). New evidence helper/test are untracked additions.
- **Not authenticated live E2E**: no real sign-in, live Gemini success, live Go matching/UI proof or human-reviewed accuracy established. The AI warning state is transient in the current UI; cross-session unavailable status persistence has not been independently tested. Source-save retry requires checking the connection and resubmission; the UI must not imply unsaved data was persisted.

Reproduce from project root:
```powershell
flutter analyze --no-pub lib/peso_logic/onboarding_ai_evidence.dart lib/peso_ui/Reusable_Designs/ai_processing_ui.dart lib/peso_ui/User/user_ui.dart lib/peso_ui/User/user_ai_profile_tab.dart
flutter test test/ai_onboarding_fallback_test.dart test/ai_absorbing_orb_test.dart test/user_ai_profile_responsive_test.dart
flutter build web --release --no-pub
Write-Output ('WEB_BUILD_EXIT_CODE=' + $LASTEXITCODE)
```

### Final focused rerun
- Following the short-viewport fixture correction, `flutter test test/ai_onboarding_fallback_test.dart test/ai_absorbing_orb_test.dart test/user_ai_profile_responsive_test.dart` exited **0**, **6/6 tests passed**. Includes source-save failure fallback, Gemini outage navigation, successful extraction, NSRP/resume privacy filtering and prior UI tests.
- Short-viewport (default test 800x600) processing-screen overflow was observed during the first expanded fixture run; the regression was rerun at the intended 390x844 mobile layout. The short-height scrolling layout itself has not been modified, and should be tracked for responsive UX QA.

## 2026-10-20 follow-up: authenticated integration hardening

- Continued from original checkpoint without altering trained Go features/datasets, source family splits, or public Mongo job postings. Git worktree contains extensive preexisting changes; no reset/checkout was performed.
- Confirmed running local API health: `ok=true`, MongoDB connected, Firebase token verification ready. Running port 3000 was already occupied by Node service. The actual owner-authenticated Gemini-to-Go-to-Flutter experience is **not verified**.
- Confirmed `GEMINI_MODEL`, `GEMINI_PDF_MODEL` and `GEMINI_FALLBACK_MODEL` are configured in private backend .env; do not expose any API keys or secret environment values. Actual error status/response on user-authenticated extraction remains unknown.
- Removed redundant client `saveAiProfile` call after persisted `POST /api/ai/profile` extraction from both `AIProcessingScreen` and user-profile retry. Modified dependency-injected widget tests to require exactly source-save -> artifacts -> extraction with no second AI-profile patch.
- Restricted legacy `PATCH /api/profile/ai-profile`: responds HTTP 409 `verified_extraction_required` rather than allowing arbitrary Gemini output to rewrite independently entered top-level `professionalTitle`/`skills`. Added route regression test that verifies account qualification fields and extraction state remain unchanged.
- `POST /api/ai/profile` now records `aiExtractionStatus='completed'` and clears old stored model results before best-effort inference; stores model status for ready, no_live_jobs, or unavailable (with empty result list when not ready). This prevents stale ready results after a new extraction.
- Profile reload prefers persisted backend extraction status rather than treating an old temporary UI failure as permanent after relogin. No standalone failed-attempt status persistence for Gemini/provider errors is implemented yet.
- Actual rerun evidence: backend `npm test` exit 0, **184/184 passed**; focused Flutter tests exit 0, **6/6 passed**; changed-file Dart analyzer exit 0; `node --check backend/server.js` exit 0; `go test -count=1 ./...` exit 0; Git tracked-file `diff --check` exit 0. Node adapter local Go smoke reported `ok=true`, `modelVersion=peso-mini-ai-v1`, one result (not authenticated production traffic).
- Do not promote to deployment-ready until an account-owner signed-in test establishes Gemini provider error/success, persisted verified facts, live role matching, Flutter visible result, and refresh/logout/login. Binary-only resume claims still need independently verifiable text extraction/OCR before they can be treated as trusted for scoring; employer source requirements and real-world evaluation remain pending.

## 2026-10-20 — Multi-role notice selection + evidence-aware model review

### Read-only live source audit
- Ran `node backend/scripts/qa-notice-linkage.mjs` against projected public job records, without profile reads or Mongo writes.
- Current visible live-record counts: 325 listings; 81 notice cards; 244 individual role cards. Every notice has a validated parentFingerprint/source URL/source document ID/company/page-matched association; 244 linked role assignments.
- Requirement gaps: 55 role cards contain nonempty unattributed requirement lists; 133 roles lack `single_role`/`explicit_role` scope. These counts are distinct and must not be conflated.
- JCRCC notice on public source page 17 is linked to 16 individual positions. Read-only Go smoke used an explicitly fictional construction/welding applicant; version `peso-mini-ai-v1` returned 16/16 distinct role IDs with 16 low-confidence and 16 review flags. Aggregate notice was never scored. These are technical checks, NOT validated hiring outcomes.

### Implemented integrations
- Added `backend/src/notice-role-linkage.js`, strict source-provenance linkage requiring exact parent fingerprint plus source ID, URL, page range, employer and active/eligible role. Similar titles/employers alone cannot produce links. Notices/synthetic/expired/inactive roles remain excluded.
- Authenticated `GET /api/jobs` now exposes `linkedRoleIds` for notice cards. Internal `sourceFingerprint` remains private (existing public API contract preserved); published `requirementScope` and `sourceRoleCount` inform uncertainty UI.
- Authenticated `POST /api/ai/job-match` accepts an explicit `{noticeId, jobIds}` batch of 2–6 unique positions; validates all selected IDs against the same notice, fails closed on wrong/expired/unlinked roles; invokes existing Go model ONLY against selected real role cards. Legacy single-role `jobId` path is preserved.
- Flutter user feed now includes `NoticeRoleSelector` for notice detail: linked positions, per-position view/evaluate actions, 2–6 position comparison, and explanation when no verifiable associations exist. Added `NoticeRoleComparisonDialog` which suppresses numeric scores on low-confidence or non-attributed requirements and retains individual PESO application pathway. No new training model or fabricated scoring.
- Added `PesoApiClient.compareNoticeRoles` and linked notice wiring in `UserProfile`.
- Added isolated route tests for proper linkage, 401, exact selected-role results, rejection of unrelated roles, notice non-scoring, and expired/synthetic exclusion. Added focused Flutter widget tests for selection, comparison, fallback, score suppression and actions.

### Controlled Go model decision
- Preserved `mini_ai/data/model_v1.json` as `mini_ai/data/experiments_20261020/model_v1_baseline.json`. Both SHA-256 `c7f34b0deaebe793331273927a275341dab441be562ee131250282c5902e41eb`.
- Added independent Go offline diagnostic at `mini_ai/tools/offlineeval`; refuses raw non-synthetic labels and applicant/source-family split leakage. Frozen held-out diagnostic at `docs/MINI_AI_HELDOUT_DIAGNOSTIC_2026-10-20.json`: 444 scored synthetic test pairs, 260 uncertain skipped; baseline F1=0.98591549, precision=1, recall=0.9722222, synthetic rubric Brier=0.00785768, ECE10=0.02673896, NDCG@5=1 across 34 qualifying fictional applicant ranking groups. These figures are **not real-world hiring accuracy or trustworthy confidence estimates**.
- **No retraining justified**: 133 roles still lack explicit employer requirement attribution and no independent human-reviewed applicant-role labels or verified missing-mandatory judgments are present. Existing trained model retained; no candidate automatically promoted. See `docs/MINI_AI_RETRAINING_GATES_2026-10-20.md` for paired-heldout experiment/evaluation gates and privacy/fairness review.

### Actual regression/release results
- Backend `npm run check`: **186/186 PASS**, exit code 0, including new linked-role regression tests (7/7 targeted).
- Flutter combined focused tests: **17/17 PASS**, exit code 0, including new role-selection tests (3/3).
- Flutter changed-file analyzer: **No issues found**, exit code 0 after local braces lint fix.
- Flutter `flutter build web --release --no-pub`: **PASS**, exit code 0, `Built build\\web` (199.9s).
- Go `go test -count=1 ./...` and `go vet ./...` completed cleanly before newly added evaluator guard tests; final rerun recorded separately when finished.
- Live API was deliberately **not restarted** during this pass. Its default `startPublicPdfRefreshSchedule()` republishes and renews live public job cards at startup; a restart could mutate live Mongo records during a read-only safety assessment. New backend source is tested in isolated route integration but **not yet running on the existing API process**.
- **Not verified:** actual authenticated owner registration -> Gemini extraction -> Go readiness UI including comparison, production browser deployment, human source-PDF review and verified real applicant/job accuracy. Do not mark deployment-ready.

### Final post-change verification addendum
- Added offline evaluation guard tests `mini_ai/tools/offlineeval/main_test.go`: explicitly reject applicant/source-family leakage and non-synthetic unreviewed labels; verify uncertain test cases do not silently enter binary ranking metrics. Final `go test -count=1 ./...`: root and evaluator packages PASS; `go vet ./...`: PASS. Both exit code 0.
- Extra 320×568 short-screen Flutter test for source-linked notice selector: PASS with no overflow; notice selector widget suite now **4/4 passed** (exit 0).
- Last full `npm run check` before these test-only changes: **186/186 passed** (exit 0). Last expanded Flutter regression suite before extra short-screen test: **17/17 passed** (exit 0), changed-file analyzer exit 0. Web build exit 0, `Built build\\web`.
- Live JCRCC role audit `docs/qa_notice_linkage_20261020.json`: `status=ready`, `modelVersion=peso-mini-ai-v1`, 16 linked roles requested, 16 distinct outputs, all low confidence, 16 needing review, no aggregate notice scoring. No actual applicant account was used.
- Local API health after all changes: `ok=true`, `mongoDbConnected=true`, Firebase verifier ready; port 3000 is still served by pre-existing Node process PID 6768. The NEW notice-role backend source has **not been deployed into that running process**. A normal backend restart invokes automatic public PDF job renewal and can mutate live records; deployment should be coordinated with source/job-posting integrity checks instead of silently restarting during a read-only QA task.
- Final disposition: **no model retraining, no model promotion, no public job collection writes from this task, and no authenticated live E2E claim**.

## 2026-10-20 — Concurrent-safe adaptive new-job requirement extraction

Separate implementation while another ChatGPT session works on translation, profile-image persistence, qualification editing, Gemini key health, and applicant Excel. **Do not overwrite that session's changes or restart its Node process.**

- Added `backend/src/role-requirement-evidence.js` (+ isolated tests): role-specific Gemini `roleRequirements` proposals are checked for exact role, page, explicit mandatory/preferred language, exclusions for protected/negated criteria, and exact source quote in independently extracted local PDF.js page text. Gemini's own `verified`/status claims are explicitly discarded. Unsupported candidate criteria remain review-only, never mandatory Go features.
- Updated only `backend/src/gemini-public-pdf-reader.js` and `backend/src/public-pdf-ai-listings.js` in existing job ingestion: bounded optional role-specific extraction, cached best-effort PDF.js source correlation for text-readable PDFs up to 40 pages, fallback human review for scanned/large documents, existing Go-compatible vetted role requirement strings and review metadata. No extra Gemini request is issued by source checking.
- Existing single-role admin job matching and current Go model require **no automatic retraining**. No changes to `backend/server.js`, Gemini provider/key pool, Flutter UI, Go features/training files, production artifacts, or live Mongo job records.
- Final `backend/npm run check` exit **0, 201/201 passed**; focused tests **39/39 passed** before final extra review cases; Go full test exit **0**, Node syntax tests exit **0**. Model artifact SHA-256 `C7F34B0DEAEBE793331273927A275341DAB441BE562EE131250282C5902E41EB` equals preserved baseline.
- Full notes: `docs/ADAPTIVE_JOB_REQUIREMENTS_2026-10-20.md`; log: `docs/qa_adaptive_jobs_check_20261020.log`.
- **Not yet a live authenticated Gemini-to-Flutter verification**, and changes to job ingestion are not loaded into the running Node process. Do not restart the concurrently edited shared backend just to claim a deployment success; startup may republish/renew job cards.

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

## Active occupation-based matching replacement — October 21, 2026

Objective: replace obsolete synthetic job-pair model knowledge with a worldwide occupational foundation. Gemini only classifies supported NSRP/resume intake facts; Go evaluates a selected job with no Minimum Required Questions (MRQ); exactly 10 MRQ items are asked only if a user chooses to continue/apply and are saved as separate information for PESO.

Architecture:
- Backend occupation taxonomy in 'backend/src/occupation-categories.js': all 10 ISCO-08 major groups, 30 broad occupational fields and 324 synonyms. Dynamic local classification of new job titles, no Gemini job-by-job calls; unknown occupations stay review-only, not a failed qualification.
- Intake Gemini profile JSON may include category proposals with exact corroborated source quotes. 'backend/src/mini-ai-service.js' validates them and normalizes an applicant only from saved NSRP/resume/form facts. MRQ answers are NEVER passed to matching features. The backend '/api/ai/job-match' disregards legacy 'answers' parameters.
- One active Go model in 'mini_ai/data/model_v1.json' trained on taxonomy-derived broad category affinity. 'mini_ai/data/occupation_taxonomy.json' is generated from the shared ontology; 'mini_ai/occupation.go' is the occupation training/inference machinery. The original active weights were replaced in place, and the obsolete 'train'/'generate' CLI paths were disabled. Active model and source job snapshot were preserved.
- Flutter: 'lib/peso_ui/User/user_ui.dart' evaluates first and displays outcomes. Only the subsequent Continue/Apply button triggers 'job_readiness_dialog.dart'; exactly 10 MRQ questions plus personal guidance saved in outcomes and sent to PESO application API on separate user confirmation. 'readiness_report_card.dart' distinguishes occupation affinity from verified hiring requirements.
- Historical synthetic-only directories 'mini_ai/data/v1', 'qa_20261020', 'qa_independent_20261020', 'experiments_20261020', and 'pre_safety_backup_20261020' were retired and removed after verifying their content was only obsolete .json, .jsonl, or .exe files. No research documentation, source job snapshot, live applicants, or official job feed deleted. Historical documentation describing the old architecture remains for research traceability.

QA results:
- Backend 'npm run check': 218/218 PASSED; Go unit suites and vet passed before artifact cleanup; Flutter 15/15 focused tests and targeted Dart analysis passed.
- Full read-only live job feed: 325 active postings, 244 individual roles and 81 aggregate notices. All 244 individual titles are recognized by at least one broad occupation field; all 244 returned Go results and notices were excluded. 136 protected-criteria invariance checks and zero failures.
- Chrome E2E QA with isolated Firebase emulator, sandbox Mongo and fictional applicant: Data Entry 16/16 PASSED, Construction 16/16 PASSED, zero JS exceptions, independent AI check happens before the MRQ, separate consent, exactly 10 MRQ answers persisted in both assessment outcomes and '/api/applications', no Go rerun when answers are given.
- Mongo verified latest fictional intake record contained occupational fields 'data_services' and 'office_administration' and both applications had 10 screening answers. A first lookup had selected an older QA emulator UID with same fixture email; the current record is verified.
- Synthetic occupation held-out F1=1 only validates catalog-defined identity/affinity, NOT any employer hiring outcome or real-world predictive accuracy. Scores are career similarity indicators, not likelihood of employment; employer-specific qualifications require official confirmation.

Deployment: Isolated QA Flutter web on localhost:5243 has emulator flags and must NEVER be deployed publicly. Production-configured 'build/web' can be rebuilt separately. Live local API on localhost:3000 must be deliberately restarted with automatic job sync disabled to load new source. No remote/hosted deployment claimed.

### Local activation and reporting verification (final continuation, 2026-10-21)
- The backend originally listening on localhost:3000 started before the occupation-model source changes. Controlled restart was performed only for that verified local Node server, with PESO_SKIP_AUTOMATIC_JOB_SYNC=1; confirmed MongoDB connected, Firebase token verification ready and automatic public-PDF re-sync disabled. Production posting records were not reseeded or modified by these actions.
- Flutter production-configured build succeeded into existing build/web, without emulator flags. Local production preview on 127.0.0.1:5298 serves main.dart.js identical by SHA-256 to build/web. Headless Chrome smoke: Home/Register visible, no QA/emulator banner, zero JavaScript exceptions.
- PESO Excel export now includes MRQ fields for employer-requirements review, preferred work arrangement and training interest, in addition to all prior MRQ answers; an export test checks all 10 fields separately from AI results.
- Local sandbox fake-account verification: Gemini intake saved data_services and office_administration occupation fields; two sample reports and two applications each contain exactly 10 MRQ answers. Real Chrome tests 16/16 each for office and construction, without model re-evaluation from MRQ answers.
- Obsolete saved job-pair datasets/backups were explicitly deleted after type verification and live active model SHA validation; obsolete Go generate and train CLI commands now fail closed. The saved checkpoint and implementation remain continuous, with no new project versions.
- Public remote deployment, empirical real hiring outcome accuracy, and universal recognition of ALL future occupations were NOT asserted; only current feed and supported local preview verified.

## 2026-10-21 — Simplified two-result PESO job evaluation (continued in-place)

Objective/user-approved:
- Every COMPLETED Go evaluation displays **Good Match!** or **Not a Match Yet**, not a confusing third "insufficient information" outcome. These mean saved occupation/skills alignment, NOT employer hiring pass/fail; services that actually fail to respond still say "evaluation unavailable" rather than falsely failing the user.
- A positive result congratulates; a negative explains missing or unrelated saved qualifications, offers up to three active related-role alternatives, and still permits continuing to PESO.
- Short Gemini explanation generated solely from selected, completed Go result and source-attributed requirement labels; Gemini cannot alter Go scores, invent credentials, or read MRQ responses. Provider failure uses an immediate standard explanation.
- Intake-only Gemini NSRP/resume categories remain. Added deterministic, source-supported category preparation in normalizeApplicantProfile for OLD saved form/resume records missing extracted occupational fields. Unsupported Gemini-only credentials remain excluded.
- Evaluation popup precedes Outcomes; explanation/recommendations persist in user's Outcomes report; selecting a suggested role opens that job in the feed; Continue Application follows ten MRQ questions then explicit PESO submission consent.
- Backend updates: backend/src/job-evaluation-feedback.js (+ tests), backend/src/mini-ai-service.js (+ test), backend/server.js /api/ai/job-feedback route, Gemini provider new bounded job_evaluation_explanation operation, QA fake Gemini handler.
- Flutter updates: lib/peso_ui/User/job_evaluation_result_dialog.dart (+ test), user_ui.dart flow, readiness_report_card.dart main binary status, peso_api_client.dart.
- Tests: backend npm run check 227/227 pass; Flutter focused 16/16 pass, changed-file analyzer clean. Fictional QA Chrome: Data Entry positive 17/17 and Construction negative with recommended Data Entry alternative 19/19: 36/36 total pass. Exactly 10 MRQ persisted to outcomes and PESO application in both cases. No rerun of Go from MRQ and no browser JS errors.
- Production-configured local web build and controlled local backend restart must be confirmed before claiming local activation. Production applicant/job DB untouched by QA; isolated QA uses port 3003, Firebase emulator and local sandbox Mongo.

### Local activation verified (two-status flow)
- Binary Good Match / Not a Match Yet outcome has been rebuilt into existing production-configured `build/web` (no Firebase emulator flags). Local web server `127.0.0.1:5298` serves the identical SHA-256 `main.dart.js` and returns HTTP 200. Headless real Chrome opened Home/Register with zero JavaScript errors and no emulator banner.
- Local Node API on `127.0.0.1:3000` deliberately restarted after verifying its parent was the existing PESO backend; `PESO_SKIP_AUTOMATIC_JOB_SYNC=1` prevents automatic job-feed renewal/publishing. Health `ok`, Mongo connected and Firebase verifier ready.
- Isolated browser QA: data-entry positive 17/17; construction negative 19/19; Gemini explanation uses mock only in sandbox; real external Gemini explanation is integrated with strict fallback but has not been demonstrated live on a real signed-in production account. Public hosted deployment not performed.
- The two outcomes are *occupational matching guidance*, not definitive legal hiring pass/fail. Only real backend outages are reported as unavailable; no unknown requirement is fabricated to force a pass/fail. Applicant-originated NSRP/resume facts are prepared into known occupation categories on both new and legacy records; MRQ remains post-evaluation and non-scoring.
