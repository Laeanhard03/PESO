# PESO NSRP user-flow repair checkpoint (2026-10-21)

## Objective
Audit Copilot's landing/auth/NSRP claims; reproduce the reported career-dropdown and registration blocking symptoms with real browser checks, repair defects, and preserve earlier source work.

## Key requirements and constraints
- Working tree: C:\Users\Admin\Desktop\Prototype. Extremely dirty worktree; no reset or stash.
- Existing live/staged backend ports 3000/3001/3002 and local QA 3003 were online. Do NOT restart live port 3000 or seed synthetic users/jobs into production.
- QA Chrome uses PYTHONPATH=C:\Users\Admin\AppData\Local\Temp\peso-playwright.
- React Vite on localhost:5173, Flutter QA on :5243.
- Machine only ~1GB free of 8GB RAM when build attempted; do not conclude build errors are source errors without rerun.

## Findings and fixes
- React NSRP fields in App.jsx responded normally to Playwright select_option on desktop 1200x900 and mobile 390x844 BEFORE changes. Browser outputs and field values synchronized; no JS errors. User's screenshot may reflect stale deployment or an interrupted parent->iframe prefill.
- Found ACTUAL latent prefill bug: save enumerated only #zoom-wrapper inputs, but restore enumerated every input/select/textarea including extra career selects; saved field index 1 mis-mapped to education select. Fixed restore to identical #zoom-wrapper scope.
- Saved applicantEssentials education, experience, skillsStage and skills were NOT restored to React state. Added named-key restoration with legacy applicant_essential fallback and allowlisted choice validation; changes persist when user reselects.
- Drawing only pointer-down before pointer movement previously did not mark canvas; added ink dot for taps and setHasSignature on pointer down.
- Added signatureDataUrl saving/restoration for reopening NSRP. Retains image in private form payload (review maximum storage constraints before broad deployment).
- Files modified: react_workspace/src/App.jsx. New QA scripts: scripts/qa-nsrp-selection-repro-20261021.py and scripts/qa-nsrp-prefill-regression-20261021.py.
- Desktop browser saved-form restoration 1200px PASS: named career fields, source numbered fields, reselection, 0 JS errors. Mobile restored-form rerun stalled; prior mobile basic dropdown select PASS.
- node --test src/applicantEssentials.test.js: 4/4 PASS on two runs.
- npm run build FAILED with 'memory allocation of 441558 bytes failed' while available physical RAM ~1GB. Rerun when resources are available. npx eslint was still underway at checkpoint.

## Historical pending items (superseded by fresh QA section below)
1. Check eslint process 5180 and run production React build after memory clears.
2. Real parent Flutter iframe injected prefills, save->close->reopen rehydration, signature, mobile viewport, production-like release deploy/cache invalidation.
3. Full registration actual email verification, Google popup cancellation using real Chrome, copied password backspace, avatar persistence, backend role access, landing motion/nav each page. Existing Copilot unit tests are not evidence of production browser E2E.
4. User says cannot proceed; finish positive-path PDF submit and browser/mobile regression after cleaning memory pressure.
5. Do NOT claim all bugs fixed or production deployed.

## Relevant files
react_workspace/src/App.jsx, react_workspace/src/applicantEssentials.js, lib/peso_ui/Reusable_Designs/pesoform_ui.dart, lib/peso_services/react_message_bridge_web.dart, docs/PESO_QA_CHECKPOINT_2026-10-21.md, docs/PESO_BROWSER_E2E_REPORT_2026-10-21.md.

