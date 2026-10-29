// Payment gateway adapters: Razorpay (Orders API + HMAC), Stripe (hosted Checkout Sessions), PayPal (Orders v2).
import crypto from 'node:crypto';
import Stripe from 'stripe';
import { cfg, PAYPAL_CLIENT_SECRET, RAZORPAY_KEY_SECRET, STRIPE_SECRET_KEY } from '../lib/config.js';
import { fail, round2, type Json } from '../lib/util.js';

export type Provider = 'razorpay' | 'stripe' | 'paypal';
export type Kind = 'order' | 'topup';

export interface PaymentRequest {
  kind: Kind;
  refId: string; // orderId or topupId
  refNo: string; // orderNo / display reference
  amountInr: number;
  customer: { name?: string; email?: string; phone?: string };
  uid: string;
  fx: Json; // settings/platform.fx
}

/** Converts INR to the target currency using settings/platform.fx ({usd: 0.012}). */
export function convert(amountInr: number, currency: string, fx: Json): number {
  const c = currency.toUpperCase();
  if (c === 'INR') return round2(amountInr);
  const rate = Number(fx?.[c.toLowerCase()]);
  if (!rate || rate <= 0) fail('failed-precondition', `No FX rate configured for ${c} in settings/platform.fx.`);
  return round2(amountInr * rate);
}

function returnUrl(provider: Provider, req: PaymentRequest, extra = '') {
  const kindQ = req.kind === 'topup' ? '&kind=topup' : '';
  return `${cfg.websiteUrl()}/payment/return?provider=${provider}&orderId=${encodeURIComponent(req.refId)}${kindQ}${extra}`;
}

// ───────────────────────── Razorpay
const rzpAuth = () => 'Basic ' + Buffer.from(`${cfg.razorpayKeyId()}:${RAZORPAY_KEY_SECRET.value()}`).toString('base64');

export async function razorpayCreate(req: PaymentRequest): Promise<Json> {
  const currency = cfg.razorpayCurrency();
  const amount = Math.round(convert(req.amountInr, currency, req.fx) * 100);
  if (amount < 100) fail('failed-precondition', 'Online payment amount must be at least ₹1.');
  const res = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: rzpAuth(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ amount, currency, receipt: req.refNo.slice(0, 40), notes: { refId: req.refId, kind: req.kind, uid: req.uid } }),
  });
  const j = (await res.json()) as Json;
  if (!res.ok) fail('unavailable', `Razorpay error: ${j?.error?.description ?? res.status}`);
  return {
    provider: 'razorpay', razorpayOrderId: j.id, keyId: cfg.razorpayKeyId(), amount, currency,
    name: 'Go4Market', description: req.kind === 'topup' ? 'Wallet top-up' : `Order ${req.refNo}`,
    prefill: { name: req.customer.name ?? '', email: req.customer.email ?? '', contact: req.customer.phone ?? '', phone: req.customer.phone ?? '' },
    notes: { refId: req.refId, kind: req.kind },
  };
}

