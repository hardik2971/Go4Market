// Shared order engine: quote computation, order creation and cancellation/release.
// Prices, stock, coupons and wallet are always recomputed from Firestore — never trusted from the client.
import type { Transaction, DocumentSnapshot, DocumentReference } from 'firebase-admin/firestore';
import { db, FieldValue, Timestamp, now } from '../lib/admin.js';
import { applyWallet } from '../lib/wallet.js';
import { fail, haversineKm, isNum, platformSettings, randomDigits, round2, type Json } from '../lib/util.js';

export type Speed = 'standard' | 'quick15' | 'quick30' | 'scheduled';
export type DeliveryType = 'home' | 'pickup';
export interface Line { productId: string; variantId: string; qty: number; addonIds?: string[] }

export interface QuoteInput {
  uid: string;
  lines: Line[];
  addressId?: string | null;
  couponCode?: string | null;
  useWallet?: boolean;
  speed?: Speed;
  deliveryType?: DeliveryType;
  scheduledSlot?: { date: string; from: string; to: string } | null;
}

export interface Unavailable { itemId: string; productId: string; variantId: string; name: string; reason: 'not_found' | 'inactive' | 'out_of_stock' | 'insufficient_stock' | 'invalid_variant'; available: number }

export interface Quote {
  subtotal: number; mrpTotal: number; deliveryFee: number; discount: number; couponDiscount: number; membershipDiscount: number;
  walletUsed: number; walletBalance: number; tax: number; total: number; payable: number;
  distanceKm: number; etaMinutes: number; itemCount: number;
  couponCode: string | null; couponError?: string; speedError?: string; minOrderError?: string; outOfRange?: boolean;
  unavailable: Unavailable[];
  items: Json[];
  codAllowed: boolean;
}

export interface QuoteContext {
  quote: Quote;
  userSnap: DocumentSnapshot;
  productSnaps: Map<string, DocumentSnapshot>;
  sellerSnaps: Map<string, DocumentSnapshot>;
  couponSnap: DocumentSnapshot | null;
  couponUsageSnap: DocumentSnapshot | null;
  address: Json | null;
  settings: Json;
  speed: Speed;
  deliveryType: DeliveryType;
}

const MODULE_DEFAULT_MINUTES: Record<string, number> = { grocery: 30, food: 35, pharmacy: 45, ecommerce: 2880 };

type Getter = <T extends DocumentSnapshot>(ref: DocumentReference) => Promise<T>;

function getterFor(tx?: Transaction | null) {
  const get: Getter = (ref) => (tx ? tx.get(ref) : ref.get()) as any;
  const getAll = async (refs: DocumentReference[]): Promise<DocumentSnapshot[]> =>
    !refs.length ? [] : tx ? tx.getAll(...refs) : db.getAll(...refs);
  return { get, getAll };
}

/** Resolves a product line's price/stock for a variant (or the base product when it has no variants). */
export function resolveVariant(p: Json, variantId: string): { v: Json | null; price: number; mrp: number; stock: number; name: string; ok: boolean } {
  const variants: Json[] = Array.isArray(p.variants) ? p.variants : [];
  if (!variants.length) {
    return { v: null, price: Number(p.price) || 0, mrp: Number(p.mrp ?? p.price) || 0, stock: Number(p.stock) || 0, name: '', ok: variantId === 'default' || !variantId };
  }
  const v = variants.find((x) => x.id === variantId) ?? (variantId === 'default' || !variantId ? variants[0] : null);
  if (!v) return { v: null, price: 0, mrp: 0, stock: 0, name: '', ok: false };
  return { v, price: Number(v.price) || 0, mrp: Number(v.mrp ?? v.price) || 0, stock: Number(v.stock) || 0, name: String(v.name ?? ''), ok: true };
}

