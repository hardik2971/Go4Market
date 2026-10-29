import * as functionsV1 from 'firebase-functions/v1';
import { onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { auth, db, FieldValue, messaging, now } from '../lib/admin.js';
import { MAIL_PASSWORD } from '../lib/config.js';
import { ALL_TOPICS, sendTemplateEmail, topicsForRole } from '../lib/notify.js';
import { toE164 } from '../lib/sms.js';
import { dayKey, fail, oneOf, randomCode, requireAuth, requireRole, ROLES, str, type Json } from '../lib/util.js';

async function uniqueReferralCode(name: string): Promise<string> {
  const base = (name || 'G4M').replace(/[^a-zA-Z]/g, '').toUpperCase().slice(0, 4).padEnd(3, 'X');
  for (let i = 0; i < 6; i++) {
    const code = `${base}${randomCode(4)}`;
    const clash = await db.collection('users').where('referralCode', '==', code).limit(1).get();
    if (clash.empty) return code;
  }
  return `G4M${randomCode(6)}`;
}

interface AuthUserLike {
  uid: string;
  email?: string | null;
  phoneNumber?: string | null;
  displayName?: string | null;
  photoURL?: string | null;
  providerData: { providerId: string; displayName?: string | null; photoURL?: string | null; email?: string | null; phoneNumber?: string | null }[];
}

const isAnonymousUser = (u: AuthUserLike) => !u.email && !u.phoneNumber && u.providerData.length === 0;

/**
 * Creates/initialises users/{uid} without clobbering fields the client already wrote: name/email/phone/photo from the
 * provider (email/password, phone, Google), referral code, role claim `customer` (unless a role claim exists), stats,
 * welcome email (only when there is an email). Idempotent. Shared by onUserCreated and completeProfile
 * (anonymous accounts upgraded with linkWithCredential never fire onUserCreated again).
 */
async function ensureUserDoc(user: AuthUserLike): Promise<{ created: boolean; name: string; referralCode: string }> {
  const fresh = await auth.getUser(user.uid);
  const claimRole = fresh.customClaims?.role as string | undefined;
  const ref = db.doc(`users/${user.uid}`);
  const provider = (id: string) => user.providerData.find((p) => p.providerId === id);
  const google = provider('google.com');
  const email = user.email || google?.email || null;
  const phone = user.phoneNumber || provider('phone')?.phoneNumber || null;
  const photo = user.photoURL || google?.photoURL || null;
  const name = (user.displayName || google?.displayName || (email ? email.split('@')[0] : '') || 'Customer').slice(0, 80);
  const existing = await ref.get();
  const code = existing.get('referralCode') || (await uniqueReferralCode(name));
  const res = await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const cur: Json = s.data() ?? {};
    const data: Json = { updatedAt: now() };
    const created = !s.exists || !cur.createdAt;
    if (created) data.createdAt = now();
    if (!cur.email && email) data.email = email;
    if (!cur.name) data.name = name;
    if (!cur.phone && phone) data.phone = phone;
    if (!cur.photoUrl && photo) data.photoUrl = photo;
    if (!cur.role) data.role = claimRole ?? 'customer';
    if (!cur.status) data.status = 'active';
    if (cur.walletBalance === undefined) data.walletBalance = 0;
    if (!cur.referralCode) data.referralCode = code;
    if (!cur.fcmTokens) data.fcmTokens = [];
    if (!cur.recentlyViewed) data.recentlyViewed = [];
    if (cur.anonymous) data.anonymous = FieldValue.delete();
    if (created) data.authProviders = [...new Set(user.providerData.map((p) => p.providerId))];
    tx.set(ref, data, { merge: true });
    return { created, name: String(cur.name || name), referralCode: String(cur.referralCode || code), welcomed: !!cur.welcomeSentAt, email: String(cur.email || email || '') };
  });
  if (!claimRole) {
    // Re-check right before writing so a role set concurrently (createStaffUser, seed) is never overwritten.
    const again = await auth.getUser(user.uid);
    if (!again.customClaims?.role) await auth.setCustomUserClaims(user.uid, { ...(again.customClaims ?? {}), role: 'customer' });
  }
  if (res.created) {
    const key = dayKey();
    const b = db.batch();
    b.set(db.doc(`stats/daily_${key}`), { date: key, newUsers: FieldValue.increment(1), updatedAt: now() }, { merge: true });
    if (!claimRole || claimRole === 'customer') b.set(db.doc('stats/overview'), { customers: FieldValue.increment(1), updatedAt: now() }, { merge: true });
    await b.commit();
  }
  if (res.created && !res.welcomed && res.email) {
    if (await sendTemplateEmail('welcome', res.email, { name: res.name, referralCode: res.referralCode })) await ref.set({ welcomeSentAt: now() }, { merge: true });
  }
  return { created: res.created, name: res.name, referralCode: res.referralCode };
}

/**
 * onUserCreated (Auth v1 trigger) — initialises users/{uid} for email/password, phone-OTP and Google sign-ups
 * (see ensureUserDoc). Phone-only users get phone = user.phoneNumber (E.164) and name 'Customer'. Anonymous users are skipped.
 */
