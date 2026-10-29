/* Go4Market web push service worker (Firebase Cloud Messaging).
 * Compat SDK pinned to the Firebase JS version FlutterFire is tested against (firebase_core_web 4.1.0).
 * Config mirrors config/web_sdk.json. */
const ICON = '/icons/Icon-192.png';
const BADGE = '/icons/favicon-32.png';

// Firebase's compat SDK calls registration.showNotification() for notification payloads.
// Wrap it so every notification carries the Go4Market icon and badge, even when the
// sender did not set one (the backend sends plain `notification {title, body}`).
(function brandNotifications() {
  const reg = self.registration;
  const original = reg.showNotification.bind(reg);
  reg.showNotification = function (title, options) {
    const o = Object.assign({}, options || {});
    if (!o.icon) o.icon = ICON;
    if (!o.badge) o.badge = BADGE;
    return original(title || 'Go4Market', o);
  };
})();

/** Same-origin path to open for a push payload: fcmOptions.link > data.link > order page > inbox. */
function targetUrl(payload) {
  const p = payload || {};
  const d = p.data || {};
  let link = (p.fcmOptions && p.fcmOptions.link) || d.link || (p.notification && p.notification.click_action) || '';
  if (!link && d.orderId) link = '/orders/' + encodeURIComponent(d.orderId);
  if (!link && d.type === 'wallet') link = '/wallet';
  if (!link) link = '/account?tab=notifications';
  try {
    const u = new URL(link, self.location.origin);
    // Only ever navigate inside the storefront.
    return u.origin === self.location.origin ? u.href : self.location.origin + '/';
  } catch (e) {
    return self.location.origin + '/';
  }
}

// Registered before the Firebase SDK so it wins: focus an open tab and navigate it,
// or open a new one, at the URL the notification points to.
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  const data = event.notification.data || {};
  const url = targetUrl(data.FCM_MSG || data);
  event.waitUntil((async () => {
    const wins = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const w of wins) {
      if (new URL(w.url).origin !== self.location.origin) continue;
      try {
        await w.focus();
        if ('navigate' in w) await w.navigate(url);
        return;
      } catch (e) { /* fall through to openWindow */ }
    }
    await clients.openWindow(url);
  })());
});

importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB2xehXMJCcMIPSVpnE26HFt9F_R_ppRGo',
  authDomain: 'go4market.firebaseapp.com',
  projectId: 'go4market',
  storageBucket: 'go4market.firebasestorage.app',
  messagingSenderId: '734533490664',
  appId: '1:734533490664:web:dbd25e9c62cdc58c04b65d',
});

const messaging = firebase.messaging();

// Notification payloads are displayed by the SDK itself (with the icon added above).
// Data-only messages are shown here so they are never silently dropped.
messaging.onBackgroundMessage((payload) => {
  if (payload && payload.notification) return;
  const d = (payload && payload.data) || {};
  if (!d.title && !d.body) return;
  return self.registration.showNotification(d.title || 'Go4Market', {
    body: d.body || '',
    image: d.image || undefined,
    tag: d.orderId ? 'order-' + d.orderId : undefined,
    renotify: !!d.orderId,
    data: { FCM_MSG: payload },
  });
});
