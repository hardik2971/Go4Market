import { onCall } from 'firebase-functions/v2/https';
import { db, FieldValue, Timestamp, now } from '../lib/admin.js';
import { applyWallet } from '../lib/wallet.js';
import { notifyUser } from '../lib/notify.js';
import { fail, num, oneOf, requireRole, requireAuth, round2, str } from '../lib/util.js';

/** adjustWallet — admin: {userId, amount, type: credit|debit, note, reason?} → {ok, balance}. */
export const adjustWallet = onCall(async (req) => {
  const c = requireRole(req, 'admin');
  const d = req.data ?? {};
  const userId = str(d.userId, 'userId', { max: 128 });
  const amount = round2(num(d.amount, 'amount', { min: 0.01, max: 1_000_000 }));
  const type = oneOf(d.type, 'type', ['credit', 'debit'] as const);
  const note = str(d.note, 'note', { required: false, max: 300 }) || 'Adjusted by admin';
  const reason = oneOf(d.reason, 'reason', ['admin', 'cashback', 'refund', 'referral'] as const, 'admin');
  const balance = await db.runTransaction(async (tx) => {
    const u = await tx.get(db.doc(`users/${userId}`));
    if (!u.exists) fail('not-found', 'User not found.');
    const bal = Number(u.get('walletBalance') ?? 0);
    if (type === 'debit' && bal < amount) fail('failed-precondition', `Wallet balance is only ₹${bal}.`);
    return applyWallet(tx, u, type, amount, reason, null, `${note} (by ${c.uid})`);
  });
  await notifyUser(userId, { title: type === 'credit' ? `₹${amount} added to your wallet` : `₹${amount} deducted from your wallet`, body: note, type: 'wallet', data: { link: '/wallet' } });
  return { ok: true, balance };
});

/**
 * transferFunds — admin: {toUserId, amount, note, type?: 'payout'|'credit'} → {ok, id, balance}.
 * payout (default): records money paid to a seller/delivery partner; it debits their earnings balance up to the amount (never below 0) and records any excess (e.g. salary) as `direct`.
 * credit: adds to their balance (salary, bonus, incentive).
 */
export const transferFunds = onCall(async (req) => {
  const c = requireRole(req, 'admin');
  const d = req.data ?? {};
  const toUserId = str(d.toUserId, 'toUserId', { max: 128 });
  const amount = round2(num(d.amount, 'amount', { min: 1, max: 10_000_000 }));
  const note = str(d.note, 'note', { required: false, max: 300 });
  const type = oneOf(d.type, 'type', ['payout', 'credit'] as const, 'payout');
  const wantRole = d.role ? oneOf(d.role, 'role', ['seller', 'delivery'] as const) : null;
  const ref = db.collection('fundTransfers').doc();
  const balance = await db.runTransaction(async (tx) => {
    const [s, p] = await tx.getAll(db.doc(`sellers/${toUserId}`), db.doc(`deliveryPartners/${toUserId}`));
    const target = wantRole === 'seller' ? (s.exists ? s : null) : wantRole === 'delivery' ? (p.exists ? p : null) : s.exists ? s : p.exists ? p : null;
    if (!target) fail('not-found', wantRole ? `No ${wantRole} with this id.` : 'No seller or delivery partner with this id.');
    const role = target === s ? 'seller' : 'delivery';
    const bal = Number(target.get('balance') ?? 0);
    // A payout settles the earnings balance first; anything above it (e.g. a monthly salary) is recorded as a direct payment.
    const fromBalance = type === 'payout' ? round2(Math.min(Math.max(bal, 0), amount)) : 0;
    const next = round2(type === 'payout' ? bal - fromBalance : bal + amount);
    tx.update(target.ref, { balance: next, updatedAt: now(), ...(type === 'payout' ? { totalPaidOut: FieldValue.increment(amount) } : {}) });
    tx.set(ref, { toUserId, role, amount, type, fromBalance, direct: type === 'payout' ? round2(amount - fromBalance) : 0, note: note || null, by: c.uid, balanceAfter: next, createdAt: now(), updatedAt: now() });
    return next;
  });
  await notifyUser(toUserId, {
    title: type === 'payout' ? `Payout of ₹${amount} sent` : `₹${amount} credited to your earnings`,
    body: note || (type === 'payout' ? 'The amount has been transferred to your bank account.' : 'Check your earnings balance.'),
    type: 'payout',
  });
  return { ok: true, id: ref.id, balance };
});

/** purchaseMembership — customer: {planId} → {ok, expiresAt, balance}. Paid from the wallet (top up first). */
export const purchaseMembership = onCall(async (req) => {
  const c = requireAuth(req);
  const planId = str(req.data?.planId, 'planId', { max: 128 });
  const res = await db.runTransaction(async (tx) => {
    const [plan, u] = await tx.getAll(db.doc(`membershipPlans/${planId}`), db.doc(`users/${c.uid}`));
    if (!plan.exists || plan.get('active') === false) fail('not-found', 'Plan not available.');
    if (!u.exists) fail('failed-precondition', 'User profile missing.');
    const price = round2(Number(plan.get('price') ?? 0));
    const bal = Number(u.get('walletBalance') ?? 0);
    if (bal < price) fail('failed-precondition', `Add ₹${round2(price - bal)} to your wallet to buy this plan.`, { shortBy: round2(price - bal) });
    const cur = u.get('membership');
    const base = cur?.expiresAt?.toMillis && cur.expiresAt.toMillis() > Date.now() && cur.planId === planId ? cur.expiresAt.toMillis() : Date.now();
    const expiresAt = Timestamp.fromMillis(base + Number(plan.get('durationDays') ?? 30) * 86_400_000);
    const balance = price > 0 ? applyWallet(tx, u, 'debit', price, 'membership', planId, `Membership: ${plan.get('name')}`) : bal;
    tx.set(u.ref, {
      membership: {
        planId, name: plan.get('name'), expiresAt, freeDelivery: !!plan.get('freeDelivery'), discountPct: Number(plan.get('discountPct') ?? 0), purchasedAt: Timestamp.now(),
      },
    }, { merge: true });
    return { expiresAt, balance, name: plan.get('name') };
  });
  await notifyUser(c.uid, { title: `Welcome to ${res.name}!`, body: 'Your membership benefits are now active.', type: 'system', data: { link: '/membership' } });
  return { ok: true, expiresAt: res.expiresAt.toDate().toISOString(), balance: res.balance };
});
