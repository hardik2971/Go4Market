import { onCall } from 'firebase-functions/v2/https';
import { auth, db, FieldValue, now } from '../lib/admin.js';
import { notifyAdmins, notifyUser } from '../lib/notify.js';
import { fail, num, oneOf, platformSettings, requireAuth, requireRole, round2, str, type Json } from '../lib/util.js';

const VEHICLES = ['bike', 'scooter', 'bicycle', 'ev', 'car', 'van'] as const;

/** Default pay for new riders from settings/platform.riderPay {type, amount} (falls back to ₹30 per order). */
function defaultSalary(settings: Json): Json {
  const rp = settings.riderPay ?? {};
  return { type: rp.type === 'monthly' ? 'monthly' : 'per_order', amount: round2(Number(rp.amount ?? settings.deliveryPerOrderDefault ?? 30)) };
}

/** registerDeliveryPartner — signed-in: {name, phone, vehicleType, vehicleNo, cities[], sellerId?, photoUrl?} → {ok, status}. */
export const registerDeliveryPartner = onCall(async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  if (c.role === 'admin' || c.role === 'seller') fail('failed-precondition', 'This account already has a business role. Use a separate account for deliveries.');
  const ref = db.doc(`deliveryPartners/${c.uid}`);
  const existing = await ref.get();
  if (existing.exists && ['approved', 'pending'].includes(existing.get('status'))) fail('already-exists', `Your partner account is already ${existing.get('status')}.`);
  const cities = Array.isArray(d.cities) ? d.cities.filter((x: unknown) => typeof x === 'string' && x.trim()).map((x: string) => x.trim()).slice(0, 10) : [];
  if (!cities.length && typeof d.city === 'string' && d.city.trim()) cities.push(d.city.trim());
  const settings = await platformSettings();
  const sellerId = str(d.sellerId, 'sellerId', { required: false, max: 128 }) || null;
  if (sellerId) {
    if (settings.sellerRidersEnabled === false) fail('failed-precondition', 'Store-owned delivery partners are disabled.');
    const s = await db.doc(`sellers/${sellerId}`).get();
    if (!s.exists || s.get('status') !== 'approved') fail('not-found', 'Store not found.');
  }
  await ref.set({
    name: str(d.name, 'name', { max: 80 }),
    email: c.email ?? str(d.email, 'email', { required: false, max: 120 }),
    phone: str(d.phone, 'phone', { max: 20 }),
    photoUrl: str(d.photoUrl, 'photoUrl', { required: false, max: 1000 }),
    vehicleType: oneOf(d.vehicleType, 'vehicleType', VEHICLES, 'bike'),
    vehicleNo: str(d.vehicleNo, 'vehicleNo', { required: false, max: 20 }).toUpperCase(),
    licenseNo: str(d.licenseNo, 'licenseNo', { required: false, max: 30 }),
    cities, ownerType: sellerId ? 'seller' : 'admin', sellerId,
    status: 'pending', online: false, lat: null, lng: null, cashInHand: 0, balance: 0, rating: 0, completedCount: 0,
    salary: defaultSalary(settings), activeOrders: [],
    createdAt: existing.exists ? existing.get('createdAt') : now(), updatedAt: now(),
  }, { merge: true });
  const u = await auth.getUser(c.uid);
  await auth.setCustomUserClaims(c.uid, { ...(u.customClaims ?? {}), role: 'delivery' });
  await db.doc(`users/${c.uid}`).set({ role: 'delivery', updatedAt: now() }, { merge: true });
  const note = { title: 'New delivery partner', body: `${d.name} applied to deliver in ${cities.join(', ')}.`, type: 'system', data: { link: `/delivery/${c.uid}` } };
  if (sellerId) await notifyUser(sellerId, note);
  await notifyAdmins(note);
  return { ok: true, status: 'pending', refreshToken: true };
});

/** reviewDeliveryPartner — admin (or the owning seller): {uid, status, salary?{type,amount}, cities?} → {ok}. */
export const reviewDeliveryPartner = onCall(async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const d = req.data ?? {};
  const uid = str(d.uid, 'uid', { max: 128 });
  const status = oneOf(d.status, 'status', ['approved', 'suspended', 'pending', 'rejected'] as const);
  const ref = db.doc(`deliveryPartners/${uid}`);
  const p = await ref.get();
  if (!p.exists) fail('not-found', 'Delivery partner not found.');
  if (c.role === 'seller' && p.get('sellerId') !== c.uid) fail('permission-denied', 'This rider is not part of your fleet.');
  const update: Json = { status, reviewedAt: now(), reviewNote: str(d.note, 'note', { required: false, max: 300 }) || null, updatedAt: now() };
  if (status !== 'approved') update.online = false;
  if (d.salary && typeof d.salary === 'object') {
    update.salary = { type: oneOf(d.salary.type, 'salary.type', ['per_order', 'monthly'] as const), amount: round2(num(d.salary.amount, 'salary.amount', { min: 0, max: 1_000_000 })) };
  }
  if (Array.isArray(d.cities)) update.cities = d.cities.filter((x: unknown) => typeof x === 'string').slice(0, 10);
  await ref.update(update);
  await notifyUser(uid, {
    title: `Partner account ${status}`,
    body: status === 'approved' ? 'You can now go online and start accepting deliveries.' : update.reviewNote || 'Please contact support for details.',
    type: 'system',
  });
  return { ok: true, status };
});

