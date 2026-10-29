import { onCall, onRequest } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { db, FieldValue, Timestamp, now } from '../lib/admin.js';
import { PAYMENT_SECRETS } from '../lib/config.js';
import { applyWallet } from '../lib/wallet.js';
import { fail, num, oneOf, platformSettings, requireAuth, round2, str, type Json } from '../lib/util.js';
import {
  createPayment, paypalCapture, razorpayFetchOrder, razorpayVerifySignature, stripeRetrieveSession, stripeVerify, type Kind, type Provider,
} from './providers.js';

const PROVIDERS = ['razorpay', 'stripe', 'paypal'] as const;

interface VerifyResult { paid: boolean; ref: string; status: string }

/** Verifies a payment with the provider. `gatewayId` is the provider order/session id we stored at creation. */
async function verify(provider: Provider, refId: string, gatewayId: string | undefined, d: Json): Promise<VerifyResult> {
  if (provider === 'razorpay') {
    const rzpOrderId = str(d.razorpayOrderId ?? gatewayId, 'razorpayOrderId', { max: 64 });
    if (gatewayId && rzpOrderId !== gatewayId) fail('permission-denied', 'Razorpay order does not match.');
    const paymentId = str(d.razorpayPaymentId, 'razorpayPaymentId', { max: 64 });
    const sig = str(d.razorpaySignature, 'razorpaySignature', { max: 256 });
    const ok = razorpayVerifySignature(rzpOrderId, paymentId, sig);
    return { paid: ok, ref: paymentId, status: ok ? 'captured' : 'signature_mismatch' };
  }
  if (provider === 'stripe') {
    const sessionId = str(d.sessionId, 'sessionId', { required: false, max: 255 }) || (d.paymentIntentId ? '' : gatewayId);
    if (sessionId && gatewayId && sessionId !== gatewayId) fail('permission-denied', 'Stripe session does not match.');
    return stripeVerify(refId, sessionId || undefined, str(d.paymentIntentId, 'paymentIntentId', { required: false, max: 255 }) || undefined);
  }
  const ppId = str(d.paypalOrderId ?? gatewayId, 'paypalOrderId', { max: 64 });
  if (gatewayId && ppId !== gatewayId) fail('permission-denied', 'PayPal order does not match.');
  return paypalCapture(ppId, refId);
}

/** Marks an order paid (pending → placed). Idempotent. Money received for an already-cancelled order goes to the wallet. */
export async function markOrderPaid(orderId: string, provider: string, ref: string): Promise<string> {
  return db.runTransaction(async (tx) => {
    const ref0 = db.doc(`orders/${orderId}`);
    const snap = await tx.get(ref0);
    if (!snap.exists) fail('not-found', 'Order not found.');
    const o = snap.data()!;
    if (o.paymentStatus === 'paid' || o.paymentStatus === 'refunded') return o.status as string;
    if (o.status === 'cancelled') {
      const user = await tx.get(db.doc(`users/${o.userId}`));
      if (user.exists) applyWallet(tx, user, 'credit', Number(o.payable), 'refund', orderId, `Payment received after order ${o.orderNo} was cancelled`);
      tx.update(ref0, { paymentStatus: 'refunded', paymentRef: ref, refundAmount: FieldValue.increment(Number(o.payable)), updatedAt: now() });
      return 'cancelled';
    }
    tx.update(ref0, {
      status: o.status === 'pending' ? 'placed' : o.status,
      paymentStatus: 'paid', paymentRef: ref, paidAt: now(),
      timeline: FieldValue.arrayUnion({ status: 'placed', at: Timestamp.now(), by: 'system', note: `Paid via ${provider}` }),
      updatedAt: now(),
    });
    return o.status === 'pending' ? 'placed' : (o.status as string);
  });
}

