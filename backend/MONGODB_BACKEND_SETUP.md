# PESO JobKonek MongoDB backend setup

This backend is the only app component that connects to MongoDB Atlas or Gemini.
Firebase Authentication remains the sign-in provider; the backend verifies Firebase
ID tokens with Firebase Admin. Application profiles/forms/AI data go to MongoDB,
and resume/PDF bytes use MongoDB GridFS. Do not enable Firebase Storage just for
this integration.

## First-time local setup

1. In MongoDB Atlas, rotate the database user's password because the previous
   connection string was exposed in chat. Use a least-privilege database user
   for the `peso_jobkonek` database.
2. Check Atlas Network Access includes your current public IP.
3. Run `powershell -ExecutionPolicy Bypass -File .\configure-backend.ps1` from
   this `backend` folder. It asks for the rotated MongoDB URI and a new Gemini
   key with hidden input, generates `FILE_LINK_SECRET`, and writes `.env`
   without echoing credentials. Type `YES` only when you intend to replace
   the existing backend configuration.
4. Generate/download a Firebase service-account JSON for project
   `capstone-4th-year-peso-ai`, save it as `backend/service-account.json`,
   and keep that file local. Alternatively set `FIREBASE_SERVICE_ACCOUNT_PATH`
   to a credential file outside this repository. Never commit this file.
5. Run:
   `npm install`
   `npm run check`
   `npm run dev`
6. Check `http://localhost:3000/api/health`. It shows readiness flags and
   never returns credentials.
7. From the Flutter project root run `flutter pub get` and press F5. The
    dev.bat script will start the API when backend/.env exists.

## Firebase profile migration

On the first MongoDB profile initialization, the backend attempts a best-effort,
read-only import of the user's existing Firestore `users/{uid}` document. It
does not write new application records to Firestore. This requires the Firebase
Admin credential to have permission to read Firestore. If the legacy Firestore
database is unavailable, a fresh MongoDB profile is created from the verified
Firebase identity and provided registration fields.

## API security and data flow

- Protected API routes require a Firebase ID token in the Authorization header.
- UID is taken from the verified token, never accepted as a client-chosen owner.
- Client updates cannot change the account role.
- Resume/NSRP documents are stored in GridFS with the owner's UID in metadata.
- Download links are signed and short-lived; no permanent bearer URL is persisted.
- Only uploaded original resume bytes are passed to Gemini. Resume-builder edited
  field text is passed as text; the NSRP PDF is not sent to Gemini.
- Gemini credentials and MongoDB credentials stay server-side.

## Local development and teammates

The default Flutter API base is `http://localhost:3000`. That only works on this
computer. For teammates to use the app from their own devices, deploy the backend
to an HTTPS service, set its environment variables and exact allowed production
origins, then build Flutter with:
`--dart-define=PESO_API_BASE_URL=https://your-api.example.com`

MongoDB Atlas Free has limited storage (currently 512 MB), so monitor GridFS
usage. Remove any test documents you no longer need.

## Troubleshooting

- `firebaseAdminReady: false`: check Firebase service-account path and project ID.
- `mongodbConnected: false`: check Atlas URI, username/password encoding, IP access,
  cluster state and database access privileges. Never paste the complete URI into logs.
- `geminiConfigured: false`: set a new server-side Gemini API key.
- Browser CORS: local loopback origins are allowed only in development; in production
  add the exact app origin to `CLIENT_ALLOWED_ORIGINS`.
- Existing Firestore data is imported only when the matching MongoDB UID record
  does not already exist. Future updates go to MongoDB.
