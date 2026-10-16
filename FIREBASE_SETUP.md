# Firebase + Firestore setup for JobKonek

The app now uses Firebase Authentication for sign-in and Cloud Firestore as its flexible NoSQL profile store. The source archive cannot create or configure a Firebase project on your behalf, so complete this setup once before testing real registration, Google sign-in, or SMS login.

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

## 3. Create Firestore and deploy rules

1. In Firebase Console → **Firestore Database**, create a database.
2. From the Flutter project root, install/use the Firebase CLI if necessary, sign into the intended account, and associate this folder with your Firebase project:

   ```bash
   firebase login
   firebase use --add
   firebase deploy --only firestore:rules
   ```

The supplied `firestore.rules` allows each user to access only `users/{their-auth-uid}` and prevents clients from changing the stored `role` field. The app creates ordinary accounts with the role `job_seeker`. To grant staff/admin access, assign the `role: "admin"` field through a trusted Firebase Console/Admin SDK workflow; do not expose an admin code in the client.

## 4. Data model

User profile documents live at `users/{uid}`. They can contain regular fields such as `firstName`, `lastName`, `phoneNumber`, `location`, `educationLevel`, `employmentStatus`, and nested maps/lists for flexible AI data:

- `aiProfile`: the profile returned by the existing AI extraction flow.
- `skills`: an array of skill strings.
- `assessmentOutcomes`: saved job/qualification results.
- `preferences`: language and notification settings.
- `providerIds`, `emailVerified`, `phoneVerified`, and timestamps.

Email/password registration, Google sign-in, and SMS sign-in all ensure a profile document exists. The **My Account** view is opened by clicking the name/avatar at the top right of the user dashboard. Saving changes updates Firestore; AI profile, preferences, and assessment outcomes are also written to Firestore.

## Security reminders

- The downloadable archive uses empty placeholders for `.env` and `lib/peso_logic/secrets.json`; your original local API keys are not included. The placeholders keep the declared Flutter assets present. Never commit real `.env`, API keys, OAuth client secrets, or service-account JSON to GitHub.
- For local prototype testing, add your own `GEMINI_API_KEY` to `.env` on your machine (the real `.env` is ignored by Git). However, any key packaged into a Flutter Web frontend can be extracted by visitors. For a deployed website, proxy AI requests through a trusted backend/Cloud Function and rotate any key that was previously exposed publicly.
- Do not use an email address or a client-editable Firestore field as proof that someone is an admin. This app keeps the role field unchanged in client profile edits, but a production admin system should use server-controlled custom claims and enforce them in rules.
