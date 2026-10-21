# PESO JobKonek — Task 4 final local checkpoint (2026-10-22)

## Objective
Complete canonical jobs, featured/public/applicant feeds, application/outcome handling, official notifications, LRA lifecycle and protected deletion IN THE EXISTING repo. Preserve Gemini → Go Mini-AI as career guidance, independent of official PESO/employer decisions.

## Key Requirements & Constraints
- Existing repo only: `C:\Users\Admin\Desktop\Prototype`. Keep pre-existing dirty worktree, `main` and `backup/stable`.
- **No Git commit, push, deploy, production job insertion or restart of original API :3000.**
- MongoDB `jobPostings` is authoritative. No demo employers or vacancies on public/production views.
- Access: public discovery is read-only; applicant actions require Firebase authentication and Session 1's server-side Montalban residency checks; admin deletion/status requires MongoDB-verified admin.
- LRA expiry is **23:59:59.999 Asia/Manila on the last scheduled recruitment day**, not a rolling 24 hours; historical listings remain stored.

## Architectural & Technical Decisions
- New `backend/src/job-feed-service.js` owns server-side Mongo active/expiry filtering, escaped query/category/type search, stable latest sorting and paged results. Public and signed-in routes share the same implementation.
- Public landing/Home/Jobs fetch saved jobs in pages (first 60), with debounced search and two-minute refresh. Signed applicant feed fetches first 60, supports incremental loading, stale-request guards and periodic refresh. Public/secure API uses `Cache-Control: no-store`.
- `ensureJobFeedIndexes()` provides 5 idempotent indexes for active job sorting/category, linked PDF roles and owner-scoped applications/notifications. Index errors are logged safely without blocking API startup.
- For LRA, admin specifies `recruitmentDate` and `recruitmentEndDate` as YYYY-MM-DD Philippine calendar days. Past events cannot be published anew. Old unscheduled public-PDF LRA notices do not qualify as confirmed upcoming events.
- PDF-sourced notice-to-role linkage is provenance-based. Paginated notice cards carry a safe set of linked public roles, so later pages do not break role selection.
- First real job application is an atomic insert with deterministic Mongo `_id` from Firebase UID+real stored job ID, preventing simultaneous duplicate submissions across processes. Server derives job title, employer, location, category from Mongo; client-provided match score is not an official outcome.
- Official application states include submitted, under_review, matched, accepted, rejected, action_required, with plain-language applicant labels. Notification records are owner-scoped projections of saved application records (never fake job alerts).
- Job deletion is audited **soft deletion**, preserving job history and dependent applicant submissions. Periodic public-PDF synchronization respects deleted tombstones and cannot silently resurrect deleted records.

## Completed Work
- **Canonical saved jobs**: `GET /api/public/jobs` for signed-out discovery and `GET /api/jobs` authenticated. Both support `limit`, `pageToken`, `q`, `category`, `type` and return `{ok,jobs,nextPageToken}`. Existing full-list API helper iterates pages instead of silently truncating them.
- **Public Home/Jobs**: removed five hardcoded employers. Real saved titles, employer data, genuine image/logo URLs where stored, neutral fallback only, appropriate searchable filters, loading/empty/retry states and incremental loading.
- **Applicant Job Feed**: actual saved jobs, debounced server-side search, strict LRA versus walk-in filtering, Go-recommendation ordering without invented jobs, image/logo rendering, featured horizontal carousel arrows + swipe, explicit loading/error/empty and Load more.
- **Admin Job Postings**: paginated saved list; LRA first/final day pickers; optional employer/logo and job-image URL inputs; clear expiry indicators, protected deactivate/reactivate and delete actions, explicit bulk-delete confirmation.
- **Application backend/UI**: prevent submissions for nonexistent/expired/deleted job and notice-only group; 409 `application_already_submitted` preserves original responses and official review status; success modal only after confirmed 201; admin application view paginates and updates real official status.
- **Outcomes and notifications**: real owner-scoped application history in Outcomes, plain official statuses, PHT submission dates, explicit separation of Gemini/Go AI advice from PESO/employer decisions. Header notification icon on mobile and desktop opens actual saved application updates; selecting one expands its exact application in Outcomes, not Settings.
- **Deletion**: protected `DELETE /api/admin/jobs/:id` and `DELETE /api/admin/jobs` (body `{confirmation:"DELETE ALL JOBS"}`). Archive timestamps/actor retained, no physical cascade into application history. `GET /api/admin/jobs?includeDeleted=1` provides history to authorized staff.
- **Matching integrity**: Go eligibility now reuses the exact LRA visibility rule rather than the old 24-hour expiry estimate; neither model weights nor external provider integrations were replaced.

