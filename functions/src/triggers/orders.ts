import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { db, FieldValue, now } from '../lib/admin.js';
import { cfg, MAIL_PASSWORD } from '../lib/config.js';
import { queueSms, type SmsEvent } from '../lib/sms.js';
import { commSettings, notifyUser, sendTemplateEmail } from '../lib/notify.js';
import { assignPartner } from '../orders/callables.js';
import { applyWallet } from '../lib/wallet.js';
import { dayKey, platformSettings, round2, type Json } from '../lib/util.js';

const TERMINAL = ['delivered', 'cancelled', 'returned'];

/** Contribution of one order snapshot to the stats docs. Pending (unpaid) orders count for nothing. */
function contrib(o: Json | undefined): { daily: Record<string, number>; overview: Record<string, number> } {
  const daily: Record<string, number> = {}, overview: Record<string, number> = {};
  if (!o || o.status === 'pending') return { daily, overview };
  const live = !['cancelled', 'returned'].includes(o.status);
  const revenue = live ? Number(o.total || 0) : 0;
  const add = (m: Record<string, number>, k: string, v: number) => { if (v) m[k] = (m[k] ?? 0) + v; };
  for (const m of [daily, overview]) {
    add(m, 'orders', 1);
    add(m, 'revenue', revenue);
    add(m, 'delivered', o.status === 'delivered' ? 1 : 0);
    add(m, 'cancelled', o.status === 'cancelled' ? 1 : 0);
    add(m, 'returns', o.status === 'returned' ? 1 : 0);
  }
  add(daily, `byChannel.${o.channel ?? 'app'}`, 1);
  add(daily, `revenueByChannel.${o.channel ?? 'app'}`, revenue);
  add(daily, `byPaymentMethod.${o.paymentMethod ?? 'cod'}`, 1);
  if (live) {
    for (const i of (o.items as Json[]) ?? []) {
      const v = Number(i.price) * Number(i.qty);
      add(daily, `byModule.${i.moduleId ?? 'ecommerce'}`, v);
      if (i.rootCategoryId) add(daily, `byCategory.${i.rootCategoryId}`, v);
    }
  }
  add(overview, 'pending', TERMINAL.includes(o.status) ? 0 : 1);
  add(overview, `byStatus.${o.status}`, 1);
  add(overview, `byChannel.${o.channel ?? 'app'}`, 1);
  return { daily, overview };
}

function nest(delta: Record<string, number>): Json {
  const out: Json = {};
  for (const [k, v] of Object.entries(delta)) {
    if (!v) continue;
    const parts = k.split('.');
    let cur = out;
    for (let i = 0; i < parts.length - 1; i++) cur = cur[parts[i]] ??= {};
    cur[parts[parts.length - 1]] = FieldValue.increment(Math.round(v * 100) / 100);
  }
  return out;
}

function diff(a: Record<string, number>, b: Record<string, number>): Record<string, number> {
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  const out: Record<string, number> = {};
  for (const k of keys) {
    const d = round2((b[k] ?? 0) - (a[k] ?? 0));
    if (d) out[k] = d;
  }
  return out;
}

async function applyStats(eventId: string, before: Json | undefined, after: Json | undefined) {
  const b = contrib(before), a = contrib(after);
  const createdAt = (after ?? before)?.createdAt;
  const key = dayKey(createdAt?.toDate ? createdAt.toDate() : new Date());
  const dDaily = diff(b.daily, a.daily), dOverview = diff(b.overview, a.overview);
  if (!Object.keys(dDaily).length && !Object.keys(dOverview).length) return;
  const batch = db.batch();
  batch.create(db.doc(`_events/${eventId}`), { kind: 'order-stats', at: now() });
  if (Object.keys(dDaily).length) batch.set(db.doc(`stats/daily_${key}`), { date: key, ...nest(dDaily), updatedAt: now() }, { merge: true });
  if (Object.keys(dOverview).length) batch.set(db.doc('stats/overview'), { ...nest(dOverview), updatedAt: now() }, { merge: true });
  try {
    await batch.commit();
  } catch (e: any) {
    if (e?.code === 6 || /ALREADY_EXISTS/.test(String(e))) return; // duplicate delivery of the same event
    throw e;
  }
}

const CUSTOMER_MSG: Record<string, [string, string]> = {
  placed: ['Order placed', 'We have received your order {no}. We will notify you when the store confirms it.'],
  confirmed: ['Order confirmed', 'The store has confirmed order {no} and is preparing it.'],
  packed: ['Order packed', 'Order {no} is packed and waiting for a delivery partner.'],
  assigned: ['Rider assigned', '{rider} will deliver order {no}.'],
  picked_up: ['Order picked up', '{rider} has picked up order {no}.'],
  out_for_delivery: ['Out for delivery', 'Order {no} is on the way. Share OTP {otp} with the rider at delivery.'],
  ready_for_pickup: ['Ready for pickup', 'Order {no} is ready at the store. Show OTP {otp} at the counter.'],
  delivered: ['Delivered', 'Order {no} has been delivered. Enjoy, and tell us how it went!'],
  cancelled: ['Order cancelled', 'Order {no} was cancelled. {reason}'],
  returned: ['Order returned', 'The return for order {no} is complete and your refund has been processed.'],
};
const EMAIL_STATUSES = ['confirmed', 'out_for_delivery', 'ready_for_pickup', 'delivered', 'cancelled', 'returned'];

