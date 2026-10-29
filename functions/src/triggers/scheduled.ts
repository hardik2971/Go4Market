import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { v1 as firestoreAdmin } from '@google-cloud/firestore';
import { db, FieldValue, Timestamp, now } from '../lib/admin.js';
import { notifyUser } from '../lib/notify.js';
import { cancelOrderTx, createOrder } from '../orders/engine.js';
import { round2 } from '../lib/util.js';

const TZ = 'Asia/Kolkata';

function nextRun(from: Date, frequency: string): Date {
  const d = new Date(from);
  if (frequency === 'daily') d.setDate(d.getDate() + 1);
  else if (frequency === 'weekly') d.setDate(d.getDate() + 7);
  else d.setMonth(d.getMonth() + 1);
  return d;
}

/** runSubscriptions — daily 07:00 IST: creates orders for due subscriptions (wallet first, rest COD). */
export const runSubscriptions = onSchedule({ schedule: '0 7 * * *', timeZone: TZ, timeoutSeconds: 540, memory: '512MiB' }, async () => {
  const due = await db.collection('subscriptions').where('status', '==', 'active').where('nextRunAt', '<=', Timestamp.now()).limit(300).get();
  let ok = 0, failed = 0;
  for (const s of due.docs) {
    const sub = s.data();
    const base = sub.nextRunAt?.toDate?.() ?? new Date();
    let next = nextRun(base, sub.frequency);
    while (next.getTime() < Date.now()) next = nextRun(next, sub.frequency);
    try {
      const r = await createOrder({
        input: { uid: sub.userId, lines: [{ productId: sub.productId, variantId: sub.variantId ?? 'default', qty: Number(sub.qty) || 1 }], addressId: sub.addressId ?? null, useWallet: true, speed: 'standard', deliveryType: 'home' },
        paymentMethod: 'cod', channel: 'app', extra: { subscriptionId: s.id, notes: `Subscription (${sub.frequency})` },
      });
      await s.ref.update({ nextRunAt: Timestamp.fromDate(next), lastRunAt: now(), lastOrderId: r.orderId, lastError: null, runCount: FieldValue.increment(1), updatedAt: now() });
      ok++;
    } catch (e: any) {
      failed++;
      await s.ref.update({ nextRunAt: Timestamp.fromDate(next), lastRunAt: now(), lastError: String(e?.message ?? e), updatedAt: now() });
      await notifyUser(sub.userId, { title: 'Subscription order skipped', body: `We couldn't place today's subscription order: ${e?.message ?? 'unknown error'}`, type: 'order', data: { link: '/subscriptions' } });
    }
  }
  logger.info('runSubscriptions done', { ok, failed });
});

/** cleanupPendingOrders — hourly: cancels unpaid online orders older than 30 min (restores stock/wallet), expires stale top-ups. */
export const cleanupPendingOrders = onSchedule({ schedule: 'every 60 minutes', timeZone: TZ, timeoutSeconds: 300 }, async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - 30 * 60_000);
  const stale = await db.collection('orders').where('status', '==', 'pending').where('createdAt', '<', cutoff).limit(300).get();
  let n = 0;
  for (const d of stale.docs) {
    try {
      await db.runTransaction((tx) => cancelOrderTx(tx, d.ref, 'system', 'Payment not completed in time'));
      n++;
    } catch (e) {
      logger.warn('cleanup cancel failed', { orderId: d.id, error: String(e) });
    }
  }
  const topups = await db.collection('walletTopups').where('status', '==', 'pending').where('createdAt', '<', Timestamp.fromMillis(Date.now() - 24 * 3_600_000)).limit(300).get();
  const b = db.batch();
  topups.docs.forEach((t) => b.update(t.ref, { status: 'expired', updatedAt: now() }));
  if (!topups.empty) await b.commit();
  logger.info('cleanupPendingOrders', { cancelled: n, expiredTopups: topups.size });
});