export async function computeQuote(input: QuoteInput, tx?: Transaction | null): Promise<QuoteContext> {
  const { get, getAll } = getterFor(tx);
  const settings = await platformSettings();
  const speed: Speed = input.speed ?? 'standard';
  const deliveryType: DeliveryType = input.deliveryType ?? 'home';

  // Merge duplicate lines.
  const merged = new Map<string, Line>();
  for (const l of input.lines) {
    const addonIds = [...new Set((l.addonIds ?? []).map(String))].sort();
    const key = `${l.productId}_${l.variantId || 'default'}_${addonIds.join('+')}`;
    const prev = merged.get(key);
    merged.set(key, { productId: l.productId, variantId: l.variantId || 'default', qty: (prev?.qty ?? 0) + l.qty, addonIds });
  }
  const lines = [...merged.values()].filter((l) => l.qty > 0);
  if (lines.length > 100) fail('invalid-argument', 'Too many items in the cart (max 100).');

  const userRef = db.doc(`users/${input.uid}`);
  const productIds = [...new Set(lines.map((l) => l.productId))];
  const [userSnap, ...pSnaps] = await getAll([userRef, ...productIds.map((id) => db.doc(`products/${id}`))]);
  const productSnaps = new Map(pSnaps.map((s) => [s.id, s]));

  const items: Json[] = [];
  const unavailable: Unavailable[] = [];
  const reserved = new Map<string, number>(); // productId_variant -> qty already used (for duplicate variants)
  for (const l of lines) {
    const snap = productSnaps.get(l.productId);
    const itemId = `${l.productId}_${l.variantId}`;
    const p = snap?.data();
    if (!snap?.exists || !p) { unavailable.push({ itemId, productId: l.productId, variantId: l.variantId, name: '', reason: 'not_found', available: 0 }); continue; }
    if (p.status !== 'active') { unavailable.push({ itemId, productId: l.productId, variantId: l.variantId, name: p.name, reason: 'inactive', available: 0 }); continue; }
    const r = resolveVariant(p, l.variantId);
    if (!r.ok) { unavailable.push({ itemId, productId: l.productId, variantId: l.variantId, name: p.name, reason: 'invalid_variant', available: 0 }); continue; }
    const vid = r.v ? String(r.v.id) : 'default';
    const used = reserved.get(`${l.productId}_${vid}`) ?? 0;
    const avail = Math.max(0, r.stock - used);
    if (avail <= 0) { unavailable.push({ itemId, productId: l.productId, variantId: vid, name: p.name, reason: 'out_of_stock', available: 0 }); continue; }
    if (avail < l.qty) { unavailable.push({ itemId, productId: l.productId, variantId: vid, name: p.name, reason: 'insufficient_stock', available: avail }); continue; }
    reserved.set(`${l.productId}_${vid}`, used + l.qty);
    const path: string[] = Array.isArray(p.categoryPath) ? p.categoryPath : [];
    const productAddons: Json[] = Array.isArray(p.addons) ? p.addons : [];
    const addons = (l.addonIds ?? []).map((id) => productAddons.find((a) => String(a.id) === id && a.active !== false)).filter(Boolean) as Json[];
    if (addons.length !== (l.addonIds ?? []).length) { unavailable.push({ itemId, productId: l.productId, variantId: vid, name: p.name, reason: 'invalid_variant', available: avail }); continue; }
    const addonTotal = addons.reduce((a, x) => a + (Number(x.price) || 0), 0);
    items.push({
      productId: l.productId, variantId: vid, name: p.name, variantName: r.name, image: (p.images ?? [])[0] ?? '',
      addons: addons.map((a) => ({ id: String(a.id), name: String(a.name), price: round2(Number(a.price) || 0) })), basePrice: round2(r.price),
      price: round2(r.price + addonTotal), mrp: round2(Math.max(r.mrp + addonTotal, r.price + addonTotal)), qty: l.qty, sellerId: p.sellerId, sellerName: p.sellerName ?? '',
      moduleId: p.moduleId ?? 'ecommerce', categoryId: p.categoryId ?? '', rootCategoryId: path[0] ?? p.categoryId ?? '', unit: p.unit ?? '',
      sku: r.v?.sku ?? p.barcode ?? '', deliveryMinutes: Number(p.deliveryMinutes) || MODULE_DEFAULT_MINUTES[p.moduleId] || 45,
    });
  }

  const sellerIds = [...new Set(items.map((i) => String(i.sellerId)).filter(Boolean))];
  const sellerSnapsArr = await getAll(sellerIds.map((id) => db.doc(`sellers/${id}`)));
  const sellerSnaps = new Map(sellerSnapsArr.map((s) => [s.id, s]));

  // Address
  let address: Json | null = null;
  if (deliveryType === 'home') {
    let addrSnap: DocumentSnapshot | null = null;
    if (input.addressId) addrSnap = await get(db.doc(`users/${input.uid}/addresses/${input.addressId}`));
    else if (userSnap.get('defaultAddressId')) addrSnap = await get(db.doc(`users/${input.uid}/addresses/${userSnap.get('defaultAddressId')}`));
    if (addrSnap?.exists) address = { id: addrSnap.id, ...addrSnap.data() };
    if (input.addressId && !address) fail('not-found', 'Delivery address not found.');
  }

  const subtotal = round2(items.reduce((a, i) => a + i.price * i.qty, 0));
  const mrpTotal = round2(items.reduce((a, i) => a + i.mrp * i.qty, 0));
  const itemCount = items.reduce((a, i) => a + i.qty, 0);

  // Distance = farthest seller store from the address.
  let distanceKm = 0;
  if (address && isNum(address.lat) && isNum(address.lng)) {
    for (const s of sellerSnaps.values()) {
      const lat = s.get('lat'), lng = s.get('lng');
      if (isNum(lat) && isNum(lng)) distanceKm = Math.max(distanceKm, haversineKm(lat, lng, address.lat, address.lng));
    }
  }
  distanceKm = round2(distanceKm);
  const outOfRange = deliveryType === 'home' && distanceKm > Number(settings.maxDeliveryKm || 25);

  // Membership benefits
  const membership = userSnap.get('membership') as Json | undefined;
  const memberActive = !!membership?.expiresAt && (membership.expiresAt as Timestamp).toMillis?.() > Date.now();
  const memberFreeDelivery = memberActive && !!membership?.freeDelivery;
  const memberDiscountPct = memberActive ? Number(membership?.discountPct) || 0 : 0;

  // Delivery fee
  let deliveryFee = 0;
  let speedError: string | undefined;
  if (deliveryType === 'pickup') {
    if (settings.pickupEnabled === false) speedError = 'Self pickup is not available right now.';
  } else if (items.length) {
    const free = subtotal >= Number(settings.freeDeliveryAbove || Infinity) || memberFreeDelivery;
    const extraKm = Math.max(0, distanceKm - Number(settings.baseKm ?? 3));
    deliveryFee = free ? 0 : Number(settings.deliveryFee || 0) + Math.ceil(extraKm) * Number(settings.perKmFee || 0);
    if (speed === 'quick15' || speed === 'quick30') {
      const enabled = speed === 'quick15' ? settings.quick15Enabled : settings.quick30Enabled;
      const maxKm = Number(speed === 'quick15' ? settings.quick15MaxKm ?? 4 : settings.quick30MaxKm ?? 8);
      if (enabled === false) speedError = 'Quick delivery is not available right now.';
      else if (distanceKm > maxKm) speedError = `Quick delivery is available within ${maxKm} km only.`;
      else if (items.some((i) => i.moduleId === 'ecommerce')) speedError = 'Quick delivery is available for grocery, food and pharmacy items only.';
      deliveryFee += Number(settings.quickDeliveryFee || 0);
    }
    if (speed === 'scheduled' && settings.scheduledEnabled === false) speedError = 'Scheduled delivery is not available right now.';
  }
  deliveryFee = round2(deliveryFee);

  // Coupon
  let couponSnap: DocumentSnapshot | null = null;
  let couponUsageSnap: DocumentSnapshot | null = null;
  let couponDiscount = 0;
  let couponError: string | undefined;
  const code = (input.couponCode ?? '').trim().toUpperCase() || null;
  if (code && !isValidCouponCode(code)) couponError = 'Invalid coupon code.';
  else if (code) {
    couponSnap = await get(db.doc(`coupons/${code}`));
    couponUsageSnap = await get(db.doc(`coupons/${code}/usages/${input.uid}`));
    const r = evaluateCoupon(couponSnap, items, subtotal, deliveryFee, Number(couponUsageSnap.get('count') ?? 0));
    couponDiscount = r.discount;
    couponError = r.error;
  }
  const membershipDiscount = round2(memberDiscountPct > 0 ? (subtotal * memberDiscountPct) / 100 : 0);
  const discount = round2(Math.min(subtotal + deliveryFee, couponDiscount + membershipDiscount));

  const taxPct = Number(settings.taxPct || 0);
  const tax = round2(Math.max(0, subtotal - discount) * taxPct / 100);
  const total = round2(Math.max(0, subtotal + deliveryFee - discount + tax));
  const walletBalance = round2(Number(userSnap.get('walletBalance') ?? 0));
  const walletUsed = input.useWallet && settings.walletEnabled !== false ? round2(Math.min(walletBalance, total)) : 0;
  const payable = round2(total - walletUsed);

  // ETA
  let etaMinutes: number;
  if (deliveryType === 'pickup') etaMinutes = Math.min(30, Math.max(15, ...items.map((i) => Math.min(i.deliveryMinutes, 30))));
  else if (speed === 'quick15') etaMinutes = 15;
  else if (speed === 'quick30') etaMinutes = 30;
  else if (speed === 'scheduled' && input.scheduledSlot?.date) {
    const start = slotStart(input.scheduledSlot);
    etaMinutes = start ? Math.max(0, Math.round((start.getTime() - Date.now()) / 60000)) : 0;
  } else etaMinutes = Math.round(Math.max(30, ...items.map((i) => i.deliveryMinutes)) + distanceKm * 3);

  const minOrder = Number(settings.minOrder || 0);
  const quote: Quote = {
    subtotal, mrpTotal, deliveryFee, discount, couponDiscount, membershipDiscount, walletUsed, walletBalance, tax, total, payable,
    distanceKm, etaMinutes, itemCount, couponCode: couponError ? null : code, couponError, speedError,
    minOrderError: items.length && subtotal < minOrder ? `Minimum order value is ₹${minOrder}.` : undefined,
    outOfRange: outOfRange || undefined,
    unavailable, items: items.map(({ deliveryMinutes, ...rest }) => rest),
    codAllowed: settings.codEnabled !== false && payable <= Number(settings.codMax || Infinity),
  };
  return { quote, userSnap, productSnaps, sellerSnaps, couponSnap, couponUsageSnap, address, settings, speed, deliveryType };
}

