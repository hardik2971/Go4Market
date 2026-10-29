// Image pipeline: Unsplash photo -> sharp WebP -> Firebase Storage (catalog/...) with a stable download token.
// Falls back to a clean branded SVG illustration when no verified photo exists for a key.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

export const SIZES = {
  product: [800, 800], category: [480, 480], slider: [1600, 640], offer: [1200, 500], banner: [1200, 600],
  blog: [1200, 630], popup: [800, 800], sellerBanner: [1200, 400], logo: [256, 256],
};

// Per-key fixes for photos that show a real brand mark. `extract` crops the downloaded photo
// (fractions of its size) before resizing; `blur` softens a region of the final image (pixels).
const CLEANUP = {
  'air-fryer': { extract: { left: 0, top: 0.475, width: 0.525, height: 0.525 } },
  'gan-charger': { blur: { left: 395, top: 305, width: 120, height: 80 } },
};

export async function applyCleanup(key, raw, w, h) {
  const c = CLEANUP[key];
  let img = sharp(raw);
  if (c?.extract) {
    const m = await img.metadata();
    img = img.extract({
      left: Math.round(c.extract.left * m.width), top: Math.round(c.extract.top * m.height),
      width: Math.round(c.extract.width * m.width), height: Math.round(c.extract.height * m.height),
    });
  }
  let out = await img.resize(w, h, { fit: 'cover', position: sharp.strategy.attention }).toBuffer();
  if (c?.blur) {
    const patch = await sharp(out).extract(c.blur).blur(18).toBuffer();
    out = await sharp(out).composite([{ input: patch, left: c.blur.left, top: c.blur.top }]).toBuffer();
  }
  return out;
}

const tokenFor = (key) => {
  const h = crypto.createHash('sha1').update(`go4market:${key}`).digest('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-5${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`;
};
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function wrap(text, max) {
  const words = String(text).split(/\s+/);
  const lines = [];
  let cur = '';
  for (const w of words) {
    if ((cur + ' ' + w).trim().length > max) { if (cur) lines.push(cur); cur = w; } else cur = (cur + ' ' + w).trim();
  }
  if (cur) lines.push(cur);
  return lines.slice(0, 3);
}

/** Branded illustration: soft gradient in the module colour, a product "tile" and the title. */
export function illustrationSvg(title, subtitle, color = '#0B8A4F', [w, h] = SIZES.product) {
  const lines = wrap(title, w > h * 1.5 ? 28 : 16);
  const initials = String(title).split(/\s+/).filter((x) => /[A-Za-z]/.test(x[0] ?? '')).slice(0, 2).map((x) => x[0].toUpperCase()).join('');
  const cx = w / 2, iconY = h * 0.36, r = Math.min(w, h) * 0.2;
  const fs1 = Math.round(Math.min(w, h) * 0.075);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${color}" stop-opacity="0.10"/><stop offset="1" stop-color="${color}" stop-opacity="0.28"/></linearGradient>
    <linearGradient id="c" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}"/><stop offset="1" stop-color="#0A4A33"/></linearGradient>
  </defs>
  <rect width="${w}" height="${h}" fill="#F7FAF8"/><rect width="${w}" height="${h}" fill="url(#g)"/>
  <circle cx="${w * 0.88}" cy="${h * 0.12}" r="${Math.min(w, h) * 0.18}" fill="${color}" opacity="0.08"/>
  <circle cx="${w * 0.1}" cy="${h * 0.9}" r="${Math.min(w, h) * 0.22}" fill="#F7860F" opacity="0.07"/>
  <rect x="${cx - r}" y="${iconY - r}" width="${r * 2}" height="${r * 2}" rx="${r * 0.45}" fill="url(#c)"/>
  <text x="${cx}" y="${iconY + r * 0.28}" font-family="Segoe UI, Arial, sans-serif" font-size="${r * 0.85}" font-weight="800" fill="#FFFFFF" text-anchor="middle">${esc(initials || 'G4')}</text>
  ${lines.map((l, i) => `<text x="${cx}" y="${h * 0.66 + i * fs1 * 1.25}" font-family="Segoe UI, Arial, sans-serif" font-size="${fs1}" font-weight="700" fill="#0F1A14" text-anchor="middle">${esc(l)}</text>`).join('\n  ')}
  ${subtitle ? `<text x="${cx}" y="${h * 0.66 + lines.length * fs1 * 1.25 + fs1 * 0.4}" font-family="Segoe UI, Arial, sans-serif" font-size="${Math.round(fs1 * 0.6)}" fill="#5B6B62" text-anchor="middle">${esc(subtitle)}</text>` : ''}
  <text x="${w - 16}" y="${h - 14}" font-family="Segoe UI, Arial, sans-serif" font-size="${Math.max(12, Math.round(fs1 * 0.45))}" font-weight="800" fill="#0A4A33" text-anchor="end" opacity="0.55">Go<tspan fill="#F7860F">4</tspan><tspan fill="#0B8A4F">Market</tspan></text>
</svg>`;
}

export function logoSvg(name, color = '#0B8A4F') {
  const initials = String(name).replace(/[^A-Za-z0-9 ]/g, '').split(/\s+/).filter(Boolean).slice(0, 2).map((x) => x[0].toUpperCase()).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs><linearGradient id="c" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${color}"/><stop offset="1" stop-color="#0A4A33"/></linearGradient></defs>
  <rect width="256" height="256" rx="56" fill="url(#c)"/>
  <circle cx="214" cy="42" r="16" fill="#F7860F"/>
  <text x="128" y="150" font-family="Segoe UI, Arial, sans-serif" font-size="96" font-weight="800" fill="#FFFFFF" text-anchor="middle">${esc(initials)}</text>
  <text x="128" y="206" font-family="Segoe UI, Arial, sans-serif" font-size="${name.length > 14 ? 17 : 21}" font-weight="600" fill="#FFFFFF" fill-opacity="0.9" text-anchor="middle">${esc(name)}</text>
</svg>`;
}