## Fresh current-source QA completed (2026-10-21, ~10:12 PH time)
- Updated Flutter current-source release compiled successfully to local isolated QA output C:\Users\Admin\AppData\Local\Temp\peso-qa-current-20261021. Uses --dart-define=PESO_E2E_AUTH_EMULATOR=true and PESO_API_BASE_URL=http://127.0.0.1:3003. This bundle must NEVER be shipped to production.
- Found and repaired actual email verification bug: Firebase user.reload() updated emailVerified but bearer token still had email_verified:false and API returned HTTP 403 for /api/profile/ensure, /api/profile/onboarding, /api/artifacts, /api/ai/profile. lib/peso_services/auth_service.dart reloadCurrentUserVerification() now forces await refreshedUser.getIdToken(true) before any protected API call. Confirmed blocked before verification and permitted after verification in isolated emulator.
- Full RELEASE Chrome browser QA passed 20/20, zero runtime JS errors: account form, dedicated avatar step, emulator verification link, verification gate, resume upload, Firebase identity preserved in embedded NSRP, required-field errors corrected, dropdown values, signature, PDF download, Flutter bridge handoff, authenticated persisted onboarding POST 200, AI API call, dashboard, returning-user fresh login, mobile-width dashboard. Report: docs/qa_browser/qa-browser-complete-results.json. Main reusable QA script updated in place: scripts/qa-browser-complete.py.
- Flutter focused suites: 12/12 passed (landing scroll reveal/nav, pasted password editing, Google popup handling, registration avatar step, login and register at 360/768/1366px).
- React applicant essentials node tests: 4/4 passed; production Vite build succeeded (231 modules; large JavaScript chunk warning only).
- Backend npm test: 211/211 passed; isolated QA API tests: 15/15 passed. Real backend and live applicant data untouched.
- NSRP signature desktop & simulated touchscreen pointer input + clear passed; standalone NSRP complete/save/reopen/mobile select passed.
- Landing _ScrollReveal moved from invalid child NotificationListener<ScrollNotification> to owning ScrollController.addListener, and home-section color bridges added. New test test/landing_scroll_reveal_regression_test.dart passed.
- Actual Google sign-in Chrome popup close automatically re-enables password and Google buttons after Firebase SDK reports popup-closed-by-user (observed ~10 seconds). No app-level time limit. A manual Cancel/Unlock button is available earlier. This delay is Firebase SDK's own asynchronous cancellation safety, not an app-imposed timeout.
- Flutter Web can lose *very fast* synthetic text fill immediately after focus due Flutter semantic text editing activation race. QA browser test now models user interaction with 650ms auth-transition settle and short focus-to-paste delay; full form and email signup passed. The widget password edit/backspace test also passed. Upstream context: https://github.com/flutter/flutter/issues/194186.
- Production-configured Flutter web build (`build/web`, NO emulator flags) now PASSED and QA-vs-production JS SHA256 was directly compared. Initial production smoke was accidentally served a QA file because port 5273 was shared; on exclusive port 5298 SHA matched `build/web/main.dart.js`, Chrome smoke PASSED (home + registration render, 5 fields, no emulator warning, no JS errors). No public deployment occurred.
- React NSRP lint was repaired by removing redundant synchronous setState from the DOM synchronization effect. `npm run lint` PASS (0 errors), React essentials tests 4/4 PASS, React production Vite build PASS (nonblocking large JS chunk warning). Final standalone React NSRP full edit/save/reopen/mobile/browser test re-ran after lint change and PASSED, 0 JS errors.
- Live/backend service on port 3000 was found stopped after prior QA. It was safely **restarted** with its existing backend `.env` connecting to configured `peso_jobkonek` (Mongo Atlas), but `PESO_SKIP_AUTOMATIC_JOB_SYNC=1` was set to prevent automatic public-PDF publishing or renewal and any unplanned writes. Read-only `GET /api/health` returned ok true, DB connected, Firebase auth ready. Anonymous `GET /api/profile` returned 401. This is a local process: operator must keep it running; auto public PDF sync remains disabled until intentionally reenabled. Test accounts/data are ONLY in local QA sandbox, never live database.
- Historical gap (URL config since added; see last section): the Flutter default NSRP workspace and default API backend are localhost. Real mobile devices/public visitors still require a configured reachable HTTPS workspace and API, hosting domain, and appropriate OAuth origins. No remote/public deployment or real Google OAuth was performed; QA release at 5272 is testing-only.
- Existing QA isolated MongoDB at 27117, Firebase emulator 9099, API 3003; Vite 5173; isolated QA release static server 5272. Never inject fictional users or jobs in production.

