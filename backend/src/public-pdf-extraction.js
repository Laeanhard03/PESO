import os from 'node:os';
import path from 'node:path';
import { mkdir } from 'node:fs/promises';

import {
  PUBLIC_PDF_LIMITS,
  PublicPdfIngestionError,
  extractPdfPages,
} from './public-pdf-ingestion.js';

function extractedCharacters(pages) {
  return (pages || []).reduce((total, page) => total + String(page?.text || '').trim().length, 0);
}

/**
 * Extract normal PDF text first and OCR only when the document is text-poor.
 * OCR is performed locally; page images and source text are not uploaded to an
 * external service. Tesseract.js downloads its open OCR engine/language data
 * at first use unless those assets are already cached.
 */
export async function extractPdfPagesWithOcr(pdfBytes, {
  textExtractor = extractPdfPages,
  ocrExtractor = ocrScannedPdfPages,
  minExtractedChars = PUBLIC_PDF_LIMITS.minExtractedChars,
} = {}) {
  const extracted = await textExtractor(pdfBytes);
  if (extractedCharacters(extracted) >= minExtractedChars) return extracted;
  return ocrExtractor(pdfBytes);
}

export async function ocrScannedPdfPages(pdfBytes, {
  maxPages = PUBLIC_PDF_LIMITS.maxPages,
  renderScale = 1.75,
  maxRenderDimension = 3_200,
  maxPixels = 7_000_000,
  language = process.env.PESO_PUBLIC_PDF_OCR_LANGS || 'eng+fil',
  workerFactory,
  renderDocument,
} = {}) {
  let createCanvas;
  let createWorker;
  try {
    ({ createCanvas } = await import('@napi-rs/canvas'));
    ({ createWorker } = await import('tesseract.js'));
  } catch {
    throw new PublicPdfIngestionError('ocr_dependencies_not_installed');
  }

  let pdfjs;
  try {
    pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  } catch {
    throw new PublicPdfIngestionError('pdf_parser_not_installed');
  }

  class NapiCanvasFactory {
    create(width, height) {
      const canvas = createCanvas(Math.ceil(width), Math.ceil(height));
      return { canvas, context: canvas.getContext('2d') };
    }
    reset(canvasAndContext, width, height) {
      canvasAndContext.canvas.width = Math.ceil(width);
      canvasAndContext.canvas.height = Math.ceil(height);
      canvasAndContext.context = canvasAndContext.canvas.getContext('2d');
    }
    destroy(canvasAndContext) {
      if (canvasAndContext?.canvas) {
        canvasAndContext.canvas.width = 0;
        canvasAndContext.canvas.height = 0;
      }
      if (canvasAndContext) {
        canvasAndContext.canvas = null;
        canvasAndContext.context = null;
      }
    }
  }

  const loader = pdfjs.getDocument({
    data: new Uint8Array(pdfBytes),
    useSystemFonts: true,
    disableFontFace: true,
    isEvalSupported: false,
    stopAtErrors: false,
    CanvasFactory: NapiCanvasFactory,
  });
  let pdf;
  let worker;
  const resultPages = [];
  const cachePath = path.join(os.tmpdir(), 'peso-public-pdf-tesseract-cache');
  try {
    pdf = await loader.promise;
    if (!Number.isInteger(pdf.numPages) || pdf.numPages < 1) {
      throw new PublicPdfIngestionError('pdf_has_no_pages');
    }
    if (pdf.numPages > maxPages) throw new PublicPdfIngestionError('pdf_too_many_pages');

    await mkdir(cachePath, { recursive: true });
    const makeWorker = workerFactory || createWorker;
    try {
      worker = await makeWorker(language, 1, {
        cachePath,
        logger: () => {},
        errorHandler: () => {},
      });
    } catch {
      if (language === 'eng') throw new PublicPdfIngestionError('ocr_language_data_unavailable');
      try {
        worker = await makeWorker('eng', 1, {
          cachePath,
          logger: () => {},
          errorHandler: () => {},
        });
      } catch {
        throw new PublicPdfIngestionError('ocr_language_data_unavailable');
      }
    }

    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
      const page = await pdf.getPage(pageNumber);
      let pair;
      try {
        const unscaled = page.getViewport({ scale: 1 });
        const pixelLimitedScale = Math.sqrt(
          maxPixels / Math.max(1, unscaled.width * unscaled.height),
        );
        const dimensionLimitedScale = Math.min(
          maxRenderDimension / Math.max(1, unscaled.width),
          maxRenderDimension / Math.max(1, unscaled.height),
        );
        const scale = Math.min(renderScale, pixelLimitedScale, dimensionLimitedScale);
        if (!Number.isFinite(scale) || scale <= 0) {
          throw new PublicPdfIngestionError('invalid_pdf_page_dimensions');
        }
        const viewport = page.getViewport({ scale });
        pair = pdf.canvasFactory.create(viewport.width, viewport.height);
        if (renderDocument) {
          await renderDocument({ page, canvas: pair.canvas, canvasContext: pair.context, viewport });
        } else {
          await page.render({
            canvas: pair.canvas,
            canvasContext: pair.context,
            viewport,
          }).promise;
        }
        const image = pair.canvas.toBuffer('image/png');
        const recognized = await worker.recognize(image);
        resultPages.push({
          pageNumber,
          text: String(recognized?.data?.text || ''),
          ocrConfidence: Number.isFinite(recognized?.data?.confidence)
            ? recognized.data.confidence
            : null,
        });
      } catch (error) {
        if (error instanceof PublicPdfIngestionError) throw error;
        throw new PublicPdfIngestionError('ocr_page_failed');
      } finally {
        page.cleanup?.();
        if (pair) pdf.canvasFactory.destroy(pair);
      }
    }
    return resultPages;
  } catch (error) {
    if (error instanceof PublicPdfIngestionError) throw error;
    throw new PublicPdfIngestionError('ocr_extraction_failed');
  } finally {
    try {
      await worker?.terminate();
    } catch {}
    try {
      if (pdf) await pdf.destroy();
      else await loader.destroy();
    } catch {}
  }
}
