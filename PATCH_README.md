# PESO JobKonek – React / Flutter onboarding data-sync patch

Copy the contents of this patch folder into the root of your existing `PESOPROTOTYPE` project, allowing these files to overwrite their matching paths.

**Do not replace** your locally configured `lib/firebase_options.dart` or `.env`. They are intentionally not included in this patch.

After copying:
1. From the project root, run `flutter pub get`.
2. Make sure the intended Firebase project has Cloud Firestore enabled.
3. To save/open original PDFs and images, create a Cloud Storage bucket in Firebase Console (Cloud Storage for Firebase requires the Blaze billing plan for default-bucket provisioning and use; review pricing and set budget alerts before enabling billing).
4. After creating the bucket, rerun `dart pub global run flutterfire_cli:flutterfire configure --project=YOUR_PROJECT_ID --platforms=web` and overwrite the generated options file so it includes the Storage bucket configuration.
5. Deploy Storage rules: `firebase deploy --only storage --project=YOUR_PROJECT_ID`.
6. Run `flutter pub get`, then press F5 or run `flutter run -d chrome`.
7. Complete onboarding again with a resume and NSRP form. Inspect Firestore `users/{uid}` and the nested `artifacts` collection, then open the AI Profile tab.

The React workspace bridge expects Vite at `http://localhost:5173`, which matches the current `dev.bat` behavior.

What it changes:
- structured resume and NSRP field payloads go from React to Flutter through the WebView channel or iframe `postMessage` bridge;
- PDFs from the uploaded resume, generated resume-builder PDF, and NSRP form PDF are sent to Flutter as base64 bytes;
- structured source fields are persisted to the authenticated user's Firestore profile before Gemini runs;
- original files are uploaded privately to Storage, with file metadata stored in Firestore;
- AI receives an uploaded original resume as file bytes plus sanitized text; in Resume Builder mode, it receives edited field text rather than the sample-filled template PDF. The NSRP PDF is not sent to Gemini because it may contain government identifiers;
- the AI Profile view displays extracted education, experience, certificates, saved form entries, resume fields, and links to stored documents.

If Firebase Storage is unavailable or Storage uploads fail, the structured Firestore fields are still saved where rules permit. Original document opening requires a configured Cloud Storage bucket.
