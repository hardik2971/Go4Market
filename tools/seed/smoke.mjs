#!/usr/bin/env node
// End-to-end smoke test against the LIVE go4market project using the Firebase *client* JS SDK
// (exactly what the apps do). The final cleanup step uses the Admin SDK only to delete throw-away orders.
// Every order created here carries notes: 'smoke-test'. One delivered COD order is kept as demo data.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, doc, getDoc, setDoc, getDocs, deleteDoc, collection, query, where, updateDoc, serverTimestamp } from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'config/web_sdk.json'), 'utf8'));
const PASSWORD = 'Go4Market@123';
const results = [];
const created = { orders: [], topups: [], reviews: [] };
let keepOrderId = null;

function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`);
}
async function expectError(name, fn, code) {
  try {
    await fn();
    record(name, false, 'expected an error but the call succeeded');
  } catch (e) {
    const got = e.code ?? e.message;
    record(name, !code || String(got).includes(code), `${got}: ${e.message?.slice(0, 120)}`);
  }
}

async function session(role, email) {
  const app = initializeApp(config, role);
  const auth = getAuth(app);
  const cred = await signInWithEmailAndPassword(auth, email, PASSWORD);
  const token = await cred.user.getIdTokenResult(true);
  const fns = getFunctions(app, 'asia-south1');
  const call = async (name, data) => (await httpsCallable(fns, name, { timeout: 120_000 })(data ?? {})).data;
  return { app, auth, db: getFirestore(app), uid: cred.user.uid, claim: token.claims.role, call };
}

async function setCart(s, lines) {
  const cart = await getDocs(collection(s.db, `users/${s.uid}/cart`));
  for (const d of cart.docs) await deleteDoc(d.ref);
  for (const l of lines) {
    await setDoc(doc(s.db, `users/${s.uid}/cart/${l.productId}_${l.variantId}`), { ...l, addedAt: serverTimestamp() });
  }
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
async function poll(fn, ok, tries = 20, every = 3000) {
  let v;
  for (let i = 0; i < tries; i++) { v = await fn(); if (ok(v)) return v; await wait(every); }
  return v;
}

async function main() {
  const customer = await session('customer', 'customer@go4market.com');
  const seller = await session('seller', 'seller@go4market.com');
  const admin = await session('admin', 'admin@go4market.com');
  const rider = await session('delivery', 'delivery@go4market.com');
  record('sign-in + role claims', customer.claim === 'customer' && seller.claim === 'seller' && admin.claim === 'admin' && rider.claim === 'delivery',
    `customer=${customer.claim} seller=${seller.claim} admin=${admin.claim} delivery=${rider.claim}`);

  // Make sure the rider is online (as the partner app would).
  await updateDoc(doc(rider.db, 'deliveryPartners/demo-delivery'), { online: true, lat: 23.0330, lng: 72.5350, locationUpdatedAt: serverTimestamp() });

  const sellerBefore = (await getDoc(doc(seller.db, 'sellers/demo-seller'))).data();
  const statsBefore = (await getDoc(doc(admin.db, 'stats/overview'))).data() ?? {};

  // ── Cart + quote
  await setCart(customer, [
    { productId: 'basmati-rice', variantId: '5-kg', qty: 1, sellerId: 'demo-seller' },
    { productId: 'toned-milk', variantId: '1-l', qty: 2, sellerId: 'demo-seller' },
    { productId: 'robusta-bananas', variantId: '6-pcs', qty: 1, sellerId: 'demo-seller' },
  ]);
  const quote = await customer.call('getCheckoutQuote', { addressId: 'home', couponCode: 'G4MSAVE20', useWallet: false, speed: 'standard', deliveryType: 'home' });
  console.log('   quote:', JSON.stringify({ subtotal: quote.subtotal, deliveryFee: quote.deliveryFee, discount: quote.discount, total: quote.total, payable: quote.payable, distanceKm: quote.distanceKm, etaMinutes: quote.etaMinutes, couponError: quote.couponError, unavailable: quote.unavailable.length }));
  record('getCheckoutQuote', quote.subtotal === 549 + 112 + 49 && quote.discount === 142 && !quote.couponError && quote.unavailable.length === 0, `subtotal ${quote.subtotal}, discount ${quote.discount}, payable ${quote.payable}`);

  const coupon = await customer.call('validateCoupon', { code: 'WELCOME50', subtotal: 150 });
  record('validateCoupon (below min order)', coupon.valid === false, coupon.message);

  // ── Place COD order
  const placed = await customer.call('placeOrder', { addressId: 'home', couponCode: 'G4MSAVE20', useWallet: false, speed: 'standard', deliveryType: 'home', paymentMethod: 'cod', channel: 'web', notes: 'smoke-test' });
  keepOrderId = placed.orderId;
  created.orders.push(placed.orderId);
  record('placeOrder COD', placed.status === 'placed' && /^G4M\d{6}$/.test(placed.orderNo), `${placed.orderNo} payable ₹${placed.payable}`);
  const cartAfter = await getDocs(collection(customer.db, `users/${customer.uid}/cart`));
  record('cart cleared after order', cartAfter.empty);
  const myOrder = (await getDoc(doc(customer.db, `orders/${placed.orderId}`))).data();
  const otp = myOrder.deliveryOtp;

  // ── Rules: client cannot write orders
  await expectError('rules: customer cannot write an order directly', () => updateDoc(doc(customer.db, `orders/${placed.orderId}`), { status: 'delivered' }), 'permission-denied');
  await expectError('rules: customer cannot change own role', () => updateDoc(doc(customer.db, `users/${customer.uid}`), { role: 'admin' }), 'permission-denied');
  await expectError('rules: customer cannot edit wallet balance', () => updateDoc(doc(customer.db, `users/${customer.uid}`), { walletBalance: 99999 }), 'permission-denied');

  // ── Seller flow
  await expectError('seller cannot skip to packed', () => seller.call('updateOrderStatus', { orderId: placed.orderId, status: 'packed' }), 'failed-precondition');
  await seller.call('updateOrderStatus', { orderId: placed.orderId, status: 'confirmed', note: 'Confirmed by store' });
  await seller.call('updateOrderStatus', { orderId: placed.orderId, status: 'packed' });
  record('seller confirm + pack', (await getDoc(doc(seller.db, `orders/${placed.orderId}`))).get('status') === 'packed');

  // ── Delivery pool visibility (rules allow riders to list unassigned packed home orders)
  const pool = await getDocs(query(collection(rider.db, 'orders'), where('deliveryPartnerId', '==', null), where('deliveryType', '==', 'home'), where('status', 'in', ['confirmed', 'packed'])));
  record('rider can list delivery pool', pool.docs.some((d) => d.id === placed.orderId), `${pool.size} order(s) in pool`);

  // ── Admin auto-assign (nearest online partner)
  const asg = await admin.call('assignDeliveryPartner', { orderId: placed.orderId, partnerId: null });
  record('admin assignDeliveryPartner (auto)', asg.partnerId === 'demo-delivery', JSON.stringify(asg));

  // ── Delivery flow
  await rider.call('updateOrderStatus', { orderId: placed.orderId, status: 'picked_up' });
  await rider.call('updateOrderStatus', { orderId: placed.orderId, status: 'out_for_delivery' });
  await updateDoc(doc(rider.db, 'deliveryPartners/demo-delivery'), { lat: 23.0361, lng: 72.5322, heading: 90, locationUpdatedAt: serverTimestamp() });
  const loc = await poll(async () => (await getDoc(doc(customer.db, `orders/${placed.orderId}`))).get('riderLocation'), (l) => l && l.lat === 23.0361, 15, 2000);
  record('orders.riderLocation mirrored for customer', loc?.lat === 23.0361 && !!loc?.updatedAt, JSON.stringify({ lat: loc?.lat, lng: loc?.lng, heading: loc?.heading }));
  await expectError('delivered with wrong OTP is rejected', () => rider.call('updateOrderStatus', { orderId: placed.orderId, status: 'delivered', otp: otp === '0000' ? '1111' : '0000' }), 'permission-denied');
  const del = await rider.call('updateOrderStatus', { orderId: placed.orderId, status: 'delivered', otp, cashCollected: placed.payable });
  const finalOrder = (await getDoc(doc(customer.db, `orders/${placed.orderId}`))).data();
  record('delivery picked_up → out_for_delivery → delivered (OTP)', del.ok && finalOrder.status === 'delivered' && finalOrder.paymentStatus === 'paid',
    `timeline: ${finalOrder.timeline.map((t) => t.status).join(' → ')}`);

  const sellerAfter = (await getDoc(doc(seller.db, 'sellers/demo-seller'))).data();
  const expectedNet = finalOrder.settlement?.sellers?.['demo-seller']?.net;
  record('seller balance credited (minus commission)', Math.abs((sellerAfter.balance - sellerBefore.balance) - expectedNet) < 0.01,
    `balance ${sellerBefore.balance} → ${sellerAfter.balance} (net ${expectedNet}, commission ${finalOrder.settlement?.sellers?.['demo-seller']?.commission})`);
  const riderDoc = (await getDoc(doc(rider.db, 'deliveryPartners/demo-delivery'))).data();
  record('rider earnings + cash in hand', riderDoc.cashInHand >= placed.payable, `balance ₹${riderDoc.balance}, cashInHand ₹${riderDoc.cashInHand}, completed ${riderDoc.completedCount}`);
  const cash = await getDocs(query(collection(rider.db, 'cashCollections'), where('deliveryPartnerId', '==', 'demo-delivery'), where('orderId', '==', placed.orderId)));
  record('cash collection record', cash.size === 1, `₹${cash.docs[0]?.get('amount')}`);

  const statsAfter = await poll(async () => (await getDoc(doc(admin.db, 'stats/overview'))).data() ?? {}, (s) => (s.delivered ?? 0) > (statsBefore.delivered ?? 0));
  record('stats/overview updated by trigger', (statsAfter.delivered ?? 0) === (statsBefore.delivered ?? 0) + 1 && (statsAfter.orders ?? 0) === (statsBefore.orders ?? 0) + 1,
    `orders ${statsBefore.orders ?? 0}→${statsAfter.orders}, delivered ${statsBefore.delivered ?? 0}→${statsAfter.delivered}, revenue ${statsBefore.revenue ?? 0}→${statsAfter.revenue}`);
  const day = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()).replace(/-/g, '');
  const daily = (await getDoc(doc(admin.db, `stats/daily_${day}`))).data() ?? {};
  record(`stats/daily_${day} updated`, (daily.orders ?? 0) >= 1, JSON.stringify({ orders: daily.orders, revenue: daily.revenue, delivered: daily.delivered, byChannel: daily.byChannel, byModule: daily.byModule }));
  const inbox = await poll(async () => getDocs(query(collection(customer.db, `users/${customer.uid}/notifications`), where('data.orderId', '==', placed.orderId))), (s) => s.size >= 5, 10);
  record('customer inbox notifications written', inbox.size >= 5, `${inbox.size} notifications for this order`);

  // ── Review after delivery
  await customer.call('submitReview', { productId: 'robusta-bananas', rating: 5, comment: 'Perfectly ripe and delivered quickly.' });
  created.reviews.push('products/robusta-bananas/reviews/' + customer.uid);
  record('submitReview (verified buyer)', true);
  await expectError('submitReview without purchase is rejected', () => customer.call('submitReview', { productId: 'laptop-14', rating: 5, comment: 'x' }), 'permission-denied');

  // ── Return → refund to wallet (partial return of the kept order)
  const walletBefore = (await getDoc(doc(customer.db, `users/${customer.uid}`))).get('walletBalance');
  const ret = await customer.call('requestReturn', { orderId: placed.orderId, reason: 'smoke-test: bananas were overripe', items: [{ productId: 'robusta-bananas', variantId: '6-pcs', qty: 1, name: 'Robusta Bananas', price: 49 }], images: [], refundTo: 'wallet' });
  created.returns = [ret.returnId];
  await seller.call('processReturn', { returnId: ret.returnId, status: 'approved', refundAmount: 40, refundTo: 'wallet' });
  const done = await admin.call('processReturn', { returnId: ret.returnId, status: 'refunded', refundTo: 'wallet', note: 'smoke-test' });
  const walletAfter = (await getDoc(doc(customer.db, `users/${customer.uid}`))).get('walletBalance');
  record('requestReturn → seller approve (lowered amount) → admin refund to wallet', done.ok && Math.abs(walletAfter - walletBefore - done.refundAmount) < 0.01 && done.refundAmount <= ret.refundAmount,
    `computed ₹${ret.refundAmount}, seller set ₹40, refunded ₹${done.refundAmount} → wallet ${walletBefore} → ${walletAfter}`);
  const sellerReturns = await getDocs(query(collection(seller.db, 'returns'), where('sellerIds', 'array-contains', 'demo-seller')));
  record('rules: seller reads own returns', sellerReturns.docs.some((d) => d.id === ret.returnId), `${sellerReturns.size} return(s)`);

  // ── Seller-owned rider + fleet visibility
  const riderEmail = `smoke.rider.${Date.now()}@go4market.com`;
  const newRider = await seller.call('createSellerRider', { name: 'Smoke Rider', email: riderEmail, password: 'Go4Market@123', phone: '+919800000000', vehicleType: 'ev', vehicleNo: 'GJ01ZZ0001' });
  created.authUsers = [newRider.uid];
  const fleet = await getDocs(query(collection(seller.db, 'deliveryPartners'), where('sellerId', '==', 'demo-seller')));
  record('createSellerRider + seller reads own fleet', fleet.docs.some((d) => d.id === newRider.uid && d.get('status') === 'approved' && d.get('ownerType') === 'seller'), `fleet size ${fleet.size}`);
  await expectError('rules: seller cannot read an admin-owned rider', () => getDoc(doc(seller.db, 'deliveryPartners/demo-delivery')), 'permission-denied');
  const myTx = await getDocs(query(collection(seller.db, 'walletTransactions'), where('userId', '==', 'demo-seller')));
  record('rules: seller can list own walletTransactions', true, `${myTx.size} txn(s)`);

  // ── Seller stock-only update keeps status active
  await updateDoc(doc(seller.db, 'products/onions'), { stock: 210, updatedAt: serverTimestamp() });
  const onions = (await getDoc(doc(seller.db, 'products/onions'))).data();
  record('rules: seller stock-only update allowed, stays active', onions.status === 'active', `stock ${onions.stock}`);
  await expectError('rules: seller cannot mark a product featured', () => updateDoc(doc(seller.db, 'products/onions'), { featured: true }), 'permission-denied');

  // ── Admin mail queue → SMTP
  const mailTo = process.env.SMOKE_MAIL_TO;
  if (mailTo) {
    const { addDoc } = await import('firebase/firestore');
    const m = await addDoc(collection(admin.db, 'mail'), { to: mailTo, message: { subject: 'Go4Market smoke test', html: '<p>The admin mail queue works.</p>', text: 'The admin mail queue works.' }, source: 'smoke-test', createdAt: serverTimestamp() });
    created.mail = [m.id];
    const st = await poll(async () => (await getDoc(m)).get('delivery.state'), (v) => v === 'SUCCESS' || v === 'ERROR', 20, 3000);
    const md = (await getDoc(m)).data();
    record('mail/{id} sent via SMTP (onMailCreated)', st === 'SUCCESS', `state=${st}${md.delivery?.error ? ' error=' + md.delivery.error : ''}`);
  } else record('mail/{id} sent via SMTP (onMailCreated)', false, 'skipped: SMOKE_MAIL_TO not set');
  await expectError('rules: customer cannot read settings/communication', () => getDoc(doc(customer.db, 'settings/communication')), 'permission-denied');
  const taxes = await getDocs(collection(customer.db, 'taxes'));
  record('rules: taxes publicly readable', taxes.size >= 5, `${taxes.size} tax classes`);

  // ── Rules: another user's order is unreadable
  await setCart(admin, [{ productId: 'groundnut-oil', variantId: '1-l', qty: 1, sellerId: 'demo-seller' }]);
  await admin.call('getCheckoutQuote', { deliveryType: 'pickup' });
  const other = await admin.call('placeOrder', { deliveryType: 'pickup', speed: 'standard', paymentMethod: 'cod', channel: 'web', notes: 'smoke-test' });
  created.orders.push(other.orderId);
  await expectError("rules: customer cannot read another user's order", () => getDoc(doc(customer.db, `orders/${other.orderId}`)), 'permission-denied');
  await expectError('rules: customer cannot list all orders', () => getDocs(collection(customer.db, 'orders')), 'permission-denied');
  await expectError("customer cannot cancel another user's order", () => customer.call('updateOrderStatus', { orderId: other.orderId, status: 'cancelled' }), 'permission-denied');
  await admin.call('updateOrderStatus', { orderId: other.orderId, status: 'cancelled', note: 'smoke-test cleanup' });

  // ── Online payment hand-offs (created, not completed)
  for (const provider of ['razorpay', 'stripe', 'paypal']) {
    await setCart(customer, [{ productId: 'assam-tea', variantId: '250-g', qty: 1, sellerId: 'demo-seller' }, { productId: 'almonds', variantId: '250-g', qty: 1, sellerId: 'demo-seller' }]);
    try {
      const r = await customer.call('placeOrder', { addressId: 'home', useWallet: false, speed: 'standard', deliveryType: 'home', paymentMethod: provider, channel: 'app', notes: 'smoke-test' });
      created.orders.push(r.orderId);
      const p = r.payment ?? {};
      const ok = provider === 'razorpay' ? /^order_/.test(p.razorpayOrderId) && !!p.keyId && p.amount > 0
        : provider === 'stripe' ? /^cs_test_/.test(p.sessionId) && /^https:\/\/checkout\.stripe\.com\//.test(p.checkoutUrl)
          : !!p.paypalOrderId && /paypal\.com/.test(p.approveUrl ?? '');
      record(`placeOrder ${provider} → payment created`, ok && r.status === 'pending',
        provider === 'razorpay' ? `razorpayOrderId ${p.razorpayOrderId}, ${p.amount} ${p.currency} paise`
          : provider === 'stripe' ? `sessionId ${p.sessionId?.slice(0, 24)}…, ${p.amount} ${p.currency} cents`
            : `paypalOrderId ${p.paypalOrderId}, ${p.amount} ${p.currency}`);
      if (provider === 'razorpay') {
        const bad = await customer.call('confirmPayment', { orderId: r.orderId, provider, razorpayOrderId: p.razorpayOrderId, razorpayPaymentId: 'pay_fake123', razorpaySignature: 'deadbeef' });
        record('confirmPayment rejects a forged Razorpay signature', bad.ok === false, JSON.stringify(bad));
      }
      if (provider === 'stripe') {
        const un = await customer.call('confirmPayment', { orderId: r.orderId, provider, sessionId: p.sessionId });
        record('confirmPayment on unpaid Stripe session reports not paid', un.ok === false, JSON.stringify(un));
      }
      await customer.call('updateOrderStatus', { orderId: r.orderId, status: 'cancelled', note: 'smoke-test: payment not completed' });
    } catch (e) {
      record(`placeOrder ${provider} → payment created`, false, `${e.code}: ${e.message}`);
    }
  }
  const top = await customer.call('walletTopup', { amount: 100, provider: 'razorpay' });
  created.topups.push(top.topupId);
  record('walletTopup razorpay', /^order_/.test(top.payment?.razorpayOrderId ?? ''), `topupId ${top.topupId}`);

  // ── Discovery & tooling APIs
  const s = await customer.call('searchProducts', { query: 'milk, bread and 2 eggs', multi: true });
  record('searchProducts (multi / voice)', s.groups.length === 3 && s.groups.every((g) => g.products.length > 0), s.groups.map((g) => `${g.term}: ${g.products[0]?.name}`).join(' | '));
  const rec = await customer.call('getRecommendations', { productId: 'tomatoes', type: 'replacement' });
  record('getRecommendations (replacement)', rec.products.length > 0, rec.products.slice(0, 3).map((p) => p.name).join(', '));
  const near = await customer.call('getNearbyStores', { lat: 23.0395, lng: 72.53 });
  record('getNearbyStores', near.stores.length >= 3, near.stores.map((x) => `${x.storeName} ${x.distanceKm} km`).join(', '));
  const gen = await seller.call('generateDescription', { name: 'Cold Pressed Coconut Oil', category: 'Oils & Ghee', keywords: ['cold pressed', 'kerala', 'virgin'] });
  record('generateDescription', gen.short.length > 10 && gen.long.length > 100, `source=${gen.source}`);
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
  const rep = await admin.call('salesReport', { from: today, to: today });
  record('salesReport', rep.totals.orders >= 1, JSON.stringify(rep.totals));
  const sys = await admin.call('getSystemStatus', {});
  record('getSystemStatus', sys.integrations.razorpay && sys.integrations.stripe && sys.integrations.paypal, JSON.stringify(sys.integrations));
  await expectError('customer cannot call admin-only salesReport', () => customer.call('salesReport', { from: today, to: today }), 'permission-denied');

  // ── Sitemap
  const sm = await fetch('https://asia-south1-go4market.cloudfunctions.net/sitemap');
  const xml = await sm.text();
  record('sitemap HTTP', sm.status === 200 && xml.includes('<urlset') && xml.includes('/p/'), `${(xml.match(/<url>/g) ?? []).length} URLs`);

  await cleanup();
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed. Kept delivered demo order: ${keepOrderId}`);
  process.exit(failed.length ? 1 : 0);
}

