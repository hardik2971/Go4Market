import { onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { db, FieldValue, Timestamp, now } from '../lib/admin.js';
import { PAYMENT_SECRETS } from '../lib/config.js';
import { fail, haversineKm, isNum, num, oneOf, platformSettings, requireAuth, requireRole, round2, str, type Caller, type Json } from '../lib/util.js';
import { cancelOrderTx, computeQuote, createOrder, evaluateCoupon, isValidCouponCode, type Line, type QuoteInput } from './engine.js';
import { createPayment, type Provider } from '../payments/providers.js';

const SPEEDS = ['standard', 'quick15', 'quick30', 'scheduled'] as const;
const DELIVERY_TYPES = ['home', 'pickup'] as const;
const METHODS = ['cod', 'razorpay', 'stripe', 'paypal', 'wallet'] as const;
const CHANNELS = ['web', 'app', 'pos'] as const;

async function cartLines(uid: string): Promise<Line[]> {
  const s = await db.collection(`users/${uid}/cart`).get();
  return s.docs.map((d) => {
    const x = d.data();
    return { productId: String(x.productId ?? d.id.split('_')[0]), variantId: String(x.variantId ?? 'default'), qty: Math.max(0, Math.min(99, Math.floor(Number(x.qty) || 0))), addonIds: Array.isArray(x.addonIds) ? x.addonIds.map(String).slice(0, 10) : [] };
  }).filter((l) => l.productId && l.qty > 0);
}

function parseQuoteInput(uid: string, d: Json, lines: Line[]): QuoteInput {
  const slot = d.scheduledSlot && typeof d.scheduledSlot === 'object'
    ? { date: str(d.scheduledSlot.date, 'scheduledSlot.date', { max: 10 }), from: str(d.scheduledSlot.from, 'scheduledSlot.from', { max: 5 }), to: str(d.scheduledSlot.to, 'scheduledSlot.to', { max: 5 }) }
    : null;
  return {
    uid, lines,
    addressId: str(d.addressId, 'addressId', { required: false, max: 128 }) || null,
    couponCode: str(d.couponCode, 'couponCode', { required: false, max: 40 }) || null,
    useWallet: d.useWallet === true,
    speed: oneOf(d.speed, 'speed', SPEEDS, 'standard'),
    deliveryType: oneOf(d.deliveryType, 'deliveryType', DELIVERY_TYPES, 'home'),
    scheduledSlot: slot,
  };
}

/** getCheckoutQuote — {addressId?, couponCode?, useWallet, speed, deliveryType, scheduledSlot?} → quote (uses the caller's cart). */
export const getCheckoutQuote = onCall(async (req) => {
  const c = requireAuth(req, true);
  const lines = await cartLines(c.uid);
  const { quote } = await computeQuote(parseQuoteInput(c.uid, req.data ?? {}, lines));
  return quote;
});

/** placeOrder — quote input + {paymentMethod, scheduledSlot?, channel, notes?} → {orderId, orderNo, payable, payment?}. */
export const placeOrder = onCall({ secrets: PAYMENT_SECRETS, timeoutSeconds: 60 }, async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  const paymentMethod = oneOf(d.paymentMethod, 'paymentMethod', METHODS);
  const channel = oneOf(d.channel, 'channel', CHANNELS, 'app');
  if (channel === 'pos') fail('invalid-argument', 'Use posCheckout for POS orders.');
  const notes = str(d.notes, 'notes', { required: false, max: 500 }) || null;
  const lines = await cartLines(c.uid);
  if (!lines.length) fail('failed-precondition', 'Your cart is empty.');
  const settings = await platformSettings();
  if (settings.maintenance === true) fail('unavailable', String(settings.maintenanceMessage || 'We are under maintenance. Please try again shortly.'));

  const { orderId, orderNo, quote, order } = await createOrder({
    input: parseQuoteInput(c.uid, d, lines), paymentMethod, channel, clearCart: true, extra: { notes },
  });
  const res: Json = { orderId, orderNo, total: quote.total, payable: order.payable, walletUsed: quote.walletUsed, status: order.status, paymentMethod: order.paymentMethod };

  if (order.status === 'pending') {
    try {
      const payment = await createPayment(order.paymentMethod as Provider, {
        kind: 'order', refId: orderId, refNo: orderNo, amountInr: order.payable, uid: c.uid, customer: order.customer, fx: settings.fx,
      });
      await db.doc(`orders/${orderId}`).update({
        gateway: { provider: payment.provider, id: payment.razorpayOrderId ?? payment.sessionId ?? payment.paypalOrderId, currency: payment.currency, amount: payment.amount },
        updatedAt: now(),
      });
      res.payment = payment;
    } catch (e) {
      logger.error('payment init failed, releasing order', { orderId, error: String(e) });
      await db.runTransaction((tx) => cancelOrderTx(tx, db.doc(`orders/${orderId}`), 'system', 'Payment could not be started'));
      throw e;
    }
  }
  return res;
});

