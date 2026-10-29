// Discovery APIs: multi-term (voice) search, recommendations (similar / cross-sell / replacement), nearby stores.
import { onCall } from 'firebase-functions/v2/https';
import { db } from '../lib/admin.js';
import { fail, haversineKm, isNum, num, oneOf, round2, str, type Json } from '../lib/util.js';

const PUBLIC_FIELDS = ['name', 'slug', 'images', 'price', 'mrp', 'unit', 'stock', 'variants', 'rating', 'ratingCount', 'sellerId', 'sellerName', 'moduleId', 'categoryId', 'isVeg', 'brandName', 'deliveryMinutes', 'soldCount'];
const pick = (id: string, d: Json) => ({ id, ...Object.fromEntries(PUBLIC_FIELDS.map((k) => [k, d[k] ?? null])) });
const inStock = (p: Json) => (Array.isArray(p.variants) && p.variants.length ? p.variants.some((v: Json) => Number(v.stock) > 0) : Number(p.stock) > 0);

function tokens(s: string): string[] {
  return s.toLowerCase().split(/[^a-z0-9]+/).filter((t) => t.length > 1).slice(0, 10);
}

async function searchTerm(term: string, moduleId: string | null, limit: number): Promise<Json[]> {
  const t = tokens(term);
  if (!t.length) return [];
  let q = db.collection('products').where('status', '==', 'active').where('keywords', 'array-contains-any', t);
  if (moduleId) q = q.where('moduleId', '==', moduleId);
  const s = await q.limit(60).get();
  const scored = s.docs.map((d) => {
    const p = d.data();
    const name = String(p.name ?? '').toLowerCase();
    const kw: string[] = p.keywords ?? [];
    const score = t.reduce((a, x) => a + (name.includes(x) ? 3 : 0) + (kw.includes(x) ? 1 : 0), 0) + (inStock(p) ? 1 : -5) + Math.min(2, Number(p.soldCount ?? 0) / 500);
    return { score, p: pick(d.id, p) };
  });
  return scored.sort((a, b) => b.score - a.score).slice(0, limit).map((x) => x.p);
}

/**
 * searchProducts — public: {query, moduleId?, multi?: bool, limit?} → {groups:[{term, products[]}], products[]}.
 * multi=true splits "milk, bread and 2 eggs" into separate terms (voice multi-product search).
 */
export const searchProducts = onCall(async (req) => {
  const query = str(req.data?.query, 'query', { max: 300 });
  const moduleId = str(req.data?.moduleId, 'moduleId', { required: false, max: 32 }) || null;
  const limit = num(req.data?.limit ?? 20, 'limit', { min: 1, max: 40, int: true });
  const multi = req.data?.multi === true;
  const terms = multi
    ? query.toLowerCase().split(/,|\band\b|\baur\b|&|\+|\n|;/).map((x) => x.replace(/\b\d+\s*(kg|g|l|ml|pcs?|packets?|dozen)?\b/g, '').trim()).filter((x) => x.length > 1).slice(0, 8)
    : [query];
  const groups = await Promise.all(terms.map(async (term) => ({ term, products: await searchTerm(term, moduleId, multi ? 6 : limit) })));
  const seen = new Set<string>();
  const products = groups.flatMap((g) => g.products).filter((p) => (seen.has(p.id) ? false : (seen.add(p.id), true)));
  return { groups, products };
});

/**
 * getRecommendations — public: {productId, type: similar|cross_sell|replacement, limit?} → {products[]}.
 * similar: same category; replacement: same category, in stock, closest price; cross_sell: frequently bought together.
 */
export const getRecommendations = onCall(async (req) => {
  const productId = str(req.data?.productId, 'productId', { max: 128 });
  const type = oneOf(req.data?.type, 'type', ['similar', 'cross_sell', 'replacement'] as const, 'similar');
  const limit = num(req.data?.limit ?? 10, 'limit', { min: 1, max: 30, int: true });
  const ps = await db.doc(`products/${productId}`).get();
  if (!ps.exists) fail('not-found', 'Product not found.');
  const p = ps.data()!;
  if (type === 'cross_sell') {
    const co = (await db.doc(`coPurchase/${productId}`).get()).data()?.counts as Json | undefined;
    let ids = co ? Object.entries(co).sort((a, b) => Number(b[1]) - Number(a[1])).map(([id]) => id).slice(0, limit) : [];
    if (ids.length < limit) {
      // Fallback: bestsellers from the same module but a different category.
      const s = await db.collection('products').where('status', '==', 'active').where('moduleId', '==', p.moduleId).orderBy('soldCount', 'desc').limit(limit * 2).get();
      ids = [...new Set([...ids, ...s.docs.filter((d) => d.id !== productId && d.get('categoryId') !== p.categoryId).map((d) => d.id)])].slice(0, limit);
    }
    const snaps = ids.length ? await db.getAll(...ids.map((id) => db.doc(`products/${id}`))) : [];
    return { products: snaps.filter((s) => s.exists && s.get('status') === 'active').map((s) => pick(s.id, s.data()!)) };
  }
  const s = await db.collection('products').where('status', '==', 'active').where('categoryId', '==', p.categoryId).limit(50).get();
  let list = s.docs.filter((d) => d.id !== productId).map((d) => ({ id: d.id, d: d.data() }));
  if (type === 'replacement') {
    list = list.filter((x) => inStock(x.d)).sort((a, b) => Math.abs(Number(a.d.price) - Number(p.price)) - Math.abs(Number(b.d.price) - Number(p.price)));
  } else {
    list.sort((a, b) => Number(b.d.rating ?? 0) - Number(a.d.rating ?? 0));
  }
  return { products: list.slice(0, limit).map((x) => pick(x.id, x.d)) };
});

/** getNearbyStores — public: {lat, lng, moduleId?, radiusKm?} → {stores:[{id, storeName, slug, logo, distanceKm, etaMinutes, ...}]}. */
export const getNearbyStores = onCall(async (req) => {
  const lat = num(req.data?.lat, 'lat', { min: -90, max: 90 });
  const lng = num(req.data?.lng, 'lng', { min: -180, max: 180 });
  const moduleId = str(req.data?.moduleId, 'moduleId', { required: false, max: 32 }) || null;
  const radius = num(req.data?.radiusKm ?? 25, 'radiusKm', { min: 1, max: 100 });
  const s = await db.collection('sellers').where('status', '==', 'approved').limit(500).get();
  const stores = s.docs
    .map((d) => ({ id: d.id, ...d.data() } as Json))
    .filter((x) => !moduleId || !Array.isArray(x.modules) || x.modules.includes(moduleId))
    .filter((x) => isNum(x.lat) && isNum(x.lng))
    .map((x) => {
      const distanceKm = round2(haversineKm(lat, lng, x.lat, x.lng));
      return {
        id: x.id, storeName: x.storeName, slug: x.slug, logo: x.logo ?? '', banner: x.banner ?? '', city: x.city, modules: x.modules ?? [],
        rating: x.rating ?? 0, ratingCount: x.ratingCount ?? 0, distanceKm, etaMinutes: Math.round(20 + distanceKm * 3),
      };
    })
    .filter((x) => x.distanceKm <= radius)
    .sort((a, b) => a.distanceKm - b.distanceKm);
  return { stores };
});