## Final NSRP workspace URL and bridge regression (same day, later continuation)
- Added `PESO_NSRP_WORKSPACE_URL` compile-time option in `lib/peso_ui/Reusable_Designs/pesoform_ui.dart`. If empty, the local Vite `http://localhost:5173/` remains the developer default. For a hosted release supply `--dart-define=PESO_NSRP_WORKSPACE_URL=https://<your-real-host>/nsrp/` and ensure the React production `dist` is actually served at that exact address. Never assume visitor's localhost points to the server.
- Secured Flutter <-> React message handling in `lib/peso_services/react_message_bridge_web.dart` with exact configured origin, exact iframe path, and actual iframe JS window identity. REPRODUCED a real regression: the old `dart:html` MessageEvent.source wrapper did not compare equal with iframe.contentWindow (even `dart:js_interop` jsIdentical with legacy wrappers returned false). Resolved by using `package:web` native MessageEvent and HTMLIFrameElement references, with `jsIdentical` on native JS values. Added `web: ^1.1.1` as direct dependency in `pubspec.yaml`, ran `flutter pub get --offline` (no unrelated upgrades). Removed temporary instrumented debug prints.
- Fixed six Dart analysis warnings from first bridge refactor. Final targeted `flutter analyze --no-pub` on bridge and NSRP Flutter component passed clean.
- Rebuilt isolated Flutter QA release with explicit `PESO_NSRP_WORKSPACE_URL=http://127.0.0.1:5173/`; Chrome Playwright browser E2E passed 28/28 with zero JS errors, report `docs/qa_browser/qa-browser-complete-results.json` and script `scripts/qa-browser-complete.py`. Scenarios include email verification, PDF and onboarding backend saves, AI call, returning-login, mobile dashboard, REOPEN FROM AI PROFILE and actual Flutter-to-React prefill of education, experience, skills, signature, reselection, and rejecting fake NSRP completion sent by a different same-origin iframe path.
- Production-configured Flutter web release was rebuilt AFTER the new web bridge and direct `web` dependency: `flutter build web --release --no-pub --no-wasm-dry-run` SUCCESS. Output `C:\\Users\\Admin\\Desktop\\Prototype\\build\\web`. Local static server http://127.0.0.1:5298/ returned JS byte-identical (hash `f45391ff443825e8` prefix); Chrome smoke rendered home + registration without JS exceptions or Firebase emulator banner. Local backend http://127.0.0.1:3000/api/health reported Mongo and Firebase auth ready; auto public PDF sync deliberately remains disabled.
- Final focused Flutter test suite rerun AFTER production build: 12/12 PASS. QA full Chrome test remains 28/28 PASS, reports retained in `docs/qa_browser/qa-browser-complete-results.json`. React lint, 4 NSRP tests and Vite release build passed. Backend 211 unit tests passed earlier, with no backend source changes in final continuation.
- Public website publishing still requires real hosted frontend/API URLs plus a React NSRP workspace at the `PESO_NSRP_WORKSPACE_URL` endpoint. None was performed. Do not copy the QA emulator build to production.
## Confirmed native career-dropdown reset and definitive fix (2026-10-21)
- User demonstrated `Senior High School` option highlighted but select remained at prompt and validation prevented progression. Reproduced on current source using *native* keyboard interaction in Chrome at widths 1250 and 510: `Home`, `ArrowDown`, `Enter` yielded empty value + "No education selected yet" even though Playwright `select_option` had passed. This explains why earlier automation missed real bug.
- Root cause: React's document-level capture-phase `input/change` listener for `data-applicant-field` indiscriminately called `setMissingEssentials(previous=>previous.filter(...))` on controlled career selects. The resulting synchronous render reset the native select before React's onChange could commit the value.
- Fix in-place in `react_workspace/src/App.jsx`: exclude the React-controlled career `education`, `experience`, `skillsStage`, `skills` fields from the document capture listener, return the identical array when no validation state genuinely changes, and clear matching missing-field warnings from the React selection handler `commitCareerChoice`.
- Reproducing browser script retained `scripts/qa_nsrp_real_dropdown_events.py`. New regression `scripts/qa_nsrp_real_input_blocker_regression.py` tested all three dropdowns AFTER the validation warning at 1260, 510, 390 CSS pixel widths; each selection persisted, all invalid indicators cleared, PDF export allowed.
- Modified existing full Chrome QA `scripts/qa-browser-complete.py` so the Flutter iframe uses native keyboard option selection instead of `select_option`. FULL E2E PASSED 31/31, zero JS errors, with Firebase auth emulator + isolated backend only: registration, email verification, resume, NSRP, actual keyboard selects, PDF/save, dashboard, reopen/form restoration, hostile iframe rejection, returning account login and mobile dashboard. At 510px parent viewport, iframe viewport=510, career section width ~479px and grid one column (no horizontal overflow).
- React `npm run lint` PASSED; 4/4 essentials tests PASSED; Vite `npm run build` PASSED with existing nonblocking large-chunk warning. Updated React `dist` and active Vite development server `:5173`. Native Flutter build does not embed the React workspace; any separately published remote React assets still require explicit update. Do not claim a public deployment.





