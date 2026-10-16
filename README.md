# PESO JobKonek

Flutter + React prototype for the PESO Montalban JobKonek flow, with Firebase-backed user profiles, onboarding data, artifacts, and AI-assisted profile extraction.

## Working notes

- SYSTEM_STATUS.md tracks source features, local test evidence, and what's still required for online production.
- GEMINI_GATEWAY_SETUP.md explains the secure Gemini backend, Secret Manager setup, allowed browser origins, deployment, and build configuration.
- ONBOARDING_DATA_SYNC.md and PATCH_README.md document the data-sync integration.

## Secure Gemini setup

Gemini API credentials are not embedded in Flutter, stored in Firestore, or committed to Git. The client calls the authenticated Firebase Function, and the server reads GEMINI_API_KEY from Google Secret Manager. Browser requests are rejected until the deployed function is configured with the exact production origins.

Before production, rotate any credential that may have existed in old Git history, configure the owner-controlled Secret Manager entry and origin allowlist, deploy the function, and test auth/quota behavior. See GEMINI_GATEWAY_SETUP.md. No live backend deployment was performed by this code change.
