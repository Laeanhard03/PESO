import { createPublicKey, verify } from 'node:crypto';

const CERT_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

export async function verifyFirebaseIdToken(token, projectId) {
  // Implementation follows Firebase's published third-party JWT verification requirements.
  throw new Error('not_implemented');
}
