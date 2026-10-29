import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { db, now } from '../lib/admin.js';
import { SMS_SECRETS } from '../lib/config.js';
import { commSettings } from '../lib/notify.js';
import { deliverSms, resolveProvider, toE164 } from '../lib/sms.js';
import type { Json } from '../lib/util.js';

/**
 * onSmsQueued — smsOutbox/{id} onCreate. Sends queued SMS through the configured provider and records
 * status (sent | failed | skipped_no_provider | skipped_disabled | invalid_number), provider, providerMessageId, error, attempts.
 * Never throws; retries are bounded inside deliverSms (3 attempts, transient errors only). Event retries are off.
 */
export const onSmsQueued = onDocumentCreated({ document: 'smsOutbox/{id}', secrets: SMS_SECRETS, retry: false, timeoutSeconds: 60 }, async (event) => {
  const ref = db.doc(`smsOutbox/${event.params.id}`);
  try {
    // Claim the doc so a duplicate event delivery never sends twice.
    const msg = await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      const d: Json | undefined = s.data();
      if (!d || (d.status && d.status !== 'queued')) return null;
      tx.update(ref, { status: 'sending', updatedAt: now() });
      return d;
    });
    if (!msg) return;
    const to = toE164(msg.to);
    const text = String(msg.text ?? '').trim();
    const event_ = String(msg.event ?? 'test');
    if (!to || !text) {
      await ref.update({ status: 'invalid_number', error: !to ? 'Could not normalise the number to E.164.' : 'Empty text.', updatedAt: now() });
      return;
    }
    const r = await resolveProvider();
    if (!r.ready) {
      await ref.update({ status: 'skipped_no_provider', provider: r.provider, error: r.reason ?? 'SMS provider not configured', to, updatedAt: now() });
      return;
    }
    const comm = await commSettings();
    if (comm.sms?.enabled !== true && msg.test !== true) {
      await ref.update({ status: 'skipped_disabled', provider: r.provider, error: 'settings/communication.sms.enabled is not true', to, updatedAt: now() });
      return;
    }
    const res = await deliverSms(r, { ...msg, to, text, event: event_, vars: msg.vars ?? {} });
    await ref.update({
      status: res.ok ? 'sent' : 'failed', provider: r.provider, to, providerMessageId: res.providerMessageId, error: res.error,
      attempts: res.attempts, ...(res.ok ? { sentAt: now() } : {}), updatedAt: now(),
    });
    if (!res.ok) logger.warn('sms failed', { id: event.params.id, provider: r.provider, error: res.error });
  } catch (e) {
    logger.error('onSmsQueued crashed', { id: event.params.id, error: String(e) });
    await ref.update({ status: 'failed', error: String(e).slice(0, 500), updatedAt: now() }).catch(() => undefined);
  }
});
