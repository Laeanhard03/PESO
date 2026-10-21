# PESO JobKonek — 20 October 2026 development checkpoint

## Objective
Upgrade user-facing Flutter screens and admin workflows into a professional, responsive, low-overhead portal without changing Firebase identity, MongoDB data ownership, or existing job-posting rules.

## Key Requirements & Constraints
- No automatic qualification failure or rejection from the placeholder evaluator. Guidance must be supportive and transparent; never represent a rule-based prototype as a trained AI.
- At most ten relevant job questions; experience, schedule, location, practical skills, role-specific licensing/certification, and support needs as appropriate.
- A readiness preview is NOT a submitted job application. Submitting to PESO requires a separate, affirmative confirmation.
- Keep images role-related and diverse without extra scroll-time image requests. Preserve the Flutter green-and-cream identity and avoid full-screen blur effects.
- Applications, resumés, Excel, Gemini keys and PDF intake are admin-protected; do not expose tokens or encrypted secrets.
- Preserve other developer work; this repository contains unrelated existing uncommitted changes.

## Architectural & Technical Decisions
- User matching preview: deterministic, local-only functions in `lib/peso_ui/User/job_readiness_model.dart`; `JobReadinessDialog` produces a JSON-compatible `status: readiness, previewOnly: true` report, then Outcomes uses `ReadinessReportCard`.
- Separate application: `UserProfile._submitReadinessApplication` confirms user consent and posts up to ten answers using the existing `POST /api/applications`. It marks a report `applicationSubmitted: true` only after the API responds successfully. The backend does not coerce missing match score to zero.
- Job detail scroll: a stable `GlobalKey` is placed OUTSIDE the detail `AnimatedSwitcher`; switching cards animates the interior child with a per-job `ValueKey`.
- Job photos: 15 bundled Pexels photos in `lib/assets/job_photos/` (sources noted in SOURCES.txt), selected by role and stable per-job hashing in `PesoImageAssets.jobFallbackFor`. No new runtime image package.
- Cancelled Firebase Google popup: login/registration forms provide explicit cancel/unlock button, bounded timeout, and request generation guards; ignore cancelled promises if they complete late.
- Admin consolidation: `Jobs & Sources` has Postings/PDF Sources tabs; `Recruitment Pipeline` has Applications/DOLE Excel; `AI & Platform` has Gemini API Keys/Platform Analytics. Existing child screens are reused. Obsolete simulated ingestion model and panel were removed.
- Excel: `AdminExcelLivePreview` is a categorized, horizontally scrollable read-only live view, refreshing every 30 seconds. User and application APIs are paginated; the viewer reports errors instead of silently truncating pages. `generateAdminWorkbookBuffer` rebuilds XLSX from real Mongo profiles+applications on each download and creates categorized worksheets. Includes new questionnaire fields; spreadsheet formula-sensitive values are treated as text.
- Résumé: admin-only API issues short-lived HMAC links tied to an individual uid/file. Serves original GridFS resume uploads/builder files or escaped, CSP-restricted HTML for structured resume-builder data. Never accept the general Excel token for arbitrary resume access.
- PDF link intake: an admin adds a direct public HTTPS PDF URL (government .gov.ph by default; extra domains via `PESO_PDF_ALLOWED_HOSTS`). Server checks size/type and does HEAD with bounded GET fallback, then saves under `jobPdfLinks` as `awaiting_review`. Admin can open the verified original PDF. **This does NOT automatically extract/publish jobs**; use the existing Job Postings workspace after manual review. Keep this limitation visible.
- Local service runner is `scripts/run_peso_desktop_service.ps1`. Desktop launcher is `scripts/launch_peso_desktop.ps1` and manages ports 3000 (API), 5173 (Vite), and 5237 (Flutter).

## Completed Work / Verification
- Backend test suite: 169/169 passing as of this checkpoint (`cd backend && npm test`).
- Focused Flutter suites passed: 22 targeted user/admin/auth/responsiveness tests; 7 career/application/Google cancellation tests; 6 admin-workspace responsive tests.
- Prior redundant/outdated code removed without changing real API auth or job data.
- UI files were formatted with `dart format`; complete Flutter validation/release build is still in progress at the time of writing.

