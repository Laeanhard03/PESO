# PESO JobKonek Task 1 — Backend contracts (local only, 2026-10-22)

## Objective
Keep the existing Express/Firebase Auth/MongoDB/GridFS stack. No push, deployment, branch changes or MongoDB migration writes.

## Identity and ownership
All routes except the barangay catalog require `Authorization: Bearer <Firebase ID token>`. UID is always derived from the verified token. MongoDB collection `users` is keyed by Firebase UID. Private documents live in GridFS `profileArtifacts`, metadata.ownerUid=UID. Existing restricted/admin APIs stay in the same server.

## New endpoints
- `GET /api/residency/barangays`: returns `{ok,municipality:"Montalban",province:"Rizal",barangays:[11],verificationRequired:true}`.
- `PUT /api/account/residency`: `{municipality:"Montalban",barangay:"Mascap",address:"Block ..."}`. Returns updated `{ok,profile}`; status becomes pending after any changed address. A selected barangay DOES NOT prove residency.
- `GET /api/account/residency`: own address and `verification:{status,revision}`.
- `PATCH /api/admin/users/:uid/residency`: admin only; `{status:"verified"|"pending"|"needs_review"|"rejected", expectedRevision:integer, note?:string}`. Responds `{ok,uid,status,revision}`; returns 409 on stale revision; verification demands complete allowable Montalban address. Audit goes into `residencyAudit`.
- `GET /api/admin/users/:uid/residency/audit`: admin-only 100 latest review events; avoid showing private documents here.
- `GET /api/account/documents`: owner-only document metadata/counts and authoritative form-presence booleans.
- `GET /api/admin/users/:uid/documents`: admin-only document metadata/counts/presence. For actual bytes, reuse existing private viewer/document authorization; do NOT expose signed public URLs indiscriminately.

## Existing compatible endpoints
- `POST /api/profile/ensure`, `GET /api/profile`, `PUT /api/profile`: profile response includes `municipality,barangay,address,residency:{status,revision},dateOfBirth,age,sex,documentSummary,onboardingRevision`; PUT allows DOB in YYYY-MM-DD and sex Male/Female/Other/Prefer not to say.
- `PATCH /api/profile/onboarding`: unchanged legacy payload `{resumeData?,pesoFormData?,onboardingText?}`. Optional `draft:true` merges supplied top-level form keys; optional `expectedRevision:N` rejects stale writes with 409 `onboarding_revision_conflict`; response profile returns latest `onboardingRevision`. Always refresh the profile/revision before resolving conflicts. Do not retry an unknown result with a different revision blindly.
- `POST /api/artifacts`, `GET /api/artifacts`, `GET /api/artifacts/:id/content`, `POST /api/artifacts/:id/link` continue using GridFS owner checking. Save source forms/files before attempting Gemini.
- `POST /api/ai/profile` remains an independent extraction step; Gemini failure does not erase persisted source fields.
- `POST /api/applications` requires verified residency or admin access. Read-only job recommendations and AI previews remain usable for onboarding and compatibility; they do not grant employment application access. Session 4 should handle 403 `residency_verification_required` on submissions.

## Migration / backwards compatibility
No destructive migration executed. Missing older residency statuses normalize to `needs_review`; such accounts do not automatically gain eligibility. Existing documents and fields remain intact. Old missing onboarding revision reads as zero. Read-only status derives from stored forms/artifact categories, not AI success. To transition genuine old residents, use admin review with evidence and audit rather than bulk setting `verified`.

## Password/session
Firebase Auth handles credential session storage/expiry. New `AuthService.changePassword(currentPassword,newPassword)` reauthenticates via Firebase email/password before changing password. Google-only accounts cannot use that method. A My Account button can call it; no applicant UI has been modified by this task.

## Verification and known limitations
- New residency helper tests: 5/5 passing.
- `node --check backend/server.js` and `node --check backend/src/residency.js`: passed.
- Broader existing tests contain fixtures without verified residency and must be updated after agreement with Session 4; do not claim clean full-suite acceptance.
- An actual Firebase browser reload/navigation/session persistence run has not been proven.
- A complete secure retry queue for offline uploads and authoritative document repair for legacy GridFS files are not yet implemented.
- Audit events are written after successful residency state update; review should consider transaction/outbox hardening before production.
- Cross-session edits already existed in the worktree and must not be discarded.
