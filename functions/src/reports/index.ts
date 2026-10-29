import { onCall } from 'firebase-functions/v2/https';
import { db, Timestamp } from '../lib/admin.js';
import { resolveProvider } from '../lib/sms.js';
import { cfg, MAIL_PASSWORD, SMS_SECRETS, PAYMENT_SECRETS, PAYPAL_CLIENT_SECRET, RAZORPAY_KEY_SECRET, STRIPE_SECRET_KEY } from '../lib/config.js';
import { dayKey, fail, num, oneOf, requireRole, round2, str, type Json } from '../lib/util.js';

function parseDay(s: string, field: string, endOfDay = false): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) fail('invalid-argument', `${field} must be yyyy-MM-dd.`);
  return new Date(`${s}T${endOfDay ? '23:59:59.999' : '00:00:00'}+05:30`);
}

/**
 * salesReport — admin/seller: {from: 'yyyy-MM-dd', to, channel?: web|app|pos, moduleId?, sellerId? (admin only)} →
 * {totals, byDay[], byStatus{}, byChannel{}, byPaymentMethod{}, byModule{}, topProducts[], slowProducts[]}.
 * Sellers always get their own figures (their items only). Covers sales, product-sales and POS reports.
 */
export const salesReport = onCall({ timeoutSeconds: 120, memory: '512MiB' }, async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const d = req.data ?? {};
  const from = parseDay(str(d.from, 'from', { max: 10 }), 'from');
  const to = parseDay(str(d.to, 'to', { max: 10 }), 'to', true);
  if (to.getTime() - from.getTime() > 366 * 86_400_000) fail('invalid-argument', 'Range can be at most one year.');
  const channel = d.channel ? oneOf(d.channel, 'channel', ['web', 'app', 'pos'] as const) : null;
  const moduleId = str(d.moduleId, 'moduleId', { required: false, max: 32 }) || null;
  const sellerId = c.role === 'seller' ? c.uid : str(d.sellerId, 'sellerId', { required: false, max: 128 }) || null;

  let q = db.collection('orders').where('createdAt', '>=', Timestamp.fromDate(from)).where('createdAt', '<=', Timestamp.fromDate(to));
  if (sellerId) q = db.collection('orders').where('sellerIds', 'array-contains', sellerId).where('createdAt', '>=', Timestamp.fromDate(from)).where('createdAt', '<=', Timestamp.fromDate(to));
  const snap = await q.orderBy('createdAt', 'desc').limit(10000).get();

  const totals = { orders: 0, revenue: 0, itemsSold: 0, delivered: 0, cancelled: 0, returned: 0, discount: 0, deliveryFees: 0, avgOrderValue: 0, commission: 0, net: 0 };
  const byDay: Record<string, Json> = {};
  const byStatus: Record<string, number> = {}, byChannel: Record<string, number> = {}, byPaymentMethod: Record<string, number> = {}, byModule: Record<string, number> = {};
  const prod: Record<string, Json> = {};
  for (const doc of snap.docs) {
    const o = doc.data();
    if (o.status === 'pending') continue;
    if (channel && o.channel !== channel) continue;
    let items: Json[] = o.items ?? [];
    if (sellerId) items = items.filter((i) => i.sellerId === sellerId);
    if (moduleId) items = items.filter((i) => i.moduleId === moduleId);
    if (!items.length) continue;
    const cancelled = o.status === 'cancelled' || o.status === 'returned';
    const gross = round2(items.reduce((a, i) => a + Number(i.price) * Number(i.qty), 0));
    const revenue = cancelled ? 0 : sellerId || moduleId ? gross : Number(o.total);
    const day = dayKey(o.createdAt.toDate());
    totals.orders++;
    totals.revenue += revenue;
    if (o.status === 'delivered') totals.delivered++;
    if (o.status === 'cancelled') totals.cancelled++;
    if (o.status === 'returned') totals.returned++;
    if (!cancelled) {
      totals.discount += Number(o.discount || 0);
      totals.deliveryFees += Number(o.deliveryFee || 0);
      if (sellerId && o.settlement?.sellers?.[sellerId]) {
        totals.commission += Number(o.settlement.sellers[sellerId].commission || 0);
        totals.net += Number(o.settlement.sellers[sellerId].net || 0);
      }
    }
    byDay[day] ??= { date: day, orders: 0, revenue: 0 };
    byDay[day].orders++;
    byDay[day].revenue = round2(byDay[day].revenue + revenue);
    byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
    byChannel[o.channel ?? 'app'] = round2((byChannel[o.channel ?? 'app'] ?? 0) + revenue);
    byPaymentMethod[o.paymentMethod] = round2((byPaymentMethod[o.paymentMethod] ?? 0) + revenue);
    for (const i of items) {
      if (!cancelled) {
        totals.itemsSold += Number(i.qty);
        byModule[i.moduleId ?? 'ecommerce'] = round2((byModule[i.moduleId ?? 'ecommerce'] ?? 0) + Number(i.price) * Number(i.qty));
        prod[i.productId] ??= { productId: i.productId, name: i.name, image: i.image, qty: 0, revenue: 0 };
        prod[i.productId].qty += Number(i.qty);
        prod[i.productId].revenue = round2(prod[i.productId].revenue + Number(i.price) * Number(i.qty));
      }
    }
  }
  const counted = totals.orders - totals.cancelled - totals.returned;
  totals.revenue = round2(totals.revenue);
  totals.discount = round2(totals.discount);
  totals.deliveryFees = round2(totals.deliveryFees);
  totals.commission = round2(totals.commission);
  totals.net = round2(totals.net);
  totals.avgOrderValue = counted > 0 ? round2(totals.revenue / counted) : 0;

  const topProducts = Object.values(prod).sort((a, b) => b.revenue - a.revenue).slice(0, 20);
  // Slow movers: active catalog items with the lowest lifetime sales.
  let sq = db.collection('products').where('status', '==', 'active');
  if (sellerId) sq = sq.where('sellerId', '==', sellerId);
  if (moduleId) sq = sq.where('moduleId', '==', moduleId);
  const slow = await sq.orderBy('soldCount', 'asc').limit(10).get();
  const slowProducts = slow.docs.map((p) => ({ productId: p.id, name: p.get('name'), image: (p.get('images') ?? [])[0] ?? '', soldCount: p.get('soldCount') ?? 0, stock: p.get('stock') ?? 0, qtyInRange: prod[p.id]?.qty ?? 0 }));
  return {
    range: { from: d.from, to: d.to }, sellerId, channel, moduleId, truncated: snap.size >= 10000,
    totals, byDay: Object.values(byDay).sort((a, b) => String(a.date).localeCompare(String(b.date))),
    byStatus, byChannel, byPaymentMethod, byModule, topProducts, slowProducts,
  };
});

