import { onCall } from 'firebase-functions/v2/https';
import { auth, db, FieldValue, now } from '../lib/admin.js';
import { notifyAdmins, notifyUser, sendTemplateEmail } from '../lib/notify.js';
import { MAIL_PASSWORD } from '../lib/config.js';
import { queueSms } from '../lib/sms.js';
import { fail, num, oneOf, requireAuth, requireRole, round2, slugify, str, isNum, type Json } from '../lib/util.js';

async function setRoleClaim(uid: string, role: string) {
  const u = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, { ...(u.customClaims ?? {}), role });
  await db.doc(`users/${uid}`).set({ role, updatedAt: now() }, { merge: true });
}

/** registerSeller — signed-in: {storeName, ownerName, phone, city, address, gstin?, description?, lat?, lng?, email?, bank?, policiesAccepted} → {ok, status}. */
export const registerSeller = onCall(async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  if (c.role === 'admin') fail('failed-precondition', 'Admins cannot register as sellers.');
  if (c.role === 'delivery') fail('failed-precondition', 'This account is a delivery partner. Use another account for selling.');
  const storeName = str(d.storeName, 'storeName', { max: 80 });
  if (d.policiesAccepted !== true) fail('failed-precondition', 'Please accept the seller policies to continue.');
  const ref = db.doc(`sellers/${c.uid}`);
  const existing = await ref.get();
  if (existing.exists && ['approved', 'pending'].includes(existing.get('status'))) fail('already-exists', `Your seller account is already ${existing.get('status')}.`);
  let slug = slugify(storeName) || c.uid.slice(0, 8);
  const clash = await db.collection('sellers').where('slug', '==', slug).limit(1).get();
  if (!clash.empty && clash.docs[0].id !== c.uid) slug = `${slug}-${c.uid.slice(0, 4).toLowerCase()}`;
  const bank = d.bank && typeof d.bank === 'object'
    ? { holder: str(d.bank.holder, 'bank.holder', { required: false, max: 100 }), account: str(d.bank.account, 'bank.account', { required: false, max: 30 }), ifsc: str(d.bank.ifsc, 'bank.ifsc', { required: false, max: 15 }).toUpperCase(), upi: str(d.bank.upi, 'bank.upi', { required: false, max: 80 }) }
    : null;
  await ref.set({
    storeName, slug,
    ownerName: str(d.ownerName, 'ownerName', { max: 80 }),
    email: str(d.email, 'email', { required: false, max: 120 }) || c.email || '',
    phone: str(d.phone, 'phone', { max: 20 }),
    city: str(d.city, 'city', { max: 60 }),
    address: str(d.address, 'address', { max: 300 }),
    gstin: str(d.gstin, 'gstin', { required: false, max: 15 }).toUpperCase() || null,
    description: str(d.description, 'description', { required: false, max: 1000 }),
    logo: str(d.logo, 'logo', { required: false, max: 1000 }), banner: str(d.banner, 'banner', { required: false, max: 1000 }),
    lat: isNum(d.lat) ? d.lat : null, lng: isNum(d.lng) ? d.lng : null,
    modules: (Array.isArray(d.modules) ? d.modules : Array.isArray(d.moduleIds) ? d.moduleIds : []).filter((m: unknown) => typeof m === 'string').slice(0, 4),
    pincode: str(d.pincode, 'pincode', { required: false, max: 10 }),
    bank, policiesAccepted: true, policiesAcceptedAt: now(),
    status: 'pending', commissionPct: 10, rating: 0, ratingCount: 0, balance: 0, totalSales: 0, productCount: 0,
    createdAt: existing.exists ? existing.get('createdAt') : now(), updatedAt: now(),
  }, { merge: true });
  await setRoleClaim(c.uid, 'seller');
  await notifyAdmins({ title: 'New seller application', body: `${storeName} is waiting for approval.`, type: 'system', data: { link: `/sellers/${c.uid}` } });
  return { ok: true, status: 'pending', refreshToken: true };
});

