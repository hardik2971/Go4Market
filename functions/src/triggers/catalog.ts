import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { db, FieldValue, messaging, now } from '../lib/admin.js';
import { notifyUser, ROLE_TOPIC, topicsForRole } from '../lib/notify.js';
import { buildKeywords, round2, slugify, type Json } from '../lib/util.js';

async function once(eventId: string, kind: string): Promise<boolean> {
  try {
    await db.doc(`_events/${eventId}`).create({ kind, at: now() });
    return true;
  } catch {
    return false;
  }
}

/** onProductWritten — keywords/slug/categoryPath, category & seller productCount, stats products, low-stock alerts. */
export const onProductWritten = onDocumentWritten({ document: 'products/{productId}', retry: false }, async (event) => {
  const before = event.data?.before.exists ? event.data.before.data() : undefined;
  const after = event.data?.after.exists ? event.data.after.data() : undefined;
  const id = event.params.productId;

  // 1) Derived fields (only written when they change, so the trigger settles after one extra run).
  if (after) {
    const fix: Json = {};
    let path: string[] = Array.isArray(after.categoryPath) ? after.categoryPath : [];
    if (after.categoryId && (!path.length || path[path.length - 1] !== after.categoryId)) {
      const cat = await db.doc(`categories/${after.categoryId}`).get();
      if (cat.exists) {
        path = [...((cat.get('path') as string[]) ?? []), cat.id];
        fix.categoryPath = path;
        if (!after.moduleId && cat.get('moduleId')) fix.moduleId = cat.get('moduleId');
      }
    }
    const catNames = path.length ? (await db.getAll(...path.map((c) => db.doc(`categories/${c}`)))).map((c) => c.get('name') as string) : [];
    const keywords = buildKeywords(after.name, after.brandName, after.tags, catNames, after.sellerName, after.barcode, (after.variants ?? []).map((v: Json) => v.name));
    if (JSON.stringify(keywords) !== JSON.stringify(after.keywords ?? [])) fix.keywords = keywords;
    if (!after.slug && after.name) fix.slug = `${slugify(after.name)}-${id.slice(0, 5).toLowerCase()}`;
    if (Array.isArray(after.variants) && after.variants.length) {
      const sum = after.variants.reduce((a: number, v: Json) => a + (Number(v.stock) || 0), 0);
      if (sum !== Number(after.stock)) fix.stock = sum;
    }
    if (Object.keys(fix).length) await event.data!.after.ref.update({ ...fix, updatedAt: now() });
  }

  // 2) Counters (idempotent per event).
  const wasActive = before?.status === 'active', isActive = after?.status === 'active';
  const pathBefore: string[] = wasActive ? before?.categoryPath ?? [] : [];
  const pathAfter: string[] = isActive ? after?.categoryPath ?? [] : [];
  const sellerBefore = wasActive ? before?.sellerId : null, sellerAfter = isActive ? after?.sellerId : null;
  const counterChanges = JSON.stringify(pathBefore) !== JSON.stringify(pathAfter) || sellerBefore !== sellerAfter || wasActive !== isActive;
  if (counterChanges && (await once(event.id, 'product-count'))) {
    const b = db.batch();
    for (const c of pathBefore.filter((x) => !pathAfter.includes(x))) b.set(db.doc(`categories/${c}`), { productCount: FieldValue.increment(-1) }, { merge: true });
    for (const c of pathAfter.filter((x) => !pathBefore.includes(x))) b.set(db.doc(`categories/${c}`), { productCount: FieldValue.increment(1) }, { merge: true });
    if (sellerBefore !== sellerAfter) {
      if (sellerBefore) b.set(db.doc(`sellers/${sellerBefore}`), { productCount: FieldValue.increment(-1) }, { merge: true });
      if (sellerAfter) b.set(db.doc(`sellers/${sellerAfter}`), { productCount: FieldValue.increment(1) }, { merge: true });
    }
    if (wasActive !== isActive) b.set(db.doc('stats/overview'), { products: FieldValue.increment(isActive ? 1 : -1) }, { merge: true });
    await b.commit();
  }

  // 3) Low-stock / out-of-stock alert to the seller when crossing the threshold.
  if (after?.sellerId && after.status === 'active') {
    const lowAt = Number(after.lowStockAt ?? 5);
    const s1 = Number(before?.stock ?? Infinity), s2 = Number(after.stock ?? 0);
    if (s2 < s1 && ((s2 <= lowAt && s1 > lowAt) || (s2 === 0 && s1 > 0))) {
      await notifyUser(after.sellerId, {
        title: s2 === 0 ? `Out of stock: ${after.name}` : `Low stock: ${after.name}`,
        body: s2 === 0 ? 'Customers can no longer order this item. Restock it soon.' : `Only ${s2} left. Restock soon to avoid missing orders.`,
        type: 'stock', data: { productId: id, link: `/products/${id}` },
      });
    }
  }
});

