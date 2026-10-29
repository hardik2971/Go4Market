// Go4Market panel push service worker (admin / seller / delivery).
// tool/build_all.ps1 writes a patched copy into each build/<panel>/ (PANEL_TITLE, PANEL_ICON).
const PANEL_TITLE = 'Go4Market';
const PANEL_ICON = '/icons/Icon-192.png';

// Registered BEFORE the Firebase SDK so our handler wins: every click opens the order inside
// this panel (/orders/<orderId>) instead of the generic fcmOptions.link.
self.addEventListener('notificationclick', (event) => {
  event.stopImmediatePropagation();
  event.notification.close();
  const raw = event.notification.data || {};
  const msg = raw.FCM_MSG || raw;
  const data = (msg && msg.data) || raw.data || raw || {};
  let path = '/';
  if (data.orderId) path = '/orders/' + encodeURIComponent(data.orderId);
  else if (data.url) {
    try {
      const u = new URL(data.url);
      if (u.origin === self.location.origin) path = u.pathname + u.search;
    } catch (_) {}
  }
  const target = new URL(path, self.location.origin).href;
  event.waitUntil((async () => {
    const wins = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const w of wins) {
      if (new URL(w.url).origin === self.location.origin) {
        await w.focus();
        // The app navigates in-place (keeps state); fall back to a full navigation.
        w.postMessage({ type: 'g4m-open', path });
        return;
      }
    }
    await clients.openWindow(target);
  })());
});

importScripts('https://www.gstatic.com/firebasejs/12.9.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.9.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB2xehXMJCcMIPSVpnE26HFt9F_R_ppRGo',
  authDomain: 'go4market.firebaseapp.com',
  projectId: 'go4market',
  storageBucket: 'go4market.firebasestorage.app',
  messagingSenderId: '734533490664',
  appId: '1:734533490664:web:dbd25e9c62cdc58c04b65d',
});

const messaging = firebase.messaging();

// Messages with a `notification` block are shown by the SDK. Data-only messages are shown here.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const d = payload.data || {};
  return self.registration.showNotification(d.title || PANEL_TITLE, {
    body: d.body || '',
    icon: PANEL_ICON,
    badge: PANEL_ICON,
    data: { data: d },
    tag: d.orderId ? 'order-' + d.orderId : undefined,
  });
});
