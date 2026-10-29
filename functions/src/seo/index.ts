import { onRequest } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { db } from '../lib/admin.js';

const SITE = 'https://go4market.web.app';
const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');
const iso = (t: any) => (t?.toDate ? t.toDate().toISOString() : undefined);

interface U { loc: string; lastmod?: string; changefreq?: string; priority?: string; image?: string; imageTitle?: string }

/**
 * sitemap (HTTP GET, hosting rewrite /sitemap.xml) — XML sitemap of the storefront.
 * Routes: / , /m/{moduleId}, /c/{categorySlug}, /p/{productSlug}, /store/{sellerSlug}, /blog, /blog/{slug}, /page/{slug}, /faqs.
 */
export const sitemap = onRequest({ memory: '512MiB', timeoutSeconds: 60, cors: false }, async (req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.status(405).send('Method not allowed'); return; }
  try {
    const [mods, cats, prods, blogs, pages, sellers] = await Promise.all([
      db.collection('modules').where('enabled', '==', true).get(),
      db.collection('categories').where('active', '==', true).get(),
      db.collection('products').where('status', '==', 'active').select('slug', 'name', 'images', 'updatedAt').limit(45000).get(),
      db.collection('blogs').where('published', '==', true).select('slug', 'title', 'cover', 'updatedAt', 'publishedAt').get(),
      db.collection('pages').select('updatedAt').get(),
      db.collection('sellers').where('status', '==', 'approved').select('slug', 'updatedAt').get(),
    ]);
    const urls: U[] = [
      { loc: `${SITE}/`, changefreq: 'daily', priority: '1.0' },
      { loc: `${SITE}/blog`, changefreq: 'weekly', priority: '0.5' },
      { loc: `${SITE}/faqs`, changefreq: 'monthly', priority: '0.3' },
      ...mods.docs.map((d) => ({ loc: `${SITE}/m/${d.id}`, changefreq: 'daily', priority: '0.9', lastmod: iso(d.get('updatedAt')) })),
      ...cats.docs.map((d) => ({ loc: `${SITE}/c/${encodeURIComponent(d.get('slug') ?? d.id)}`, changefreq: 'daily', priority: d.get('depth') ? '0.7' : '0.8', lastmod: iso(d.get('updatedAt')) })),
      ...sellers.docs.map((d) => ({ loc: `${SITE}/store/${encodeURIComponent(d.get('slug') ?? d.id)}`, changefreq: 'weekly', priority: '0.6', lastmod: iso(d.get('updatedAt')) })),
      ...prods.docs.map((d) => ({
        loc: `${SITE}/p/${encodeURIComponent(d.get('slug') ?? d.id)}`, changefreq: 'weekly', priority: '0.8', lastmod: iso(d.get('updatedAt')),
        image: (d.get('images') ?? [])[0], imageTitle: d.get('name'),
      })),
      ...blogs.docs.map((d) => ({ loc: `${SITE}/blog/${encodeURIComponent(d.get('slug') ?? d.id)}`, changefreq: 'monthly', priority: '0.6', lastmod: iso(d.get('updatedAt') ?? d.get('publishedAt')), image: d.get('cover'), imageTitle: d.get('title') })),
      ...pages.docs.map((d) => ({ loc: `${SITE}/page/${encodeURIComponent(d.id)}`, changefreq: 'yearly', priority: '0.3', lastmod: iso(d.get('updatedAt')) })),
    ];
    const body = urls.map((u) => [
      '  <url>',
      `    <loc>${esc(u.loc)}</loc>`,
      u.lastmod ? `    <lastmod>${u.lastmod}</lastmod>` : '',
      u.changefreq ? `    <changefreq>${u.changefreq}</changefreq>` : '',
      u.priority ? `    <priority>${u.priority}</priority>` : '',
      u.image ? `    <image:image><image:loc>${esc(u.image)}</image:loc>${u.imageTitle ? `<image:title>${esc(String(u.imageTitle))}</image:title>` : ''}</image:image>` : '',
      '  </url>',
    ].filter(Boolean).join('\n')).join('\n');
    const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">\n${body}\n</urlset>\n`;
    res.set('Content-Type', 'application/xml; charset=utf-8');
    res.set('Cache-Control', 'public, max-age=3600, s-maxage=3600');
    res.status(200).send(xml);
  } catch (e) {
    logger.error('sitemap failed', { error: String(e) });
    res.status(500).send('sitemap unavailable');
  }
});