/** Deletes throw-away smoke orders/top-ups/reviews with the Admin SDK (the delivered COD order is kept, labelled notes: 'smoke-test'). */
async function cleanup() {
  const { initializeApp: initAdmin, cert } = await import('firebase-admin/app');
  const { getFirestore: adminDb } = await import('firebase-admin/firestore');
  const sa = JSON.parse(fs.readFileSync(path.join(root, 'secret/go4market-firebase-adminsdk.json'), 'utf8'));
  const cleanupApp = initAdmin({ credential: cert(sa) }, 'cleanup');
  const db = adminDb(cleanupApp);
  let n = 0;
  for (const id of created.orders) if (id !== keepOrderId) { await db.doc(`orders/${id}`).delete(); n++; }
  for (const id of created.topups) { await db.doc(`walletTopups/${id}`).delete(); n++; }
  for (const p of created.reviews) { await db.doc(p).delete(); n++; }
  for (const id of created.mail ?? []) { await db.doc(`mail/${id}`).delete(); n++; }
  for (const uid of created.authUsers ?? []) {
    const { getAuth: adminAuth } = await import('firebase-admin/auth');
    await adminAuth(cleanupApp).deleteUser(uid).catch(() => {});
    await db.doc(`deliveryPartners/${uid}`).delete(); await db.doc(`users/${uid}`).delete(); n += 3;
  }
  console.log(`cleanup: deleted ${n} throw-away docs (cancelled smoke orders, top-ups, review)`);
}

main().catch(async (e) => {
  console.error('SMOKE ABORTED:', e.code ?? '', e.message, e.details ? JSON.stringify(e.details) : '');
  try { await cleanup(); } catch (c) { console.error('cleanup failed', c.message); }
  process.exit(1);
});