export class ImageStore {
  constructor(bucket, photoMap, cacheDir) {
    this.bucket = bucket;
    this.photos = photoMap;
    this.cacheDir = cacheDir;
    fs.mkdirSync(cacheDir, { recursive: true });
    this.stats = { uploaded: 0, skipped: 0, photos: 0, illustrations: 0, failed: [] };
  }

  url(p, token) {
    return `https://firebasestorage.googleapis.com/v0/b/${this.bucket.name}/o/${encodeURIComponent(p)}?alt=media&token=${token}`;
  }

  async download(src, w, h) {
    const cache = path.join(this.cacheDir, crypto.createHash('md5').update(`${src}|${w}x${h}`).digest('hex') + '.jpg');
    if (fs.existsSync(cache)) return fs.readFileSync(cache);
    const u = `${src}?w=${Math.min(2000, Math.round(w * 1.25))}&h=${Math.min(2000, Math.round(h * 1.25))}&fit=crop&crop=entropy&q=80&fm=jpg`;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const res = await fetch(u, { signal: AbortSignal.timeout(30000) });
        const ct = res.headers.get('content-type') ?? '';
        if (res.status !== 200 || !ct.startsWith('image/')) throw new Error(`HTTP ${res.status} ${ct}`);
        const buf = Buffer.from(await res.arrayBuffer());
        fs.writeFileSync(cache, buf);
        return buf;
      } catch (e) {
        if (attempt === 3) throw e;
        await new Promise((r) => setTimeout(r, 1000 * attempt));
      }
    }
  }

  /** Returns a tokened download URL for `key`, uploading to `storagePath` if needed. */
  async get(key, storagePath, size, fallback = {}) {
    const [w, h] = size;
    const src = this.photos[key];
    const fix = CLEANUP[key] ? `|fix:${JSON.stringify(CLEANUP[key])}` : '';
    const token = tokenFor(`${key}|${storagePath}|${src ?? 'svg'}|${w}x${h}${fix}`);
    const file = this.bucket.file(storagePath);
    try {
      const [exists] = await file.exists();
      if (exists) {
        const [meta] = await file.getMetadata();
        if (meta.metadata?.firebaseStorageDownloadTokens === token) { this.stats.skipped++; return this.url(storagePath, token); }
      }
    } catch { /* fall through to upload */ }

    let webp;
    if (src) {
      try {
        const raw = await this.download(src, w, h);
        webp = await sharp(await applyCleanup(key, raw, w, h)).webp({ quality: 80, effort: 5 }).toBuffer();
        this.stats.photos++;
      } catch (e) {
        this.stats.failed.push(`${key}: ${e.message}`);
      }
    }
    if (!webp) {
      const svg = fallback.logo ? logoSvg(fallback.title ?? key, fallback.color) : illustrationSvg(fallback.title ?? key, fallback.subtitle ?? '', fallback.color, size);
      webp = await sharp(Buffer.from(svg)).resize(w, h).webp({ quality: 90 }).toBuffer();
      this.stats.illustrations++;
    }
    await file.save(webp, {
      resumable: false,
      metadata: { contentType: 'image/webp', cacheControl: 'public, max-age=31536000', metadata: { firebaseStorageDownloadTokens: token, source: src ?? 'generated', key } },
    });
    this.stats.uploaded++;
    return this.url(storagePath, token);
  }
}

/** Runs async tasks with limited concurrency. */
export async function pool(items, n, fn) {
  const out = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, async () => {
    while (i < items.length) {
      const k = i++;
      out[k] = await fn(items[k], k);
    }
  }));
  return out;
}
