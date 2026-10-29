import { onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { PAYMENT_SECRETS } from '../lib/config.js';
import { refundToSource } from '../payments/providers.js';
import { db, FieldValue, Timestamp, now } from '../lib/admin.js';
import { applyWallet } from '../lib/wallet.js';
import { notifyUser } from '../lib/notify.js';
import { fail, num, oneOf, platformSettings, requireAuth, requireRole, round2, str, type Json } from '../lib/util.js';

/** requestReturn — customer: {orderId, items:[{productId, variantId?, qty}], reason, images?[]} → {returnId, refundAmount}. */
export const requestReturn = onCall(async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  const orderId = str(d.orderId, 'orderId', { max: 128 });
  const reason = str(d.reason, 'reason', { max: 500 });
  const images = Array.isArray(d.images) ? d.images.filter((x: unknown) => typeof x === 'string').slice(0, 5) : [];
  const settings = await platformSettings();
  const ref = db.collection('returns').doc();
  const result = await db.runTransaction(async (tx) => {
    const os = await tx.get(db.doc(`orders/${orderId}`));
    if (!os.exists) fail('not-found', 'Order not found.');
    const o = os.data()!;
    if (o.userId !== c.uid) fail('permission-denied', 'Not your order.');
    if (o.status !== 'delivered') fail('failed-precondition', 'Only delivered orders can be returned.');
    const deliveredMs = o.deliveredAt?.toMillis?.() ?? 0;
    const days = Number(settings.returnWindowDays ?? 7);
    if (deliveredMs && Date.now() - deliveredMs > days * 86_400_000) fail('failed-precondition', `Returns are accepted within ${days} days of delivery.`);
    if ((o.items as Json[]).some((i) => i.moduleId === 'food')) fail('failed-precondition', 'Food orders cannot be returned. Please contact support for any issue.');
    const already: Json = o.returnedQty ?? {};
    const wanted: Json[] = Array.isArray(d.items) && d.items.length ? d.items : (o.items as Json[]).map((i) => ({ productId: i.productId, variantId: i.variantId, qty: i.qty }));
    const items: Json[] = [];
    for (const w of wanted) {
      const it = (o.items as Json[]).find((i) => i.productId === w.productId && (i.variantId === (w.variantId ?? i.variantId)));
      if (!it) fail('invalid-argument', 'Item not in this order.');
      const key = `${it.productId}_${it.variantId}`;
      const qty = num(w.qty ?? it.qty, 'qty', { min: 1, max: Number(it.qty) - Number(already[key] ?? 0), int: true });
      items.push({ productId: it.productId, variantId: it.variantId, name: it.name, variantName: it.variantName, image: it.image, price: it.price, qty, sellerId: it.sellerId });
    }
    // Pro-rate order-level discounts across items.
    const gross = items.reduce((a, i) => a + i.price * i.qty, 0);
    const ratio = Number(o.subtotal) > 0 ? Math.max(0, Number(o.subtotal) - Number(o.discount || 0)) / Number(o.subtotal) : 1;
    const refundAmount = round2(gross * ratio);
    tx.set(ref, {
      orderId, orderNo: o.orderNo, userId: c.uid, sellerIds: [...new Set(items.map((i) => i.sellerId))], items, reason, images,
      status: 'requested', refundAmount, computedRefund: refundAmount, refundTo: d.refundTo === 'source' ? 'source' : 'wallet', paymentMethod: o.paymentMethod,
      timeline: [{ status: 'requested', at: Timestamp.now(), by: c.uid, note: reason }], createdAt: now(), updatedAt: now(),
    });
    tx.update(os.ref, { returnRequested: true, returnIds: FieldValue.arrayUnion(ref.id), updatedAt: now() });
    return { refundAmount, sellerIds: [...new Set(items.map((i) => i.sellerId))] };
  });
  for (const s of result.sellerIds) await notifyUser(s, { title: 'Return requested', body: `A customer requested a return. Refund ₹${result.refundAmount}.`, type: 'order', data: { returnId: ref.id } });
  return { returnId: ref.id, refundAmount: result.refundAmount, status: 'requested' };
});


