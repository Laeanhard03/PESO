import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import app from '../backend/server.js';

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

export default function handler(req, res) {
  try {
    setupGoModel();
  } catch (error) {
    // Other API endpoints should still work when the optional Go executable is unavailable.
    console.error('[PESO API] Local inference bundle unavailable: ' + (error?.name || 'Error'));
  }
  return app(req, res);
}
