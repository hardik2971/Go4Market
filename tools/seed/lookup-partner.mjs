// Prints the delivery-partner record for an email: node lookup-partner.mjs <email>
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';
initializeApp({ credential: cert(JSON.parse(readFileSync(new URL('../../secret/go4market-firebase-adminsdk.json', import.meta.url)))) });
const u = await getAuth().getUserByEmail(process.argv[2]);
const d = (await getFirestore().doc(`deliveryPartners/${u.uid}`).get()).data() ?? {};
console.log({ uid: u.uid, name: d.name, status: d.status, online: d.online, ownerType: d.ownerType, cashInHand: d.cashInHand });