/** validateCoupon — {code, subtotal} → {valid, discount, message}. */
export const validateCoupon = onCall(async (req) => {
  const c = requireAuth(req, true);
  const code = str(req.data?.code, 'code', { max: 40 }).toUpperCase();
  if (!isValidCouponCode(code)) return { valid: false, discount: 0, message: 'Invalid coupon code.', code };
  const subtotal = num(req.data?.subtotal, 'subtotal', { min: 0, max: 10_000_000 });
  const settings = await platformSettings();
  const [snap, usage] = await Promise.all([db.doc(`coupons/${code}`).get(), db.doc(`coupons/${code}/usages/${c.uid}`).get()]);
  // Seller-specific coupons are evaluated against the caller's cart.
  let items: Json[] = [{ sellerId: null, price: subtotal, qty: 1 }];
  if (snap.get('sellerId')) {
    const { quote } = await computeQuote({ uid: c.uid, lines: await cartLines(c.uid) });
    items = quote.items;
  }
  const deliveryFee = subtotal >= Number(settings.freeDeliveryAbove || Infinity) ? 0 : Number(settings.deliveryFee || 0);
  const r = evaluateCoupon(snap, items, subtotal, deliveryFee, Number(usage.get('count') ?? 0));
  return { valid: !r.error, discount: r.discount, message: r.error ?? r.message, code };
});

// ───────────────────────── Status machine
const HOME_FLOW = ['placed', 'confirmed', 'packed', 'assigned', 'picked_up', 'out_for_delivery', 'delivered'];
const PICKUP_FLOW = ['placed', 'confirmed', 'packed', 'ready_for_pickup', 'delivered'];
const ALL_STATUSES = ['confirmed', 'packed', 'assigned', 'picked_up', 'out_for_delivery', 'ready_for_pickup', 'delivered', 'cancelled'] as const;

