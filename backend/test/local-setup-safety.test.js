import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const setupScript = await readFile(path.join(here, '..', 'configure-backend-admin.ps1'), 'utf8');
const geminiEncryptionSetup = await readFile(path.join(here, '..', 'scripts', 'ensure-gemini-key-encryption.ps1'), 'utf8');
const migrationCli = await readFile(path.join(here, '..', 'scripts', 'migrate-firestore-to-mongodb.js'), 'utf8');

test('Admin backend setup accepts only hidden URI input and does not require Gemini', () => {
  assert.match(setupScript, /Read-Host[\s\S]*-AsSecureString/);
  assert.ok(setupScript.includes('mongodb(\\+srv)?://'));
  assert.match(setupScript, /RandomNumberGenerator/);
  assert.match(setupScript, /FILE_LINK_SECRET/);
  assert.match(setupScript, /HOST=127\.0\.0\.1/);
  assert.doesNotMatch(setupScript, /GEMINI_API_KEY=/);
  assert.doesNotMatch(setupScript, /Write-Host.{0,100}mongoUri/i);
  assert.doesNotMatch(setupScript, /Write-Host.{0,100}fileLinkSecret/i);
});

test('Admin setup safely configures the Gemini encryption key without exposing or rotating secrets silently', () => {
  assert.match(setupScript, /GEMINI_KEY_ENCRYPTION_SECRET/);
  assert.match(setupScript, /RandomNumberGenerator/);
  assert.match(setupScript, /byte\[\] 32/);
  assert.match(setupScript, /secure-backups/);
  assert.match(setupScript, /GEMINI_API_KEY/);
  assert.match(setupScript, /SMS_AUTH_ENABLED/);
  assert.match(setupScript, /SMS_API_KEY/);
  assert.match(setupScript, /SMS_OTP_PEPPER/);
  assert.doesNotMatch(setupScript, /SMS_AUTH_ENABLED='false'/);
  assert.match(setupScript, /ToBase64String/);
  assert.match(setupScript, /GENERATE NEW ENCRYPTION SECRET/);
  assert.doesNotMatch(setupScript, /Write-Host.{0,120}(geminiEncryptionSecret|encryptionSecret|geminiApiKey)/i);
  assert.doesNotMatch(setupScript, /Write-Output.{0,120}(geminiEncryptionSecret|encryptionSecret|geminiApiKey)/i);
});

test('standalone Gemini vault setup requires explicit confirmation and keeps encryption secret values out of output', () => {
  assert.match(geminiEncryptionSetup, /ConfirmAddEncryptionSecret/);
  assert.match(geminiEncryptionSetup, /RandomNumberGenerator/);
  assert.match(geminiEncryptionSetup, /byte\[\] 32/);
  assert.match(geminiEncryptionSetup, /GEMINI_KEY_ENCRYPTION_SECRET/);
  assert.match(geminiEncryptionSetup, /secure-backups/);
  assert.match(geminiEncryptionSetup, /File]::Replace/);
  assert.match(geminiEncryptionSetup, /Get-FileHash/);
  assert.match(geminiEncryptionSetup, /already configured and valid; no changes made/i);
  assert.doesNotMatch(geminiEncryptionSetup, /Write-Host.{0,120}(secretValue|secretBytes|GEMINI_KEY_ENCRYPTION_SECRET)/i);
  assert.doesNotMatch(geminiEncryptionSetup, /Write-Output.{0,120}(secretValue|secretBytes|GEMINI_KEY_ENCRYPTION_SECRET)/i);
});

test('migration CLI defaults to dry-run and requires two explicit flags for writes', () => {
  assert.match(migrationCli, /const apply = argv\.includes\('--apply'\)/);
  assert.match(migrationCli, /const confirm = argv\.includes\('--confirm-peso-migration'\)/);
  assert.match(migrationCli, /if \(apply && !confirm\)/);
  assert.match(migrationCli, /apply: options\.apply/);
  assert.match(migrationCli, /sourceFirestoreAndStorageModified: false/);
});