export function razorpayVerifySignature(orderId: string, paymentId: string, signature: string): boolean {
  const expected = crypto.createHmac('sha256', RAZORPAY_KEY_SECRET.value()).update(`${orderId}|${paymentId}`).digest('hex');
  const a = Buffer.from(expected), b = Buffer.from(String(signature));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

export async function razorpayFetchOrder(rzpOrderId: string): Promise<Json> {
  const res = await fetch(`https://api.razorpay.com/v1/orders/${encodeURIComponent(rzpOrderId)}`, { headers: { Authorization: rzpAuth() } });
  const j = (await res.json()) as Json;
  if (!res.ok) fail('unavailable', `Razorpay error: ${j?.error?.description ?? res.status}`);
  return j;
}

// ───────────────────────── Stripe (Checkout Sessions, hosted)
let stripeClient: Stripe | null = null;
const stripe = () => (stripeClient ??= new Stripe(STRIPE_SECRET_KEY.value()));

export async function stripeCreate(req: PaymentRequest): Promise<Json> {
  const currency = cfg.stripeCurrency();
  const amount = convert(req.amountInr, currency, req.fx);
  const unit = Math.round(amount * 100);
  if (currency !== 'INR' && unit < 50) fail('failed-precondition', 'Amount is below the card minimum for this currency. Use another method.');
  const session = await stripe().checkout.sessions.create({
    mode: 'payment',
    client_reference_id: req.refId,
    customer_email: req.customer.email || undefined,
    line_items: [{
      quantity: 1,
      price_data: {
        currency: currency.toLowerCase(),
        unit_amount: unit,
        product_data: { name: req.kind === 'topup' ? 'Go4Market wallet top-up' : `Go4Market order ${req.refNo}`, description: `₹${round2(req.amountInr)} (INR)` },
      },
    }],
    metadata: { refId: req.refId, kind: req.kind, uid: req.uid, amountInr: String(round2(req.amountInr)) },
    payment_intent_data: { metadata: { refId: req.refId, kind: req.kind, uid: req.uid } },
    success_url: returnUrl('stripe', req, '&session_id={CHECKOUT_SESSION_ID}'),
    cancel_url: returnUrl('stripe', req, '&cancelled=1'),
    expires_at: Math.floor(Date.now() / 1000) + 60 * 60,
  });
  return { provider: 'stripe', checkoutUrl: session.url, sessionId: session.id, amount: unit, currency };
}

export async function stripeVerify(refId: string, sessionId?: string, paymentIntentId?: string): Promise<{ paid: boolean; ref: string; status: string }> {
  if (sessionId) {
    const s = await stripe().checkout.sessions.retrieve(sessionId);
    if (s.metadata?.refId !== refId && s.client_reference_id !== refId) fail('permission-denied', 'Session does not belong to this order.');
    const pi = typeof s.payment_intent === 'string' ? s.payment_intent : s.payment_intent?.id;
    return { paid: s.payment_status === 'paid', ref: pi ?? s.id, status: s.payment_status };
  }
  if (paymentIntentId) {
    const pi = await stripe().paymentIntents.retrieve(paymentIntentId);
    if (pi.metadata?.refId !== refId) fail('permission-denied', 'Payment does not belong to this order.');
    return { paid: pi.status === 'succeeded', ref: pi.id, status: pi.status };
  }
  fail('invalid-argument', 'sessionId is required for Stripe.');
}

export async function stripeRetrieveSession(sessionId: string) {
  return stripe().checkout.sessions.retrieve(sessionId);
}

// ───────────────────────── PayPal Orders v2
const paypalBase = () => (cfg.paypalEnv() === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com');
let ppToken: { token: string; exp: number } | null = null;

async function paypalToken(): Promise<string> {
  if (ppToken && ppToken.exp > Date.now() + 60_000) return ppToken.token;
  const res = await fetch(`${paypalBase()}/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + Buffer.from(`${cfg.paypalClientId()}:${PAYPAL_CLIENT_SECRET.value()}`).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  const j = (await res.json()) as Json;
  if (!res.ok) fail('unavailable', `PayPal auth error: ${j?.error_description ?? res.status}`);
  ppToken = { token: j.access_token, exp: Date.now() + Number(j.expires_in) * 1000 };
  return ppToken.token;
}

export async function paypalCreate(req: PaymentRequest): Promise<Json> {
  const currency = cfg.paypalCurrency();
  const amount = convert(req.amountInr, currency, req.fx);
  if (amount < 0.01) fail('failed-precondition', 'Amount is too small for PayPal.');
  const res = await fetch(`${paypalBase()}/v2/checkout/orders`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${await paypalToken()}`, 'Content-Type': 'application/json', 'PayPal-Request-Id': `${req.kind}-${req.refId}` },
    body: JSON.stringify({
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: req.refId, custom_id: `${req.kind}:${req.refId}`, invoice_id: `${req.refNo}-${Date.now()}`.slice(0, 127),
        description: req.kind === 'topup' ? 'Go4Market wallet top-up' : `Go4Market order ${req.refNo}`,
        amount: { currency_code: currency, value: amount.toFixed(2) },
      }],
      payment_source: {
        paypal: {
          experience_context: {
            brand_name: 'Go4Market', user_action: 'PAY_NOW', shipping_preference: 'NO_SHIPPING',
            return_url: returnUrl('paypal', req), cancel_url: returnUrl('paypal', req, '&cancelled=1'),
          },
        },
      },
    }),
  });
  const j = (await res.json()) as Json;
  if (!res.ok) fail('unavailable', `PayPal error: ${j?.message ?? res.status}`);
  const approve = (j.links as Json[] | undefined)?.find((l) => l.rel === 'payer-action' || l.rel === 'approve')?.href;
  return { provider: 'paypal', paypalOrderId: j.id, approveUrl: approve, amount, currency };
}