function checkTransition(c: Caller, o: Json, next: string) {
  const flow = o.deliveryType === 'pickup' ? PICKUP_FLOW : HOME_FLOW;
  const cur = String(o.status);
  if (['delivered', 'cancelled', 'returned'].includes(cur)) fail('failed-precondition', `Order is already ${cur}.`);
  if (next === 'cancelled') {
    if (c.role === 'customer' || (c.role !== 'admin' && o.userId === c.uid && !(o.sellerIds ?? []).includes(c.uid))) {
      if (o.userId !== c.uid) fail('permission-denied', 'Not your order.');
      if (!['pending', 'placed', 'confirmed'].includes(cur)) fail('failed-precondition', 'This order can no longer be cancelled. Please contact support.');
      return;
    }
    if (c.role === 'seller' && !(o.sellerIds ?? []).includes(c.uid)) fail('permission-denied', 'This order has none of your items.');
    if (c.role === 'delivery') fail('permission-denied', 'Delivery partners cannot cancel orders.');
    return;
  }
  if (cur === 'pending') fail('failed-precondition', 'Order is awaiting payment.');
  if (!flow.includes(next)) fail('invalid-argument', `Status ${next} is not valid for a ${o.deliveryType} order.`);
  if (next === 'assigned') fail('invalid-argument', 'Use assignDeliveryPartner or acceptDelivery to assign a rider.');
  const ci = flow.indexOf(cur), ni = flow.indexOf(next);
  if (ni <= ci) fail('failed-precondition', `Cannot move from ${cur} to ${next}.`);
  if (c.role === 'admin') {
    if (o.deliveryType === 'home' && ni > flow.indexOf('assigned') && !o.deliveryPartnerId) fail('failed-precondition', 'Assign a delivery partner first.');
    return;
  }
  if (ni !== ci + 1) fail('failed-precondition', `Next status must be ${flow[ci + 1]}.`);
  if (c.role === 'seller') {
    if (!(o.sellerIds ?? []).includes(c.uid)) fail('permission-denied', 'This order has none of your items.');
    if (!['confirmed', 'packed', 'ready_for_pickup', 'delivered'].includes(next)) fail('permission-denied', 'The delivery partner updates this status.');
    if (next === 'delivered' && o.deliveryType !== 'pickup') fail('permission-denied', 'The delivery partner marks home deliveries as delivered.');
    return;
  }
  if (c.role === 'delivery') {
    if (o.deliveryPartnerId !== c.uid) fail('permission-denied', 'This order is not assigned to you.');
    if (!['picked_up', 'out_for_delivery', 'delivered'].includes(next)) fail('permission-denied', 'Only the store can update this status.');
    return;
  }
  fail('permission-denied', 'You cannot change this order.');
}

/** updateOrderStatus — {orderId, status, note?, otp?, cashCollected?} → {ok, status}. */
export const updateOrderStatus = onCall(async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  const orderId = str(d.orderId, 'orderId', { max: 128 });
  const next = oneOf(d.status, 'status', ALL_STATUSES);
  const note = str(d.note, 'note', { required: false, max: 500 }) || null;
  const orderRef = db.doc(`orders/${orderId}`);

  if (next === 'cancelled') {
    await db.runTransaction(async (tx) => {
      const pre = await tx.get(orderRef);
      if (!pre.exists) fail('not-found', 'Order not found.');
      checkTransition(c, pre.data()!, 'cancelled');
      await cancelOrderTx(tx, orderRef, c.uid, note ?? `Cancelled by ${c.role}`);
    });
    return { ok: true, status: 'cancelled' };
  }

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) fail('not-found', 'Order not found.');
    const o = snap.data()!;
    checkTransition(c, o, next);
    const update: Json = {
      status: next,
      timeline: FieldValue.arrayUnion({ status: next, at: Timestamp.now(), by: c.uid, note: note ?? '' }),
      updatedAt: now(),
    };
    if (next === 'out_for_delivery') update.outForDeliveryAt = now();
    if (next === 'picked_up') update.pickedUpAt = now();

    if (next === 'delivered') {
      if (c.role !== 'admin' && o.deliveryOtp) {
        const otp = str(d.otp, 'otp', { max: 8 });
        if (otp !== String(o.deliveryOtp)) fail('permission-denied', 'Incorrect delivery OTP.');
      }
      const sellerIds: string[] = o.sellerIds ?? [];
      const sellerSnaps = sellerIds.length ? await tx.getAll(...sellerIds.map((id) => db.doc(`sellers/${id}`))) : [];
      const partnerSnap = o.deliveryPartnerId ? await tx.get(db.doc(`deliveryPartners/${o.deliveryPartnerId}`)) : null;
      const settings = await platformSettings();

      const settlement: Json = { sellers: {}, delivery: null };
      for (const s of sellerSnaps) {
        if (!s.exists) continue;
        const items = (o.items as Json[]).filter((i) => i.sellerId === s.id);
        const gross = round2(items.reduce((a, i) => a + Number(i.price) * Number(i.qty), 0));
        const pct = Number(s.get('commissionPct') ?? 10);
        const commission = round2((gross * pct) / 100);
        const couponShare = o.couponSellerId === s.id ? round2(Number(o.couponDiscount || 0)) : 0;
        const net = round2(Math.max(0, gross - commission - couponShare));
        settlement.sellers[s.id] = { gross, commissionPct: pct, commission, couponShare, net };
        tx.update(s.ref, { balance: FieldValue.increment(net), totalSales: FieldValue.increment(gross), orderCount: FieldValue.increment(1), updatedAt: now() });
      }
      const isCod = o.paymentMethod === 'cod';
      const cash = isCod ? round2(d.cashCollected === undefined || d.cashCollected === null ? Number(o.payable) : num(d.cashCollected, 'cashCollected', { min: 0, max: 1_000_000 })) : 0;
      if (partnerSnap?.exists) {
        // Rider pay: own salary {type, amount} or settings.riderPay {type, amount, perKm, bonusPct}.
        const rp: Json = settings.riderPay ?? {};
        const sal = (partnerSnap.get('salary') as Json) ?? { type: rp.type ?? 'per_order', amount: rp.amount ?? settings.deliveryPerOrderDefault };
        const base = sal.type === 'monthly' ? 0 : Number(sal.amount ?? rp.amount ?? settings.deliveryPerOrderDefault ?? 30);
        const earning = round2(base + Number(rp.perKm ?? 0) * Number(o.distanceKm ?? 0) + (Number(rp.bonusPct ?? 0) / 100) * Number(o.deliveryFee ?? 0));
        settlement.delivery = { partnerId: partnerSnap.id, earning, cash };
        tx.update(partnerSnap.ref, {
          balance: FieldValue.increment(earning), cashInHand: FieldValue.increment(cash), completedCount: FieldValue.increment(1),
          activeOrders: FieldValue.arrayRemove(orderId), updatedAt: now(),
        });
        if (cash > 0) {
          tx.set(db.collection('cashCollections').doc(), {
            deliveryPartnerId: partnerSnap.id, orderId, orderNo: o.orderNo, amount: cash, status: 'collected', createdAt: now(), updatedAt: now(),
          });
        }
      }
      Object.assign(update, {
        deliveredAt: now(), settlement, cashCollected: cash,
        paymentStatus: isCod || o.paymentMethod === 'wallet' ? 'paid' : o.paymentStatus,
        paymentRef: isCod ? o.paymentRef ?? (o.deliveryType === 'pickup' ? 'cash-at-store' : 'cash-on-delivery') : o.paymentRef,
      });
    }
    tx.update(orderRef, update);
  });
  return { ok: true, status: next };
});

