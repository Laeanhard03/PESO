import fs from 'node:fs';
import crypto from 'node:crypto';

const adminPath = 'C:/Users/Admin/Desktop/Prototype/lib/peso_ui/Admin/admin_user_management_section.dart';
const apiPath = 'C:/Users/Admin/Desktop/Prototype/lib/peso_services/peso_api_client.dart';
const admin = fs.readFileSync(adminPath, 'utf8');
const api = fs.readFileSync(apiPath, 'utf8');

function replaceOnce(source, before, after, label) {
  const first = source.indexOf(before);
  if (first < 0 || source.indexOf(before, first + before.length) >= 0) {
    throw new Error('Expected exactly one match for ' + label + '; no UI files written.');
  }
  return source.slice(0, first) + after + source.slice(first + before.length);
}
function replaceCount(source, before, after, expected, label) {
  const count = source.split(before).length - 1;
  if (count !== expected) throw new Error('Expected ' + expected + ' matches for ' + label + ', got ' + count + '; no UI files written.');
  return source.split(before).join(after);
}
let nextAdmin = admin;
let nextApi = api;

nextAdmin = replaceOnce(nextAdmin,
  '/// Live Firebase Auth account management with profile data served by the PESO MongoDB API.',
  '/// PESO application user management backed by MongoDB; Firebase supplies sign-in identity.',
  'widget documentation');

const oldClaimGate = [
"      final tokenResult = await currentUser.getIdTokenResult(true);",
"      if (tokenResult.claims?['admin'] != true) {",
"        if (mounted) {",
"          setState(() => _error =",
"              'This session does not have the verified admin: true claim. Sign in again with your administrator account.');",
"        }",
"        return;",
"      }",
""
].join('\n');
const newClaimGate = [
"      // The backend verifies the signed Firebase ID token and resolves the",
"      // PESO admin role from MongoDB. Do not rely on a Firebase custom claim here.",
""
].join('\n');
nextAdmin = replaceOnce(nextAdmin, oldClaimGate, newClaimGate, 'client-side admin custom-claim gate');

nextAdmin = replaceOnce(nextAdmin,
  "      return 'This action requires a valid Firebase admin session.';",
  "      return 'This action requires a PESO admin role stored in MongoDB.';",
  'admin-required message');

nextAdmin = replaceOnce(nextAdmin,
  "      if (mounted) _toast(disabled ? 'Login disabled.' : 'Login enabled.');",
  "      if (mounted) _toast(disabled ? 'PESO access disabled.' : 'PESO access restored.');",
  'status toast');

nextAdmin = replaceOnce(nextAdmin,
  "      if (mounted) _toast('Could not change this login status. Check the PESO API.', error: true);",
  "      if (mounted) _toast('Could not change PESO access. Check the PESO API.', error: true);",
  'status error toast');

const oldDeleteDialog = [
"        title: const Text('Permanently delete this account?'),",
"        content: Text(",
"          'This deletes ' + _displayName(user) + ' (' + _text(user['email']) +",
"          ') from Firebase Authentication and attempts to remove its MongoDB profile and stored documents. This cannot be undone.',",
"        ),"
].join('\n');
const newDeleteDialog = [
"        title: const Text('Remove this PESO account?'),",
"        content: Text(",
"          'This clears the PESO profile and attempts to remove stored documents for ' +",
"          _displayName(user) + ' (' + _text(user['email']) +",
"          '). The Google/Firebase sign-in identity remains active, but PESO access is revoked.',",
"        ),"
].join('\n');
nextAdmin = replaceOnce(nextAdmin, oldDeleteDialog, newDeleteDialog, 'delete dialog semantics');

nextAdmin = replaceOnce(nextAdmin,
  "            label: const Text('Delete permanently'),",
  "            label: const Text('Remove PESO data'),",
  'delete confirmation label');

nextAdmin = replaceOnce(nextAdmin,
  "            ? 'Account deleted and MongoDB data cleanup completed.'\n            : 'Login deleted; some MongoDB document cleanup needs review.',",
  "            ? 'PESO profile cleared and MongoDB data cleanup completed.'\n            : 'PESO access revoked; some MongoDB document cleanup needs review.',",
  'delete completion messages');

nextAdmin = replaceOnce(nextAdmin,
  "            'This screen uses the PESO API for MongoDB profile data. Firebase is used for sign-in and server-verified authentication account operations. The backend needs a valid MongoDB Atlas URI and Firebase Admin credentials.',",
  "            'This screen uses MongoDB-backed PESO profiles and roles. Firebase provides Google sign-in and signed ID tokens; Firebase Admin credentials are not required for PESO role/profile management. Configure the dedicated Atlas database URI to enable Admin.',",
  'admin banner');

nextAdmin = replaceOnce(nextAdmin,
  "              'MongoDB profile data is currently unavailable. Firebase Authentication accounts still appear, and login enable/disable actions remain available. Profile edits and account deletion are disabled until MongoDB reconnects so private profile and document cleanup cannot be skipped.',",
  "              'MongoDB is not connected. PESO profiles, profile edits, access-status changes, and deletion cleanup are unavailable until the Atlas connection is restored.',",
  'mongo unavailable banner');

nextAdmin = replaceOnce(nextAdmin,
  "                    'No registered Firebase Authentication accounts were returned by the API.',",
  "                    'No PESO user profiles were returned from MongoDB. Firebase Auth identities without a PESO profile are not listed here.',",
  'empty-list message');

nextAdmin = replaceOnce(nextAdmin,
  "                          DataColumn(label: Text('Status')),",
  "                          DataColumn(label: Text('PESO access')),",
  'status column header');

nextAdmin = replaceOnce(nextAdmin,
  "                                    user['disabled'] == true ? 'Disabled' : 'Enabled',",
  "                                    user['disabled'] == true ? 'Disabled' : 'Active',",
  'status display');

nextAdmin = replaceOnce(nextAdmin,
  "                                          ? 'Protected administrator login'\n                                          : (user['disabled'] == true ? 'Enable login' : 'Disable login'),",
  "                                          ? 'Protected administrator PESO access'\n                                          : (user['disabled'] == true ? 'Restore PESO access' : 'Disable PESO access'),",
  'status tooltip');

nextAdmin = replaceCount(nextAdmin,
  "'Protected administrator login'",
  "'Protected administrator PESO access'",
  1,
  'delete tooltip');

nextAdmin = replaceOnce(nextAdmin,
  "                                              : 'Delete account',",
  "                                              : 'Clear PESO profile and documents',",
  'delete tooltip');

nextAdmin = replaceOnce(nextAdmin,
  "                                      onPressed: busy || protected ? null : () => _toggleDisabled(user),",
  "                                      onPressed: busy || protected || !profileStoreReady ? null : () => _toggleDisabled(user),",
  'status action readiness');

nextApi = replaceOnce(nextApi,
  "      'firebaseAdminReady': false,",
  "      'firebaseTokenVerificationReady': false,\n      'appRolesStoredIn': 'mongodb',",
  'health fallback');

const beforeHashes = {
  adminUi: crypto.createHash('sha256').update(admin).digest('hex'),
  apiClient: crypto.createHash('sha256').update(api).digest('hex'),
};
fs.writeFileSync(adminPath, nextAdmin, 'utf8');
fs.writeFileSync(apiPath, nextApi, 'utf8');
const afterHashes = {
  adminUi: crypto.createHash('sha256').update(nextAdmin).digest('hex'),
  apiClient: crypto.createHash('sha256').update(nextApi).digest('hex'),
};
console.log(JSON.stringify({ changed: true, beforeHashes, afterHashes }));