/** remindAbandonedCarts — daily 18:00 IST: one reminder per user for carts idle 6–48 h. */
export const remindAbandonedCarts = onSchedule({ schedule: '0 18 * * *', timeZone: TZ, timeoutSeconds: 300 }, async () => {
  const from = Timestamp.fromMillis(Date.now() - 48 * 3_600_000), to = Timestamp.fromMillis(Date.now() - 6 * 3_600_000);
  const items = await db.collectionGroup('cart').where('addedAt', '>=', from).where('addedAt', '<=', to).limit(2000).get();
  const users = new Map<string, number>();
  for (const d of items.docs) {
    const uid = d.ref.parent.parent?.id;
    if (uid) users.set(uid, (users.get(uid) ?? 0) + Number(d.get('qty') ?? 1));
  }
  for (const [uid, qty] of users) {
    const u = await db.doc(`users/${uid}`).get();
    const last = u.get('cartReminderAt')?.toMillis?.() ?? 0;
    if (Date.now() - last < 24 * 3_600_000) continue;
    await notifyUser(uid, { title: 'Your cart is waiting', body: `You left ${qty} item(s) in your cart. Complete your order before they sell out!`, type: 'promo', data: { link: '/cart' } });
    await u.ref.set({ cartReminderAt: now() }, { merge: true });
  }
  logger.info('remindAbandonedCarts', { users: users.size });
});

/** runMonthlySalaries — 1st of month 09:00 IST: credits monthly-salaried delivery partners (idempotent per month). */
export const runMonthlySalaries = onSchedule({ schedule: '0 9 1 * *', timeZone: TZ, timeoutSeconds: 300 }, async () => {
  const month = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit' }).format(new Date()).replace('-', '');
  const ps = await db.collection('deliveryPartners').where('status', '==', 'approved').where('salary.type', '==', 'monthly').get();
  let n = 0;
  for (const p of ps.docs) {
    const amount = round2(Number(p.get('salary.amount') ?? 0));
    if (amount <= 0) continue;
    const tref = db.doc(`fundTransfers/salary_${month}_${p.id}`);
    try {
      await db.runTransaction(async (tx) => {
        const t = await tx.get(tref);
        if (t.exists) return;
        tx.create(tref, { toUserId: p.id, role: 'delivery', amount, type: 'salary', note: `Salary for ${month}`, by: 'system', createdAt: now(), updatedAt: now() });
        tx.update(p.ref, { balance: FieldValue.increment(amount), updatedAt: now() });
      });
      await notifyUser(p.id, { title: 'Salary credited', body: `₹${amount} salary for ${month} added to your earnings.`, type: 'payout' });
      n++;
    } catch (e) {
      logger.warn('salary failed', { uid: p.id, error: String(e) });
    }
  }
  logger.info('runMonthlySalaries', { credited: n });
});

/** backupFirestore — weekly Sun 02:30 IST: managed export of Firestore to gs://<bucket>/backups/<date>. */
export const backupFirestore = onSchedule({ schedule: '30 2 * * 0', timeZone: TZ, timeoutSeconds: 300 }, async () => {
  const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? 'go4market';
  const bucket = process.env.BACKUP_BUCKET ?? `${projectId}.firebasestorage.app`;
  const client = new firestoreAdmin.FirestoreAdminClient();
  const stamp = new Date().toISOString().slice(0, 10);
  try {
    const [op] = await client.exportDocuments({ name: client.databasePath(projectId, '(default)'), outputUriPrefix: `gs://${bucket}/backups/${stamp}`, collectionIds: [] });
    await db.doc('system/backup').set({ lastRunAt: now(), operation: op.name ?? null, path: `gs://${bucket}/backups/${stamp}`, status: 'started' }, { merge: true });
  } catch (e) {
    logger.error('backup failed', { error: String(e) });
    await db.doc('system/backup').set({ lastRunAt: now(), status: 'failed', error: String(e) }, { merge: true });
  }
});
