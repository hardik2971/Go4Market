#!/usr/bin/env node
// Smoke test for v1.2 (push tokens, completeProfile, SMS outbox) against the LIVE project with the client JS SDK.
// Restores every field it changes on the demo customer and deletes the test smsOutbox doc.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, signInAnonymously, updateProfile, signOut } from 'firebase/auth';
import { getFirestore, doc, getDoc, updateDoc, addDoc, deleteDoc, collection, deleteField } from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';

const here = path.dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(fs.readFileSync(path.resolve(here, '../../config/web_sdk.json'), 'utf8'));
const PASSWORD = 'Go4Market@123';
const show = (label, v) => console.log(`${label}:`, JSON.stringify(v));
const err = (e) => ({ code: e.code, message: e.message, details: e.details });

async function session(name, email) {
  const app = initializeApp(config, name);
  const auth = getAuth(app);
  const cred = email ? await signInWithEmailAndPassword(auth, email, PASSWORD) : await signInAnonymously(auth);
  return { app, auth, user: cred.user, db: getFirestore(app), fn: (n) => httpsCallable(getFunctions(app, 'asia-south1'), n) };
}

// 1. registerPushToken with a dummy token (customer + anonymous) and validation errors
const cust = await session('cust', 'customer@go4market.com');
const dummy = 'dummy-token-' + 'x'.repeat(140);
for (const [label, s, data] of [
  ['registerPushToken customer dummy', cust, { token: dummy, platform: 'web' }],
  ['registerPushToken bad platform', cust, { token: dummy, platform: 'windows' }],
  ['unregisterPushToken customer dummy', cust, { token: dummy }],
]) {
  try { show(label, (await s.fn(label.split(' ')[0])(data)).data); } catch (e) { show(label + ' ERROR', err(e)); }
}
const anon = await session('anon');
try { show('registerPushToken anonymous dummy', (await anon.fn('registerPushToken')({ token: dummy, platform: 'android' })).data); } catch (e) { show('registerPushToken anonymous dummy ERROR', err(e)); }
try { show('completeProfile anonymous', (await anon.fn('completeProfile')({ name: 'X' })).data); } catch (e) { show('completeProfile anonymous ERROR', err(e)); }
await anon.user.delete().catch(() => undefined);

// 2. completeProfile on the demo customer, then restore
const uref = doc(cust.db, `users/${cust.user.uid}`);
const orig = (await getDoc(uref)).data();
const keep = { name: orig.name, email: orig.email, phone: orig.phone, referredBy: orig.referredBy, profileCompleted: orig.profileCompleted, welcomeSentAt: orig.welcomeSentAt };
show('customer before', { name: keep.name, email: keep.email, phone: keep.phone, referredBy: keep.referredBy ?? null, profileCompleted: keep.profileCompleted ?? null, displayName: cust.user.displayName });
try {
  show('completeProfile customer', (await cust.fn('completeProfile')({ name: 'Smoke Customer', email: orig.email, phone: '098765 43210', referralCode: 'NOSUCH99' })).data);
} catch (e) { show('completeProfile customer ERROR', err(e)); }
try { show('completeProfile invalid phone', (await cust.fn('completeProfile')({ name: 'Smoke Customer', phone: '12345' })).data); } catch (e) { show('completeProfile invalid phone ERROR', err(e)); }
const restore = { name: keep.name, email: keep.email ?? deleteField(), phone: keep.phone ?? deleteField(), profileCompleted: keep.profileCompleted ?? deleteField() };
await updateDoc(uref, restore);
await updateProfile(cust.user, { displayName: orig.name ?? null });
const after = (await getDoc(uref)).data();
show('customer restored', { name: after.name, email: after.email, phone: after.phone, referredBy: after.referredBy ?? null, profileCompleted: after.profileCompleted ?? null });
await signOut(cust.auth);

// 3. SMS enqueue (admin test doc) → expect skipped_no_provider
const admin = await session('admin', 'admin@go4market.com');
const ref = await addDoc(collection(admin.db, 'smsOutbox'), { to: '98765 43210', text: 'Go4Market smoke test (not sent)', event: 'test', test: true, status: 'queued' });
let sms;
for (let i = 0; i < 20; i++) {
  await new Promise((r) => setTimeout(r, 2000));
  sms = (await getDoc(ref)).data();
  if (sms && !['queued', 'sending'].includes(sms.status)) break;
}
show('smsOutbox result', { id: ref.id, status: sms?.status, provider: sms?.provider, to: sms?.to, error: sms?.error, providerMessageId: sms?.providerMessageId ?? null });
await deleteDoc(ref);
try { const st = (await admin.fn('getSystemStatus')({})).data; show('getSystemStatus.integrations', { sms: st.integrations.sms, smsProvider: st.integrations.smsProvider, smtp: st.integrations.smtp }); } catch (e) { show('getSystemStatus ERROR', err(e)); }
process.exit(0);
