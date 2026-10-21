# PESO data architecture: authentication plus MongoDB

## Standing development rule

Use Firebase Authentication for account identity, email/password and Google sign-in, email verification and password reset, ID-token issuance, and server-side Auth account actions. Do not use Cloud Firestore or Firebase Storage as the app's ongoing profile/database/document store. Do not add Firebase Cloud Functions as a default requirement.

Use the authenticated PESO API and MongoDB Atlas for:
- User profile fields and profile preferences
- NSRP and resume form submissions, extracted AI profile data, and assessment outcomes
- Resume/NSRP/document bytes in MongoDB GridFS, with owner UID metadata and short-lived signed download links
- Admin profile listing and profile-field edits
- Private files, with the API enforcing owner access server-side

## Security contract

- Flutter gets the active Firebase ID token and sends it as an Authorization: Bearer header to the API.
- The Node API validates the token through Firebase Admin. It derives the profile UID from that verified token rather than trusting a client-supplied owner ID.
- Admin endpoints independently enforce the verified admin: true custom claim server-side.
- When MongoDB is offline, the admin API can still list Firebase Auth accounts and enable/disable ordinary login accounts; profile edits return a clear mongodb_not_ready response, and account deletion is blocked until private profile/GridFS cleanup can run safely.
- Admin profile updates accept only approved profile fields; role, UID, and email cannot be changed through the profile-edit endpoint.
- Protect administrator accounts and block self-disable/self-delete.
- Never put MongoDB credentials, Firebase service-account JSON, Gemini credentials, or file-link secrets in Flutter code or Git.
- Never turn off existing Firestore rules or deploy new ones as part of this migration. The current client should not need Firestore/Storage rules for new app data.

## Local configuration prerequisites

The backend lives in the backend folder. Use backend/configure-backend.ps1 to configure the MongoDB URI and Gemini API key via hidden input, then provide the trusted Firebase Admin service-account JSON locally or use supported Google credentials. Do not commit or print those secrets. Start the API with npm run dev from backend and verify /api/health reports MongoDB connected and Firebase Admin ready.

The Flutter API base is configured via --dart-define=PESO_API_BASE_URL=...; local web uses loopback on port 3000 by default. Android emulator uses 10.0.2.2 by default. A physical phone or a different computer requires a reachable LAN/HTTPS API URL.

## Migration state as of 2026-10-17

- Admin dashboard and User Management use the MongoDB API; they no longer read Firestore.
- Admin endpoints have authentication-claim, field-whitelist, protected-account and cleanup tests.
- The Flutter AuthService profile/onboarding/preferences/outcomes calls have been redirected to the MongoDB API in the current worktree.
- The profile-artifact service migration to MongoDB GridFS is prepared but still awaiting explicit file-write approval.
- The copied API source and config-independent tests are ready. Live API use is not yet verified because this workspace currently has no configured backend/.env, MongoDB URI, backend/service-account.json or Google application credentials.
- The API includes an optional, temporary read-only legacy Firestore profile import when a MongoDB record is missing; ongoing writes should target MongoDB. Remove that migration fallback after legacy profiles are migrated or otherwise accounted for.
- No Firebase rules were deployed, no Firebase plan/billing change was made, and no Firebase Cloud Function deployment was attempted.

## Developer reminder

Before adding or changing persistence code, check this document first. Keep the API contract in backend/ and lib/peso_services/peso_api_client.dart as the common boundary for Flutter and React/NSRP form submission. Keep Firebase Auth as identity only; do not introduce new client Firestore/Storage writes for profile, onboarding, or private files.