/** assignDeliveryPartner — admin/seller: {orderId, partnerId?} (null = nearest online) → {partnerId, partnerName, distanceKm?}. */
export const assignDeliveryPartner = onCall(async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const orderId = str(req.data?.orderId, 'orderId', { max: 128 });
  const wanted = str(req.data?.partnerId, 'partnerId', { required: false, max: 128 }) || null;
  return assignPartner(c, orderId, wanted);
});

/** Shared by assignDeliveryPartner and the settings.autoAssign trigger. `wanted` null = nearest online approved rider. */
export async function assignPartner(c: { uid: string; role: string }, orderId: string, wanted: string | null): Promise<{ partnerId: string; partnerName: string; distanceKm?: number }> {
  const orderRef = db.doc(`orders/${orderId}`);
  const pre = await orderRef.get();
  if (!pre.exists) fail('not-found', 'Order not found.');
  const o = pre.data()!;
  if (c.role === 'seller' && !(o.sellerIds ?? []).includes(c.uid)) fail('permission-denied', 'This order has none of your items.');
  if (o.deliveryType !== 'home') fail('failed-precondition', 'Pickup orders do not need a rider.');
  if (!['confirmed', 'packed', 'assigned'].includes(o.status)) fail('failed-precondition', `Cannot assign a rider while the order is ${o.status}.`);

  let partnerId = wanted;
  let distanceKm: number | undefined;
  if (!partnerId) {
    const store = o.sellerIds?.[0] ? (await db.doc(`sellers/${o.sellerIds[0]}`).get()).data() : null;
    const origin = isNum(store?.lat) && isNum(store?.lng) ? { lat: store!.lat, lng: store!.lng } : isNum(o.address?.lat) ? { lat: o.address.lat, lng: o.address.lng } : null;
    const snap = await db.collection('deliveryPartners').where('status', '==', 'approved').where('online', '==', true).limit(200).get();
    const city = String(o.address?.city ?? '').toLowerCase();
    const candidates = snap.docs
      .map((s) => ({ id: s.id, ...s.data() } as Json))
      .filter((p) => p.ownerType !== 'seller' || (o.sellerIds ?? []).includes(p.sellerId))
      .filter((p) => !city || !Array.isArray(p.cities) || !p.cities.length || p.cities.some((x: string) => x.toLowerCase() === city))
      .map((p): Json => ({ ...p, dist: origin && isNum(p.lat) && isNum(p.lng) ? haversineKm(origin.lat, origin.lng, p.lat, p.lng) : 9999 }))
      // Prefer the seller's own fleet, then nearest.
      .sort((a, b) => Number(b.ownerType === 'seller') - Number(a.ownerType === 'seller') || a.dist - b.dist);
    if (!candidates.length) fail('not-found', 'No online delivery partner is available right now.');
    partnerId = candidates[0].id;
    distanceKm = candidates[0].dist === 9999 ? undefined : round2(candidates[0].dist);
  }

  const name = await db.runTransaction(async (tx) => {
    const [os, ps] = await tx.getAll(orderRef, db.doc(`deliveryPartners/${partnerId}`));
    if (!ps.exists || ps.get('status') !== 'approved') fail('failed-precondition', 'Delivery partner is not approved.');
    const p = ps.data()!;
    if (c.role === 'seller' && p.ownerType === 'seller' && p.sellerId !== c.uid) fail('permission-denied', 'This rider belongs to another store.');
    const ord = os.data()!;
    if (!['confirmed', 'packed', 'assigned'].includes(ord.status)) fail('failed-precondition', `Cannot assign a rider while the order is ${ord.status}.`);
    if (ord.deliveryPartnerId && ord.deliveryPartnerId !== partnerId) {
      tx.update(db.doc(`deliveryPartners/${ord.deliveryPartnerId}`), { activeOrders: FieldValue.arrayRemove(orderId) });
    }
    tx.update(orderRef, {
      deliveryPartnerId: partnerId, deliveryPartnerName: p.name ?? '', deliveryPartnerPhone: p.phone ?? '',
      status: 'assigned', assignedAt: now(),
      timeline: FieldValue.arrayUnion({ status: 'assigned', at: Timestamp.now(), by: c.uid, note: `Assigned to ${p.name ?? 'rider'}` }),
      updatedAt: now(),
    });
    tx.update(ps.ref, { activeOrders: FieldValue.arrayUnion(orderId), updatedAt: now() });
    return p.name ?? '';
  });
  return { partnerId: partnerId!, partnerName: name, distanceKm };
}