/** abandonedCarts — admin/seller: {olderThanHours?=6, limit?} → {carts:[{userId, name, phone, email, items[], value, lastAddedAt}]}. */
export const abandonedCarts = onCall(async (req) => {
  const c = requireRole(req, 'admin', 'seller');
  const hours = num(req.data?.olderThanHours ?? 6, 'olderThanHours', { min: 1, max: 24 * 60 });
  const limit = num(req.data?.limit ?? 300, 'limit', { min: 1, max: 1000, int: true });
  const cutoff = Timestamp.fromMillis(Date.now() - hours * 3_600_000);
  let q = db.collectionGroup('cart').where('addedAt', '<', cutoff);
  if (c.role === 'seller') q = db.collectionGroup('cart').where('sellerId', '==', c.uid).where('addedAt', '<', cutoff);
  const s = await q.orderBy('addedAt', 'desc').limit(limit).get();
  const byUser = new Map<string, Json[]>();
  for (const d of s.docs) {
    const uid = d.ref.parent.parent?.id;
    if (!uid) continue;
    byUser.set(uid, [...(byUser.get(uid) ?? []), { id: d.id, ...d.data(), addedAt: d.get('addedAt')?.toDate?.().toISOString() ?? null }]);
  }
  const uids = [...byUser.keys()];
  const pids = [...new Set(s.docs.map((d) => String(d.get('productId'))))];
  const [users, prods] = await Promise.all([
    uids.length ? db.getAll(...uids.map((u) => db.doc(`users/${u}`))) : [],
    pids.length ? db.getAll(...pids.map((p) => db.doc(`products/${p}`))) : [],
  ]);
  const pmap = new Map(prods.map((p) => [p.id, p.data() ?? {}]));
  const carts = users.map((u) => {
    const items = (byUser.get(u.id) ?? []).map((i) => {
      const p = pmap.get(String(i.productId)) ?? {};
      const v = Array.isArray(p.variants) ? p.variants.find((x: Json) => x.id === i.variantId) : null;
      const price = Number(v?.price ?? p.price ?? 0);
      return { productId: i.productId, variantId: i.variantId, qty: i.qty, name: p.name ?? '', image: (p.images ?? [])[0] ?? '', price, addedAt: i.addedAt };
    });
    return {
      userId: u.id, name: u.get('name') ?? '', phone: u.get('phone') ?? '', email: u.get('email') ?? '',
      items, value: round2(items.reduce((a, i) => a + i.price * Number(i.qty), 0)), lastAddedAt: items.map((i) => i.addedAt).sort().pop() ?? null,
    };
  }).sort((a, b) => b.value - a.value);
  return { carts, count: carts.length };
});

/** getSystemStatus — admin: → integration health (booleans only, never secret values), stats overview, last backup, settings flags. */
export const getSystemStatus = onCall({ secrets: [...PAYMENT_SECRETS, MAIL_PASSWORD, ...SMS_SECRETS] }, async (req) => {
  requireRole(req, 'admin');
  const sms = await resolveProvider().catch(() => null);
  const has = (fn: () => string) => { try { return !!fn(); } catch { return false; } };
  const [overview, platform, backup] = await Promise.all([db.doc('stats/overview').get(), db.doc('settings/platform').get(), db.doc('system/backup').get()]);
  return {
    region: 'asia-south1',
    node: process.version,
    integrations: {
      razorpay: has(() => cfg.razorpayKeyId()) && has(() => RAZORPAY_KEY_SECRET.value()),
      stripe: has(() => STRIPE_SECRET_KEY.value()),
      paypal: has(() => cfg.paypalClientId()) && has(() => PAYPAL_CLIENT_SECRET.value()),
      paypalEnv: cfg.paypalEnv(),
      smtp: has(() => cfg.mailUser()) && has(() => MAIL_PASSWORD.value()),
      gemini: has(() => cfg.geminiKey()),
      sms: !!sms?.ready,
      smsProvider: sms?.provider ?? 'none',
      currencies: { razorpay: cfg.razorpayCurrency(), stripe: cfg.stripeCurrency(), paypal: cfg.paypalCurrency() },
    },
    stats: overview.data() ?? {},
    flags: { maintenance: !!platform.get('maintenance'), demoMode: !!platform.get('demoMode') },
    lastBackup: backup.data() ?? null,
    serverTime: new Date().toISOString(),
  };
});
