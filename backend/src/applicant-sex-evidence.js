/** Applicant-sex evidence is narrowly sourced from a text-bearing uploaded
 * resume PDF. Never infer a sex from a person's name, photograph or pronouns.
 * Scanned/image-only documents do not produce an automatic sex suggestion.
 */
export function explicitSexFromResumeText(raw) {
  const text = String(raw || '').replace(/\s+/g, ' ').slice(0, 100000);
  const match = /(?:^|[;,. ]+)(sex|gender)\s*[:=-]\s*(male|female|other)\b/i.exec(text);
  if (!match) return null;
  const sex = match[2][0].toUpperCase() + match[2].slice(1).toLowerCase();
  return { verified: true, sex, sourceQuote: match[1] + ': ' + sex,
    source: 'uploaded_resume_pdf_text' };
}

export async function verifyUploadedResumeSex(artifacts, decodeBytes) {
  const pdf = (Array.isArray(artifacts) ? artifacts : []).find(
    item => item?.category === 'resume_upload' &&
      String(item?.mimeType || '').toLowerCase() === 'application/pdf'
  );
  if (!pdf) return null;
  try {
    const bytes = decodeBytes(pdf);
    if (bytes.length > 4 * 1024 * 1024 || bytes.length < 5) return null;
    const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
    const job = pdfjs.getDocument({ data: new Uint8Array(bytes),
      useSystemFonts: true, disableFontFace: true, isEvalSupported: false });
    const document = await job.promise;
    try {
      for (let number = 1; number <= Math.min(document.numPages, 5); number++) {
        const page = await document.getPage(number);
        const content = await page.getTextContent();
        const joined = content.items.map(item => String(item.str || '')).join(' ');
        const evidence = explicitSexFromResumeText(joined);
        if (evidence) return evidence;
      }
    } finally {
      await document.destroy();
    }
  } catch {
    // Missing text layers, malformed PDFs, and read failures simply require
    // applicant correction; the user's saved records are unaffected.
  }
  return null;
}
