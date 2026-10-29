import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Load the Express app lazily so startup failures are reported as a bounded API
// diagnostic instead of Vercel's opaque FUNCTION_INVOCATION_FAILED response.
let appPromise = null;
async function loadExpressApp() {
  if (!appPromise) {
    appPromise = import('../backend/server.js')
      .then((module) => module.default)
      .catch((error) => {
        appPromise = null;
        throw error;
      });
  }
  return appPromise;
}

function startupDiagnostic(error) {
  const code = String(error?.code || error?.name || 'unknown').slice(0, 80);
  let message = String(error?.message || 'API startup failed');
  message = message
    .replace(/mongodb(?:\+srv)?:\/\/[^\s"'\x60]+/gi, '[redacted MongoDB URI]')
    .replace(/AIza[0-9A-Za-z_-]{20,}/g, '[redacted API key]')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted token]')
    .replace(/(password|secret|api[_ -]?key)\s*[:=]\s*[^,\s]+/gi, '$1=[redacted]')
    .slice(0, 180);
  const diagnostic = { code, message };
  const missing = message.match(/Cannot find (?:package|module) ['"]([^'"]+)['"]/i);
  if (missing) diagnostic.missingDependency = missing[1].slice(0, 100);
  return diagnostic;
}

// Run the existing Express API in the same Vercel project as Flutter and NSRP.
// Vercel Functions run on Linux and have a writable /tmp directory, unlike the
// read-only application bundle. Preserve the exact trained Go model.
let modelReady = false;
function setupGoModel() {
  if (modelReady || process.platform !== 'linux' || process.env.PESO_GO_AI_BIN) return;
  const binarySource = fileURLToPath(new URL('../backend/mini_ai_runtime/peso-mini-ai', import.meta.url));
  const modelSource = fileURLToPath(new URL('../backend/mini_ai_runtime/model_v1.json', import.meta.url));
  if (!fs.existsSync(binarySource) || !fs.existsSync(modelSource)) {
    throw new Error('Go runtime assets are missing from the deployment bundle.');
  }
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'peso-go-runtime-'));
  const binary = path.join(temp, 'peso-mini-ai');
  const model = path.join(temp, 'model_v1.json');
  fs.copyFileSync(binarySource, binary);
  fs.chmodSync(binary, 0o700);
  fs.copyFileSync(modelSource, model);
  process.env.PESO_GO_AI_BIN = binary;
  process.env.PESO_GO_AI_MODEL = model;
  modelReady = true;
}

export default async function handler(req, res) {
  let app;
  try {
    app = await loadExpressApp();
  } catch (error) {
    const diagnostic = startupDiagnostic(error);
    console.error('[PESO API] Express initialization failed (' + diagnostic.code + '): ' + diagnostic.message);
    return res.status(500).json({
      ok: false,
      error: 'api_startup_failed',
      diagnostic,
    });
  }

  try {
    setupGoModel();
  } catch (error) {
    // Other API endpoints should still work when the optional Go executable is unavailable.
    console.error('[PESO API] Local inference bundle unavailable: ' + (error?.name || 'Error'));
  }
  return app(req, res);
}