export const onUserCreated = functionsV1
  .runWith({ secrets: [MAIL_PASSWORD] })
  .region('asia-south1')
  .auth.user()
  .onCreate(async (user) => {
    if (isAnonymousUser(user)) return;
    await ensureUserDoc(user);
    logger.info('user initialised', { uid: user.uid, providers: user.providerData.map((p) => p.providerId) });
  });

// ───────────────────────── push tokens (FEATURES #38)

const PLATFORMS = ['web', 'android', 'ios'] as const;
const MAX_TOKENS = 10;

/**
 * registerPushToken — any signed-in user incl. anonymous: {token, platform: web|android|ios} → {ok, topics}.
 * Subscribes the token server-side to `all` + the role topic (customers|sellers|delivery; admins → all only), then
 * stores it in users/{uid}.fcmTokens (de-duplicated, newest last, capped at 10). Web clients cannot subscribe to topics
 * themselves, so this is how sendCampaign reaches browsers. An unusable token fails with invalid-argument.
 */
export const registerPushToken = onCall(async (req) => {
  const c = requireAuth(req, true);
  const token = str(req.data?.token, 'token', { max: 4096 });
  const platform = oneOf(req.data?.platform, 'platform', PLATFORMS);
  if (token.length < 20 || /\s/.test(token)) fail('invalid-argument', 'token is not a valid FCM registration token.');
  const topics = topicsForRole(c.role);
  for (const topic of topics) {
    const r = await messaging.subscribeToTopic([token], topic);
    if (r.failureCount) {
      const code = r.errors[0]?.error?.code ?? 'unknown';
      fail('invalid-argument', `FCM rejected the token (${code}).`, { code });
    }
  }
  const ref = db.doc(`users/${c.uid}`);
  await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const list = ((s.get('fcmTokens') as string[] | undefined) ?? []).filter((t) => t !== token);
    list.push(token);
    const data: Json = { fcmTokens: list.slice(-MAX_TOKENS), pushPlatforms: { [platform]: now() }, updatedAt: now() };
    if (!s.exists && c.anonymous) data.anonymous = true;
    tx.set(ref, data, { merge: true });
  });
  return { ok: true, topics };
});

/** unregisterPushToken — signed-in (incl. anonymous): {token} → {ok, removed}. Removes it from fcmTokens and unsubscribes all topics (call on sign-out). */
export const unregisterPushToken = onCall(async (req) => {
  const c = requireAuth(req, true);
  const token = str(req.data?.token, 'token', { max: 4096 });
  const ref = db.doc(`users/${c.uid}`);
  const removed = await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const list = (s.get('fcmTokens') as string[] | undefined) ?? [];
    if (!s.exists || !list.includes(token)) return false;
    tx.update(ref, { fcmTokens: FieldValue.arrayRemove(token), updatedAt: now() });
    return true;
  });
  await Promise.all(ALL_TOPICS.map((t) => messaging.unsubscribeFromTopic([token], t).catch(() => undefined)));
  return { ok: true, removed };
});

// ───────────────────────── profile completion (phone OTP / Google sign-in)

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/**
 * completeProfile — signed-in, non-anonymous: {name, email?, phone?, referralCode?} →
 * {ok, profile{name,email,phone,photoUrl,referralCode,referredBy}, referral{applied, reason?}, warnings[]}.
 * Call right after the first phone-OTP or Google sign-in (also after linking an anonymous account). Initialises the users doc
 * if needed, sets name/email/phone (phone normalised to E.164, +91 default) and applies the referral code if the user
 * has no orders yet. Phone/email uniqueness is advisory only: clashes come back in `warnings` (email_in_use, phone_in_use).
 */