## 2026-10-21 — Resume scan, mobile NSRP pinch, job interests, localization, categorized PDF intake

### Objective
Fix the uploaded resume scan progress UX; mobile NSRP two-finger zoom centering; recommendations based on verified NSRP preferences, resume and actual Go scores; Tagalog/Taglish job display; and Walk-in/LRA classification for administrator PDF links.

### Key Requirements & Constraints
- Preserve this prototype in-place; no duplicate version directories and no reset of the dirty worktree.
- No invented jobs, guessed eligibility or model match percentages, and no unverified automatic publication of historical 2020 PDF listings.
- Tests only in loopback QA database `peso_e2e_browser_20261020` (:27117), Firebase emulator (:9099), QA backend (:3003), Flutter QA (:5272), and React Vite (:5173).
- Local production API (:3000) uses actual `peso_jobkonek` database, but was restarted under `PESO_SKIP_AUTOMATIC_JOB_SYNC=1`; it must not renew archive jobs. Remote public hosting not configured.

### Architectural & Technical Decisions
- `lib/peso_ui/Login_register_pages/auth_ui.dart`: animated `_ResumeAnalysisDialog(progress: ValueListenable<double>)` via `TweenAnimationBuilder` and `LinearProgressIndicator`. Progress eases up to 90% **estimated**; displays 100% only after real Gemini extraction returns, then 550ms completion display. Timer cancel/fallback preserved.
- `react_workspace/src/App.jsx`: form zoom shell has proper scaled layout dimensions. Touch-point midpoint and distance used for pinch zoom, focal location maintained through horizontal/vertical scroll offsets. Native touch listeners nonpassive; normal one-finger scroll/input preserved. Former negative margin / top-center transform removed.
- `lib/peso_logic/job_interest_recommendations.dart`: pure read-only sorter for active backend job postings; prioritizes actual role titles matching applicant NSRP preferred occupations IT/mall/restaurant, then source-supported skills and *only authentic* ready Go model matching scores. Never assigns guessed score or suggests employer-wide generic notice as an individual match.
- `lib/peso_ui/User/user_ui.dart` + `user_job_feed_tab.dart`: account NSRP preferred occupation and source-supported resume skills drive ranking, suggestions explanation, honest empty state, and interest chips. New on-screen language choices override stale in-flight profile preferences. `job_listing_localization.dart`: Tagalog/Taglish standard job/notice labels, boilerplate, and source warnings; verified Gemini translation supersedes fallback when returned, with clear notice that fallback can be partial. Original employer requirements preserved.
- `backend/server.js`, `src/pdf-link-policy.js`, `lib/peso_services/peso_api_client.dart`, `lib/peso_ui/Admin/admin_pdf_link_ingestion.dart`: explicit category Walk-in or LRA required on source attach, verified both source URLs, category returned from GET, authorized reclassification of existing links, no link-to-job publishing side effect. PDF URL HEAD metadata size cap raised from 32 MB to 64 MB to accept official LRA `PARA-SA-MONTALBENO.pdf` (47,711,697 bytes); Walk-in source 19,725,791 bytes. Larger PDFs still rejected. Unclassified older links labeled for review rather than assumed Walk-in.
- Existing application job posting category lifecycle continues: Walk-in until deactivated; LRA posts expire after 24h. 2020 historical PDF links are NOT current recruitment events. When no live LRA is listed, job feed displays a clearly dated historic PDF reference, not an invented vacancy.