/** Credits a wallet top-up. Idempotent. Returns the new balance. */
export async function creditTopup(topupId: string, provider: string, ref: string): Promise<number> {
  return db.runTransaction(async (tx) => {
    const tref = db.doc(`walletTopups/${topupId}`);
    const t = await tx.get(tref);
    if (!t.exists) fail('not-found', 'Top-up not found.');
    const user = await tx.get(db.doc(`users/${t.get('userId')}`));
    if (t.get('status') === 'paid') return Number(user.get('walletBalance') ?? 0);
    const bal = applyWallet(tx, user, 'credit', Number(t.get('amount')), 'topup', topupId, `Wallet top-up via ${provider}`);
    tx.update(tref, { status: 'paid', paymentRef: ref, paidAt: now(), updatedAt: now() });
    return bal;
  });
}

/** confirmPayment — owner: {orderId, provider, razorpayOrderId?, razorpayPaymentId?, razorpaySignature?, sessionId?, paymentIntentId?, paypalOrderId?} → {ok, status, paymentStatus}. */
export const confirmPayment = onCall({ secrets: PAYMENT_SECRETS }, async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  const orderId = str(d.orderId, 'orderId', { max: 128 });
  const provider = oneOf(d.provider, 'provider', PROVIDERS);
  const snap = await db.doc(`orders/${orderId}`).get();
  if (!snap.exists) fail('not-found', 'Order not found.');
  const o = snap.data()!;
  if (o.userId !== c.uid && c.role !== 'admin') fail('permission-denied', 'Not your order.');
  if (o.paymentStatus === 'paid') return { ok: true, status: o.status, paymentStatus: 'paid' };
  if (o.paymentMethod !== provider) fail('invalid-argument', `This order is set to pay with ${o.paymentMethod}.`);
  const r = await verify(provider, orderId, o.gateway?.id, d);
  if (!r.paid) {
    await snap.ref.update({ paymentStatus: 'failed', paymentError: r.status, updatedAt: now() });
    return { ok: false, status: o.status, paymentStatus: 'failed', reason: r.status };
  }
  const status = await markOrderPaid(orderId, provider, r.ref);
  return { ok: true, status, paymentStatus: status === 'cancelled' ? 'refunded' : 'paid' };
});

/** walletTopup — {amount, provider} → {topupId, amount, payment}. */
export const walletTopup = onCall({ secrets: PAYMENT_SECRETS }, async (req) => {
  const c = requireAuth(req);
  const amount = round2(num(req.data?.amount, 'amount', { min: 10, max: 50_000 }));
  const provider = oneOf(req.data?.provider, 'provider', PROVIDERS);
  const settings = await platformSettings();
  if (settings.walletEnabled === false) fail('failed-precondition', 'Wallet is disabled.');
  const user = (await db.doc(`users/${c.uid}`).get()).data() ?? {};
  const tref = db.collection('walletTopups').doc();
  const refNo = `TOP${Date.now().toString().slice(-8)}`;
  await tref.set({ userId: c.uid, amount, provider, status: 'pending', refNo, createdAt: now(), updatedAt: now() });
  try {
    const payment = await createPayment(provider, {
      kind: 'topup', refId: tref.id, refNo, amountInr: amount, uid: c.uid, fx: settings.fx,
      customer: { name: user.name, email: user.email ?? c.email, phone: user.phone },
    });
    await tref.update({ gateway: { provider, id: payment.razorpayOrderId ?? payment.sessionId ?? payment.paypalOrderId, currency: payment.currency, amount: payment.amount } });
    return { topupId: tref.id, orderId: tref.id, amount, payment };
  } catch (e) {
    await tref.update({ status: 'failed', updatedAt: now() });
    throw e;
  }
});

