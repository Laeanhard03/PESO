# React resume / NSRP → Flutter → Firebase data sync

This patch connects the React workspace forms with the Flutter onboarding flow.

## What it does

- React's NSRP form sends labeled field values, a sanitized AI-text subset, and a generated PDF to Flutter.
- React's resume builder sends edited resume fields, a plain-text resume, and a generated PDF to Flutter. Unmodified template sample text is excluded from the extracted profile payload.
- The uploaded-resume path also sends the selected PDF/image bytes to the same onboarding flow.
- Flutter stores structured `resumeData`, `pesoFormData`, and sanitized `onboardingText` on the signed-in user's `users/{uid}` Firestore document.
- Original resume and NSRP/resume-builder PDFs are stored in a private Cloud Storage path `users/{uid}/artifacts/{artifactId}`; Firestore stores metadata and the Storage path, not a persistent download URL.
- AI receives uploaded original resume files as bytes plus sanitized supplemental text. In Resume Builder mode, AI receives only edited text fields, not the sample-filled template PDF. The NSRP PDF is stored privately but never sent to Gemini because the form can contain government ID numbers.
- The user AI Profile tab loads and displays saved documents, the NSRP saved entries, and resume fields, and lets the signed-in user open saved files.

## Apply the patch

1. Copy the files in this patch over the matching paths in your existing project. Do **not** replace your local `lib/firebase_options.dart` or `.env` with any archived copy; keep the values you have already configured locally.
2. From the project root, run `flutter pub get`.
3. In Firebase Console for the intended project, create a Cloud Storage bucket if you do not already have one. Cloud Storage for Firebase requires the Blaze billing plan for default-bucket provisioning and continued access; review pricing and set budget alerts before enabling billing. If the project has no Storage bucket yet, structured form data can still be saved to Firestore, but PDF/image files cannot be stored until Storage is available.
4. Once the Storage bucket exists, rerun `dart pub global run flutterfire_cli:flutterfire configure --project=YOUR_PROJECT_ID --platforms=web` so generated Firebase options include the bucket settings.
5. Deploy the Storage rules using `firebase deploy --only storage --project=YOUR_PROJECT_ID`. Firestore rules are unchanged by this patch; the nested `users/{uid}/artifacts` records remain protected by your existing Firestore rules.
6. Ensure your React/Vite dev server runs on `http://localhost:5173` because the web bridge validates that origin. The existing `dev.bat` launches Vite on the default port 5173.
7. Run `flutter pub get` and launch with F5. Complete onboarding with a resume or resume-builder PDF plus the NSRP form. Check the user's `users/{uid}` Firestore document and `users/{uid}/artifacts` subcollection, then open AI Profile → Saved Resumes & Forms.

## Security notes

- Never commit `.env`, Firebase service-account keys, or live AI credentials. Do not replace your locally generated `lib/firebase_options.dart` with a placeholder copy from an older archive.
- The full NSRP form is kept under the authenticated user's Firestore profile. Sensitive government identifiers are excluded from the AI prompt, and the NSRP PDF itself is not sent to Gemini.
- Cloud Storage rules allow only the signed-in owner to read, write, or delete their documents and restrict file type/size.
- If Storage uploads fail, the app displays a warning; Firestore text data is saved independently where rules permit. The profile also shows the selected uploaded-resume filename when the structured data was saved but file storage was unavailable.
