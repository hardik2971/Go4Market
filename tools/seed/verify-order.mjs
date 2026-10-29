// Prints the server-side state of an order and the balances it touched: node verify-order.mjs G4M100011
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';
initializeApp({ credential: cert(JSON.parse(readFileSync(new URL('../../secret/go4market-firebase-adminsdk.json', import.meta.url)))) });
const db = getFirestore();
const o = (await db.collection('orders').where('orderNo', '==', process.argv[2]).get()).docs[0];
const d = o.data();
const seller = (await db.doc(`sellers/${d.sellerIds[0]}`).get()).data();
const rider = (await db.doc(`deliveryPartners/${d.deliveryPartnerId}`).get()).data();
const cash = await db.collection('cashCollections').where('orderId', '==', o.id).get();
const coupon = (await db.doc(`coupons/${d.couponCode}`).get()).data();
const ov = (await db.doc('stats/overview').get()).data();
console.log(JSON.stringify({
  order: { id: o.id, status: d.status, paymentStatus: d.paymentStatus, total: d.total, cashCollected: d.cashCollected, timeline: d.timeline.map((t) => t.status) },
  seller: { store: seller.storeName, balance: seller.balance, totalSales: seller.totalSales, commissionPct: seller.commissionPct },
  rider: { name: rider.name, cashInHand: rider.cashInHand, balance: rider.balance, completed: rider.completedCount },
  cashCollections: cash.docs.map((c) => c.data().amount),
  coupon: { code: d.couponCode, usedCount: coupon?.usedCount },
  statsOverview: { orders: ov.orders, revenue: ov.revenue, delivered: ov.delivered },
}, null, 1));