## Active Work & Next Moves
1. Finish the full Flutter test run, resolve any regression, then run `flutter build web --release --no-pub` and static analysis. Distinguish pre-existing info lints from introduced analyzer errors.
2. Restart the verified local API process via the PESO launcher, not by starting a second server on port 3000. Confirm `GET /api/health` readiness and browser API calls.
3. Start/reuse Flutter service on 127.0.0.1:5237 through launcher if possible; the old temporary Chrome debug port 57566 is not part of the supported desktop launcher.
4. Actual trained AI qualification model, automatic parsing of newly attached PDFs, Firebase popup behavior with live OAuth credentials, and production device FPS still require later work/testing; do not claim those are already complete.

## Relevant Files
- `lib/peso_ui/User/job_readiness_model.dart`
- `lib/peso_ui/User/job_readiness_dialog.dart`
- `lib/peso_ui/User/readiness_report_card.dart`
- `lib/peso_ui/User/user_ui.dart`, `user_job_feed_tab.dart`, `user_outcomes_tab.dart`
- `lib/peso_ui/Login_register_pages/login_ui.dart`, `register_ui.dart`
- `lib/peso_ui/Admin/admin_ui.dart`, `admin_excel_live_preview.dart`, `admin_pdf_link_ingestion.dart`, `admin_user_management_section.dart`
- `lib/peso_ui/Reusable_Designs/peso_images.dart`, `lib/assets/job_photos/`, `pubspec.yaml`
- `backend/server.js`, `backend/src/admin-excel-report.js`, `pdf-link-policy.js`, `resume-preview.js`
- `backend/.env.example` (configure `PESO_EXPORT_SECRET` and `PESO_PDF_ALLOWED_HOSTS` as needed)
- Tests: `test/job_readiness_preview_test.dart`, `test/google_popup_cancellation_test.dart`, `test/admin_workspaces_responsive_test.dart`, `backend/test/admin-documents-routes.test.js`, `backend/test/job-applications-routes.test.js`, `backend/src/*.test.js`

## Unified notification update — 20 October 2026
- Replaced lower-page Flutter SnackBars with one accessible status notification in `lib/peso_services/app_toast.dart`: green success, red error, amber warning and blue information.
- White card design with PESO green typography, soft elevation, status icon, explicit close button, subtle animated entry/exit, and shrinking duration indicator. Desktop notifications appear bottom-right; mobile cards fit within narrow viewports and move above the keyboard.
- Central helper supports `AppToast.success/error/warning/info`, optional title/duration, legacy icon/color, and `showInOverlay` for route handoffs. Notifications replace rather than queue; the last error remains visible longer.
- Updated notification calls throughout Flutter Admin, authentication, User, PDF/Excel management and AI onboarding. Converted the old Admin `showToast` helper and updated fallback `PesoTheme.snackBarTheme`.
- Newly added `test/app_toast_test.dart` verifies desktop positioning/dismissal, mobile long-message layout and replacement/timeout. Focused tests 12/12, full Flutter tests **115/115**, core notification/theme analyzer **zero issues**. Other existing informational lints remain in the wider codebase.
- Notifications show friendlier troubleshooting messages rather than exposing raw exception text in profile save, opening documents, and AI processing flows. The React NSRP/resume workspace uses browser alerts, not Flutter bottom notifications, and was not changed here.
- Final release check: `flutter build web --release --no-pub` succeeded; the verified Flutter-only runner was restarted using the PESO launcher without restarting API/Vite. Launcher reported all services ready and reused the existing Edge app window. GET `/` on Flutter/React both returned HTTP 200; `/main.dart.js` returned HTTP 200; API health reports MongoDB connected and Firebase token verification ready. Existing Edge tabs may need Ctrl+Shift+R to reload in-memory Flutter code. Existing MongoDB, Firebase, PDF intake, readiness/evaluator limitations are unchanged.
