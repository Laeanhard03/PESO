# Firebase + Firestore setup for JobKonek

> **Current architecture notice (2026-10-17):** This file contains legacy Firestore setup notes. The current app keeps Firebase Authentication for sign-in, verification, and ID tokens; the separate Node API and MongoDB Atlas own ongoing profiles, onboarding/NSRP data, AI profile fields, preferences, assessment outcomes, and document storage. See [docs/ARCHITECTURE_AUTH_MONGODB.md](docs/ARCHITECTURE_AUTH_MONGODB.md) and [backend/ADMIN_API.md](backend/ADMIN_API.md). Do **not** create/deploy Firestore rules as part of the current admin/profile migration. The Firestore steps below are legacy/reference only.

The current app uses Firebase Authentication for account sign-in, verification, password reset, and ID tokens. Configure those Authentication providers for the current architecture; use backend/MONGODB_BACKEND_SETUP.md to configure the separate MongoDB-backed API for profile and document data.

## 1. Connect the Flutter app

1. Create or choose a project at https://console.firebase.google.com/.
2. In a terminal, open the **Flutter project root** (the folder containing `pubspec.yaml`).
3. Run:

   ```bash
   dart pub global activate flutterfire_cli
   flutter pub get
   flutterfire configure
   ```

4. Select the platforms you intend to use (at minimum **Web**; also Android/iOS if applicable). FlutterFire generates `lib/firebase_options.dart` and the native platform config files. It will replace the placeholder options included in this archive.
5. Run `flutter pub get` once more after configuration.

The app deliberately lets the public landing page open before Firebase is configured. Login/registration displays a setup error until real Firebase options are present.

## 2. Enable authentication providers

In Firebase Console → **Authentication** → **Sign-in method**, enable:

- **Email/Password** — for email registration, login, and password reset.
- **Google** — for Google sign-in. Set the public app domain/OAuth configuration as required by Firebase.
- **Phone** — for SMS verification. For Web, add the deployed website domain under Authentication settings → Authorized domains. Firebase handles the reCAPTCHA check for the Flutter Web phone-auth flow.

For Android, register the app and add the required SHA-1/SHA-256 fingerprints in Firebase project settings. For iOS, finish the platform-specific phone-auth/APNs setup required by Firebase. SMS delivery is subject to Firebase quotas, anti-abuse controls, and any billing requirements. Use Firebase Console test phone numbers while developing where possible.

## 3. Legacy reference only ? Create Firestore and deploy rules (not required by the current architecture)

1. In Firebase Console → **Firestore Database**, create a database.
2. From the Flutter project root, install/use the Firebase CLI if necessary, sign into the intended account, and associate this folder with your Firebase project:

   ```bash
   firebase login
   firebase use --add
   firebase deploy --only firestore:rules
   ```

Legacy only: these rules described the former Firestore profile store. The current application checks the server-controlled Firebase Authentication custom claim admin: true; ongoing profile and document data is handled by the Node API and MongoDB. Do not follow this legacy role-field advice for current admin access.

## 4. Legacy Firestore data model (new app data belongs in MongoDB)

User profile documents live at `users/{uid}`. They can contain regular fields such as `firstName`, `lastName`, `phoneNumber`, `location`, `educationLevel`, `employmentStatus`, and nested maps/lists for flexible AI data:

- `aiProfile`: the profile returned by the existing AI extraction flow.
- `skills`: an array of skill strings.
- `assessmentOutcomes`: saved job/qualification results.
- `preferences`: language and notification settings.
- `providerIds`, `emailVerified`, `phoneVerified`, and timestamps.

Email/password registration, Google sign-in, and SMS sign-in all ensure a profile document exists. The **My Account** view is opened by clicking the name/avatar at the top right of the user dashboard. These statements describe the old Firestore implementation; the current data-write path is the authenticated Node API backed by MongoDB.

## Security reminders

- The downloadable archive uses empty placeholders for `.env` and `lib/peso_logic/secrets.json`; your original local API keys are not included. The placeholders keep the declared Flutter assets present. Never commit real `.env`, API keys, OAuth client secrets, or service-account JSON to GitHub.
- For local prototype testing, add your own `GEMINI_API_KEY` to `.env` on your machine (the real `.env` is ignored by Git). However, any key packaged into a Flutter Web frontend can be extracted by visitors. For a deployed website, proxy AI requests through a trusted backend/Cloud Function and rotate any key that was previously exposed publicly.
- Admin authorization is based on the verified Firebase Authentication custom claim admin: true and is checked again on the Node API. A MongoDB profile role field or email address alone must never grant admin access.
