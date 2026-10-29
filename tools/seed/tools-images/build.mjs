// Usage: node tools-images/build.mjs <out.json> <picks1.json> [picks2.json ...]  (later files override earlier)
// picks files: { key: "<digits>-<hex>" }. Writes { key: "https://images.unsplash.com/photo-..." } and re-verifies every URL.
import fs from 'node:fs';
import { products, categoryTree } from '../data/catalog.mjs';

const [, , out, ...files] = process.argv;
const picks = Object.assign({}, ...files.map((f) => JSON.parse(fs.readFileSync(f, 'utf8'))));
const cats = [];
const walk = (n) => { for (const [id, , kids] of n) { cats.push(id); if (kids) walk(kids); } };
for (const m of Object.values(categoryTree)) walk(m);
const content = [
  'slider:grocery-fresh', 'slider:food-feast', 'slider:pharmacy', 'slider:electronics', 'slider:fashion',
  'slider:quick-delivery', 'slider:home-kitchen', 'slider:dairy-breakfast',
  'offer:fruits', 'offer:snacks', 'offer:pizza', 'offer:vitamins', 'offer:sneakers', 'offer:skincare',
  'banner:breakfast', 'banner:festive-sweets', 'banner:gadgets',
  'blog:seasonal-produce', 'blog:spice-pantry', 'blog:immunity', 'blog:biryani', 'blog:wfh-setup', 'blog:summer-skincare',
  'popup:welcome', 'seller:demo-seller', 'seller:seller-urbantrend', 'seller:seller-mediplus', 'seller:seller-spiceroute',
];
const keys = [...products.map((p) => p[0]), ...cats.map((c) => `cat:${c}`), ...content];
const res = {}, missing = [];
for (const k of keys) {
  if (picks[k]) res[k] = `https://images.unsplash.com/photo-${picks[k]}`;
  else missing.push(k);
}
const extra = Object.keys(picks).filter((k) => !keys.includes(k));

const urls = [...new Set(Object.values(res))];
const bad = [];
await Promise.all(urls.map(async (u) => {
  const r = await fetch(`${u}?w=400&q=70&fm=jpg`);
  const ct = r.headers.get('content-type') || '';
  await r.arrayBuffer();
  if (r.status !== 200 || !ct.startsWith('image/')) bad.push(`${u} ${r.status} ${ct}`);
}));

const byUrl = {};
for (const [k, u] of Object.entries(res)) (byUrl[u] ||= []).push(k);
const dups = Object.values(byUrl).filter((a) => a.length > 1);

fs.writeFileSync(out, JSON.stringify(res, null, 2) + '\n');
console.log(JSON.stringify({ total: keys.length, products: products.length, cats: cats.length, content: content.length,
  mapped: Object.keys(res).length, uniqueUrls: urls.length, missing, extra, bad, dups }, null, 1));
