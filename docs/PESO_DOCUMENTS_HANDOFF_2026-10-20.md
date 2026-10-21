# PESO Profile Documents: Verification & Canva Handoff (2026-10-20)

## Scope
- Preserved the existing PESO Mini-AI and protected authentication flows.
- Backend route `GET /api/artifacts/:id/content`: authenticated Firebase bearer token and MongoDB GridFS owner check; no-store, inline PDF bytes. No public document URL required.
- Flutter PDF preview: `lib/peso_ui/User/profile_document_dialog.dart`, `profile_pdf_view_web.dart`; browser Blob URL is created locally and revoked after closing; download and retry are available. This bypasses popup blockers for normal viewing.
- Resume replacement: user chooses a valid PDF under 20 MB, upload creates a new private artifact, and the profile metadata is updated. Old GridFS artifacts remain for history.
- NSRP: `nsrp_entries_editor.dart` edits the structured saved values. For original Form 1 formatting use **Edit full Form 1 and regenerate PDF**; the React NSRP wizard pre-fills via trusted iframe postMessage and re-saves its official-style rendered PDF plus structured fields.
- Canva PDF editor: the user explicitly chooses **Edit in Canva**. PESO downloads a private PDF to their computer and opens the official Canva PDF editor in a separate tab; users sign in with their own Canva/Google login, import their file, export an edited PDF, then return to PESO and choose **Upload revised PDF**. This is a manual handoff, **not** automatic Canva account linking.

## Canva automated OAuth integration still required
True auto-import and auto-return cannot be implemented from a static Canva URL. Canva Connect requires a developer integration, redirect URI, client ID/secret, OAuth PKCE scopes (`design:content:write`, `design:content:read`), authenticated binary PDF import and asynchronous export jobs. No Canva Connect credentials are configured in `backend/.env`. Do not send confidential resumes to the publicly accessible URL-import API. Any future automated design-export roundtrip must store user-scoped OAuth tokens securely, verify callback state and return ownership, and obtain user consent before third-party transfer.

Official API docs: https://www.canva.dev/docs/apps/rest-apis/reference/design-imports/ and https://www.canva.dev/docs/apps/rest-apis/reference/exports/ .

## Verification
- Live local backend restarted, `GET /api/health` reports MongoDB connected.
- Anonymous `GET /api/artifacts/not-an-id/content` returns 401 (new protected route is active).
- Backend `npm test`: **181 tests passed**, including owner/other-user/anonymous content access and exact PDF bytes.
- Flutter `flutter test test/profile_document_workflow_test.dart test/user_ai_profile_responsive_test.dart test/user_responsive_ui_test.dart`: **6 widget tests passed**; NSRP save and resume preview/replacement tested with controlled bytes.
- React `npm run build`: passed with a bundle-size warning.
- Flutter production web build **PASS**, isolated output at `build/peso_documents_web_verify`. An earlier build sharing `build/web` with another concurrent process failed with `PathExistsException` copying a job photo; the isolated build succeeded without that collision.
- Focused `flutter analyze --no-pub` on the eight touched Dart UI/services files reports **No issues found**.
- NSRP edited AI summaries include job-related fields only; personal identifiers remain in the private form records and do not enter the AI summary.
- Not yet verified by a real signed-in browser click in Chrome or a real Canva account handoff.

## UI usage
1. User profile > AI Profile > Saved Resumes & Forms > eye icon opens a private in-app PDF preview.
2. NSRP > Edit saved entries; or **Edit full Form 1 and regenerate PDF** to update the original Form 1 layout and save a new PDF.
3. Resume > Preview > Edit in Canva; download the source, open Canva, sign in with Google if preferred, edit/export the PDF, switch back to PESO, choose **Upload revised PDF**.
4. The verified latest Flutter web build is now served locally at `http://localhost:63041` (HTTP 200); React (Vite) runs on `http://localhost:5173` (HTTP 200) and the PESO backend at `http://127.0.0.1:3000` (HTTP 200). CORS accepts the web frontend origin, and the protected document endpoint rejects anonymous requests (401). Perform a hard refresh in Chrome after updates.