/** Coupon codes double as document ids: A–Z, 0–9, _ and - only, and never the reserved __x__ form. */
export const isValidCouponCode = (c: string) => /^[A-Z0-9_-]{2,40}$/.test(c) && !/^__.*__$/.test(c);

export function slotStart(slot: { date: string; from: string }): Date | null {
  // date yyyy-MM-dd, from HH:mm in IST
  if (!/^\d{4}-\d{2}-\d{2}$/.test(slot.date) || !/^\d{2}:\d{2}$/.test(slot.from)) return null;
  const d = new Date(`${slot.date}T${slot.from}:00+05:30`);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function evaluateCoupon(
  snap: DocumentSnapshot | null, items: Json[], subtotal: number, deliveryFee: number, userUses: number,
): { discount: number; error?: string; message?: string } {
  if (!snap?.exists) return { discount: 0, error: 'Invalid coupon code.' };
  const c = snap.data()!;
  const nowMs = Date.now();
  if (c.active === false) return { discount: 0, error: 'This coupon is no longer active.' };
  if (c.startAt?.toMillis && c.startAt.toMillis() > nowMs) return { discount: 0, error: 'This coupon is not active yet.' };
  if (c.endAt?.toMillis && c.endAt.toMillis() < nowMs) return { discount: 0, error: 'This coupon has expired.' };
  if (Number(c.usageLimit) > 0 && Number(c.usedCount ?? 0) >= Number(c.usageLimit)) return { discount: 0, error: 'This coupon has reached its usage limit.' };
  if (Number(c.perUserLimit) > 0 && userUses >= Number(c.perUserLimit)) return { discount: 0, error: 'You have already used this coupon.' };
  const eligible = c.sellerId ? round2(items.filter((i) => i.sellerId === c.sellerId).reduce((a, i) => a + i.price * i.qty, 0)) : subtotal;
  if (c.sellerId && eligible <= 0) return { discount: 0, error: 'This coupon is valid only on items from a specific store.' };
  if (eligible < Number(c.minOrder || 0)) return { discount: 0, error: `Add items worth ₹${round2(Number(c.minOrder) - eligible)} more to use this coupon.` };
  let d: number;
  if (c.freeDelivery) d = Math.min(deliveryFee, Number(c.value) || deliveryFee);
  else if (c.discountType === 'percent') d = (eligible * Number(c.value || 0)) / 100;
  else d = Number(c.value || 0);
  if (Number(c.maxDiscount) > 0) d = Math.min(d, Number(c.maxDiscount));
  d = round2(Math.max(0, Math.min(d, c.freeDelivery ? deliveryFee : eligible)));
  if (c.freeDelivery && d === 0) return { discount: 0, error: 'Delivery is already free on this order.' };
  return { discount: d, message: c.message || `Coupon applied: you save ₹${d}.` };
}

export interface CreateOrderOptions {
  input: QuoteInput;
  paymentMethod: 'cod' | 'razorpay' | 'stripe' | 'paypal' | 'wallet';
  channel: 'web' | 'app' | 'pos';
  extra?: Json | ((q: Quote) => Json); // merged into the order doc (e.g. notes, subscriptionId)
  clearCart?: boolean;
  status?: string; // override initial status
}

/** Creates an order inside a transaction: re-quotes, validates, reserves stock, debits wallet, bumps coupon & counter. */
export async function createOrder(opts: CreateOrderOptions): Promise<{ orderId: string; orderNo: string; quote: Quote; order: Json }> {
  const orderRef = db.collection('orders').doc();
  return db.runTransaction(async (tx) => {
    const ctx = await computeQuote(opts.input, tx);
    const counterSnap = await tx.get(db.doc('counters/orders'));
    const cartSnaps = opts.clearCart ? await tx.get(db.collection(`users/${opts.input.uid}/cart`)) : null;
    const q = ctx.quote;

    if (!q.items.length) fail('failed-precondition', 'Your cart is empty.', { unavailable: q.unavailable });
    if (q.unavailable.length) fail('failed-precondition', 'Some items are unavailable. Please review your cart.', { unavailable: q.unavailable });
    if (q.minOrderError && opts.channel !== 'pos') fail('failed-precondition', q.minOrderError);
    if (q.speedError) fail('failed-precondition', q.speedError);
    if (opts.input.couponCode && q.couponError) fail('failed-precondition', q.couponError);
    if (ctx.deliveryType === 'home' && opts.channel !== 'pos') {
      if (!ctx.address) fail('failed-precondition', 'Please add a delivery address.');
      if (q.outOfRange) fail('failed-precondition', `Sorry, this address is outside our ${ctx.settings.maxDeliveryKm} km delivery range.`);
    }
    if (ctx.speed === 'scheduled') {
      const s = opts.input.scheduledSlot;
      const start = s ? slotStart(s) : null;
      if (!s || !start) fail('invalid-argument', 'Pick a delivery slot (date yyyy-MM-dd, from/to HH:mm).');
      if (start.getTime() < Date.now() + 30 * 60_000) fail('failed-precondition', 'Please choose a slot at least 30 minutes from now.');
    }
    let method = opts.paymentMethod;
    if (q.payable <= 0) method = 'wallet';
    if (method === 'wallet' && q.payable > 0) fail('failed-precondition', 'Wallet balance is not enough. Choose another payment method for the rest.');
    if (method === 'cod' && !q.codAllowed) fail('failed-precondition', `Cash on delivery is not available for this order.`);

    // Reserve stock
    const perProduct = new Map<string, Json[]>();
    for (const it of q.items) perProduct.set(it.productId, [...(perProduct.get(it.productId) ?? []), it]);
    for (const [pid, its] of perProduct) {
      const snap = ctx.productSnaps.get(pid)!;
      const p = snap.data()!;
      const qty = its.reduce((a, i) => a + i.qty, 0);
      if (Array.isArray(p.variants) && p.variants.length) {
        const variants = p.variants.map((v: Json) => {
          const take = its.filter((i) => i.variantId === v.id).reduce((a, i) => a + i.qty, 0);
          return take ? { ...v, stock: Math.max(0, Number(v.stock) - take) } : v;
        });
        tx.update(snap.ref, { variants, stock: variants.reduce((a: number, v: Json) => a + (Number(v.stock) || 0), 0), soldCount: FieldValue.increment(qty), updatedAt: now() });
      } else {
        tx.update(snap.ref, { stock: Math.max(0, Number(p.stock) - qty), soldCount: FieldValue.increment(qty), updatedAt: now() });
      }
    }

    // Wallet
    if (q.walletUsed > 0) applyWallet(tx, ctx.userSnap, 'debit', q.walletUsed, 'order', orderRef.id, 'Paid for order');

    // Coupon usage
    if (q.couponCode && ctx.couponSnap?.exists) {
      tx.update(ctx.couponSnap.ref, { usedCount: FieldValue.increment(1) });
      tx.set(db.doc(`coupons/${q.couponCode}/usages/${opts.input.uid}`), { count: FieldValue.increment(1), lastOrderId: orderRef.id, updatedAt: now() }, { merge: true });
    }

    const seq = Number(counterSnap.get('seq') ?? 100000) + 1;
    tx.set(counterSnap.ref, { seq, updatedAt: now() }, { merge: true });
    const orderNo = `G4M${String(seq).padStart(6, '0').slice(-6)}`;

    const online = ['razorpay', 'stripe', 'paypal'].includes(method);
    const status = opts.status ?? (online ? 'pending' : 'placed');
    const u = ctx.userSnap.data() ?? {};
    const etaAt = Timestamp.fromMillis(Date.now() + q.etaMinutes * 60_000);
    const sellers = [...new Set(q.items.map((i) => i.sellerId))];
    const order: Json = {
      orderNo,
      userId: opts.input.uid,
      customer: { name: u.name ?? ctx.address?.name ?? 'Customer', phone: u.phone ?? ctx.address?.phone ?? '', email: u.email ?? '' },
      channel: opts.channel,
      items: q.items,
      sellerIds: sellers,
      moduleIds: [...new Set(q.items.map((i) => i.moduleId))],
      subtotal: q.subtotal, mrpTotal: q.mrpTotal, deliveryFee: q.deliveryFee, discount: q.discount, couponCode: q.couponCode ?? null,
      couponDiscount: q.couponDiscount, couponSellerId: ctx.couponSnap?.get('sellerId') ?? null,
      walletUsed: q.walletUsed, tax: q.tax, total: q.total, payable: q.payable,
      paymentMethod: method, paymentStatus: method === 'wallet' ? 'paid' : 'pending', paymentRef: null,
      status,
      deliveryType: ctx.deliveryType, speed: ctx.speed, scheduledSlot: ctx.speed === 'scheduled' ? opts.input.scheduledSlot : null,
      address: ctx.address, distanceKm: q.distanceKm, etaAt, etaMinutes: q.etaMinutes,
      deliveryPartnerId: null, deliveryPartnerName: null, deliveryOtp: randomDigits(4), cashCollected: 0,
      timeline: [{ status, at: Timestamp.now(), by: opts.input.uid, note: online ? 'Awaiting online payment' : 'Order placed' }],
      cancelReason: null,
      createdAt: now(), updatedAt: now(),
      ...(typeof opts.extra === 'function' ? opts.extra(q) : opts.extra ?? {}),
    };
    tx.set(orderRef, order);
    if (cartSnaps) for (const d of cartSnaps.docs) tx.delete(d.ref);
    return { orderId: orderRef.id, orderNo, quote: q, order };
  });
}

/**
 * Cancels an order inside a transaction: restores stock, refunds wallet (+ any captured online payment) to the wallet,
 * releases the coupon and appends the timeline. Performs its own reads first.
 */
export async function cancelOrderTx(tx: Transaction, orderRef: DocumentReference, by: string, reason: string, status: 'cancelled' | 'returned' = 'cancelled') {
  const snap = await tx.get(orderRef);
  if (!snap.exists) fail('not-found', 'Order not found.');
  const o = snap.data()!;
  if (['cancelled', 'returned', 'delivered'].includes(o.status)) fail('failed-precondition', `Order is already ${o.status}.`);
  const items: Json[] = o.items ?? [];
  const pids = [...new Set(items.map((i) => i.productId))];
  const pSnaps = pids.length ? await tx.getAll(...pids.map((id) => db.doc(`products/${id}`))) : [];
  const refund = round2(Number(o.walletUsed || 0) + (o.paymentStatus === 'paid' && o.paymentMethod !== 'wallet' && o.paymentMethod !== 'cod' ? Number(o.payable || 0) : 0));
  const userSnap = refund > 0 && o.userId ? await tx.get(db.doc(`users/${o.userId}`)) : null;

  for (const ps of pSnaps) {
    if (!ps.exists) continue;
    const p = ps.data()!;
    const its = items.filter((i) => i.productId === ps.id);
    const qty = its.reduce((a, i) => a + Number(i.qty), 0);
    if (Array.isArray(p.variants) && p.variants.length) {
      const variants = p.variants.map((v: Json) => {
        const back = its.filter((i) => i.variantId === v.id).reduce((a, i) => a + Number(i.qty), 0);
        return back ? { ...v, stock: Number(v.stock) + back } : v;
      });
      tx.update(ps.ref, { variants, stock: variants.reduce((a: number, v: Json) => a + (Number(v.stock) || 0), 0), soldCount: FieldValue.increment(-qty), updatedAt: now() });
    } else {
      tx.update(ps.ref, { stock: FieldValue.increment(qty), soldCount: FieldValue.increment(-qty), updatedAt: now() });
    }
  }
  if (userSnap?.exists && refund > 0) applyWallet(tx, userSnap, 'credit', refund, 'refund', orderRef.id, `Refund for order ${o.orderNo}`);
  if (o.couponCode) {
    tx.set(db.doc(`coupons/${o.couponCode}`), { usedCount: FieldValue.increment(-1) }, { merge: true });
    tx.set(db.doc(`coupons/${o.couponCode}/usages/${o.userId}`), { count: FieldValue.increment(-1) }, { merge: true });
  }
  tx.update(orderRef, {
    status,
    cancelReason: reason,
    paymentStatus: refund > 0 && o.paymentStatus === 'paid' ? 'refunded' : o.paymentStatus === 'pending' && o.paymentMethod !== 'cod' ? 'failed' : o.paymentStatus,
    refundAmount: refund,
    timeline: FieldValue.arrayUnion({ status, at: Timestamp.now(), by, note: reason }),
    updatedAt: now(),
  });
  // Free the rider if one was assigned.
  return { order: o, refund };
}
