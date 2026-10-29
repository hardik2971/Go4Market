// Generates firestore.indexes.json at the repo root. Run: node tools/seed/gen-indexes.mjs
import fs from 'node:fs';

const idx = [];
const A = 'ASCENDING', D = 'DESCENDING', C = 'CONTAINS';
const F = (fieldPath, o = A) => (o === C ? { fieldPath, arrayConfig: C } : { fieldPath, order: o });
const add = (collectionGroup, fields, queryScope = 'COLLECTION') => idx.push({ collectionGroup, queryScope, fields });

// products: status + optional filters + every sort used by CatalogRepo.productsQuery
const sorts = [['createdAt', D], ['price', A], ['price', D], ['soldCount', D], ['rating', D]];
const eqSets = [[], ['moduleId'], ['sellerId'], ['brandId'], ['featured'], ['moduleId', 'featured'], ['moduleId', 'brandId'], ['sellerId', 'moduleId']];
for (const eq of eqSets) for (const [f, o] of sorts) add('products', [F('status'), ...eq.map((e) => F(e)), F(f, o)]);
for (const extra of [[], ['brandId'], ['sellerId']]) for (const [f, o] of sorts) add('products', [F('status'), F('categoryPath', C), ...extra.map((e) => F(e)), F(f, o)]);
add('products', [F('status'), F('keywords', C)]);
add('products', [F('status'), F('moduleId'), F('keywords', C)]);
add('products', [F('status'), F('categoryId')]);
add('products', [F('status'), F('soldCount', A)]);
add('products', [F('status'), F('sellerId'), F('soldCount', A)]);
add('products', [F('status'), F('moduleId'), F('soldCount', A)]);
add('products', [F('sellerId'), F('createdAt', D)]);
add('products', [F('sellerId'), F('stock', A)]);
add('products', [F('sellerId'), F('status'), F('stock', A)]);
add('products', [F('status'), F('stock', A)]);

// orders
add('orders', [F('userId'), F('createdAt', D)]);
add('orders', [F('userId'), F('status'), F('createdAt', D)]);
add('orders', [F('sellerIds', C), F('createdAt', D)]);
add('orders', [F('sellerIds', C), F('createdAt', A)]);
add('orders', [F('sellerIds', C), F('status'), F('createdAt', D)]);
add('orders', [F('deliveryPartnerId'), F('createdAt', D)]);
add('orders', [F('deliveryPartnerId'), F('status'), F('createdAt', D)]);
add('orders', [F('deliveryPartnerId'), F('deliveryType'), F('status'), F('createdAt', D)]);
add('orders', [F('status'), F('createdAt', D)]);
add('orders', [F('status'), F('createdAt', A)]);
add('orders', [F('channel'), F('createdAt', D)]);
add('orders', [F('channel'), F('status'), F('createdAt', D)]);
add('orders', [F('paymentStatus'), F('createdAt', D)]);
add('orders', [F('moduleIds', C), F('createdAt', D)]);
add('orders', [F('speed'), F('status'), F('createdAt', D)]);

// money
add('walletTransactions', [F('userId'), F('createdAt', D)]);
add('walletTransactions', [F('reason'), F('createdAt', D)]);
add('walletTopups', [F('userId'), F('createdAt', D)]);
add('walletTopups', [F('status'), F('createdAt', A)]);
add('withdrawals', [F('userId'), F('createdAt', D)]);
add('withdrawals', [F('status'), F('createdAt', D)]);
add('withdrawals', [F('role'), F('status'), F('createdAt', D)]);
add('fundTransfers', [F('toUserId'), F('createdAt', D)]);
add('fundTransfers', [F('role'), F('createdAt', D)]);
add('cashCollections', [F('deliveryPartnerId'), F('status'), F('createdAt', A)]);
add('cashCollections', [F('deliveryPartnerId'), F('createdAt', D)]);
add('cashCollections', [F('status'), F('createdAt', D)]);

