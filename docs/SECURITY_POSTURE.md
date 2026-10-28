# Security posture and safe configuration

## Firebase client API key

The API key in lib/firebase_options.dart is part of the public Firebase client configuration. Firebase documents that Firebase API keys identify the project/app; they are not authorization credentials. Removing the key or rotating it only because it is visible in a client bundle can break sign-in without fixing access control.

The owner should verify in Google Cloud Console that the client key is restricted to the Firebase APIs PESO actually uses, and that no Gemini Developer API is allowed on that public key. Also review Firebase Authentication quotas, App Check where applicable, Firestore rules, and Storage rules. These console-side restrictions cannot be verified or changed from this source checkout.

References:
- https://firebase.google.com/docs/projects/api-keys
- https://firebase.google.com/support/guides/security-checklist

## Server-side credentials

- MongoDB credentials, Gemini Developer API keys, the Gemini key-encryption secret, file-link/export signing secrets, and Firebase Admin service-account private keys belong only in backend/.env for local development or the existing Vercel project's server-side environment.
- Never copy those values into lib/firebase_options.dart, React source, a Flutter --dart-define, or a committed environment example.
- Keep service-account JSON outside Git. The repository ignores backend/service-account.json and local .env files.
- Use a least-privilege MongoDB database user scoped to peso_jobkonek. Do not paste a full MongoDB URI into issue reports or logs.
- Use separate API keys for non-Firebase Google APIs. Do not enable the Gemini Developer API on the public Firebase client key.

## Local Git trust

The Windows dev.bat launcher previously marked every Git repository on the machine as safe using a global wildcard. That weakened Git's ownership protection for unrelated repositories. The wildcard has been removed; the launcher no longer changes global Git safe-directory settings.

## Access-control baseline

The tracked Firestore rules deny collections by default and restrict user documents to the signed-in UID, with an explicit admin-token read path. The tracked Storage rules scope artifacts to a user's own UID and restrict content type and size. Keep these rules under review as new collections or artifact types are added. The authenticated Node API remains the source of truth for MongoDB/GridFS profile and document data.

## Limits of this source audit

Source inspection cannot confirm live Google Cloud API-key restrictions, App Check enforcement, production Firebase rules deployment, MongoDB network access, or Vercel environment values. Verify those in the respective consoles without copying secret values into chat or Git.