/** onReviewWritten — keeps products.rating / ratingCount / ratingSum (and seller rating) in sync. */
export const onReviewWritten = onDocumentWritten({ document: 'products/{productId}/reviews/{reviewId}', retry: false }, async (event) => {
  const b = event.data?.before.exists ? Number(event.data.before.get('rating')) || 0 : null;
  const a = event.data?.after.exists ? Number(event.data.after.get('rating')) || 0 : null;
  const dCount = (a !== null ? 1 : 0) - (b !== null ? 1 : 0);
  const dSum = (a ?? 0) - (b ?? 0);
  if (!dCount && !dSum) return;
  const pref = db.doc(`products/${event.params.productId}`);
  await db.runTransaction(async (tx) => {
    const ev = await tx.get(db.doc(`_events/${event.id}`));
    if (ev.exists) return;
    const p = await tx.get(pref);
    if (!p.exists) return;
    const count0 = Number(p.get('ratingCount') ?? 0);
    const sum0 = p.get('ratingSum') !== undefined ? Number(p.get('ratingSum')) : Number(p.get('rating') ?? 0) * count0;
    const count = Math.max(0, count0 + dCount), sum = Math.max(0, sum0 + dSum);
    const rating = count ? Math.round((sum / count) * 10) / 10 : 0;
    const sellerId = p.get('sellerId');
    const s = sellerId ? await tx.get(db.doc(`sellers/${sellerId}`)) : null;
    tx.update(pref, { ratingCount: count, ratingSum: round2(sum), rating });
    if (s) {
      if (s.exists) {
        const sc = Number(s.get('ratingCount') ?? 0), ss = s.get('ratingSum') !== undefined ? Number(s.get('ratingSum')) : Number(s.get('rating') ?? 0) * sc;
        const nc = Math.max(0, sc + dCount), ns = Math.max(0, ss + dSum);
        tx.update(s.ref, { ratingCount: nc, ratingSum: round2(ns), rating: nc ? Math.round((ns / nc) * 10) / 10 : 0 });
      }
    }
    tx.create(db.doc(`_events/${event.id}`), { kind: 'review', at: now() });
  });
});

/**
 * onUserWritten — subscribes FCM tokens to topics `all` + role topic so sendCampaign reaches them
 * (covers clients that write fcmTokens directly; registerPushToken also subscribes server-side). Admins get `all` only.
 */
export const onUserWritten = onDocumentWritten({ document: 'users/{uid}', retry: false }, async (event) => {
  const before = event.data?.before.data() ?? {};
  const after = event.data?.after.data();
  if (!after) return;
  const oldTokens: string[] = before.fcmTokens ?? [], newTokens: string[] = after.fcmTokens ?? [];
  const added = newTokens.filter((t) => !oldTokens.includes(t));
  const roleChanged = before.role !== after.role;
  try {
    if (added.length) for (const t of topicsForRole(after.role)) await messaging.subscribeToTopic(added, t);
    if (roleChanged && newTokens.length) {
      const old = ROLE_TOPIC[before.role ?? 'customer'], cur = ROLE_TOPIC[after.role ?? 'customer'];
      if (old && old !== cur) await messaging.unsubscribeFromTopic(newTokens, old);
      if (before.role === 'admin') await messaging.unsubscribeFromTopic(newTokens, 'admins').catch(() => undefined); // legacy topic
      if (cur) await messaging.subscribeToTopic(newTokens, cur);
    }
  } catch (e) {
    logger.warn('topic subscription failed', { uid: event.params.uid, error: String(e) });
  }
});

/** onDeliveryPartnerWritten — mirrors the rider's live location into their active orders (orders.riderLocation) for tracking. */
export const onDeliveryPartnerWritten = onDocumentWritten({ document: 'deliveryPartners/{uid}', retry: false }, async (event) => {
  const b = event.data?.before.data(), a = event.data?.after.data();
  if (!a || typeof a.lat !== 'number' || typeof a.lng !== 'number') return;
  if (b && b.lat === a.lat && b.lng === a.lng) return;
  const active: string[] = a.activeOrders ?? [];
  if (!active.length) return;
  const snaps = await db.getAll(...active.slice(0, 10).map((id) => db.doc(`orders/${id}`)));
  const batch = db.batch();
  let n = 0;
  for (const s of snaps) {
    if (!s.exists || !['assigned', 'picked_up', 'out_for_delivery'].includes(s.get('status')) || s.get('deliveryPartnerId') !== event.params.uid) continue;
    const at = a.locationUpdatedAt ?? now();
    batch.update(s.ref, { riderLocation: { lat: a.lat, lng: a.lng, heading: a.heading ?? null, at, updatedAt: at } });
    n++;
  }
  if (n) await batch.commit();
});

/** onAttributeWritten — global attribute changes raise migration alerts for sellers whose products use removed values. */
export const onAttributeWritten = onDocumentWritten({ document: 'attributes/{attrId}', retry: false }, async (event) => {
  const b = event.data?.before.data(), a = event.data?.after.data();
  if (!b || (a && a.sellerId) || b.sellerId) return; // only global attributes that existed before
  const removed: string[] = (b.values ?? []).filter((v: string) => !(a?.values ?? []).includes(v));
  const renamed = a && a.name !== b.name;
  if (!removed.length && !renamed && a) return;
  const field = `customFields.${String(b.name).replace(/[^\w]/g, '_')}`;
  const q = !a || renamed
    ? db.collection('products').where(field, '!=', null).limit(500)
    : db.collection('products').where(field, 'in', removed.slice(0, 30)).limit(500);
  const ps = await q.get();
  const bySeller = new Map<string, string[]>();
  for (const p of ps.docs) bySeller.set(p.get('sellerId'), [...(bySeller.get(p.get('sellerId')) ?? []), p.id]);
  const kind = !a ? 'deleted' : renamed ? 'renamed' : 'values_removed';
  for (const [sellerId, productIds] of bySeller) {
    if (!sellerId) continue;
    await db.collection('attributeAlerts').add({
      attributeId: event.params.attrId, attributeName: b.name, newName: a?.name ?? null, kind, removedValues: removed, sellerId, productIds,
      resolved: false, createdAt: now(),
    });
    await notifyUser(sellerId, {
      title: `Attribute "${b.name}" changed`,
      body: `${productIds.length} of your products use ${kind === 'values_removed' ? `removed values (${removed.join(', ')})` : `this attribute, which was ${kind}`}. Please update them.`,
      type: 'system', data: { link: '/attributes/alerts' },
    });
  }
});
