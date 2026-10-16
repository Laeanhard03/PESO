# Production Gemini gateway setup

This project deliberately does not commit encrypted or plaintext Gemini keys. An encryption key bundled in Flutter can be recovered by anyone who inspects the distributed app. Use Google Cloud Secret Manager through Firebase Functions instead.

## Before deployment

- Revoke any old Gemini API key that was stored in local secrets.json or .env if the repository history was publicly accessible. Deleting a secret file from the latest commit does not erase prior Git history.
- Confirm the Firebase project and billing owner. Cloud Functions deployment may require an eligible billing account.
- Use a project credential that the app owner is authorized to manage. Do not collect coworkers' personal keys or rotate across accounts to evade quotas. Gemini quotas are generally project-scoped.

## Set the secret

From the repository root, run this command in a trusted terminal:

    firebase functions:secrets:set GEMINI_API_KEY

Enter the newly rotated API key only at the CLI's secure interactive prompt. Do not pass it as a command-line argument, save it in a file within the source tree, add it to GitHub Actions logs, or paste it in chat. The Cloud Function binds only this secret and reads it at runtime.

For non-secret deployment parameters, create a local file named functions/.env.capstone-4th-year-peso-ai (copy the shape of functions/.env.example) and set GEMINI_MODEL plus GEMINI_ALLOWED_ORIGINS there. Set GEMINI_ALLOWED_ORIGINS to your real comma-separated web origins, such as https://jobs.your-real-domain.example; add a localhost origin only for local development. This project-specific parameter file is ignored by Git. Do not put the API key in it.

The default server model is gemini-3.6-flash. Change the non-secret GEMINI_MODEL parameter if your project is configured for another supported model. During deployment, set GEMINI_ALLOWED_ORIGINS to a comma-separated list of the exact production web origins, including scheme and hostname (for example, https://jobs.example.org). The default is empty and browser origins are rejected until you configure it. Native clients without an Origin header still require Firebase Authentication.

## Install and test the backend

    cd functions
    npm install
    npm test
    npm run lint
    cd ..

## Deploy the gateway

    firebase deploy --only functions:geminiGateway

This operation has not been performed by this task. It requires owner-controlled billing/permission review and the secret to be configured first.

The URL normally follows this form:

    https://us-central1-capstone-4th-year-peso-ai.cloudfunctions.net/geminiGateway

Build the Flutter web app with the public endpoint configured:

    flutter build web --dart-define=GEMINI_GATEWAY_URL=https://us-central1-capstone-4th-year-peso-ai.cloudfunctions.net/geminiGateway

Use the exact URL printed by Firebase after deployment if the project or region differs. The URL is public configuration, not a secret. Native builds need the same dart-define at build time.

## Security and quota behavior

- Requests require a valid Firebase Authentication ID token.
- Each authenticated UID is limited to 20 gateway requests per rolling one-hour window.
- Requests are limited to 8 MB total, 20,000-character questions, 60,000-character supplemental profile text, and at most three PDF/JPEG/PNG attachments up to 4 MB each.
- Transient upstream 502/503/504 failures receive at most three total attempts with exponential backoff and jitter.
- Gemini HTTP 429 is returned with Retry-After guidance. The server does not switch accounts, projects, or keys to bypass a quota. If a daily/project limit is reached, wait for reset or request a quota increase.
- Restrict the function's CORS origins to actual production web domains, enable Firebase App Check where appropriate, set billing alerts, and live-test access control before launch.


## Admin registered-user management

The admin user-management panel calls adminListUsers, adminUpdateUser and adminDeleteUser in the Functions source. These callable endpoints require the Firebase Authentication custom claim admin: true and reject edits/deletions of administrator accounts and the caller's own account. Editable fields are explicitly allowlisted; role, UID and custom claims cannot be changed through the UI. Deletion also attempts to remove user-prefixed Storage objects and the Firestore document tree, and records an admin audit event.

To configure the existing trusted admin one time, use a trusted machine with Google Application Default Credentials for the correct Firebase project:

    gcloud auth application-default login
    $env:FIREBASE_PROJECT_ID="capstone-4th-year-peso-ai"
    $env:ADMIN_UID="the-administrator-auth-uid"
    node functions/scripts/set-admin-claim.js

Use the intended administrator UID obtained from the Firebase console; never grant the claim to an ordinary user. The script preserves other custom claims. To revoke the admin flag, set ADMIN_REVOKE_ADMIN_CLAIM=true before running the same script. After setting or changing claims, sign out/in again so the ID token refreshes.

The callable functions are source-only until deployed. No real user account was edited/deleted and no admin claim was assigned by this task. Test using a disposable account after deploying to the intended project.