/** acceptDelivery — delivery: {orderId} → {ok}. Self-assign from the pool (status confirmed/packed, no rider yet). */
export const acceptDelivery = onCall(async (req) => {
  const c = requireRole(req, 'delivery');
  const orderId = str(req.data?.orderId, 'orderId', { max: 128 });
  await db.runTransaction(async (tx) => {
    const [os, ps] = await tx.getAll(db.doc(`orders/${orderId}`), db.doc(`deliveryPartners/${c.uid}`));
    if (!os.exists) fail('not-found', 'Order not found.');
    if (!ps.exists || ps.get('status') !== 'approved') fail('failed-precondition', 'Your partner account is not approved yet.');
    const o = os.data()!, p = ps.data()!;
    if (o.deliveryType !== 'home') fail('failed-precondition', 'Pickup orders do not need a rider.');
    if (o.deliveryPartnerId) fail('already-exists', 'Another rider already accepted this order.');
    if (!['confirmed', 'packed'].includes(o.status)) fail('failed-precondition', `Order is ${o.status}.`);
    if (p.ownerType === 'seller' && !(o.sellerIds ?? []).includes(p.sellerId)) fail('permission-denied', 'You can only accept orders from your store.');
    const city = String(o.address?.city ?? '').toLowerCase();
    if (city && Array.isArray(p.cities) && p.cities.length && !p.cities.some((x: string) => x.toLowerCase() === city)) fail('permission-denied', 'This order is outside your service cities.');
    tx.update(os.ref, {
      deliveryPartnerId: c.uid, deliveryPartnerName: p.name ?? '', deliveryPartnerPhone: p.phone ?? '', status: 'assigned', assignedAt: now(),
      timeline: FieldValue.arrayUnion({ status: 'assigned', at: Timestamp.now(), by: c.uid, note: `Accepted by ${p.name ?? 'rider'}` }),
      updatedAt: now(),
    });
    tx.update(ps.ref, { activeOrders: FieldValue.arrayUnion(orderId), updatedAt: now() });
  });
  return { ok: true };
});

