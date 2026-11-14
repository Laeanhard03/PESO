import os from 'node:os';
import path from 'node:path';
import { mkdir } from 'node:fs/promises';

export const RESUME_IMAGE_OCR_LIMITS = Object.freeze({
  maxImages: 8,
  maxImageBytes: 20 * 1024 * 1024,
  maxSourcePixels: 48_000_000,
  maxPixels: 8_000_000,
  maxEdge: 2_800,
  maxTextCharsPerImage: 35_000,
  minTextChars: 24,
  minConfidence: 65,
});

function imageBytes(value) {
  const bytes = value?.bytes ?? value;
  return Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes || []);
}

function confidenceValue(value) {
  const confidence = Number(value);
  return Number.isFinite(confidence) ? Math.max(0, Math.min(100, confidence)) : null;
}

async function defaultImageEncoder(image, width, height, canvasApi) {
  const canvas = canvasApi.createCanvas(width, height);
  try {
    const context = canvas.getContext('2d');
    context.fillStyle = '#ffffff';
    context.fillRect(0, 0, width, height);
    context.drawImage(image, 0, 0, width, height);
    return canvas.toBuffer('image/jpeg', 90);
  } finally {
    canvas.width = 0;
    canvas.height = 0;
  }
}

async function createOcrWorker(workerFactory, language, cachePath) {
  const options = { cachePath, logger: () => {}, errorHandler: () => {} };
  try {
    return await workerFactory(language, 1, options);
  } catch {
    if (language === 'eng') throw new Error('resume_ocr_language_data_unavailable');
    try {
      return await workerFactory('eng', 1, options);
    } catch {
      throw new Error('resume_ocr_language_data_unavailable');
    }
  }
}

/**
 * Independently transcribes uploaded resume photographs on the PESO server.
 * OCR text is returned only to the extraction pipeline; callers should persist
 * verified facts and aggregate status, never the raw transcription.
 */
export async function extractResumeImageTexts(images, {
  language = process.env.PESO_RESUME_OCR_LANGS || process.env.PESO_PUBLIC_PDF_OCR_LANGS || 'eng+fil',
  workerFactory,
  imageDecoder,
  imageEncoder,
  cachePath = path.join(os.tmpdir(), 'peso-public-pdf-tesseract-cache'),
  maxImages = RESUME_IMAGE_OCR_LIMITS.maxImages,
} = {}) {
  const candidates = (Array.isArray(images) ? images : []).slice(0, maxImages).map((image) => ({
    bytes: imageBytes(image),
    mimeType: String(image?.mimeType || '').toLowerCase(),
  }));
  if (candidates.length === 0) return [];

  if (candidates.some(({ bytes }) => bytes.length === 0 || bytes.length > RESUME_IMAGE_OCR_LIMITS.maxImageBytes)) {
    throw new Error('resume_ocr_image_size_invalid');
  }

  let canvasApi;
  if (!imageDecoder || !imageEncoder) {
    try {
      canvasApi = await import('@napi-rs/canvas');
    } catch {
      throw new Error('resume_ocr_image_decoder_unavailable');
    }
  }
  let makeWorker = workerFactory;
  if (!makeWorker) {
    try {
      ({ createWorker: makeWorker } = await import('tesseract.js'));
    } catch {
      throw new Error('resume_ocr_dependencies_unavailable');
    }
  }
  const decode = imageDecoder || canvasApi.loadImage;
  const encode = imageEncoder || ((image, width, height) =>
    defaultImageEncoder(image, width, height, canvasApi));

  await mkdir(cachePath, { recursive: true });
  const worker = await createOcrWorker(makeWorker, language, cachePath);
  const results = [];
  try {
    for (const candidate of candidates) {
      let decoded;
      let preparedBytes;
      try {
        decoded = await decode(candidate.bytes);
        const sourceWidth = Number(decoded?.naturalWidth || decoded?.width);
        const sourceHeight = Number(decoded?.naturalHeight || decoded?.height);
        const sourcePixels = sourceWidth * sourceHeight;
        if (!Number.isFinite(sourceWidth) || !Number.isFinite(sourceHeight) ||
            sourceWidth < 1 || sourceHeight < 1 ||
            !Number.isFinite(sourcePixels) || sourcePixels > RESUME_IMAGE_OCR_LIMITS.maxSourcePixels) {
          results.push({ status: 'invalid_dimensions', text: '', confidence: null });
          continue;
        }

        const scale = Math.min(
          1,
          RESUME_IMAGE_OCR_LIMITS.maxEdge / Math.max(sourceWidth, sourceHeight),
          Math.sqrt(RESUME_IMAGE_OCR_LIMITS.maxPixels / sourcePixels),
        );
        const width = Math.max(1, Math.round(sourceWidth * scale));
        const height = Math.max(1, Math.round(sourceHeight * scale));
        preparedBytes = await encode(decoded, width, height);
        const recognized = await worker.recognize(preparedBytes);
        const text = String(recognized?.data?.text || '').trim()
          .slice(0, RESUME_IMAGE_OCR_LIMITS.maxTextCharsPerImage);
        const confidence = confidenceValue(recognized?.data?.confidence);
        const readable = text.length >= RESUME_IMAGE_OCR_LIMITS.minTextChars &&
          confidence !== null && confidence >= RESUME_IMAGE_OCR_LIMITS.minConfidence;
        results.push({
          status: readable ? 'readable' : text ? 'low_confidence' : 'no_text',
          text,
          confidence,
          width,
          height,
          preparedBytes,
        });
      } catch {
        results.push({ status: 'image_ocr_failed', text: '', confidence: null, preparedBytes });
      }
    }
    return results;
  } finally {
    try {
      await worker.terminate();
    } catch {
      // OCR output is already complete; worker cleanup must not hide it.
    }
  }
}