// returns, requests, subscriptions
add('returns', [F('userId'), F('createdAt', D)]);
add('returns', [F('sellerIds', C), F('createdAt', D)]);
add('returns', [F('status'), F('createdAt', D)]);
add('productRequests', [F('userId'), F('createdAt', D)]);
add('productRequests', [F('status'), F('createdAt', D)]);
add('subscriptions', [F('status'), F('nextRunAt', A)]);
add('subscriptions', [F('userId'), F('createdAt', D)]);

// people
add('users', [F('role'), F('createdAt', D)]);
add('users', [F('role'), F('status')]);
add('users', [F('status'), F('createdAt', D)]);
add('sellers', [F('status'), F('createdAt', D)]);
add('sellers', [F('status'), F('rating', D)]);
add('deliveryPartners', [F('status'), F('online')]);
add('deliveryPartners', [F('status'), F('salary.type')]);
add('deliveryPartners', [F('sellerId'), F('status')]);
add('deliveryPartners', [F('status'), F('createdAt', D)]);

// content
add('blogs', [F('published'), F('publishedAt', D)]);
add('blogs', [F('published'), F('categoryId'), F('publishedAt', D)]);
add('coupons', [F('sellerId'), F('createdAt', D)]);
add('coupons', [F('active'), F('endAt', A)]);
add('attributeAlerts', [F('sellerId'), F('createdAt', D)]);
add('campaigns', [F('status'), F('createdAt', D)]);

// collection groups
add('cart', [F('sellerId'), F('addedAt', D)], 'COLLECTION_GROUP');
add('cart', [F('sellerId'), F('addedAt', A)], 'COLLECTION_GROUP');
add('reviews', [F('rating'), F('createdAt', D)], 'COLLECTION_GROUP');

const singleBoth = (collectionGroup, fieldPath) => ({
  collectionGroup, fieldPath,
  indexes: [
    { order: A, queryScope: 'COLLECTION' }, { order: D, queryScope: 'COLLECTION' }, { arrayConfig: C, queryScope: 'COLLECTION' },
    { order: A, queryScope: 'COLLECTION_GROUP' }, { order: D, queryScope: 'COLLECTION_GROUP' },
  ],
});
const fieldOverrides = [
  singleBoth('cart', 'addedAt'),
  singleBoth('reviews', 'createdAt'),
  singleBoth('notifications', 'createdAt'),
  { collectionGroup: 'products', fieldPath: 'description', indexes: [] },
  { collectionGroup: 'blogs', fieldPath: 'content', indexes: [] },
  { collectionGroup: 'pages', fieldPath: 'content', indexes: [] },
  { collectionGroup: 'emailTemplates', fieldPath: 'html', indexes: [] },
];
// Merge the panel team's requirements (apps/panel/firestore.indexes.panel.json) when present.
const panelFile = new URL('../../apps/panel/firestore.indexes.panel.json', import.meta.url);
if (fs.existsSync(panelFile)) {
  const panel = JSON.parse(fs.readFileSync(panelFile, 'utf8'));
  for (const i of panel.indexes ?? []) idx.push({ collectionGroup: i.collectionGroup, queryScope: i.queryScope ?? 'COLLECTION', fields: i.fields });
  for (const fo of panel.fieldOverrides ?? []) if (!fieldOverrides.some((x) => x.collectionGroup === fo.collectionGroup && x.fieldPath === fo.fieldPath)) fieldOverrides.push(singleBoth(fo.collectionGroup, fo.fieldPath));
}
const seen = new Set();
const indexes = idx.filter((i) => { const k = JSON.stringify(i); if (seen.has(k)) return false; seen.add(k); return true; });
fs.writeFileSync(new URL('../../firestore.indexes.json', import.meta.url), JSON.stringify({ indexes, fieldOverrides }, null, 2) + '\n');
console.log('composite indexes:', indexes.length, 'field overrides:', fieldOverrides.length);
