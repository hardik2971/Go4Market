import { onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { db, now } from '../lib/admin.js';
import { cfg } from '../lib/config.js';
import { notifyTopic } from '../lib/notify.js';
import { fail, num, requireAuth, requireRole, str, type Json } from '../lib/util.js';

const AUDIENCE_TOPIC: Record<string, string> = { all: 'all', customers: 'customers', sellers: 'sellers', delivery: 'delivery' };
const AUDIENCE_ROLE: Record<string, string | null> = { all: null, customers: 'customer', sellers: 'seller', delivery: 'delivery' };

/** sendCampaign — admin: {campaignId} → {ok, messageId, inboxCount}. Pushes to topic and writes inbox docs (max 5000 users). */
export const sendCampaign = onCall({ timeoutSeconds: 300, memory: '512MiB' }, async (req) => {
  requireRole(req, 'admin');
  const id = str(req.data?.campaignId, 'campaignId', { max: 128 });
  const ref = db.doc(`campaigns/${id}`);
  const snap = await ref.get();
  if (!snap.exists) fail('not-found', 'Campaign not found.');
  const cmp = snap.data()!;
  if (cmp.status === 'sent') fail('failed-precondition', 'Campaign was already sent.');
  const audience = String(cmp.audience ?? 'all');
  const topic = AUDIENCE_TOPIC[audience];
  if (!topic) fail('invalid-argument', 'audience must be all, customers, sellers or delivery.');
  await ref.update({ status: 'sending', updatedAt: now() });
  const note = { title: String(cmp.title ?? ''), body: String(cmp.body ?? ''), type: 'promo', image: cmp.image || undefined, data: { campaignId: id, link: String(cmp.link ?? '') } };
  const messageId = await notifyTopic(topic, note);
  // Inbox copies so users see it in-app even without push permission.
  let q = db.collection('users').where('status', '==', 'active');
  if (AUDIENCE_ROLE[audience]) q = q.where('role', '==', AUDIENCE_ROLE[audience]);
  const users = await q.limit(5000).get();
  for (let i = 0; i < users.docs.length; i += 450) {
    const b = db.batch();
    users.docs.slice(i, i + 450).forEach((u) => b.set(u.ref.collection('notifications').doc(`cmp_${id}`), {
      title: note.title, body: note.body, type: 'promo', image: note.image ?? null, data: note.data, read: false, createdAt: now(),
    }));
    await b.commit();
  }
  await ref.update({ status: 'sent', sentAt: now(), messageId, inboxCount: users.size, updatedAt: now() });
  return { ok: true, messageId, inboxCount: users.size };
});

function templateDescription(name: string, category: string, keywords: string[]): { short: string; long: string } {
  const kw = keywords.filter(Boolean).slice(0, 6);
  const lead = kw.length ? kw.slice(0, 3).join(', ') : 'quality and value';
  const short = `${name} — ${category ? `a ${category.toLowerCase()} favourite` : 'a customer favourite'} known for ${lead}.`.slice(0, 160);
  const bullets = (kw.length ? kw : ['Quality checked', 'Great value', 'Fast delivery']).map((k) => `- **${k[0].toUpperCase()}${k.slice(1)}**`).join('\n');
  const long = [
    `**${name}** brings you ${lead} in every order. ${category ? `Carefully selected for our ${category} range, it` : 'It'} is sourced from trusted suppliers and quality-checked before it leaves the store.`,
    '',
    '### Why you will love it',
    bullets,
    '',
    '### Good to know',
    '- Packed hygienically and delivered fast by Go4Market partners',
    '- Easy returns on eligible items within the return window',
    '- Pay online, with your Go4Market wallet or cash on delivery',
  ].join('\n');
  return { short, long };
}

/** generateDescription — admin/seller: {name, category, keywords[]} → {short, long, source: gemini|template}. */
export const generateDescription = onCall({ timeoutSeconds: 60 }, async (req) => {
  requireRole(req, 'admin', 'seller');
  const name = str(req.data?.name, 'name', { max: 150 });
  const category = str(req.data?.category, 'category', { required: false, max: 100 });
  const keywords: string[] = Array.isArray(req.data?.keywords) ? req.data.keywords.filter((k: unknown) => typeof k === 'string').map((k: string) => k.trim()).slice(0, 15) : [];
  const key = cfg.geminiKey();
  if (key) {
    try {
      const prompt = `You write product copy for Go4Market, an Indian online marketplace (grocery, food, pharmacy, electronics, fashion).
Product: ${name}
Category: ${category || 'general'}
Keywords: ${keywords.join(', ') || 'none'}
Return strict JSON: {"short": "<=160 characters, one sentence", "long": "120-200 words in Markdown with a short intro, a '### Highlights' bullet list and a '### How to use' or '### Care' section"}.
Do not invent certifications, medical claims or prices. Use Indian English.`;
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${encodeURIComponent(key)}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.7 } }),
      });
      const j = (await res.json()) as Json;
      const text = j?.candidates?.[0]?.content?.parts?.[0]?.text;
      const parsed = text ? JSON.parse(text) : null;
      if (parsed?.short && parsed?.long) return { short: String(parsed.short).slice(0, 200), long: String(parsed.long), source: 'gemini' };
      logger.warn('Gemini returned no usable content', { status: res.status });
    } catch (e) {
      logger.warn('Gemini failed, using template', { error: String(e) });
    }
  }
  return { ...templateDescription(name, category, keywords), source: 'template' };
});

/** submitReview — customer with a delivered order containing the product: {productId, rating 1-5, comment, images?[]} → {ok}. */
export const submitReview = onCall(async (req) => {
  const c = requireAuth(req);
  const productId = str(req.data?.productId, 'productId', { max: 128 });
  const rating = num(req.data?.rating, 'rating', { min: 1, max: 5, int: true });
  const comment = str(req.data?.comment, 'comment', { required: false, max: 2000 });
  const images = Array.isArray(req.data?.images) ? req.data.images.filter((x: unknown) => typeof x === 'string').slice(0, 5) : [];
  const orders = await db.collection('orders').where('userId', '==', c.uid).where('status', '==', 'delivered').orderBy('createdAt', 'desc').limit(100).get();
  const bought = orders.docs.some((o) => (o.get('items') as Json[] | undefined)?.some((i) => i.productId === productId));
  if (!bought) fail('permission-denied', 'You can review products you have received.');
  const user = (await db.doc(`users/${c.uid}`).get()).data() ?? {};
  const ref = db.doc(`products/${productId}/reviews/${c.uid}`);
  const existing = await ref.get();
  await ref.set({
    userId: c.uid, userName: String(user.name ?? 'Customer').split(' ').map((w: string, i: number) => (i === 0 ? w : `${w[0] ?? ''}.`)).join(' '),
    userPhoto: user.photoUrl ?? null, rating, comment, images, verified: true,
    createdAt: existing.exists ? existing.get('createdAt') : now(), updatedAt: now(),
  });
  return { ok: true, updated: existing.exists };
});