function fill(t: string, o: Json): string {
  return t.replace('{no}', o.orderNo ?? '').replace('{rider}', o.deliveryPartnerName || 'Your rider').replace('{otp}', o.deliveryOtp ?? '')
    .replace('{reason}', o.cancelReason ? `Reason: ${o.cancelReason}.` : '').trim();
}

function itemsHtml(o: Json): string {
  return ((o.items as Json[]) ?? []).map((i) =>
    `<tr><td style="padding:6px 0">${i.name}${i.variantName ? ` (${i.variantName})` : ''} × ${i.qty}</td><td style="padding:6px 0;text-align:right">₹${round2(i.price * i.qty).toFixed(2)}</td></tr>`).join('');
}

async function payReferral(o: Json) {
  if (!o.userId || o.userId === 'pos') return;
  const u = await db.doc(`users/${o.userId}`).get();
  const code = u.get('referredBy');
  if (!code || u.get('referralRewarded')) return;
  const ref = await db.collection('users').where('referralCode', '==', String(code).toUpperCase()).limit(1).get();
  if (ref.empty || ref.docs[0].id === o.userId) {
    await u.ref.set({ referralRewarded: true, referralNote: 'invalid code' }, { merge: true });
    return;
  }
  const settings = await platformSettings();
  const referrerId = ref.docs[0].id;
  const paid = await db.runTransaction(async (tx) => {
    const [me, them] = await tx.getAll(u.ref, ref.docs[0].ref);
    if (me.get('referralRewarded')) return false;
    const r1 = Number(settings.refereeReward ?? 50), r2 = Number(settings.referralReward ?? 50);
    if (r1 > 0) applyWallet(tx, me, 'credit', r1, 'referral', o.orderNo, 'Welcome reward for joining with a referral');
    if (r2 > 0) applyWallet(tx, them, 'credit', r2, 'referral', me.id, `Referral reward: ${me.get('name') ?? 'a friend'} completed their first order`);
    tx.set(me.ref, { referralRewarded: true, referrerId }, { merge: true });
    tx.set(them.ref, { referralCount: FieldValue.increment(1) }, { merge: true });
    return true;
  });
  if (paid) {
    await notifyUser(o.userId, { title: 'Referral reward unlocked', body: `₹${settings.refereeReward ?? 50} has been added to your wallet.`, type: 'wallet', data: { link: '/wallet' } });
    await notifyUser(referrerId, { title: 'You earned a referral reward', body: `₹${settings.referralReward ?? 50} has been added to your wallet.`, type: 'wallet', data: { link: '/wallet' } });
  }
}

async function updateCoPurchase(o: Json) {
  const ids = [...new Set(((o.items as Json[]) ?? []).map((i) => String(i.productId)))].slice(0, 10);
  if (ids.length < 2) return;
  const b = db.batch();
  for (const a of ids) {
    const counts: Json = {};
    for (const x of ids) if (x !== a) counts[x] = FieldValue.increment(1);
    b.set(db.doc(`coPurchase/${a}`), { counts, updatedAt: now() }, { merge: true });
  }
  await b.commit();
}

const SMS_STATUSES = ['out_for_delivery', 'ready_for_pickup', 'delivered', 'cancelled'];

/** Queues the customer SMS for an order event (settings/communication.events.{event}.sms). Never throws. */
async function orderSms(o: Json, event: SmsEvent) {
  let phone = o.customer?.phone;
  try {
    if (!phone && o.userId && o.userId !== 'pos') phone = (await db.doc(`users/${o.userId}`).get()).get('phone');
  } catch { /* ignore */ }
  if (!phone) return;
  await queueSms({
    to: phone, event, orderId: o.id ?? null, userId: o.userId ?? null,
    vars: {
      name: String(o.customer?.name || 'Customer').split(' ')[0], orderNo: o.orderNo ?? '', amount: Number(o.payable ?? o.total ?? 0).toFixed(2),
      otp: o.deliveryOtp ?? '', rider: o.deliveryPartnerName ?? '', reason: o.cancelReason ? `Reason: ${o.cancelReason}.` : '',
      link: `${cfg.websiteUrl()}/orders/${o.id}`,
    },
  });
}

