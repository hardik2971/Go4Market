import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';
import { db, now } from '../lib/admin.js';
import { MAIL_PASSWORD } from '../lib/config.js';
import { sendRawEmail } from '../lib/notify.js';
import type { Json } from '../lib/util.js';

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const AUDIENCE_ROLE: Record<string, string | null> = { all: null, customers: 'customer', sellers: 'seller', delivery: 'delivery' };
const MAX_AUDIENCE = 450; // Gmail SMTP sends ~500/day; stay under it.

/**
 * onMailCreated — sends documents written to `mail/{id}` (admin-only collection, see rules).
 * Shape (Trigger-Email compatible): {to?: string|string[], audience?: all|customers|sellers|delivery, cc?, bcc?,
 *   message: {subject, html?, text?}, replyTo?}. Result is written back as
 *   delivery {state: PROCESSING|SUCCESS|ERROR, attempts, recipients, error?, startTime, endTime} and status (sent/failed).
 */
export const onMailCreated = onDocumentCreated({ document: 'mail/{mailId}', secrets: [MAIL_PASSWORD], timeoutSeconds: 300, retry: false }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const m = snap.data() as Json;
  if (m.delivery?.state && m.delivery.state !== 'PENDING') return;
  await snap.ref.update({ delivery: { state: 'PROCESSING', attempts: 1, startTime: now() }, status: 'processing' });
  try {
    const subject = String(m.message?.subject ?? m.subject ?? '').trim().slice(0, 300);
    const html = m.message?.html ?? m.html;
    const text = m.message?.text ?? m.text;
    if (!subject || (!html && !text)) throw new Error('subject and html/text are required');

    let to: string[] = (Array.isArray(m.to) ? m.to : m.to ? [m.to] : []).map(String).filter((e: string) => EMAIL.test(e)).slice(0, 50);
    let bcc: string[] = (Array.isArray(m.bcc) ? m.bcc : m.bcc ? [m.bcc] : []).map(String).filter((e: string) => EMAIL.test(e)).slice(0, 50);
    if (m.audience) {
      if (!(m.audience in AUDIENCE_ROLE)) throw new Error(`unknown audience ${m.audience}`);
      let q = db.collection('users').where('status', '==', 'active');
      if (AUDIENCE_ROLE[m.audience]) q = q.where('role', '==', AUDIENCE_ROLE[m.audience]);
      const users = await q.select('email').limit(MAX_AUDIENCE).get();
      bcc = [...new Set([...bcc, ...users.docs.map((u) => String(u.get('email') ?? '')).filter((e) => EMAIL.test(e))])];
    }
    if (!to.length && !bcc.length) throw new Error('no valid recipients');
    // Bulk mail goes out as BCC batches of 50 so recipients never see each other.
    let sent = 0;
    if (to.length) {
      if (!(await sendRawEmail({ to, subject, html, text, replyTo: m.replyTo }))) throw new Error('SMTP is not configured');
      sent += to.length;
    }
    for (let i = 0; i < bcc.length; i += 50) {
      const chunk = bcc.slice(i, i + 50);
      if (!(await sendRawEmail({ bcc: chunk, subject, html, text, replyTo: m.replyTo }))) throw new Error('SMTP is not configured');
      sent += chunk.length;
    }
    await snap.ref.update({ delivery: { state: 'SUCCESS', attempts: 1, recipients: sent, startTime: m.createdAt ?? null, endTime: now() }, status: 'sent', sentAt: now() });
  } catch (e: any) {
    logger.warn('mail send failed', { id: event.params.mailId, error: String(e?.message ?? e) });
    await snap.ref.update({ delivery: { state: 'ERROR', attempts: 1, error: String(e?.message ?? e).slice(0, 500), endTime: now() }, status: 'failed' });
  }
});