/** settleCash — admin (or owning seller): {partnerId, amount, note?} → {ok, cashInHand, settled}. Marks oldest collections settled. */
export const settleCash = onCall(async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const partnerId = str(req.data?.partnerId, 'partnerId', { max: 128 });
  const amount = round2(num(req.data?.amount, 'amount', { min: 0.01, max: 10_000_000 }));
  const open = await db.collection('cashCollections').where('deliveryPartnerId', '==', partnerId).where('status', '==', 'collected').orderBy('createdAt').limit(200).get();
  const res = await db.runTransaction(async (tx) => {
    const p = await tx.get(db.doc(`deliveryPartners/${partnerId}`));
    if (!p.exists) fail('not-found', 'Delivery partner not found.');
    if (c.role === 'seller' && p.get('sellerId') !== c.uid) fail('permission-denied', 'This rider is not part of your fleet.');
    const cash = round2(Number(p.get('cashInHand') ?? 0));
    if (amount > cash) fail('failed-precondition', `Rider holds only ₹${cash}.`);
    let left = amount;
    let settled = 0;
    for (const doc of open.docs) {
      const a = Number(doc.get('amount'));
      if (a > left + 0.001) break;
      left = round2(left - a);
      settled++;
      tx.update(doc.ref, { status: 'settled', settledAt: now(), settledBy: c.uid, updatedAt: now() });
    }
    tx.update(p.ref, { cashInHand: round2(cash - amount), cashSettledTotal: FieldValue.increment(amount), updatedAt: now() });
    tx.set(db.collection('cashSettlements').doc(), { deliveryPartnerId: partnerId, amount, by: c.uid, note: str(req.data?.note, 'note', { required: false, max: 300 }) || null, createdAt: now() });
    return { cashInHand: round2(cash - amount), settled };
  });
  await notifyUser(partnerId, { title: 'Cash settled', body: `₹${amount} cash deposit recorded. Cash in hand: ₹${res.cashInHand}.`, type: 'payout' });
  return { ok: true, ...res };
});

/**
 * createSellerRider — seller (approved): {name, email, password, phone, vehicleType?, vehicleNo?, cities?[]} → {uid}.
 * Creates an Auth user with claim `delivery` and an approved deliveryPartners doc owned by the calling store
 * (ownerType 'seller', sellerId = caller). Requires settings/platform.sellerRidersEnabled !== false.
 */
export const createSellerRider = onCall(async (req) => {
  const c = requireRole(req, 'seller');
  const d = req.data ?? {};
  const settings = await platformSettings();
  if (settings.sellerRidersEnabled === false) fail('failed-precondition', 'Store-owned delivery partners are disabled by the admin.');
  const seller = await db.doc(`sellers/${c.uid}`).get();
  if (!seller.exists || seller.get('status') !== 'approved') fail('failed-precondition', 'Your store must be approved first.');
  const name = str(d.name, 'name', { max: 80 });
  const email = str(d.email, 'email', { max: 120 }).toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) fail('invalid-argument', 'Enter a valid email address.');
  const password = str(d.password, 'password', { max: 128 });
  if (password.length < 8) fail('invalid-argument', 'Password must be at least 8 characters.');
  const phone = str(d.phone, 'phone', { max: 20 });
  const cities = Array.isArray(d.cities) && d.cities.length
    ? d.cities.filter((x: unknown) => typeof x === 'string' && x.trim()).map((x: string) => x.trim()).slice(0, 10)
    : [seller.get('city')].filter(Boolean);
  let user;
  try {
    user = await auth.createUser({ email, password, displayName: name, emailVerified: false });
  } catch (e: any) {
    if (e?.code === 'auth/email-already-exists') fail('already-exists', 'An account with this email already exists.');
    if (e?.code === 'auth/invalid-password') fail('invalid-argument', 'Password is too weak.');
    throw e;
  }
  await auth.setCustomUserClaims(user.uid, { role: 'delivery' });
  await db.doc(`users/${user.uid}`).set({
    name, email, phone, role: 'delivery', status: 'active', walletBalance: 0, fcmTokens: [], recentlyViewed: [], createdAt: now(), updatedAt: now(),
  }, { merge: true });
  await db.doc(`deliveryPartners/${user.uid}`).set({
    name, email, phone, photoUrl: '', vehicleType: oneOf(d.vehicleType, 'vehicleType', VEHICLES, 'bike'),
    vehicleNo: str(d.vehicleNo, 'vehicleNo', { required: false, max: 20 }).toUpperCase(), cities,
    ownerType: 'seller', sellerId: c.uid, status: 'approved', online: false, lat: null, lng: null,
    cashInHand: 0, balance: 0, rating: 0, completedCount: 0, salary: defaultSalary(settings), activeOrders: [],
    createdBy: c.uid, createdAt: now(), updatedAt: now(),
  });
  await notifyUser(c.uid, { title: 'Rider added', body: `${name} can now sign in to the partner app with ${email}.`, type: 'system' });
  return { uid: user.uid };
});