/** onOrderWritten — stats, notifications (FCM + inbox), email, SMS outbox, referral payout, co-purchase graph. */
export const onOrderWritten = onDocumentWritten({ document: 'orders/{orderId}', secrets: [MAIL_PASSWORD], retry: false }, async (event) => {
  const before = event.data?.before.exists ? event.data.before.data() : undefined;
  const after = event.data?.after.exists ? event.data.after.data() : undefined;
  const orderId = event.params.orderId;
  try {
    await applyStats(event.id, before, after);
  } catch (e) {
    logger.error('stats update failed', { orderId, error: String(e) });
  }
  if (!after) return;
  const o: Json = { ...after, id: orderId };
  const prev = before?.status;
  const cur = after.status;
  const becameLive = cur !== 'pending' && (!before || prev === 'pending');
  const statusChanged = prev !== cur;
  const link = `/orders/${orderId}`;
  const tasks: Promise<unknown>[] = [];

  if (statusChanged && o.userId && o.userId !== 'pos' && CUSTOMER_MSG[cur] && !(cur === 'delivered' && o.channel === 'pos')) {
    const [title, body] = CUSTOMER_MSG[cur];
    tasks.push(notifyUser(o.userId, { title: `${title} · ${o.orderNo}`, body: fill(body, o), type: 'order', data: { orderId, status: cur, link } }));
    if (SMS_STATUSES.includes(cur)) tasks.push(orderSms(o, cur as SmsEvent));
  }
  if (becameLive && o.channel !== 'pos') {
    for (const s of (o.sellerIds as string[]) ?? []) {
      const mine = ((o.items as Json[]) ?? []).filter((i) => i.sellerId === s);
      tasks.push(notifyUser(s, {
        title: `New order ${o.orderNo}`, body: `${mine.reduce((a, i) => a + i.qty, 0)} item(s) · ₹${round2(mine.reduce((a, i) => a + i.price * i.qty, 0))} · ${o.paymentMethod.toUpperCase()}`,
        type: 'order', data: { orderId, link },
      }));
    }
    tasks.push(sendTemplateEmail('order_placed', o.customer?.email, {
      name: o.customer?.name, orderNo: o.orderNo, total: Number(o.total).toFixed(2), payable: Number(o.payable).toFixed(2),
      paymentMethod: String(o.paymentMethod).toUpperCase(), itemsHtml: itemsHtml(o), orderUrl: `https://go4market.web.app${link}`,
      address: o.address ? [o.address.line1, o.address.city, o.address.pincode].filter(Boolean).join(', ') : 'Store pickup',
    }, (await commSettings()).email?.adminCopy || undefined));
    if (o.userId !== 'pos') tasks.push(orderSms(o, 'placed'));
    tasks.push(updateCoPurchase(o).catch((e) => logger.warn('coPurchase failed', { error: String(e) })));
  }
  if (statusChanged && !becameLive && EMAIL_STATUSES.includes(cur) && o.channel !== 'pos') {
    tasks.push(sendTemplateEmail('order_status', o.customer?.email, {
      name: o.customer?.name, orderNo: o.orderNo, status: CUSTOMER_MSG[cur]?.[0] ?? cur, message: fill(CUSTOMER_MSG[cur]?.[1] ?? '', o),
      orderUrl: `https://go4market.web.app${link}`,
    }));
  }
  if (after.deliveryPartnerId && after.deliveryPartnerId !== before?.deliveryPartnerId) {
    tasks.push(notifyUser(after.deliveryPartnerId, {
      title: `New delivery · ${o.orderNo}`, body: `Pick up from ${((o.items as Json[])[0]?.sellerName) ?? 'the store'} → ${o.address?.city ?? ''} (${o.distanceKm ?? 0} km)`,
      type: 'order', data: { orderId, link },
    }));
  }
  // settings/platform.autoAssign: give packed home orders to the nearest online rider automatically.
  if (statusChanged && cur === 'packed' && o.deliveryType === 'home' && !o.deliveryPartnerId && o.channel !== 'pos') {
    tasks.push((async () => {
      const s = await platformSettings();
      if (s.autoAssign !== true) return;
      try {
        const r = await assignPartner({ uid: 'system', role: 'admin' }, orderId, null);
        logger.info('auto-assigned', { orderId, partnerId: r.partnerId });
      } catch (e: any) {
        logger.warn('auto-assign failed', { orderId, error: String(e?.message ?? e) });
        for (const sid of (o.sellerIds as string[]) ?? []) await notifyUser(sid, { title: `No rider available · ${o.orderNo}`, body: 'Auto-assign found no online rider. Please assign one manually.', type: 'order', data: { orderId, link: `/orders/${orderId}` } });
      }
    })());
  }
  if (statusChanged && cur === 'delivered') tasks.push(payReferral(o).catch((e) => logger.warn('referral failed', { error: String(e) })));
  await Promise.allSettled(tasks);
});
