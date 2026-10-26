import { randomUUID } from 'node:crypto';

const MAX_GALLERY_ITEMS = 30;
const MAX_PARTNER_ITEMS = 40;

const BUNDLED_PARTNER_ASSETS = new Set([
  'asset:lib/assets/peso_partners/JOLLIBEE LOGO.png',
  'asset:lib/assets/peso_partners/EEI CORPORATION LOGO.png',
  'asset:lib/assets/peso_partners/SAVEMORE.jpg',
  'asset:lib/assets/peso_partners/SAGULITIY.jpg',
  'asset:lib/assets/peso_partners/JRCC.jpg',
  'asset:lib/assets/peso_partners/SHOPWISE.jpg',
  'asset:lib/assets/peso_partners/RUDER SPARK.jpg',
  'asset:lib/assets/peso_partners/OMNICORES.png',
  'asset:lib/assets/peso_partners/ROBINSON.png',
  'asset:lib/assets/peso_partners/EXCEL SOURCE.jpg',
  'asset:lib/assets/peso_partners/SM.png',
  'asset:lib/assets/peso_partners/joBNET.png',
  'asset:lib/assets/peso_partners/PUREGOLD.webp',
  'asset:lib/assets/peso_partners/AVILON.png',
  'asset:lib/assets/peso_partners/XENTRO MALL.jpg',
]);


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
    const isBundled = /^asset:lib\/assets\/(?:peso_gallery\/[a-z0-9_]+\.jpg|peso_gallery_[a-z0-9_]+\.jpg)$/.test(String(item.imageUrl ?? ''));
    if (!title) throw new TypeError('Every gallery photo needs a title.');
    if (!imageUrl && !isBundled) throw new TypeError('Gallery image URLs must be valid HTTPS URLs or bundled PESO photos.');
    return { id: stableId(item.id), title, imageUrl: isBundled ? String(item.imageUrl) : imageUrl, caption };
  });

  const partners = requireArray(input.partners, 'Employer partners', MAX_PARTNER_ITEMS).map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new TypeError('Every employer partner entry must be an object.');
    }
    const name = shortText(item.name, 120);
    const logoUrl = httpsUrl(item.logoUrl);
    const bundledLogo = BUNDLED_PARTNER_ASSETS.has(String(item.logoUrl ?? ''));
    const websiteUrl = httpsUrl(item.websiteUrl, { required: false });
    if (!name) throw new TypeError('Every employer partner needs a name.');
    if (!logoUrl && !bundledLogo) throw new TypeError('Employer logo URLs must be valid HTTPS URLs or a bundled PESO partner logo.');
    if (String(item.websiteUrl ?? '').trim() && !websiteUrl) {
      throw new TypeError('Employer website URLs must be valid HTTPS URLs.');
    }
    return { id: stableId(item.id), name, logoUrl: bundledLogo ? String(item.logoUrl) : logoUrl, websiteUrl };
  });

  return { gallery, partners, galleryConfigured: input.galleryConfigured === true || gallery.length > 0, partnersConfigured: input.partnersConfigured === true || partners.length > 0 };
}

export const LANDING_SITE_CONTENT_LIMITS = Object.freeze({
  gallery: MAX_GALLERY_ITEMS,
  partners: MAX_PARTNER_ITEMS,
});