export const completeProfile = onCall({ secrets: [MAIL_PASSWORD] }, async (req) => {
  const c = requireAuth(req);
  const d = req.data ?? {};
  const name = str(d.name, 'name', { max: 80 });
  const email = str(d.email, 'email', { required: false, max: 120 }).toLowerCase();
  if (email && !EMAIL_RE.test(email)) fail('invalid-argument', 'email is not a valid email address.');
  const phoneRaw = str(d.phone, 'phone', { required: false, max: 20 });
  const phone = phoneRaw ? toE164(phoneRaw) : null;
  if (phoneRaw && !phone) fail('invalid-argument', 'phone is not a valid mobile number.');
  const code = str(d.referralCode, 'referralCode', { required: false, max: 20 }).toUpperCase();

  const user = await auth.getUser(c.uid);
  await ensureUserDoc(user);
  const ref = db.doc(`users/${c.uid}`);
  const cur = (await ref.get()).data() ?? {};

  const warnings: string[] = [];
  if (email && email !== String(cur.email ?? '').toLowerCase()) {
    const q = await db.collection('users').where('email', '==', email).limit(2).get();
    if (q.docs.some((x) => x.id !== c.uid)) warnings.push('email_in_use');
  }
  if (phone && phone !== cur.phone) {
    const q = await db.collection('users').where('phone', 'in', [phone, phone.slice(-10)]).limit(2).get();
    if (q.docs.some((x) => x.id !== c.uid)) warnings.push('phone_in_use');
  }

  const update: Json = { name, profileCompleted: true, updatedAt: now() };
  if (email) update.email = email;
  if (phone) update.phone = phone;
  else if (!cur.phone && user.phoneNumber) update.phone = user.phoneNumber;

  let referral: { applied: boolean; reason?: string } = { applied: false };
  if (code) {
    if (cur.referredBy) referral = { applied: false, reason: 'already_referred' };
    else if (code === cur.referralCode) referral = { applied: false, reason: 'own_code' };
    else if (!(await db.collection('orders').where('userId', '==', c.uid).limit(1).get()).empty) referral = { applied: false, reason: 'has_orders' };
    else {
      const owner = await db.collection('users').where('referralCode', '==', code).limit(1).get();
      if (owner.empty || owner.docs[0].id === c.uid) referral = { applied: false, reason: 'invalid_code' };
      else { update.referredBy = code; referral = { applied: true }; }
    }
  }
  await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (update.referredBy && s.get('referredBy')) { delete update.referredBy; referral = { applied: false, reason: 'already_referred' }; }
    tx.set(ref, update, { merge: true });
  });
  if (user.displayName !== name) await auth.updateUser(c.uid, { displayName: name }).catch((e) => logger.warn('displayName update failed', { error: String(e) }));
  // Phone users who add an email now get the welcome email once.
  const after = (await ref.get()).data() ?? {};
  if (email && !cur.email && !after.welcomeSentAt && await sendTemplateEmail('welcome', email, { name, referralCode: after.referralCode })) await ref.set({ welcomeSentAt: now() }, { merge: true });
  return {
    ok: true,
    profile: { name: after.name ?? name, email: after.email ?? null, phone: after.phone ?? null, photoUrl: after.photoUrl ?? null, referralCode: after.referralCode ?? null, referredBy: after.referredBy ?? null },
    referral,
    warnings,
  };
});

async function applyRole(uid: string, role: string) {
  const u = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, { ...(u.customClaims ?? {}), role });
  await db.doc(`users/${uid}`).set({ role, updatedAt: now() }, { merge: true });
}

/** setUserRole — admin: {uid, role, status?: active|blocked} → {ok}. Blocking also disables the Auth account. */
export const setUserRole = onCall(async (req) => {
  const c = requireRole(req, 'admin');
  const uid = str(req.data?.uid, 'uid', { max: 128 });
  if (req.data?.role) {
    const role = oneOf(req.data.role, 'role', ROLES);
    if (uid === c.uid && role !== 'admin') fail('failed-precondition', 'You cannot remove your own admin role.');
    await applyRole(uid, role);
  }
  if (req.data?.status) {
    const status = oneOf(req.data.status, 'status', ['active', 'blocked'] as const);
    if (uid === c.uid) fail('failed-precondition', 'You cannot block yourself.');
    await auth.updateUser(uid, { disabled: status === 'blocked' });
    if (status === 'blocked') await auth.revokeRefreshTokens(uid);
    await db.doc(`users/${uid}`).set({ status, updatedAt: now() }, { merge: true });
  }
  return { ok: true };
});

/**
 * createStaffUser — admin: {email, password, name, role, phone?} → {uid}.
 * `role` is either a platform role (customer|seller|delivery|admin) or an adminRoles/{id}; staff roles get claim role=admin + staffRole.
 */
export const createStaffUser = onCall(async (req) => {
  const c = requireRole(req, 'admin');
  const d = req.data ?? {};
  const email = str(d.email, 'email', { max: 120 }).toLowerCase();
  const password = str(d.password, 'password', { max: 128 });
  if (password.length < 8) fail('invalid-argument', 'Password must be at least 8 characters.');
  const name = str(d.name, 'name', { max: 80 });
  const roleIn = str(d.role, 'role', { max: 64 });
  let claimRole = roleIn;
  let staffRole: string | null = null;
  if (!ROLES.includes(roleIn as any)) {
    const r = await db.doc(`adminRoles/${roleIn}`).get();
    if (!r.exists) fail('not-found', `Unknown role ${roleIn}.`);
    claimRole = 'admin';
    staffRole = roleIn;
  }
  let user;
  try {
    user = await auth.createUser({ email, password, displayName: name, emailVerified: true });
  } catch (e: any) {
    if (e?.code === 'auth/email-already-exists') fail('already-exists', 'An account with this email already exists.');
    throw e;
  }
  await auth.setCustomUserClaims(user.uid, { role: claimRole, ...(staffRole ? { staffRole } : {}) });
  await db.doc(`users/${user.uid}`).set({
    name, email, phone: str(d.phone, 'phone', { required: false, max: 20 }), role: claimRole, status: 'active', walletBalance: 0,
    fcmTokens: [], createdAt: now(), updatedAt: now(),
  }, { merge: true });
  if (claimRole === 'admin') {
    await db.doc(`staff/${user.uid}`).set({ name, email, roleId: staffRole ?? 'super_admin', createdBy: c.uid, active: true, createdAt: now(), updatedAt: now() });
  }
  return { uid: user.uid, role: claimRole, staffRole };
});