/** posCheckout — admin/seller: {items:[{productId|barcode, variantId?, qty}], customer?, paymentMethod(cash/card/upi), discount} → {orderId, orderNo, total}. */
export const posCheckout = onCall(async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const d = req.data ?? {};
  const method = oneOf(d.paymentMethod, 'paymentMethod', ['cash', 'card', 'upi'] as const);
  const posDiscount = num(d.discount ?? 0, 'discount', { min: 0, max: 1_000_000 });
  if (!Array.isArray(d.items) || !d.items.length) fail('invalid-argument', 'items are required.');
  if (d.items.length > 100) fail('invalid-argument', 'Too many items (max 100).');
  const lines: Line[] = [];
  for (const [i, it] of (d.items as Json[]).entries()) {
    let productId = str(it.productId, `items[${i}].productId`, { required: false, max: 128 });
    if (!productId) {
      const barcode = str(it.barcode, `items[${i}].barcode`, { max: 64 });
      const q = await db.collection('products').where('barcode', '==', barcode).limit(5).get();
      const match = q.docs.find((x) => c.role === 'admin' || x.get('sellerId') === c.uid) ?? (q.docs.length ? null : undefined);
      if (!match) fail('not-found', `No product with barcode ${barcode}.`);
      productId = match.id;
    }
    lines.push({ productId, variantId: str(it.variantId, 'variantId', { required: false, max: 64 }) || 'default', qty: num(it.qty, `items[${i}].qty`, { min: 1, max: 999, int: true }) });
  }
  if (c.role === 'seller') {
    const snaps = await db.getAll(...[...new Set(lines.map((l) => l.productId))].map((id) => db.doc(`products/${id}`)));
    if (snaps.some((s) => s.exists && s.get('sellerId') !== c.uid)) fail('permission-denied', 'You can only sell your own products at the POS.');
  }
  const cust = (d.customer ?? {}) as Json;
  const customer = {
    name: str(cust.name, 'customer.name', { required: false, max: 100 }) || 'Walk-in customer',
    phone: str(cust.phone, 'customer.phone', { required: false, max: 20 }),
    email: str(cust.email, 'customer.email', { required: false, max: 120 }),
  };
  const r = await createOrder({
    input: { uid: c.uid, lines, deliveryType: 'pickup', speed: 'standard', useWallet: false },
    paymentMethod: 'cod', channel: 'pos', status: 'delivered',
    extra: (q) => {
      const disc = round2(Math.min(posDiscount, q.subtotal));
      const total = round2(q.subtotal - disc + q.tax);
      return {
        userId: 'pos', cashierId: c.uid, customer, paymentMethod: method, paymentStatus: 'paid', paymentRef: `pos-${method}`,
        discount: round2(q.discount + disc), posDiscount: disc, total, payable: total, deliveryOtp: null, deliveredAt: now(),
        timeline: [{ status: 'delivered', at: Timestamp.now(), by: c.uid, note: `POS sale (${method})` }],
      };
    },
  });
  return { orderId: r.orderId, orderNo: r.orderNo, total: r.order.total, subtotal: r.quote.subtotal, discount: r.order.discount, items: r.quote.items };
});
