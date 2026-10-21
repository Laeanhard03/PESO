/**
 * Public PDF link validation for admin-curated recruitment sources.
 * External URL fetching must not become an SSRF path into internal services.
 * Extra official hosts can be configured in PESO_PDF_ALLOWED_HOSTS.
 */
export function validateAdminPdfUrl(raw, allowedHosts = []) {
  const input = String(raw || '').trim();
  if (input.length < 12 || input.length > 2048) {
    throw Object.assign(new Error('Use a valid direct HTTPS PDF link.'), { code: 'invalid_pdf_url' });
  }
  let url;
  try {
    url = new URL(input);
  } catch {
    throw Object.assign(new Error('Use a valid direct HTTPS PDF link.'), { code: 'invalid_pdf_url' });
  }
  if (url.protocol !== 'https:' || url.username || url.password ||
      url.port || !url.hostname || url.hostname === 'localhost') {
    throw Object.assign(new Error('Only public HTTPS PDF URLs are supported.'), { code: 'unsafe_pdf_url' });
  }
  const hostname = url.hostname.toLowerCase().replace(/\.$/, '');
  const approvedHost = hostname.endsWith('.gov.ph') || hostname === 'gov.ph' ||
    allowedHosts.some((allowed) => {
      const site = String(allowed || '').trim().toLowerCase();
      return site.length > 2 && (hostname === site || hostname.endsWith('.' + site));
    });
  if (!approvedHost) {
    throw Object.assign(new Error('This PDF host is not approved. Ask the administrator to add its public host to PESO_PDF_ALLOWED_HOSTS.'), {
      code: 'pdf_host_not_approved',
    });
  }
  if (!url.pathname.toLowerCase().endsWith('.pdf')) {
    throw Object.assign(new Error('Paste the direct public .pdf URL, not a webpage or viewer link.'), { code: 'pdf_link_required' });
  }
  url.hash = '';
  return url.toString();
}

export async function inspectAdminPdfUrl(url, { fetchImpl = globalThis.fetch } = {}) {
  const opts = {
    redirect: 'manual',
    signal: AbortSignal.timeout(12000),
    headers: { Accept: 'application/pdf' },
  };
  let response = await fetchImpl(url, { ...opts, method: 'HEAD' });
  // Some legitimate public document hosts reject HEAD. Read at most the
  // beginning of the same verified URL with Range, never follow redirects.
  const usedGetFallback = [403, 405, 501].includes(response.status);
  if (usedGetFallback) {
    response = await fetchImpl(url, {
      ...opts,
      method: 'GET',
      headers: { ...opts.headers, Range: 'bytes=0-1023' },
    });
  }
  try {
    if (!response.ok) {
      throw Object.assign(new Error('Could not verify the PDF link. Check that it is public and accessible.'), {
        code: 'pdf_source_unreachable',
      });
    }
    const length = Number(response.headers.get('content-length') || 0);
    // The official Montalban LRA compilation is about 47.7 MB. Keep the
    // metadata-only intake cap consistent with the PDF ingestion service's
    // actual 64 MB bounded streaming limit (no body download on HEAD).
    if (Number.isFinite(length) && length > 64 * 1024 * 1024) {
      throw Object.assign(new Error('This PDF is larger than the 64 MB intake limit.'), { code: 'pdf_too_large' });
    }
    const type = String(response.headers.get('content-type') || '').toLowerCase();
    if (type && !type.includes('application/pdf') && !type.includes('octet-stream')) {
      throw Object.assign(new Error('The link did not return a PDF document.'), { code: 'pdf_content_type_invalid' });
    }
    return { contentType: type || 'application/pdf', declaredBytes: length || null };
  } finally {
    if (usedGetFallback) {
      // Stop a server that ignores Range from streaming its whole PDF body.
      try { await response.body?.cancel?.(); } catch { /* Best effort. */ }
    }
  }
}