/** confirmWalletTopup — {orderId|topupId, provider, ...provider fields} → {ok, balance}. */
export const confirmWalletTopup = onCall({ secrets: PAYMENT_SECRETS }, async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  const topupId = str(d.topupId ?? d.orderId, 'orderId', { max: 128 });
  const provider = oneOf(d.provider, 'provider', PROVIDERS);
  const t = await db.doc(`walletTopups/${topupId}`).get();
  if (!t.exists) fail('not-found', 'Top-up not found.');
  if (t.get('userId') !== c.uid) fail('permission-denied', 'Not your top-up.');
  if (t.get('status') === 'paid') {
    const bal = Number((await db.doc(`users/${c.uid}`).get()).get('walletBalance') ?? 0);
    return { ok: true, balance: bal };
  }
  if (t.get('provider') !== provider) fail('invalid-argument', 'Provider does not match this top-up.');
  const r = await verify(provider, topupId, t.get('gateway')?.id, d);
  if (!r.paid) {
    await t.ref.update({ status: 'failed', paymentError: r.status, updatedAt: now() });
    return { ok: false, status: r.status };
  }
  const balance = await creditTopup(topupId, provider, r.ref);
  return { ok: true, balance };
});

async function settle(kind: Kind, refId: string, provider: string, ref: string) {
  if (kind === 'topup') await creditTopup(refId, provider, ref);
  else await markOrderPaid(refId, provider, ref);
}

/**
 * paymentWebhook (HTTP POST) — Razorpay / Stripe / PayPal events. The payload is never trusted:
 * every event is re-verified against the provider API with our secret key before anything is marked paid.
 */
export const paymentWebhook = onRequest({ secrets: PAYMENT_SECRETS, cors: false }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).send('Method not allowed'); return; }
  const b: Json = req.body ?? {};
  try {
    // Stripe
    if (req.get('stripe-signature') || b.object === 'event') {
      if (['checkout.session.completed', 'checkout.session.async_payment_succeeded'].includes(b.type)) {
        const s = await stripeRetrieveSession(String(b.data?.object?.id ?? ''));
        if (s.payment_status === 'paid' && s.metadata?.refId) {
          const pi = typeof s.payment_intent === 'string' ? s.payment_intent : s.payment_intent?.id;
          await settle((s.metadata.kind as Kind) ?? 'order', s.metadata.refId, 'stripe', pi ?? s.id);
        }
      }
      res.json({ received: true }); return;
    }
    // Razorpay
    if (req.get('x-razorpay-signature') || b.entity === 'event') {
      const rzpOrderId = b.payload?.payment?.entity?.order_id ?? b.payload?.order?.entity?.id;
      if (rzpOrderId && ['payment.captured', 'order.paid'].includes(b.event)) {
        const ord = await razorpayFetchOrder(String(rzpOrderId));
        const refId = ord.notes?.refId;
        if (ord.status === 'paid' && refId) {
          const coll = ord.notes?.kind === 'topup' ? 'walletTopups' : 'orders';
          const doc = await db.doc(`${coll}/${refId}`).get();
          if (doc.exists && doc.get('gateway')?.id === ord.id) {
            await settle(ord.notes.kind === 'topup' ? 'topup' : 'order', refId, 'razorpay', b.payload?.payment?.entity?.id ?? ord.id);
          }
        }
      }
      res.json({ received: true }); return;
    }
    // PayPal
    if (b.event_type) {
      if (b.event_type === 'CHECKOUT.ORDER.APPROVED' || b.event_type === 'PAYMENT.CAPTURE.COMPLETED') {
        const custom: string = b.resource?.purchase_units?.[0]?.custom_id ?? b.resource?.custom_id ?? '';
        const [kind, refId] = custom.split(':');
        const ppId = b.event_type === 'CHECKOUT.ORDER.APPROVED' ? b.resource?.id : b.resource?.supplementary_data?.related_ids?.order_id;
        if (refId && ppId) {
          const coll = kind === 'topup' ? 'walletTopups' : 'orders';
          const doc = await db.doc(`${coll}/${refId}`).get();
          if (doc.exists && doc.get('gateway')?.id === ppId) {
            const r = await paypalCapture(ppId, refId);
            if (r.paid) await settle(kind === 'topup' ? 'topup' : 'order', refId, 'paypal', r.ref);
          }
        }
      }
      res.json({ received: true }); return;
    }
    res.status(400).json({ error: 'Unrecognised webhook' });
  } catch (e) {
    logger.error('paymentWebhook error', { error: String(e) });
    res.status(500).json({ error: 'processing failed' });
  }
});