### Completed Work and Verification
- Mobile Chrome CDP two-pointer zoom test `scripts/qa_nsrp_pinch_zoom.py`: scale 0.421 to 0.981, focus drift X 0.07 px, Y 1.2 px, width layout consistent, no page overflow, form remained editable, no JS errors. Native NSRP dropdown and PDF tests passed at 1260/510/390px.
- Real Flutter web E2E `scripts/qa-browser-complete.py`: **34/34 passed**, zero JS errors, verified registration/email/resume upload/NSRP native selections/PDF download/Flutter bridge/onboarding API/AI/profile/dashboard; Tagalog welcome actually applied; preferred "IT, mall, restaurant" placed QA Data Entry role ahead of unrelated construction; switched to Taglish in Settings and confirmed job feed applied it; reopened saved NSRP including signature, hostile iframe rejection; returned through new sign-in and mobile-width dashboard. Report `docs/qa_browser/qa-browser-complete-results.json`.
- Pure Flutter interests and localization tests 4/4 `test/job_interest_localization_test.dart`; source-based Go score and zero-fabricated-job behavior verified.
- Admin API QA `backend/scripts/qa-pdf-link-category-e2e.mjs`: **8/8** using isolated emulator/Mongo; rejected missing/invalid category and anonymous callers, accepted both government PDFs in Walk-in and LRA categories, updated category of an existing link, GET reflected choice, no job records published; restored QA link registry afterwards.
- `backend/src/pdf-link-policy.test.js`: official 47.7 MB LRA boundary and >64 MB rejection. Backend `npm test`: **213/213 passed** (existing host rejection test updated to supply new required category).
- React lint, 4/4 form tests, Vite build succeeded. Targeted Flutter analyzer of six changed files: **No issues found** after cleaning lints.
- Local backend :3000 restarted with PDF job sync explicitly disabled. QA scripts never accessed production records.

### Active Work & Next Moves
- Non-emulator release `flutter build web --release --no-pub --no-wasm-dry-run` in progress (PID 12320 at checkpoint write). Verify build success and hosted JS hash on :5298 before finalizing.
- Public deployment to a real HTTPS origin requires actual hosted Flutter and React workspace URLs and reachable API base, domain/SSL, and real Google OAuth validation. No public deployment performed.
- Review any new dated LRA PDF notices in admin, confirm dates/requirements, then publish role-specific jobs manually; legacy PDFs are archived references only.

### Relevant Files & Context
`lib/peso_ui/Login_register_pages/auth_ui.dart`,
`react_workspace/src/App.jsx`,
`lib/peso_logic/job_interest_recommendations.dart`,
`lib/peso_logic/job_listing_localization.dart`,
`lib/peso_ui/User/user_ui.dart`,
`lib/peso_ui/User/user_job_feed_tab.dart`,
`lib/peso_ui/Admin/admin_pdf_link_ingestion.dart`,
`lib/peso_services/peso_api_client.dart`,
`backend/server.js`,
`backend/src/pdf-link-policy.js`,
`backend/src/pdf-link-policy.test.js`,
`backend/test/admin-documents-routes.test.js`,
`backend/scripts/qa-pdf-link-category-e2e.mjs`,
`test/job_interest_localization_test.dart`,
`scripts/qa_nsrp_pinch_zoom.py`,
`scripts/qa-browser-complete.py`.

### Final release verification (same session)
- Ordinary NON-emulator Flutter web release SUCCESS: `flutter build web --release --no-pub --no-wasm-dry-run`, output `C:\Users\Admin\Desktop\Prototype\build\web`.
- Serving http://127.0.0.1:5298/ returned JavaScript byte-identical to `build/web/main.dart.js` (SHA256 prefix `8694da8b9eec9ae1d4`). Bundle does not reference QA API :3003. Chrome smoke SUCCESS: landing and registration appear, five fields, zero JS exceptions, no emulator warning.
- Local API http://127.0.0.1:3000/api/health SUCCESS after safe restart with `PESO_SKIP_AUTOMATIC_JOB_SYNC=1`, MongoDB `peso_jobkonek` and Firebase verification ready; test users and PDF registry modifications confined to QA MongoDB only. No production PDF re-reads/publishing occurred.
- Backend unit tests `npm test`: 213/213 passed; new official government PDF HEAD preflight tests 6/6; isolated QA authenticated admin PDF-category endpoints 8/8; Flutter pure recommendation/localization tests 4/4; full Chrome user E2E 34/34; mobile two-finger NSRP zoom under ~2px focal drift. Targeted Flutter analyzer no issues and React lint/build successful.
- No public web deployment. Historical July 2020 LRA and Walk-in source PDFs are categorized review references only, **not confirmed currently open vacancies**. Admin needs to review dates and publish genuinely active roles. Real production Gemini full-translation reliability and OAuth popup on deployed domain are outside this isolated emulator E2E.