## Admin and Applicant API Contract (for Session 3 coordination)
- `GET /api/admin/jobs?limit=100&pageToken=0[&includeDeleted=1]` -> `jobs`, `nextPageToken` (admin only).
- `POST /api/admin/jobs` -> saved job with valid category and posting metadata; LRA requires valid event dates or uses PH publication day.
- `PATCH /api/admin/jobs/:id/status` body `{active:boolean}` -> 409 on expired LRA, 404 on deleted.
- `DELETE /api/admin/jobs/:id` -> `{ok:true,deleted:1,id,retainedHistory:true}`; 404 absent/deleted.
- `DELETE /api/admin/jobs` body exact `{confirmation:"DELETE ALL JOBS"}` -> `{ok:true,deleted:N,retainedHistory:true}`; 400 without confirmation.
- `GET /api/public/jobs?limit=30&pageToken=0&q=...&category=...&type=...` -> real active visible saved jobs; public-safe.
- `GET /api/jobs` same filters, authenticated and residency-compatible; no synthetic matching percentages.
- `POST /api/applications` body includes `jobId` (persisted Mongo ObjectId) and nonempty `answers`. First 201; duplicate 409; unavailable 409; invalid 400; subject to signed user residency eligibility.
- `GET /api/applications?limit=100&pageToken=...` -> applicant-only application history.
- `GET /api/notifications?limit=30` -> applicant's saved application notifications, each with `target:"outcomes"` and exact `applicationId`.
- `GET /api/admin/applications`, `PATCH /api/admin/applications/:id/status` support authorized review/update (including action_required).

## Completed Work — Verification
- **57/57 targeted Node backend tests PASS**, covering PHT LRA boundaries, real Mongo-derived jobs, search/category/pagination, official role provenance, saved data ownership, admin permissions/deletion, PDF tombstone preservation, Go Mini-AI, 12 concurrent applications and notification routing. `node --check` for server/job-feed service passed.
- **5/5 targeted Flutter job matching/localization tests PASS**. Both production-configured local Flutter web release and isolated QA-configured web release built successfully.
- **5/5 local Chrome/Playwright public UI checks PASS** against the isolated QA environment: actual persisted QA vacancy in Home (after scrolling) and Jobs, old demo employers absent, unrelated search empties results, clearing restores saved vacancy, zero page errors and HTTP200 public API fetches.
- `git diff --check` for Task 4 changed files: PASS; Git reported only LF→CRLF future conversion warnings.
- Additional general backend tests were started with local Mongo-only overrides. Do not equate them with production deployment acceptance.

## Active Work & Next Moves
- **Implementation is local and ready for coordinated release review; not yet deployed by explicit user instruction.** Hosting `peso-psi.vercel.app` and real end-to-end authenticated hosted acceptance necessarily await explicit authorization to push/deploy. Do not claim those are already updated.
- Session 1 owns residency/auth contracts and Session 3 owns User Management/analytics. Do not remove their existing changes. Session 5 owns unrelated public gallery and About.
- When a separate release is authorized: ensure new `backend/src/job-feed-service.js` is included in Git and backend deploy, inspect live Mongo index-permission logs, run authorized production read-only smoke checks, and confirm hosted candidate/admin paths.
- QA preview and local backend were launched only on temporary ports 5289/3004 against the local MongoDB `peso_e2e_browser_20261020` and Firebase emulator :9099, not on production.

## Relevant Files & Context
`backend/server.js`; `backend/src/job-feed-service.js`; `backend/src/job_postings.js`; `backend/src/mini-ai-service.js`; `backend/src/public-pdf-ai-listings.js`; `backend/test/job-routes.test.js`; `backend/test/job-applications-routes.test.js`; `backend/src/public-pdf-ai-listings.test.js`; `lib/peso_services/peso_api_client.dart`; `lib/peso_models/job_posting.dart`; `lib/peso_ui/Landingpage/landingpage_ui.dart`; `lib/peso_ui/User/user_ui.dart`; `lib/peso_ui/User/user_job_feed_tab.dart`; `lib/peso_ui/User/user_outcomes_tab.dart`; `lib/peso_ui/Admin/job_management_section.dart`; `lib/peso_ui/Admin/job_applications_section.dart`.
