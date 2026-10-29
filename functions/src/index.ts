// Go4Market Cloud Functions — the backend API. Contract: docs/ARCHITECTURE.md, feature map: docs/API.md.
import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({ region: 'asia-south1', memory: '256MiB', timeoutSeconds: 60, maxInstances: 20 });

// Orders & checkout
export { getCheckoutQuote, placeOrder, validateCoupon, updateOrderStatus, assignDeliveryPartner, acceptDelivery, posCheckout } from './orders/callables.js';
// Payments & wallet top-ups
export { confirmPayment, walletTopup, confirmWalletTopup, paymentWebhook } from './payments/index.js';
// Wallet, payouts, membership
export { adjustWallet, transferFunds, purchaseMembership } from './wallet/index.js';
// Users & roles
export { onUserCreated, setUserRole, createStaffUser, registerPushToken, unregisterPushToken, completeProfile } from './users/index.js';
// Sellers & withdrawals
export { registerSeller, reviewSeller, requestWithdrawal, processWithdrawal } from './sellers/index.js';
// Delivery partners
export { registerDeliveryPartner, reviewDeliveryPartner, settleCash, createSellerRider } from './delivery/index.js';
// Returns
export { requestReturn, processReturn } from './returns/index.js';
// Marketing & content
export { sendCampaign, generateDescription, submitReview } from './marketing/index.js';
// Catalog discovery
export { searchProducts, getRecommendations, getNearbyStores } from './catalog/index.js';
// Reports & admin
export { salesReport, abandonedCarts, getSystemStatus } from './reports/index.js';
// SEO
export { sitemap } from './seo/index.js';
// Triggers & scheduled jobs
export { onOrderWritten } from './triggers/orders.js';
export { onMailCreated } from './triggers/mail.js';
export { onSmsQueued } from './triggers/sms.js';
export { onProductWritten, onReviewWritten, onUserWritten, onDeliveryPartnerWritten, onAttributeWritten } from './triggers/catalog.js';
export { runSubscriptions, cleanupPendingOrders, remindAbandonedCarts, runMonthlySalaries, backupFirestore } from './triggers/scheduled.js';