/** Captures an approved PayPal order (idempotent: an already-captured order returns COMPLETED). */
export async function paypalCapture(paypalOrderId: string, refId: string): Promise<{ paid: boolean; ref: string; status: string }> {
  const token = await paypalToken();
  const res = await fetch(`${paypalBase()}/v2/checkout/orders/${encodeURIComponent(paypalOrderId)}/capture`, {
    method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'PayPal-Request-Id': `cap-${paypalOrderId}` },
  });
  let j = (await res.json()) as Json;
  if (!res.ok) {
    const issue = j?.details?.[0]?.issue;
    if (issue === 'ORDER_ALREADY_CAPTURED') {
      const g = await fetch(`${paypalBase()}/v2/checkout/orders/${encodeURIComponent(paypalOrderId)}`, { headers: { Authorization: `Bearer ${token}` } });
      j = (await g.json()) as Json;
    } else {
      return { paid: false, ref: paypalOrderId, status: issue ?? j?.name ?? 'FAILED' };
    }
  }
  const pu = j.purchase_units?.[0];
  if (pu?.reference_id && pu.reference_id !== refId) fail('permission-denied', 'PayPal order does not belong to this order.');
  const capture = pu?.payments?.captures?.[0];
  return { paid: j.status === 'COMPLETED' && (!capture || capture.status === 'COMPLETED'), ref: capture?.id ?? paypalOrderId, status: j.status };
}

export async function createPayment(provider: Provider, req: PaymentRequest): Promise<Json> {
  if (provider === 'razorpay') return razorpayCreate(req);
  if (provider === 'stripe') return stripeCreate(req);
  if (provider === 'paypal') return paypalCreate(req);
  fail('invalid-argument', 'Unknown payment provider.');
}

/**
 * Refunds part or all of a captured online payment back to the original method.
 * `paymentRef` is what we stored on the order: Razorpay payment id, Stripe PaymentIntent id or PayPal capture id.
 * `idem` makes the call idempotent where the provider supports it (Stripe, PayPal).
 */
export async function refundToSource(provider: string, paymentRef: string, amountInr: number, fx: Json, idem: string): Promise<{ id: string; status: string }> {
  if (!paymentRef) fail('failed-precondition', 'No captured payment reference on this order.');
  if (provider === 'razorpay') {
    const currency = cfg.razorpayCurrency();
    const amount = Math.round(convert(amountInr, currency, fx) * 100);
    const res = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentRef)}/refund`, {
      method: 'POST', headers: { Authorization: rzpAuth(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount, notes: { ref: idem }, receipt: idem.slice(0, 40) }),
    });
    const j = (await res.json()) as Json;
    if (!res.ok) fail('unavailable', `Razorpay refund failed: ${j?.error?.description ?? res.status}`);
    return { id: j.id, status: j.status };
  }
  if (provider === 'stripe') {
    const currency = cfg.stripeCurrency();
    const amount = Math.round(convert(amountInr, currency, fx) * 100);
    const r = await stripe().refunds.create({ payment_intent: paymentRef, amount, metadata: { ref: idem } }, { idempotencyKey: `refund-${idem}` });
    return { id: r.id, status: r.status ?? 'pending' };
  }
  if (provider === 'paypal') {
    const currency = cfg.paypalCurrency();
    const value = convert(amountInr, currency, fx).toFixed(2);
    const res = await fetch(`${paypalBase()}/v2/payments/captures/${encodeURIComponent(paymentRef)}/refund`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await paypalToken()}`, 'Content-Type': 'application/json', 'PayPal-Request-Id': `refund-${idem}` },
      body: JSON.stringify({ amount: { value, currency_code: currency }, note_to_payer: 'Go4Market refund' }),
    });
    const j = (await res.json()) as Json;
    if (!res.ok) fail('unavailable', `PayPal refund failed: ${j?.message ?? res.status}`);
    return { id: j.id, status: j.status };
  }
  fail('failed-precondition', `Refund to source is not supported for ${provider}.`);
}