/** reviewSeller — admin: {uid, status: approved|rejected|suspended|pending, commissionPct?, note?} → {ok}. */
export const reviewSeller = onCall(async (req) => {
  requireRole(req, 'admin');
  const d = req.data ?? {};
  const uid = str(d.uid, 'uid', { max: 128 });
  const status = oneOf(d.status, 'status', ['approved', 'rejected', 'suspended', 'pending'] as const);
  const update: Json = { status, reviewNote: str(d.note, 'note', { required: false, max: 300 }) || null, reviewedAt: now(), updatedAt: now() };
  if (d.commissionPct !== undefined && d.commissionPct !== null) update.commissionPct = num(d.commissionPct, 'commissionPct', { min: 0, max: 60 });
  const before = await db.runTransaction(async (tx) => {
    const s = await tx.get(db.doc(`sellers/${uid}`));
    if (!s.exists) fail('not-found', 'Seller not found.');
    tx.update(s.ref, update);
    const prev = s.get('status');
    if (prev !== 'approved' && status === 'approved') tx.set(db.doc('stats/overview'), { sellers: FieldValue.increment(1) }, { merge: true });
    if (prev === 'approved' && status !== 'approved') tx.set(db.doc('stats/overview'), { sellers: FieldValue.increment(-1) }, { merge: true });
    return prev;
  });
  if (status === 'approved' || status === 'pending') await setRoleClaim(uid, 'seller');
  // Hide products of suspended/rejected stores.
  if (before === 'approved' && status !== 'approved') {
    const ps = await db.collection('products').where('sellerId', '==', uid).where('status', '==', 'active').get();
    for (let i = 0; i < ps.docs.length; i += 400) {
      const b = db.batch();
      ps.docs.slice(i, i + 400).forEach((p) => b.update(p.ref, { status: 'draft', hiddenBySuspension: true, updatedAt: now() }));
      await b.commit();
    }
  }
  if (status === 'approved' && before !== 'approved') {
    const ps = await db.collection('products').where('sellerId', '==', uid).where('hiddenBySuspension', '==', true).get();
    const b = db.batch();
    ps.docs.slice(0, 450).forEach((p) => b.update(p.ref, { status: 'active', hiddenBySuspension: FieldValue.delete(), updatedAt: now() }));
    if (!ps.empty) await b.commit();
  }
  const msg: Record<string, string> = {
    approved: 'Congratulations! Your store is live on Go4Market.', rejected: 'Your seller application was not approved.',
    suspended: 'Your store has been suspended. Please contact support.', pending: 'Your store is under review again.',
  };
  await notifyUser(uid, { title: `Seller account ${status}`, body: update.reviewNote || msg[status], type: 'system' });
  return { ok: true, status };
});

/** Accepts withdrawal details as a string or a small flat object (bank/UPI fields). */
function cleanDetails(v: unknown): Json | string | null {
  if (typeof v === 'string') return str(v, 'details', { required: false, max: 300 }) || null;
  if (v && typeof v === 'object' && !Array.isArray(v)) {
    const out: Json = {};
    for (const [k, x] of Object.entries(v as Json).slice(0, 12)) if (/^[A-Za-z0-9_.-]{1,40}$/.test(k) && ['string', 'number', 'boolean'].includes(typeof x)) out[k] = typeof x === 'string' ? x.slice(0, 200) : x;
    return out;
  }
  return null;
}