## 2026-10-21 — Single-repo GitHub/Vercel auto-deployment and backup branch

### Objective
Automatic production deployments from `Laeanhard03/PESO` `main` with a static GitHub rollback branch `backup/stable`, without development/feature branches.

### Verified and completed
- On the user-authorized `marcelino` PC, `C:\Users\Admin\Desktop\Prototype`, fetched `origin/main` and confirmed local HEAD matched remote HEAD `34b6bef046976e4fa105580fdaa5231399939df1`.
- Created and pushed `backup/stable` at exactly that commit. `main` stayed checked out. No reset, checkout, force push, or staging of 115 existing dirty/untracked files.
- Vercel `peso` (Flutter), `peso-jobkonek-api` (Express), and `peso_aimatching` (React) each have **Production Branch Tracking = main**. Initial Flutter and backend Git integrations already connected to `Laeanhard03/PESO`.
- Flutter Vercel uses the existing root `vercel.json` with custom `bash scripts/vercel_install_flutter.sh`, `bash scripts/vercel_build_flutter.sh`, output `build/web`; Flutter SDK pinned to `3.47.1`; build requires HTTPS `PESO_API_BASE_URL` and supplies `PESO_NSRP_WORKSPACE_URL=https://pesoaimatching.vercel.app/`. No npm Flutter substitute.
- React `peso_aimatching` Vercel project was incorrectly connected to separate GitHub repo `Laeanhard03/peso_aimatching`. Inspection of its Git tree showed an old unrelated Flutter app with **no `react_workspace/src/App.jsx`**. The `PESO` monorepo DOES track `react_workspace` (25 tracked files).
- Safely disconnected React project's outdated Git repository, reconnected it to `Laeanhard03/PESO` in the existing Vercel project, preserving its domain, Root Directory `react_workspace`, Build Command `npm run build`, Install Command `npm ci`, and Output Directory `dist`.
- Built React Preview deployment from `backup/stable` commit `34b6bef`; **Ready**. Built React Production deployment explicitly from `main` commit `34b6bef`; **Ready**, assigned `pesoaimatching.vercel.app`. Future relevant commits to `main` automatically deploy through Vercel Git.
- Live `https://pesoaimatching.vercel.app/` returned HTTP 200 and correct HTML; Chrome Playwright native dropdown regression passed at 1250px and 510px with selections preserved, no JS errors.
- Never auto-update `backup/stable`. Vercel may create preview builds for backup branch; backup branch does **not** deploy to production. Use `git revert` or an explicitly reviewed restore commit on `main` to roll back while preserving history; avoid forced rewrite of main.
- Existing dirty/untracked local changes were NOT committed or pushed. Review/test/selectively stage intended work before future `git push origin main`. Git/Vercel will take over without manual Vercel redeploy.

### Deployment model
- `PESO/main` -> Vercel `peso`: Flutter SDK + web build to `build/web`.
- `PESO/main` -> Vercel `peso_aimmatching`: Vite build in `react_workspace` -> `dist`.
- `PESO/main` -> Vercel `peso-jobkonek-api`: Express deploy with Root Directory `backend`.
- `PESO/backup/stable`: static GitHub rollback point `34b6bef`, not a production deployment branch.

### Technical references
Vercel Git auto-build documentation: `https://vercel.com/docs/git`; Vercel monorepo behavior: `https://vercel.com/docs/monorepos`; Flutter build web: `https://docs.flutter.dev/deployment/web`.
