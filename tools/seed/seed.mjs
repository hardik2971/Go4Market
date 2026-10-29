#!/usr/bin/env node
// Go4Market seed — idempotent (stable ids; safe to re-run). Seeds the LIVE project with the Admin SDK.
//   node seed.mjs              full seed
//   node seed.mjs --no-wait    skip the final wait-and-recount step
// Runtime fields (stock, soldCount, ratings, balances, wallet) are preserved on re-runs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { modules, categoryTree, brands, sellers, products, reviewsSeed } from './data/catalog.mjs';
import * as C from './data/content.mjs';
import { ImageStore, SIZES, pool } from './lib/images.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const sa = JSON.parse(fs.readFileSync(path.join(root, 'secret/go4market-firebase-adminsdk.json'), 'utf8'));
const env = Object.fromEntries(fs.readFileSync(path.join(root, 'secret/.env'), 'utf8').split(/\r?\n/)
  .map((l) => l.match(/^([A-Z0-9_]+)=(.*)$/)).filter(Boolean).map((m) => [m[1], m[2].trim().replace(/^['"]|['"]$/g, '')]));
const PASSWORD = 'Go4Market@123';
const BUCKET = 'go4market.firebasestorage.app';
const CACHE = process.env.SEED_CACHE ?? path.join(process.env.TEMP ?? root, 'go4market-seed-cache');

initializeApp({ credential: cert(sa), storageBucket: BUCKET, projectId: 'go4market' });
const auth = getAuth();
const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });
const bucket = getStorage().bucket(BUCKET);
const photos = JSON.parse(fs.readFileSync(path.join(here, 'data/images.json'), 'utf8'));
const img = new ImageStore(bucket, photos, CACHE);
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const counts = {};
const bump = (k, n = 1) => (counts[k] = (counts[k] ?? 0) + n);
const NOW = Date.now();
const ts = (msAgo) => Timestamp.fromMillis(NOW - msAgo);
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

/** Upsert: creates with createdAt, or merges while preserving runtime keys that already exist. */
const writer = db.bulkWriter();
writer.onWriteError((err) => { console.error('write failed', err.documentRef.path, err.message); return err.failedAttempts < 3; });
async function upsert(ref, data, preserve = [], existing) {
  const snap = existing ?? (await ref.get());
  const d = { ...data, updatedAt: FieldValue.serverTimestamp() };
  if (snap.exists) {
    for (const k of preserve) if (snap.get(k) !== undefined) delete d[k];
    if (snap.get('createdAt') !== undefined) delete d.createdAt;
  } else if (!d.createdAt) d.createdAt = FieldValue.serverTimestamp();
  writer.set(ref, d, { merge: true });
}

/** Settings docs: only fill keys that do not exist yet, so re-running never overwrites admin changes. */
const upsertMissing = (ref, data) => upsert(ref, data, Object.keys(data));

function buildKeywords(...parts) {
  const STOP = new Set(['and', 'the', 'for', 'with', 'of', 'in', 'to', 'a', 'an', 'pcs', 'pc']);
  const out = new Set();
  for (const p of parts.flat()) {
    if (!p) continue;
    for (const t of String(p).toLowerCase().split(/[^a-z0-9]+/)) {
      if (t.length < 2 || STOP.has(t)) continue;
      out.add(t);
      for (let i = 2; i < t.length && i <= 10; i++) out.add(t.slice(0, i));
    }
  }
  return [...out].slice(0, 150);
}
function ean13(seed) {
  const h = crypto.createHash('md5').update(seed).digest('hex');
  const body = '890' + String(parseInt(h.slice(0, 12), 16)).slice(0, 9).padStart(9, '0');
  const sum = body.split('').reduce((a, d, i) => a + Number(d) * (i % 2 ? 3 : 1), 0);
  return body + ((10 - (sum % 10)) % 10);
}

// ───────────────────────── accounts
const ACCOUNTS = [
  { uid: 'demo-admin', email: 'admin@go4market.com', name: 'Aarti Sharma', phone: '+919825000001', role: 'admin' },
  { uid: 'demo-seller', email: 'seller@go4market.com', name: 'Rakesh Patel', phone: '+919825011111', role: 'seller' },
  { uid: 'demo-delivery', email: 'delivery@go4market.com', name: 'Kiran Solanki', phone: '+919825055555', role: 'delivery' },
  { uid: 'demo-customer', email: 'customer@go4market.com', name: 'Priya Shah', phone: '+919825099999', role: 'customer' },
  { uid: 'seller-urbantrend', email: 'urbantrend@go4market.com', name: 'Nisha Mehta', phone: '+919825022222', role: 'seller' },
  { uid: 'seller-mediplus', email: 'mediplus@go4market.com', name: 'Dr. Ankit Shah', phone: '+919825033333', role: 'seller' },
  { uid: 'seller-spiceroute', email: 'spiceroute@go4market.com', name: 'Imran Qureshi', phone: '+919825044444', role: 'seller' },
  { uid: 'rider-mahesh', email: 'rider.mahesh@go4market.com', name: 'Mahesh Rathod', phone: '+919825066666', role: 'delivery' },
  { uid: 'rider-salim', email: 'rider.salim@go4market.com', name: 'Salim Shaikh', phone: '+919825077777', role: 'delivery' },
];

async function seedAccounts() {
  for (const a of ACCOUNTS) {
    try {
      await auth.getUser(a.uid);
      await auth.updateUser(a.uid, { email: a.email, password: PASSWORD, displayName: a.name, emailVerified: true, disabled: false });
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      try {
        await auth.createUser({ uid: a.uid, email: a.email, password: PASSWORD, displayName: a.name, emailVerified: true });
      } catch (e2) {
        if (e2.code === 'auth/email-already-exists') {
          const other = await auth.getUserByEmail(a.email);
          throw new Error(`${a.email} already exists with uid ${other.uid}; delete it or adjust ACCOUNTS.`);
        }
        throw e2;
      }
    }
    await auth.setCustomUserClaims(a.uid, { role: a.role });
    const ref = db.doc(`users/${a.uid}`);
    const snap = await ref.get();
    const code = snap.get('referralCode') ?? `${a.name.replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 4)}${crypto.createHash('md5').update(a.uid).digest('hex').slice(0, 4).toUpperCase()}`;
    const isCustomer = a.uid === 'demo-customer';
    await upsert(ref, {
      name: a.name, email: a.email, phone: a.phone, photoUrl: '', role: a.role, status: 'active',
      walletBalance: isCustomer ? 500 : 0, referralCode: code, fcmTokens: [], recentlyViewed: [], city: 'Ahmedabad',
      ...(isCustomer ? { defaultAddressId: 'home', recentlyViewed: ['shimla-apples', 'chicken-biryani', 'anc-headphones', 'toned-milk'] } : {}),
    }, ['walletBalance', 'fcmTokens', 'recentlyViewed', 'membership', 'referralCode'], snap);
    const welcome = isCustomer ? await db.doc('walletTransactions/seed-welcome-credit').get() : null;
    if (isCustomer && !welcome.exists) {
      const bal = Number(snap.get('walletBalance') ?? 0) + 500;
      await ref.set({ walletBalance: bal }, { merge: true });
      writer.set(db.doc('walletTransactions/seed-welcome-credit'), {
        userId: a.uid, type: 'credit', amount: 500, reason: 'cashback', refId: 'seed', balanceAfter: bal, note: 'Welcome cashback',
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
    }
    bump('authUsers');
  }
  // Customer addresses
  const addr = [
    ['home', { label: 'Home', name: 'Priya Shah', phone: '+919825099999', line1: 'B-702, Shaligram Lakeview', line2: 'Near Vastrapur Lake', landmark: 'Opp. Himalaya Mall', city: 'Ahmedabad', state: 'Gujarat', pincode: '380052', lat: 23.0395, lng: 72.5300, isDefault: true }],
    ['work', { label: 'Work', name: 'Priya Shah', phone: '+919825099999', line1: '5th Floor, Titanium City Centre', line2: '100 Ft Anand Nagar Road, Satellite', landmark: 'Near Sachin Tower', city: 'Ahmedabad', state: 'Gujarat', pincode: '380015', lat: 23.0120, lng: 72.5250, isDefault: false }],
  ];
  for (const [id, a] of addr) await upsert(db.doc(`users/demo-customer/addresses/${id}`), a);
  await upsert(db.doc('staff/demo-admin'), { name: 'Aarti Sharma', email: 'admin@go4market.com', roleId: 'super_admin', active: true });
}

// ───────────────────────── catalog
const catIndex = new Map(); // id -> {id, name, moduleId, parentId, path, depth}
function walk(moduleId, nodes, parent = null, pathIds = []) {
  nodes.forEach(([id, name, children], i) => {
    catIndex.set(id, { id, name, moduleId, parentId: parent, path: pathIds, depth: pathIds.length, order: i + 1 });
    if (children) walk(moduleId, children, id, [...pathIds, id]);
  });
}
Object.entries(categoryTree).forEach(([m, nodes]) => walk(m, nodes));
const moduleColor = Object.fromEntries(modules.map((m) => [m.id, m.themeColor]));

async function seedModulesAndCategories() {
  for (const m of modules) await upsert(db.doc(`modules/${m.id}`), { ...m, enabled: true });
  bump('modules', modules.length);
  await pool([...catIndex.values()], 6, async (c) => {
    const image = await img.get(`cat:${c.id}`, `catalog/categories/${c.id}.webp`, SIZES.category, { title: c.name, color: moduleColor[c.moduleId] });
    await upsert(db.doc(`categories/${c.id}`), {
      name: c.name, slug: c.id, image, moduleId: c.moduleId, parentId: c.parentId, path: c.path, depth: c.depth, order: c.order, active: true, productCount: 0,
    }, ['productCount']);
  });
  bump('categories', catIndex.size);
  const brandColors = ['#0B8A4F', '#2563EB', '#F7860F', '#0E9F9A', '#7C3AED', '#DC2626', '#0A4A33'];
  await pool(brands, 6, async (b, i) => {
    const logo = await img.get(`brand:${b.id}`, `catalog/brands/${b.id}.webp`, SIZES.logo, { logo: true, title: b.name, color: brandColors[i % brandColors.length] });
    await upsert(db.doc(`brands/${b.id}`), { name: b.name, logo, active: true, slug: b.id });
  });
  bump('brands', brands.length);
}

async function seedSellersAndRiders() {
  for (const s of sellers) {
    const color = moduleColor[s.modules[0]];
    const logo = await img.get(`logo:${s.uid}`, `catalog/sellers/${s.uid}-logo.webp`, SIZES.logo, { logo: true, title: s.storeName, color });
    const banner = await img.get(`seller:${s.uid}`, `catalog/sellers/${s.uid}-banner.webp`, SIZES.sellerBanner, { title: s.storeName, color });
    const { uid, modules: mods, extraRoots, excludeRoots, ...rest } = s;
    await upsert(db.doc(`sellers/${uid}`), {
      ...rest, logo, banner, modules: [...mods, ...(extraRoots ? ['ecommerce'] : [])], status: 'approved', policiesAccepted: true,
      rating: 4.5, ratingCount: 0, balance: 0, totalSales: 0, productCount: 0, orderCount: 0,
      bank: { holder: s.storeName, account: `XXXXXX${String(Math.abs(s.phone.slice(-4) * 7)).padStart(4, '0').slice(-4)}`, ifsc: 'HDFC0001234' },
    }, ['balance', 'totalSales', 'productCount', 'rating', 'ratingCount', 'ratingSum', 'orderCount', 'pendingWithdrawal', 'totalPaidOut']);
  }
  bump('sellers', sellers.length);
  const riders = [
    { uid: 'demo-delivery', name: 'Kiran Solanki', email: 'delivery@go4market.com', phone: '+919825055555', vehicleType: 'bike', vehicleNo: 'GJ01AB4521', cities: ['Ahmedabad', 'Gandhinagar'], ownerType: 'admin', sellerId: null, online: true, lat: 23.0330, lng: 72.5350, salary: { type: 'per_order', amount: 35 }, rating: 4.8, completedCount: 0 },
    { uid: 'rider-mahesh', name: 'Mahesh Rathod', email: 'rider.mahesh@go4market.com', phone: '+919825066666', vehicleType: 'scooter', vehicleNo: 'GJ01CD7788', cities: ['Ahmedabad'], ownerType: 'admin', sellerId: null, online: false, lat: 23.0450, lng: 72.5600, salary: { type: 'monthly', amount: 18000 }, rating: 4.6, completedCount: 0 },
    { uid: 'rider-salim', name: 'Salim Shaikh', email: 'rider.salim@go4market.com', phone: '+919825077777', vehicleType: 'bike', vehicleNo: 'GJ01EF3390', cities: ['Ahmedabad'], ownerType: 'seller', sellerId: 'demo-seller', online: false, lat: 23.0290, lng: 72.5280, salary: { type: 'per_order', amount: 30 }, rating: 4.7, completedCount: 0 },
  ];
  for (const r of riders) {
    const { uid, ...rest } = r;
    await upsert(db.doc(`deliveryPartners/${uid}`), {
      ...rest, photoUrl: '', status: 'approved', cashInHand: 0, balance: 0, activeOrders: [], licenseNo: `GJ01 2019${uid.length}04${uid.length * 7}`,
      locationUpdatedAt: FieldValue.serverTimestamp(),
    }, ['cashInHand', 'balance', 'completedCount', 'activeOrders', 'online', 'lat', 'lng', 'rating']);
  }
  bump('deliveryPartners', riders.length);
}

const sellerForCategory = (catId) => {
  const c = catIndex.get(catId);
  const rootId = c.path[0] ?? catId;
  if (c.moduleId === 'ecommerce') return rootId === 'home-kitchen' ? sellers[0] : sellers[1];
  return sellers.find((s) => s.modules.includes(c.moduleId));
};
const MODULE_MINUTES = { grocery: 30, food: 35, pharmacy: 45, ecommerce: 2880 };

function describe(p, mod, brandName, sellerName) {
  const [, , name, , , , unit, , short, ex] = p;
  const cf = Object.entries(ex.cf ?? {}).map(([k, v]) => `- **${k.replace(/_/g, ' ')}:** ${v}`);
  const parts = [short, ''];
  if (mod === 'grocery') {
    parts.push(`${brandName} ${name} is sourced from trusted farms and suppliers, quality-checked and packed hygienically at ${sellerName}. Order before 10 pm for the freshest pick, delivered in as little as 15 minutes.`);
    parts.push('', '### Highlights', ...(cf.length ? cf : []), `- **Pack size:** ${unit}`, `- **Diet:** ${ex.veg === false ? 'Non-vegetarian' : 'Vegetarian'}`);
    parts.push('', '### Storage', 'Store in a cool, dry place away from direct sunlight unless stated otherwise. Refrigerate fresh produce and dairy on arrival.');
  } else if (mod === 'food') {
    parts.push(`Cooked fresh to order at ${sellerName} using house-ground masalas and no artificial colours. Packed in tamper-proof, leak-resistant containers to arrive hot.`);
    parts.push('', '### Details', `- **Portion:** ${unit}`, `- **Diet:** ${ex.veg === false ? 'Non-vegetarian' : 'Vegetarian'}`, ...cf);
    parts.push('', 'Customise your order with add-ons at checkout. Please mention allergies in the order notes.');
  } else if (mod === 'pharmacy') {
    parts.push(`Supplied by ${sellerName}, a licensed pharmacy with a registered pharmacist on every shift. Every pack is sealed, stored as per label instructions and has at least 6 months of shelf life at dispatch.`);
    parts.push('', '### Product information', `- **Pack:** ${unit}`, ...cf);
    parts.push('', '> Read the label carefully before use. Keep out of reach of children. If symptoms persist, consult a doctor. This information is not a substitute for medical advice.');
  } else {
    parts.push(`${brandName} ${name} — sold by ${sellerName} with a GST invoice, genuine-product guarantee and easy 7-day returns.`);
    parts.push('', '### Specifications', '| Feature | Detail |', '|---|---|', `| Brand | ${brandName} |`, ...Object.entries(ex.cf ?? {}).map(([k, v]) => `| ${k.replace(/_/g, ' ')} | ${v} |`), `| In the box | ${unit} |`);
    parts.push('', '### Delivery & returns', '- Ships in 1–3 days across serviceable cities', '- 7-day easy returns in original condition');
  }
  return parts.join('\n');
}

async function seedProducts() {
  const brandName = Object.fromEntries(brands.map((b) => [b.id, b.name]));
  await pool(products, 6, async (p, i) => {
    const [id, catId, name, brandId, price, mrp, unit, stock, short, ex] = p;
    const c = catIndex.get(catId);
    if (!c) throw new Error(`Unknown category ${catId} for ${id}`);
    const mod = c.moduleId;
    const seller = sellerForCategory(catId);
    const image = await img.get(id, `catalog/products/${id}.webp`, SIZES.product, { title: name, subtitle: brandName[brandId], color: moduleColor[mod] });
    const variants = (ex.v ?? []).map(([vn, vp, vm, vs], k) => ({ id: slug(vn), name: vn, price: vp, mrp: vm, stock: vs, sku: `${id.toUpperCase().slice(0, 10)}-${k + 1}` }));
    const totalStock = variants.length ? variants.reduce((a, v) => a + v.stock, 0) : stock;
    const isVeg = mod === 'food' || mod === 'grocery' ? ex.veg !== false : ex.veg === undefined ? null : ex.veg;
    const customFields = Object.fromEntries(Object.entries(ex.cf ?? {}).map(([k, v]) => [k.replace(/_/g, ' '), v]));
    const addons = C.foodAddons[id]?.map(([aid, an, ap]) => ({ id: aid, name: an, price: ap, active: true })) ?? null;
    const tags = [...new Set([...(ex.tags ?? []), mod, c.name.toLowerCase(), ...(ex.featured ? ['featured'] : []), ...(mrp > price && (mrp - price) / mrp >= 0.25 ? ['deal'] : [])])];
    const pathIds = [...c.path, catId];
    const catNames = pathIds.map((x) => catIndex.get(x).name);
    await upsert(db.doc(`products/${id}`), {
      name, slug: id, shortDescription: short, description: describe(p, mod, brandName[brandId], seller.storeName),
      moduleId: mod, categoryId: catId, categoryPath: pathIds, brandId, brandName: brandName[brandId], sellerId: seller.uid, sellerName: seller.storeName,
      images: [image], price: variants.length ? variants[0].price : price, mrp: variants.length ? variants[0].mrp : mrp,
      stock: totalStock, lowStockAt: mod === 'ecommerce' ? 3 : 5, unit, variants, tags, isVeg, customFields, addons,
      rating: ex.rating ?? 0, ratingCount: ex.rc ?? 0, soldCount: ex.sold ?? 0, viewCount: (ex.sold ?? 0) * 7, featured: !!ex.featured,
      status: 'active', barcode: ean13(id), keywords: buildKeywords(name, brandName[brandId], tags, catNames, seller.storeName, variants.map((v) => v.name)),
      deliveryMinutes: ex.mins ?? MODULE_MINUTES[mod], hsn: null,
      createdAt: ts((products.length - i) * 3_600_000 * 5),
    }, ['stock', 'variants', 'soldCount', 'rating', 'ratingCount', 'ratingSum', 'viewCount']);
  });
  bump('products', products.length);
  for (const [k, [pid, userName, rating, comment]] of reviewsSeed.entries()) {
    await upsert(db.doc(`products/${pid}/reviews/seed-review-${k + 1}`), {
      userId: `seed-review-${k + 1}`, userName, userPhoto: null, rating, comment, images: [], verified: true, createdAt: ts((k + 1) * 86_400_000 * 2),
    });
  }
  bump('reviews', reviewsSeed.length);
}

// ───────────────────────── marketing & content
async function seedMarketing() {
  await pool(C.sliders, 4, async (s, i) => {
    const image = await img.get(s.img, `catalog/sliders/${s.id}.webp`, SIZES.slider, { title: s.title, subtitle: s.subtitle, color: moduleColor[s.moduleId] });
    const { img: _i, id, ...rest } = s;
    await upsert(db.doc(`sliders/${id}`), { ...rest, image, order: i + 1, active: true });
  });
  bump('sliders', C.sliders.length);
  await pool(C.offers, 4, async (o, i) => {
    const image = await img.get(o.image, `catalog/offers/${o.id}.webp`, SIZES.offer, { title: o.title, color: moduleColor[o.moduleId] });
    await upsert(db.doc(`offers/${o.id}`), { ...o, image, order: i + 1, active: true, startAt: ts(86_400_000), endAt: ts(-90 * 86_400_000) });
  });
  bump('offers', C.offers.length);

  const byDiscount = [...products].sort((a, b) => (b[5] - b[4]) / b[5] - (a[5] - a[4]) / a[5]);
  const breakfast = await img.get('banner:breakfast', 'catalog/banners/breakfast.webp', SIZES.banner, { title: 'Deals of the day', color: '#0B8A4F' });
  const festive = await img.get('banner:festive-sweets', 'catalog/banners/festive-sweets.webp', SIZES.banner, { title: 'Festive treats', color: '#F7860F' });
  const gadgets = await img.get('banner:gadgets', 'catalog/banners/gadgets.webp', SIZES.banner, { title: 'Gadget picks', color: '#2563EB' });
  const sections = [
    { id: 'grocery-bestsellers', title: 'Bestsellers near you', subtitle: 'What Ahmedabad is ordering today', moduleId: 'grocery', type: 'bestsellers', style: 'carousel', bgColor: '' },
    { id: 'fresh-vegetables', title: 'Fresh vegetables', subtitle: 'Picked this morning', moduleId: 'grocery', type: 'category', categoryId: 'fresh-vegetables', style: 'grid', bgColor: '#F0FAF4' },
    { id: 'deals-of-the-day', title: 'Deals of the day', subtitle: 'Biggest discounts, limited stock', moduleId: '', type: 'deals', style: 'banner_left', bannerImage: breakfast, bgColor: '#FFF7ED', productIds: byDiscount.filter((p) => p[1] && catIndex.get(p[1]).moduleId !== 'food').slice(0, 12).map((p) => p[0]) },
    { id: 'food-top-rated', title: 'Top-rated dishes', subtitle: 'Loved by 4.5★+ diners', moduleId: 'food', type: 'top_rated', style: 'carousel', bgColor: '' },
    { id: 'shopping-new', title: 'New arrivals', subtitle: 'Fresh drops in electronics, fashion and home', moduleId: 'ecommerce', type: 'newest', style: 'grid', bgColor: '' },
    { id: 'festive-treats', title: 'Festive treats', subtitle: 'Sweets, dry fruits and more', moduleId: '', type: 'manual', style: 'banner_left', bannerImage: festive, bgColor: '#FFF4E6', productIds: ['gulab-jamun', 'chocolate-brownie', 'almonds', 'cashews', 'raisins', 'mango-lassi', 'butter-cookies', 'scented-candle'] },
    { id: 'gadget-picks', title: 'Gadget picks', subtitle: 'Hand-picked tech under ₹5,000', moduleId: 'ecommerce', type: 'manual', style: 'banner_left', bannerImage: gadgets, bgColor: '#EEF2FF', productIds: ['tws-earbuds', 'smartwatch', 'powerbank-20k', 'bt-speaker', 'gan-charger', 'anc-headphones'] },
    { id: 'wellness-essentials', title: 'Wellness essentials', subtitle: 'Vitamins, protein and more', moduleId: 'pharmacy', type: 'category', categoryId: 'vitamins-supplements', style: 'carousel', bgColor: '#E6F7F6' },
  ];
  for (const [i, s] of sections.entries()) {
    const { id, ...rest } = s;
    await upsert(db.doc(`featuredSections/${id}`), { productIds: [], categoryId: '', bannerImage: '', ...rest, order: i + 1, active: true });
  }
  bump('featuredSections', sections.length);

  for (const c of C.coupons) {
    const { id, ...rest } = c;
    await upsert(db.doc(`coupons/${id}`), { sellerId: null, freeDelivery: false, ...rest, usedCount: 0, active: true, startAt: ts(86_400_000), endAt: ts(-365 * 86_400_000) }, ['usedCount']);
  }
  bump('coupons', C.coupons.length);
  for (const m of C.membershipPlans) { const { id, ...rest } = m; await upsert(db.doc(`membershipPlans/${id}`), rest); }
  bump('membershipPlans', C.membershipPlans.length);

  const popupImg = await img.get('popup:welcome', 'catalog/popups/welcome.webp', SIZES.popup, { title: '₹50 off your first order', color: '#0B8A4F' });
  await upsert(db.doc('popups/welcome-offer'), {
    title: 'Get ₹50 off your first order', subtitle: 'Use code WELCOME50 on orders above ₹299', image: popupImg, link: '/offers', ctaText: 'Shop now',
    showOn: 'both', active: true, startAt: ts(86_400_000), endAt: ts(-180 * 86_400_000), frequency: 'once_per_day',
  });
  bump('popups');
  await upsert(db.doc('campaigns/weekend-biryani-fest'), {
    title: 'Weekend Biryani Fest 🍛', body: 'Flat 20% off on dum biryanis at Spice Route Kitchen. Use code BIRYANI20.', image: '', link: '/m/food',
    audience: 'customers', status: 'draft', sentAt: null,
  }, ['status', 'sentAt', 'messageId', 'inboxCount']);
  bump('campaigns');
}

async function seedContent() {
  for (const c of C.cities) { const { id, ...rest } = c; await upsert(db.doc(`cities/${id}`), rest); }
  bump('cities', C.cities.length);
  for (const l of C.languages) { const { code, ...rest } = l; await upsert(db.doc(`languages/${code}`), { code, ...rest }); }
  bump('languages', C.languages.length);
  for (const [code, strings] of Object.entries(C.translations)) await upsert(db.doc(`translations/${code}`), { code, strings });
  for (const f of C.faqs) { const { id, ...rest } = f; await upsert(db.doc(`faqs/${id}`), rest); }
  bump('faqs', C.faqs.length);
  for (const b of C.blogCategories) { const { id, ...rest } = b; await upsert(db.doc(`blogCategories/${id}`), { ...rest, active: true }); }
  bump('blogCategories', C.blogCategories.length);
  await pool(C.blogs, 3, async (b) => {
    const cover = await img.get(b.img, `catalog/blogs/${b.id}.webp`, SIZES.blog, { title: b.title, color: '#0B8A4F' });
    const { id, img: _i, daysAgo, ...rest } = b;
    await upsert(db.doc(`blogs/${id}`), {
      ...rest, cover, published: true, publishedAt: ts(daysAgo * 86_400_000), readMinutes: Math.max(2, Math.round(b.content.split(/\s+/).length / 200)),
      seo: { title: `${b.title} | Go4Market Blog`, description: b.excerpt },
    });
  });
  bump('blogs', C.blogs.length);
  for (const [slugId, p] of Object.entries(C.pages)) await upsert(db.doc(`pages/${slugId}`), { slug: slugId, ...p });
  bump('pages', Object.keys(C.pages).length);
  for (const [id, t] of Object.entries(C.emailTemplates)) await upsert(db.doc(`emailTemplates/${id}`), { id, ...t, active: true });
  bump('emailTemplates', Object.keys(C.emailTemplates).length);
  for (const r of C.adminRoles) { const { id, ...rest } = r; await upsert(db.doc(`adminRoles/${id}`), rest); }
  bump('adminRoles', C.adminRoles.length);
  for (const a of C.globalAttributes) { const { id, ...rest } = a; await upsert(db.doc(`attributes/${id}`), { ...rest, sellerId: null }); }
  await upsert(db.doc('attributes/seller-urbantrend-fit'), { name: 'Fit', values: ['Slim', 'Regular', 'Relaxed', 'Oversized'], sellerId: 'seller-urbantrend' });
  bump('attributes', C.globalAttributes.length + 1);

  // Tax classes (prices are GST-inclusive; used for invoices/reports) and countries.
  for (const [id, title, percent, description] of [['gst-0', 'GST 0%', 0, 'Fresh fruits, vegetables, milk, eggs and other exempt items'], ['gst-5', 'GST 5%', 5, 'Packaged staples, tea, edible oils, restaurant food'], ['gst-12', 'GST 12%', 12, 'Ghee, butter, dry fruits, mobile phones'], ['gst-18', 'GST 18%', 18, 'Most electronics, cosmetics, kitchen appliances and services'], ['gst-28', 'GST 28%', 28, 'Luxury goods and aerated drinks']]) {
    await upsert(db.doc(`taxes/${id}`), { title, percent, description, active: true });
  }
  bump('taxes', 5);
  for (const [code, name, dialCode, currency] of [['IN', 'India', '+91', 'INR'], ['AE', 'United Arab Emirates', '+971', 'AED'], ['US', 'United States', '+1', 'USD'], ['GB', 'United Kingdom', '+44', 'GBP']]) {
    await upsert(db.doc(`countries/${code}`), { code, name, dialCode, currency, flag: '', active: true });
  }
  bump('countries', 4);

  // Customer-generated demo records
  await upsert(db.doc('productRequests/seed-quinoa'), { userId: 'demo-customer', userName: 'Priya Shah', name: 'Organic white quinoa (500 g)', description: 'Would love an organic quinoa option in Staples.', status: 'open' }, ['status']);
  await upsert(db.doc('productRequests/seed-a2-milk'), { userId: 'demo-customer', userName: 'Priya Shah', name: 'A2 Gir cow milk', description: 'Daily subscription for A2 milk in glass bottles.', status: 'open' }, ['status']);
  bump('productRequests', 2);
  const tomorrow7 = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  await upsert(db.doc('subscriptions/seed-daily-milk'), {
    userId: 'demo-customer', productId: 'toned-milk', variantId: '1-l', qty: 1, frequency: 'daily', addressId: 'home', status: 'paused',
    nextRunAt: Timestamp.fromMillis(Date.now() + 86_400_000), productName: 'Toned Milk · 1 L', note: 'Paused demo subscription — resume to start daily deliveries.',
  }, ['status', 'nextRunAt', 'lastOrderId', 'runCount', 'lastRunAt', 'lastError']);
  void tomorrow7;
  bump('subscriptions');

  // Settings
  await upsertMissing(db.doc('settings/platform'), {
    appName: 'Go4Market', tagline: 'Everything you need, delivered fast', currency: 'INR', currencySymbol: '₹',
    contactEmail: 'support@go4market.com', contactPhone: '+91 79 4000 4000',
    address: 'Go4Market, 3rd Floor, Shivalik Shilp, Iscon Cross Road, S.G. Highway, Ahmedabad, Gujarat 380015, India',
    social: { facebook: 'https://facebook.com/go4market', instagram: 'https://instagram.com/go4market', x: 'https://x.com/go4market', youtube: 'https://youtube.com/@go4market', linkedin: 'https://linkedin.com/company/go4market' },
    deliveryFee: 30, freeDeliveryAbove: 499, quickDeliveryFee: 25, perKmFee: 6, baseKm: 3, maxDeliveryKm: 25, quick15MaxKm: 4, quick30MaxKm: 8,
    taxPct: 0, taxInclusive: true, minOrder: 99, codEnabled: true, codMax: 5000, walletEnabled: true,
    referralReward: 50, refereeReward: 50, pickupEnabled: true, scheduledEnabled: true, quick15Enabled: true, quick30Enabled: true,
    returnWindowDays: 7, deliveryPerOrderDefault: 30, autoApproveProducts: false,
    autoAssign: false, sellerRidersEnabled: true, riderPay: { type: 'per_order', amount: 30, perKm: 0, bonusPct: 0 },
    maintenanceMessage: 'We are upgrading Go4Market. Back shortly!',
    slots: [{ from: '07:00', to: '09:00' }, { from: '09:00', to: '11:00' }, { from: '11:00', to: '13:00' }, { from: '13:00', to: '15:00' }, { from: '15:00', to: '17:00' }, { from: '17:00', to: '19:00' }, { from: '19:00', to: '21:00' }],
    seo: {
      title: 'Go4Market — Groceries, Food, Medicines & Shopping Delivered Fast',
      description: 'Order groceries in 15 minutes, hot meals from local kitchens, medicines and electronics from trusted stores in Ahmedabad, Surat, Vadodara and more.',
      keywords: ['online grocery', 'food delivery', 'online pharmacy', 'quick commerce', 'Ahmedabad', 'Go4Market'],
      ogImage: '',
    },
    theme: { primary: '#0B8A4F', accent: '#F7860F', primaryDeep: '#0A4A33' },
    appVersions: { customer: { min: '1.0.0', latest: '1.0.0' }, partner: { min: '1.0.0', latest: '1.0.0' } },
    storeUrls: { customerAndroid: 'https://play.google.com/store/apps/details?id=com.go4market.customer', partnerAndroid: 'https://play.google.com/store/apps/details?id=com.go4market.partner' },
    fx: { usd: 0.012 },
    maps: { provider: 'osm', tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png' },
    sms: { enabled: false, provider: null },
    demoMode: true,
    demo: { accounts: ACCOUNTS.slice(0, 4).map((a) => ({ role: a.role, email: a.email, password: PASSWORD })) },
    maintenance: false,
  });
  await upsertMissing(db.doc('settings/payments'), {
    razorpay: { enabled: true, keyId: env.RAZORPAY_KEY_ID ?? '', currency: env.RAZORPAY_CURRENCY ?? 'INR' },
    stripe: { enabled: true, publishableKey: env.STRIPE_PUBLISHABLE_KEY ?? '', currency: (env.STRIPE_CURRENCY ?? 'usd').toUpperCase() },
    paypal: { enabled: true, clientId: env.PAYPAL_CLIENT_ID ?? '', env: env.PAYPAL_ENV ?? 'sandbox', currency: env.PAYPAL_CURRENCY ?? 'USD' },
    cod: { enabled: true, max: 5000 },
    wallet: { enabled: true },
  });
  const counter = await db.doc('counters/orders').get();
  if (!counter.exists) writer.set(counter.ref, { seq: 100000, updatedAt: FieldValue.serverTimestamp() });
}

async function recount() {
  log('recounting categories / sellers / overview');
  const ps = await db.collection('products').where('status', '==', 'active').get();
  const catCount = new Map(), sellerCount = new Map();
  for (const p of ps.docs) {
    for (const c of p.get('categoryPath') ?? []) catCount.set(c, (catCount.get(c) ?? 0) + 1);
    sellerCount.set(p.get('sellerId'), (sellerCount.get(p.get('sellerId')) ?? 0) + 1);
  }
  const cats = await db.collection('categories').get();
  for (const c of cats.docs) writer.set(c.ref, { productCount: catCount.get(c.id) ?? 0 }, { merge: true });
  const ss = await db.collection('sellers').get();
  for (const s of ss.docs) writer.set(s.ref, { productCount: sellerCount.get(s.id) ?? 0 }, { merge: true });
  const customers = (await db.collection('users').where('role', '==', 'customer').count().get()).data().count;
  const approved = ss.docs.filter((s) => s.get('status') === 'approved').length;
  const ov = await db.doc('stats/overview').get();
  const base = { orders: 0, revenue: 0, delivered: 0, pending: 0, cancelled: 0, returns: 0, byStatus: {} };
  writer.set(ov.ref, { ...(ov.exists ? {} : base), customers, sellers: approved, products: ps.size, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  counts.overview = { customers, sellers: approved, products: ps.size };
}

async function main() {
  log('seeding project go4market');
  await seedAccounts(); log('accounts done');
  await seedModulesAndCategories(); log('modules/categories/brands done');
  await seedSellersAndRiders(); log('sellers/riders done');
  await seedProducts(); log('products done');
  await seedMarketing(); log('marketing done');
  await seedContent(); log('content done');
  await writer.flush();
  // Re-assert role claims in case onUserCreated raced with the first run.
  for (const a of ACCOUNTS) await auth.setCustomUserClaims(a.uid, { role: a.role });
  if (!process.argv.includes('--no-wait')) {
    log('waiting 60 s for triggers to settle before recounting…');
    await new Promise((r) => setTimeout(r, 60_000));
    for (const a of ACCOUNTS) await auth.setCustomUserClaims(a.uid, { role: a.role });
    for (const a of ACCOUNTS) await db.doc(`users/${a.uid}`).set({ role: a.role }, { merge: true });
  }
  await recount();
  await writer.close();
  log('images:', JSON.stringify({ ...img.stats, failed: img.stats.failed.length }));
  if (img.stats.failed.length) console.log('image failures (illustration used):\n  ' + img.stats.failed.join('\n  '));
  log('counts:', JSON.stringify(counts));
}

main().catch((e) => { console.error(e); process.exit(1); });