/** requestWithdrawal — seller/delivery: {amount, method, note?, details?} → {ok, id, balance}. Holds the amount from the balance. */
export const requestWithdrawal = onCall(async (req) => {
  const c = requireRole(req, 'seller', 'delivery');
  const d = req.data ?? {};
  const amount = round2(num(d.amount, 'amount', { min: 100, max: 10_000_000 }));
  const method = oneOf(d.method, 'method', ['bank', 'upi', 'cash'] as const, 'bank');
  const coll = c.role === 'seller' ? 'sellers' : 'deliveryPartners';
  const ref = db.collection('withdrawals').doc();
  const balance = await db.runTransaction(async (tx) => {
    const s = await tx.get(db.doc(`${coll}/${c.uid}`));
    if (!s.exists) fail('not-found', 'Profile not found.');
    if (!['approved'].includes(s.get('status'))) fail('failed-precondition', 'Your account must be approved first.');
    const bal = Number(s.get('balance') ?? 0);
    if (amount > bal) fail('failed-precondition', `You can withdraw up to ₹${bal}.`);
    tx.update(s.ref, { balance: round2(bal - amount), pendingWithdrawal: FieldValue.increment(amount), updatedAt: now() });
    tx.set(ref, {
      userId: c.uid, role: c.role, amount, method, status: 'pending',
      name: s.get('storeName') ?? s.get('name') ?? '', bank: s.get('bank') ?? null,
      details: cleanDetails(d.details),
      note: str(d.note, 'note', { required: false, max: 300 }) || null, createdAt: now(), updatedAt: now(),
    });
    return round2(bal - amount);
  });
  await notifyAdmins({ title: 'Withdrawal request', body: `₹${amount} requested by a ${c.role}.`, type: 'payout', data: { link: `/withdrawals/${ref.id}` } });
  return { ok: true, id: ref.id, balance };
});

/** processWithdrawal — admin: {id, status: approved|rejected|paid, note?, txnRef?} → {ok}. Rejected returns the amount to the balance. */
export const processWithdrawal = onCall({ secrets: [MAIL_PASSWORD] }, async (req) => {
  const c = requireRole(req, 'admin');
  const d = req.data ?? {};
  const id = str(d.id, 'id', { max: 128 });
  const status = oneOf(d.status, 'status', ['approved', 'rejected', 'paid'] as const);
  const note = str(d.note, 'note', { required: false, max: 300 }) || null;
  const w = await db.runTransaction(async (tx) => {
    const ws = await tx.get(db.doc(`withdrawals/${id}`));
    if (!ws.exists) fail('not-found', 'Withdrawal not found.');
    const w = ws.data()!;
    if (['rejected', 'paid'].includes(w.status)) fail('failed-precondition', `Withdrawal is already ${w.status}.`);
    const pref = db.doc(`${w.role === 'seller' ? 'sellers' : 'deliveryPartners'}/${w.userId}`);
    const ps = await tx.get(pref);
    if (status === 'rejected' && ps.exists) tx.update(pref, { balance: FieldValue.increment(w.amount), pendingWithdrawal: FieldValue.increment(-w.amount), updatedAt: now() });
    if (status === 'paid' && ps.exists) tx.update(pref, { pendingWithdrawal: FieldValue.increment(-w.amount), totalPaidOut: FieldValue.increment(w.amount), updatedAt: now() });
    tx.update(ws.ref, { status, adminNote: note, txnRef: str(d.txnRef, 'txnRef', { required: false, max: 100 }) || null, processedBy: c.uid, processedAt: now(), updatedAt: now() });
    return w;
  });
  const who = (await db.doc(`users/${w.userId}`).get()).data() ?? {};
  await sendTemplateEmail('withdrawal', who.email, { name: who.name ?? w.name ?? '', amount: w.amount, status, note: note ?? '' });
  let phone = who.phone;
  if (!phone) phone = (await db.doc(`${w.role === 'seller' ? 'sellers' : 'deliveryPartners'}/${w.userId}`).get().catch(() => null))?.get('phone');
  await queueSms({ to: phone, event: 'withdrawal', userId: w.userId, refId: id, vars: { name: who.name ?? w.name ?? '', amount: Number(w.amount).toFixed(2), status } });
  await notifyUser(w.userId, {
    title: `Withdrawal ${status}`,
    body: status === 'paid' ? `₹${w.amount} has been transferred to you.` : status === 'rejected' ? `₹${w.amount} was returned to your balance.${note ? ' ' + note : ''}` : `Your request for ₹${w.amount} is approved and will be paid soon.`,
    type: 'payout',
  });
  return { ok: true, status };
});
