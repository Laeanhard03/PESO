import { randomUUID } from 'node:crypto';

const MAX_GALLERY_ITEMS = 30;
const MAX_PARTNER_ITEMS = 40;

function shortText(value, maxLength) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function httpsUrl(value, { required = true } = {}) {
  const raw = String(value ?? '').trim();
  if (!raw) return required ? null : '';
  if (raw.length > 2048) return null;
  try {
    const parsed = new URL(raw);
    if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.username || parsed.password) {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

function stableId(value) {
  const raw = String(value ?? '').trim();
  return /^[A-Za-z0-9_-]{1,80}$/.test(raw) ? raw : randomUUID();
}

function requireArray(value, label, maximum) {
  if (!Array.isArray(value)) throw new TypeError(label + ' must be a list.');
  if (value.length > maximum) throw new RangeError(label + ' can contain at most ' + maximum + ' items.');
  return value;
}

/** Trust-boundary validation for editable public landing-page content. */
export function sanitizeLandingSiteContent(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new TypeError('Landing content must be an object.');
  }

  const gallery = requireArray(input.gallery, 'Gallery', MAX_GALLERY_ITEMS).map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new TypeError('Every gallery entry must be an object.');
    }
    const title = shortText(item.title, 120);
    const imageUrl = httpsUrl(item.imageUrl);
    const caption = shortText(item.caption, 240);
    if (!title) throw new TypeError('Every gallery photo needs a title.');
    if (!imageUrl) throw new TypeError('Gallery image URLs must be valid HTTPS URLs.');
    return { id: stableId(item.id), title, imageUrl, caption };
  });

  const partners = requireArray(input.partners, 'Employer partners', MAX_PARTNER_ITEMS).map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new TypeError('Every employer partner entry must be an object.');
    }
    const name = shortText(item.name, 120);
    const logoUrl = httpsUrl(item.logoUrl);
    const websiteUrl = httpsUrl(item.websiteUrl, { required: false });
    if (!name) throw new TypeError('Every employer partner needs a name.');
    if (!logoUrl) throw new TypeError('Employer logo URLs must be valid HTTPS URLs.');
    if (String(item.websiteUrl ?? '').trim() && !websiteUrl) {
      throw new TypeError('Employer website URLs must be valid HTTPS URLs.');
    }
    return { id: stableId(item.id), name, logoUrl, websiteUrl };
  });

  return { gallery, partners };
}

export const LANDING_SITE_CONTENT_LIMITS = Object.freeze({
  gallery: MAX_GALLERY_ITEMS,
  partners: MAX_PARTNER_ITEMS,
});