/**
 * processReturn — admin or seller of the items: {returnId (or id), status: approved|rejected|picked|refunded, refundAmount?, refundTo?: wallet|source, note?} → {ok, status, refundAmount, refundTo}.
 * refundAmount: admin may set up to the order total; a seller may only lower it (≤ the computed amount).
 * refunded: refunds the customer (wallet, or the original online payment when refundTo='source' and the order was paid online;
 * any wallet-paid part always goes back to the wallet), restocks items, debits the seller's net earning and
 * marks the order `returned` when everything has been returned.
 */
export const processReturn = onCall({ secrets: PAYMENT_SECRETS, timeoutSeconds: 60 }, async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const d = req.data ?? {};
  const returnId = str(d.returnId ?? d.id, 'returnId', { max: 128 });
  const status = oneOf(d.status, 'status', ['approved', 'rejected', 'picked', 'refunded'] as const);
  const note = str(d.note, 'note', { required: false, max: 500 }) || '';
  const refundToIn = oneOf(d.refundTo, 'refundTo', ['wallet', 'source'] as const, 'wallet');
  const flow = ['requested', 'approved', 'picked', 'refunded'];
  const rref = db.doc(`returns/${returnId}`);

  // Pre-checks and amount resolution (outside the transaction so a gateway refund can be issued first).
  const pre = await rref.get();
  if (!pre.exists) fail('not-found', 'Return not found.');
  const r0 = pre.data()!;
  if (c.role === 'seller' && !(r0.sellerIds ?? []).includes(c.uid)) fail('permission-denied', 'Not your return.');
  if (['rejected', 'refunded'].includes(r0.status)) fail('failed-precondition', `Return is already ${r0.status}.`);
  if (status !== 'rejected' && flow.indexOf(status) <= flow.indexOf(r0.status)) fail('failed-precondition', `Cannot move from ${r0.status} to ${status}.`);
  const order0 = (await db.doc(`orders/${r0.orderId}`).get()).data();
  if (!order0) fail('not-found', 'Order not found.');
  let amount = Number(r0.refundAmount);
  if (d.refundAmount !== undefined && d.refundAmount !== null && d.refundAmount !== '') {
    const want = round2(num(d.refundAmount, 'refundAmount', { min: 0, max: Number(order0.total) }));
    amount = c.role === 'admin' ? want : Math.min(want, Number(r0.computedRefund ?? r0.refundAmount));
  }

  let refundTo: 'wallet' | 'source' = refundToIn;
  let sourcePart = 0;
  let sourceRefund: Json | null = r0.sourceRefund ?? null;
  if (status === 'refunded') {
    const online = ['razorpay', 'stripe', 'paypal'].includes(order0.paymentMethod) && ['paid', 'refunded'].includes(order0.paymentStatus);
    if (refundTo === 'source' && !online) refundTo = 'wallet';
    if (refundTo === 'source') {
      const alreadySource = Number(order0.sourceRefunded ?? 0);
      sourcePart = round2(Math.max(0, Math.min(amount, Number(order0.payable) - alreadySource)));
      if (sourcePart > 0 && !sourceRefund) {
        const settings = await platformSettings();
        try {
          const res = await refundToSource(order0.paymentMethod, String(order0.paymentRef ?? ''), sourcePart, settings.fx, `ret-${returnId}`);
          sourceRefund = { provider: order0.paymentMethod, id: res.id, status: res.status, amount: sourcePart };
          await rref.update({ sourceRefund, updatedAt: now() }); // persisted before the tx so a retry never refunds twice
        } catch (e) {
          logger.error('source refund failed', { returnId, error: String(e) });
          throw e;
        }
      }
      if (sourceRefund) sourcePart = Number(sourceRefund.amount);
    }
  }

  const r = await db.runTransaction(async (tx) => {
    const rs = await tx.get(rref);
    const r = rs.data()!;
    if (['rejected', 'refunded'].includes(r.status)) fail('failed-precondition', `Return is already ${r.status}.`);
    const update: Json = {
      status, refundAmount: amount, timeline: FieldValue.arrayUnion({ status, at: Timestamp.now(), by: c.uid, note }), updatedAt: now(),
    };
    if (r.computedRefund === undefined) update.computedRefund = r.refundAmount;
    if (status === 'refunded') {
      const os = await tx.get(db.doc(`orders/${r.orderId}`));
      const o = os.data()!;
      const pids = [...new Set((r.items as Json[]).map((i) => i.productId))];
      const ps = await tx.getAll(...pids.map((id) => db.doc(`products/${id}`)));
      const sellerSnaps = await tx.getAll(...(r.sellerIds as string[]).map((id) => db.doc(`sellers/${id}`)));
      const user = await tx.get(db.doc(`users/${r.userId}`));
      const walletPart = round2(amount - sourcePart);
      if (walletPart > 0 && user.exists) applyWallet(tx, user, 'credit', walletPart, 'refund', returnId, `Refund for return on order ${r.orderNo}`);
      for (const p of ps) {
        if (!p.exists) continue;
        const its = (r.items as Json[]).filter((i) => i.productId === p.id);
        const qty = its.reduce((a, i) => a + i.qty, 0);
        const pd = p.data()!;
        if (Array.isArray(pd.variants) && pd.variants.length) {
          const variants = pd.variants.map((v: Json) => {
            const back = its.filter((i) => i.variantId === v.id).reduce((a, i) => a + i.qty, 0);
            return back ? { ...v, stock: Number(v.stock) + back } : v;
          });
          tx.update(p.ref, { variants, stock: variants.reduce((a: number, v: Json) => a + (Number(v.stock) || 0), 0), soldCount: FieldValue.increment(-qty) });
        } else tx.update(p.ref, { stock: FieldValue.increment(qty), soldCount: FieldValue.increment(-qty) });
      }
      for (const s of sellerSnaps) {
        if (!s.exists) continue;
        const gross = (r.items as Json[]).filter((i) => i.sellerId === s.id).reduce((a, i) => a + i.price * i.qty, 0);
        const net = round2(gross * (1 - Number(s.get('commissionPct') ?? 10) / 100));
        tx.update(s.ref, { balance: FieldValue.increment(-net), totalSales: FieldValue.increment(-round2(gross)), updatedAt: now() });
      }
      const returnedQty: Json = { ...(o.returnedQty ?? {}) };
      for (const i of r.items as Json[]) returnedQty[`${i.productId}_${i.variantId}`] = Number(returnedQty[`${i.productId}_${i.variantId}`] ?? 0) + i.qty;
      const fully = (o.items as Json[]).every((i) => Number(returnedQty[`${i.productId}_${i.variantId}`] ?? 0) >= Number(i.qty));
      const via = sourcePart > 0 ? `₹${sourcePart} to ${o.paymentMethod}${walletPart > 0 ? ` + ₹${walletPart} to wallet` : ''}` : `₹${amount} to wallet`;
      tx.update(os.ref, {
        returnedQty, refundAmount: FieldValue.increment(amount), ...(sourcePart > 0 ? { sourceRefunded: FieldValue.increment(sourcePart) } : {}),
        ...(fully ? { status: 'returned', paymentStatus: 'refunded' } : {}),
        timeline: FieldValue.arrayUnion({ status: fully ? 'returned' : 'partially_returned', at: Timestamp.now(), by: c.uid, note: `Refund ${via}` }),
        updatedAt: now(),
      });
      Object.assign(update, { refundTo: sourcePart > 0 ? 'source' : 'wallet', walletRefund: walletPart, sourceRefund, refundedAt: now() });
    }
    tx.update(rs.ref, update);
    return { ...r, refundTo: update.refundTo ?? r.refundTo } as Json;
  });
  const msg: Record<string, string> = {
    approved: 'Your return was approved. Our partner will pick it up soon.', rejected: `Your return was rejected. ${note}`,
    picked: 'We have picked up your return.',
    refunded: r.refundTo === 'source' ? `Your refund of ₹${amount} is on its way to your original payment method (5–7 business days).` : `₹${amount} has been credited to your Go4Market wallet.`,
  };
  await notifyUser(r.userId, { title: `Return ${status}`, body: msg[status], type: 'order', data: { orderId: r.orderId, returnId } });
  return { ok: true, status, refundAmount: amount, refundTo: r.refundTo ?? 'wallet' };
});
