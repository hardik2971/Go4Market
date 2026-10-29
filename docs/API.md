# Go4Market — Backend API & Feature Coverage

Companion to `docs/ARCHITECTURE.md`, which is the data contract. This file maps each of the **98 features** in `documentation/FEATURES.md` to the Cloud Functions and Firestore collections that implement it.

All callables are in region **asia-south1**. Dart: `FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable(name)`. Web/Node: `httpsCallable(getFunctions(app, 'asia-south1'), name)`.
Errors are `HttpsError` codes: `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition` (business rule; `details` may carry `unavailable[]` / `shortBy`), `not-found`, `already-exists`, `unavailable` (payment gateway).
Roles come from the custom claim `role`. "public" means it can be called without signing in (or anonymously).

**Coverage: 98 / 98.** 91 features have a backend piece (function, trigger or rules-guarded collection). 7 are purely client-side or N/A (43, 45, 46, 49, 87, 88, 89) and are marked **[client]** or **[n/a]**.

---

## 1. Callable reference

### Checkout & orders
| Callable | Roles | Input | Output |
|---|---|---|---|
| `getCheckoutQuote` | any signed-in (incl. anonymous) | `{addressId?, couponCode?, useWallet?, speed?: standard\|quick15\|quick30\|scheduled, deliveryType?: home\|pickup, scheduledSlot?: {date:'yyyy-MM-dd', from:'HH:mm', to:'HH:mm'}}`. Reads the caller's cart. | `{subtotal, mrpTotal, deliveryFee, discount, couponDiscount, membershipDiscount, walletUsed, walletBalance, tax, total, payable, distanceKm, etaMinutes, itemCount, couponCode, couponError?, speedError?, minOrderError?, outOfRange?, codAllowed, unavailable[], items[]}` |
| `placeOrder` | customer (email account) | quote input + `{paymentMethod: cod\|razorpay\|stripe\|paypal\|wallet, channel: web\|app, notes?}` | `{orderId, orderNo, total, payable, walletUsed, status: placed\|pending, paymentMethod, payment?}`. `payment`: razorpay `{provider, razorpayOrderId, keyId, amount (paise), currency, name, description, prefill{name,email,contact,phone}}`; stripe `{provider, checkoutUrl, sessionId, amount, currency}`; paypal `{provider, paypalOrderId, approveUrl, amount, currency}` |
| `confirmPayment` | order owner / admin | `{orderId, provider, razorpayOrderId?, razorpayPaymentId?, razorpaySignature?, sessionId?, paymentIntentId?, paypalOrderId?}` | `{ok, status, paymentStatus, reason?}` |
| `validateCoupon` | signed-in | `{code, subtotal}` | `{valid, discount, message, code}` |
| `updateOrderStatus` | seller (own items) / delivery (assigned) / admin / customer (cancel) | `{orderId, status: confirmed\|packed\|picked_up\|out_for_delivery\|ready_for_pickup\|delivered\|cancelled, note?, otp?, cashCollected?}` | `{ok, status}` |
| `assignDeliveryPartner` | admin / seller | `{orderId, partnerId?}` (null = nearest online partner, seller fleet first) | `{partnerId, partnerName, distanceKm?}` |
| `acceptDelivery` | delivery | `{orderId}` | `{ok}` |
| `posCheckout` | admin / seller | `{items:[{productId? \| barcode?, variantId?, qty}], customer?:{name,phone,email}, paymentMethod: cash\|card\|upi, discount?}` | `{orderId, orderNo, total, subtotal, discount, items[]}` |
| `requestReturn` | customer (owner) | `{orderId, items?:[{productId, variantId?, qty}], reason, images?[]}` (items default to the whole order) | `{returnId, refundAmount, status:'requested'}` |
| `processReturn` | admin / seller of the items | `{returnId \| id, status: approved\|rejected\|picked\|refunded, refundAmount? (admin ≤ order total; seller may only lower), refundTo?: wallet\|source, note?}` | `{ok, status, refundAmount, refundTo}` |

### Wallet, payments, membership
| Callable | Roles | Input | Output |
|---|---|---|---|
| `walletTopup` | signed-in | `{amount: 10–50000, provider: razorpay\|stripe\|paypal}` | `{topupId, orderId (=topupId), amount, payment}` |
| `confirmWalletTopup` | owner | `{topupId \| orderId, provider, …provider fields as confirmPayment}` | `{ok, balance}` or `{ok:false, status}` |
| `adjustWallet` | admin | `{userId, amount, type: credit\|debit, note?, reason?: admin\|cashback\|refund\|referral}` | `{ok, balance}` |
| `purchaseMembership` | signed-in | `{planId}` | `{ok, expiresAt, balance}` |
| `transferFunds` | admin | `{toUserId, amount, note?, role?: seller\|delivery, type?: payout\|credit}`. A payout debits earnings up to the amount (never below 0); any excess is recorded as `direct` | `{ok, id, balance}` |
| `requestWithdrawal` | seller / delivery | `{amount ≥ 100, method?: bank\|upi\|cash, note?, details?: string \| {bank/UPI fields}}` | `{ok, id, balance}` |
| `processWithdrawal` | admin | `{id, status: approved\|rejected\|paid (pending → paid allowed), note?, txnRef?}`. Emails the `withdrawal` template | `{ok, status}` |
| `settleCash` | admin / owning seller | `{partnerId, amount, note?}` | `{ok, cashInHand, settled}` |

### Users, sellers, delivery
| Callable | Roles | Input | Output |
|---|---|---|---|
| `registerSeller` | signed-in (not admin/delivery) | `{storeName, ownerName, phone, city, address, policiesAccepted:true, gstin?, description?, email?, logo?, banner?, lat?, lng?, modules?[], bank?{holder,account,ifsc}}` | `{ok, status:'pending', refreshToken:true}` |
| `reviewSeller` | admin | `{uid, status: approved\|rejected\|suspended\|pending, commissionPct?, note?, role? (ignored)}` | `{ok, status}` |
| `registerDeliveryPartner` | signed-in (not admin/seller) | `{name, phone, vehicleType?: bike\|scooter\|bicycle\|car\|van, vehicleNo?, licenseNo?, cities[], sellerId?, photoUrl?}` | `{ok, status:'pending', refreshToken:true}` |
| `createSellerRider` | seller (approved; `settings.sellerRidersEnabled`) | `{name, email, password ≥ 8, phone, vehicleType?, vehicleNo?, cities?[]}` | `{uid}`. Creates an Auth user (claim `delivery`) and an approved `deliveryPartners` doc with `ownerType:'seller'` and `sellerId` = caller |
| `reviewDeliveryPartner` | admin / owning seller | `{uid, status: approved\|suspended\|pending\|rejected, salary?{type: per_order\|monthly, amount}, cities?[], note?}` | `{ok, status}` |
| `setUserRole` | admin | `{uid, role?, status?: active\|blocked}` | `{ok}` |
| `createStaffUser` | admin | `{email, password (≥8), name, role (platform role or adminRoles id), phone?}` | `{uid, role, staffRole}` |
| `completeProfile` | signed-in (not anonymous) — call after the first phone-OTP / Google sign-in | `{name, email?, phone?, referralCode?}` | `{ok, profile{name,email,phone,photoUrl,referralCode,referredBy}, referral{applied, reason?: already_referred\|own_code\|has_orders\|invalid_code}, warnings[]: email_in_use\|phone_in_use}`. Phone → E.164 (+91 default). Uniqueness is advisory only |
| `registerPushToken` | any signed-in incl. anonymous | `{token, platform: web\|android\|ios}` | `{ok, topics[]}` — server-side topic subscribe (`all` + `customers\|sellers\|delivery`; admins `all` only) and `users.fcmTokens` (max 10). Bad token → `invalid-argument` "FCM rejected the token (messaging/…)" |
| `unregisterPushToken` | any signed-in incl. anonymous | `{token}` | `{ok, removed}` — removes it and unsubscribes all topics |

### Catalog, marketing, reports
| Callable | Roles | Input | Output |
|---|---|---|---|
| `searchProducts` | public | `{query, moduleId?, multi?, limit?}` | `{groups:[{term, products[]}], products[]}` |
| `getRecommendations` | public | `{productId, type: similar\|cross_sell\|replacement, limit?}` | `{products[]}` |
| `getNearbyStores` | public | `{lat, lng, moduleId?, radiusKm?}` | `{stores[]}` |
| `submitReview` | customer with a delivered order containing the product | `{productId, rating 1–5, comment?, images?[]}` | `{ok, updated}` |
| `generateDescription` | admin / seller | `{name, category?, keywords?[]}` | `{short, long, source: gemini\|template}` |
| `sendCampaign` | admin | `{campaignId}` | `{ok, messageId, inboxCount}` |
| `salesReport` | admin / seller | `{from, to, channel?, moduleId?, sellerId?}` | `{totals, byDay[], byStatus, byChannel, byPaymentMethod, byModule, topProducts[], slowProducts[]}` |
| `abandonedCarts` | admin / seller | `{olderThanHours?, limit?}` | `{carts[], count}` |
| `getSystemStatus` | admin | `{}` | `{integrations, stats, flags, lastBackup, region, node, serverTime}` |

### HTTP, triggers, schedules
| Function | Type | Purpose |
|---|---|---|
| `sitemap` | HTTP GET (hosting rewrite `/sitemap.xml`) | XML sitemap with image tags |
| `paymentWebhook` | HTTP POST | Razorpay / Stripe / PayPal events, re-verified against the provider API |
| `onUserCreated` | Auth v1 onCreate | users doc for email / phone-OTP / Google sign-ups (name, email, phone, photoUrl from the provider; phone-only → name `Customer`), referral code, `customer` claim, newUsers stat, welcome email (if an email exists) |
| `onOrderWritten` | Firestore | stats deltas, FCM + inbox, emails (+ `adminCopy` BCC), SMS outbox, referral payout, co-purchase graph, `settings.autoAssign` rider assignment on `packed` |
| `onSmsQueued` | Firestore (`smsOutbox/{id}` create) | sends via Twilio / MSG91 / Fast2SMS (`SMS_PROVIDER`), writes `status` (sent, failed, skipped_no_provider, skipped_disabled, invalid_number), `provider`, `providerMessageId`, `error`, `attempts` (≤ 3) |
| `onMailCreated` | Firestore (`mail/{id}` create) | sends admin-composed email (to / audience) via SMTP and writes `delivery.state` |
| `onProductWritten` | Firestore | keywords, slug, categoryPath, productCount, low-stock alerts |
| `onReviewWritten` | Firestore | product and seller rating aggregates |
| `onUserWritten` | Firestore | FCM topic subscriptions |
| `onDeliveryPartnerWritten` | Firestore | live rider location → `orders.riderLocation` |
| `onAttributeWritten` | Firestore | attribute-migration alerts to sellers |
| `runSubscriptions` | daily 07:00 IST | subscription orders |
| `cleanupPendingOrders` | hourly | cancel unpaid orders, expire top-ups |
| `remindAbandonedCarts` | daily 18:00 IST | cart reminders |
| `runMonthlySalaries` | 1st 09:00 IST | monthly rider salaries |
| `backupFirestore` | weekly | Firestore export to Storage |

---

## 2. Feature → backend map

| # | Feature | Backend implementation | Who |
|---|---|---|---|
| 01 | Multi-Module Commerce Ecosystem | `modules/{grocery,food,pharmacy,ecommerce}`; every product/category/order item carries `moduleId`; `orders.moduleIds[]`; module filters in `searchProducts`, `salesReport` | public read / admin write |
| 02 | Multi-Vendor Marketplace | `sellers/{uid}`, `products.sellerId`, `orders.sellerIds[]`, per-seller settlement on delivery (`updateOrderStatus`), rules scope sellers to their own products and orders | seller, admin |
| 03 | Quick Delivery (15 & 30 Minutes) | `speed: quick15\|quick30` in `getCheckoutQuote`/`placeOrder`; `settings.quick15Enabled/quick30Enabled/quickDeliveryFee/quick15MaxKm/quick30MaxKm`; `etaAt` | customer |
| 04 | Food Delivery Module | `food` module, restaurant seller, `products.addons[]` (modifiers) + cart `addonIds[]` priced by the order engine, variants (Half/Full, sizes), `customFields` (spice, allergens) | customer, seller |
| 05 | Point of Sale (POS) | `posCheckout` (channel `pos`, cash/card/upi, discount, stock decrement) | admin, seller |
| 06 | Real-Time Delivery Boy Location | rider writes `deliveryPartners/{uid}.lat/lng/heading/locationUpdatedAt` (rules); `onDeliveryPartnerWritten` mirrors it to `orders/{id}.riderLocation`, which the customer reads | delivery, customer |
| 07 | Live Order Tracking | `orders/{id}` snapshot: `status`, `timeline[]`, `etaAt`, `riderLocation{lat,lng,heading,at}`, `deliveryPartnerName/Phone`; `onOrderWritten` pushes each status | customer |
| 08 | AI Product Descriptions (Gemini) | `generateDescription` (Gemini 2.5 Flash when `GEMINI_API_KEY` is set in functions env; otherwise a structured template) | admin, seller |
| 09 | Multiple Payment Gateways | Razorpay (Orders API + HMAC), Stripe (Checkout Sessions), PayPal (Orders v2) in `placeOrder` / `confirmPayment` / `walletTopup` / `paymentWebhook`; public keys in `settings/payments` | customer |
| 10 | Membership Plans | `membershipPlans`, `purchaseMembership`; quote applies `freeDelivery` and `discountPct` | customer |
| 11 | Customer Subscription Management | `subscriptions` (owner CRUD via rules), `runSubscriptions` daily (wallet first, rest COD), admin manages all | customer, admin |
| 12 | Refer & Earn | `users.referralCode` (`onUserCreated`), client sets `referredBy` once (rules), `onOrderWritten` credits both wallets on the first delivered order (`referralReward`, `refereeReward`) | customer |
| 13 | Single-Screen Cart & Checkout | `users/{uid}/cart` + `getCheckoutQuote` (one call returns everything) + `placeOrder` | customer |
| 14 | Cart Management | `users/{uid}/cart/{productId_variantId}` (rules-validated qty 1–99), `unavailable[]` in quote, `wishlist` | customer |
| 15 | Smart Search & Product Discovery | `products.keywords` (tokens + prefixes, `onProductWritten`), `searchProducts` (ranked), composite indexes for every filter/sort | public |
| 16 | Voice Search for Multiple Products | `searchProducts {multi:true}` splits spoken lists ("milk, bread and eggs") into grouped results. Speech-to-text runs on device **[client]** | public |
| 17 | Similar Product Replacement | `getRecommendations {type:'replacement'}` (same category, in stock, closest price); quote `unavailable[]` flags items to replace | public |
| 18 | Abandoned Cart Management | collection-group `cart` (rules let sellers read their own lines), `abandonedCarts`, `remindAbandonedCarts` push | admin, seller |
| 19 | Cross-Selling Recommendations | `coPurchase/{productId}` graph built by `onOrderWritten`; `getRecommendations {type:'cross_sell'}` | public |
| 20 | Coupon & Discount Management | `coupons/{CODE}` (admin; seller coupons with `sellerId`), `validateCoupon`, server-side evaluation in quote/order, `usedCount`, `usages/{uid}` | admin, seller |
| 21 | Offer Management | `offers` (position, schedule `startAt/endAt`), `featuredSections type 'deals'` | admin |
| 22 | Promo Code Management | coupon rules: `minOrder`, `maxDiscount`, `usageLimit`, `perUserLimit`, `startAt/endAt`, `freeDelivery` | admin |
| 23 | Digital Wallet | `users.walletBalance` (functions only), `walletTransactions`, `applyWallet` in every money flow | customer |
| 24 | Partial Wallet Payment | `useWallet:true` → `walletUsed` + remaining `payable` via any method | customer |
| 25 | Add Funds to Wallet | `walletTopup` + `confirmWalletTopup` (+ webhook), `walletTopups` | customer |
| 26 | Cash on Delivery | `paymentMethod:'cod'`, `settings.codEnabled/codMax`, cash recorded at delivery | customer, delivery |
| 27 | Location-Based Shopping | `getNearbyStores`, `cities`, distance-based delivery fee/range (`maxDeliveryKm`) in quote | public |
| 28 | Quick Delivery Arrival Countdown | `orders.etaAt` / `etaMinutes` (countdown UI **[client]**) | customer |
| 29 | Scheduled Delivery | `speed:'scheduled'` + `scheduledSlot` validated against `settings.slots` window (≥ 30 min ahead) | customer |
| 30 | Home Delivery | `deliveryType:'home'`, address from `users/{uid}/addresses` snapshot into the order, rider flow | customer, delivery |
| 31 | Self Pickup Order Management | `deliveryType:'pickup'` → `ready_for_pickup` → seller marks `delivered` with OTP | customer, seller |
| 32 | Distance & Delivery Estimates | quote `distanceKm` (haversine store→address), `etaMinutes`, per-km fee | customer |
| 33 | OpenStreetMap Integration | `settings.platform.maps {provider:'osm', tileUrl}`; map rendering **[client]** | client |
| 34 | Dynamic Homepage | `sliders`, `offers`, `featuredSections`, `popups`, `modules` ordering, all admin-managed | admin |
| 35 | Home Slider Management | `sliders` (module-scoped, ordered, active) | admin |
| 36 | Featured Section Management | `featuredSections` (types manual/category/bestsellers/newest/top_rated/deals; styles carousel/grid/banner_left) | admin |
| 37 | Popup Management | `popups` (`showOn`, schedule) | admin |
| 38 | Push Notifications | FCM via `notifyUser` (all order/wallet/payout events; Android, iOS and web with `webpush.fcmOptions.link` to the role's site), `registerPushToken` / `unregisterPushToken` (server-side topic subscription, needed for web), topics also via `onUserWritten`, broadcasts via `sendCampaign`; dead tokens pruned | all |
| 39 | Ratings & Reviews | `submitReview` (verified buyers), `onReviewWritten` aggregates, public read | customer |
| 40 | Recently Viewed Products | `users.recentlyViewed[]` (owner write, max 20) | customer |
| 41 | Barcode Scanner | `products.barcode` (EAN-13 seeded), `posCheckout {barcode}`; scanning **[client]** | seller, admin |
| 42 | Product Variants | `products.variants[{id,name,price,mrp,stock,sku}]`, variant-level stock reserve/restore in the engine | seller |
| 43 | Grid & List Product View | **[client]** | — |
| 44 | Multi-Language Support | `languages`, `translations/{code}.strings` | public read / admin write |
| 45 | Dark & Light Mode | **[client]** | — |
| 46 | Liquid Glass Design (iOS 26) | **[client]** | — |
| 47 | Secure Login & Authentication | Firebase Auth (email/password, phone OTP, Google + anonymous), `completeProfile`, `onUserCreated`, custom claims, rules on every collection | all |
| 48 | Role-Based Management Dashboards | claims `customer/seller/delivery/admin` (+ `staffRole`), role checks in every callable and rule, `stats/overview` (admin) | all |
| 49 | Responsive Admin/Seller/Delivery Panels | panels **[client]**; data via rules-scoped queries + composite indexes | — |
| 50 | Unified Order Management | `orders` (admin all, seller via `sellerIds`, rider via `deliveryPartnerId`), `updateOrderStatus` state machine, `assignDeliveryPartner` | admin, seller, delivery |
| 51 | Business Reports & Analytics | `stats/overview`, `stats/daily_*` (incremental, `onOrderWritten`), `salesReport` | admin, seller |
| 52 | Sales Reports | `salesReport` totals/byDay/byStatus/byPaymentMethod | admin, seller |
| 53 | Product Sales Reports | `salesReport.topProducts[]` / `slowProducts[]` | admin, seller |
| 54 | POS Reports | `salesReport {channel:'pos'}`, `stats.daily.byChannel.pos` / `revenueByChannel.pos` | admin, seller |
| 55 | Product Management | `products` (seller CRUD own, status forced to pending/draft unless `autoApproveProducts`; admin approves) | seller, admin |
| 56 | Stock Management | stock reserve/restore in transactions, `lowStockAt`, `onProductWritten` low/out-of-stock alerts | seller |
| 57 | Category Management | `categories` (admin), `productCount` maintained by trigger | admin |
| 58 | Infinite Category Structure | `categories.parentId/path[]/depth`; `products.categoryPath[]` (auto-derived), `array-contains` queries at any depth | admin |
| 59 | Streamlined Category Navigation | roots `parentId==null`, children by `parentId`, `productCount` for hiding empty nodes | public |
| 60 | Veg/Non-Veg & Custom Fields | `products.isVeg`, `products.customFields{}`, `customFields` definitions (admin: global; seller: own), `attributes` | seller |
| 61 | Product Request Management | `productRequests` (customer create; admin/sellers read; admin updates status) | customer, admin |
| 62 | Return Request Management | `requestReturn` / `processReturn` → wallet refund, restock, seller debit, `returns` | customer, seller, admin |
| 63 | Customer Management | `users` (admin), `setUserRole {status:'blocked'}` disables Auth + revokes tokens | admin |
| 64 | Customer Financial Management | `users.walletBalance`, `walletTransactions`, `adjustWallet` | admin |
| 65 | Wallet Transaction Management | `walletTransactions` (owner/admin read, functions-only write; reasons topup/order/refund/referral/cashback/admin/membership) | admin, customer |
| 66 | Seller Onboarding | `registerSeller` (pending, claim seller, admin notified) | signed-in |
| 67 | Seller Request Management | `reviewSeller`; product approval via `products.status` | admin |
| 68 | Seller Account Management | `sellers` (owner edits profile; admin sets status/commission), suspension hides products | admin, seller |
| 69 | Seller Attribute & Custom Field Control | `attributes` with `sellerId == uid` (rules) + global attributes | seller |
| 70 | Seller Policy Management | `pages/seller-policy`, `registerSeller` requires `policiesAccepted` | admin |
| 71 | Global Attribute Migration Alerts | `onAttributeWritten` → `attributeAlerts` + inbox/push to affected sellers | seller |
| 72 | Withdrawal Request Management | `requestWithdrawal` / `processWithdrawal`, `withdrawals` | seller, delivery, admin |
| 73 | Delivery Partner Management | `registerDeliveryPartner`, `reviewDeliveryPartner`, `deliveryPartners` | admin |
| 74 | Multi-City Delivery Boy Service | `deliveryPartners.cities[]` enforced in auto-assign and `acceptDelivery` | admin, delivery |
| 75 | Admin-/Seller-wise Delivery Boy Mgmt | `ownerType: admin\|seller` + `sellerId`; `createSellerRider`; sellers read, assign, review and settle their own fleet; `settings.sellerRidersEnabled` | admin, seller |
| 76 | Cash Collection Management | `cashCollections` on COD delivery, `deliveryPartners.cashInHand`, `settleCash` | admin, seller |
| 77 | Fund Transfer Management | `transferFunds` (payout/credit), `fundTransfers` | admin |
| 78 | Salary Management | `deliveryPartners.salary{type,amount}`, `settings.riderPay{type,amount,perKm,bonusPct}`, per-order earnings on delivery, `runMonthlySalaries`, `transferFunds` | admin |
| 79 | SEO Management | `settings.platform.seo`, per-blog `seo`, `sitemap` HTTP | admin |
| 80 | Blog Management | `blogs`, `blogCategories` | admin |
| 81 | Communication Management | `settings/communication`, `emailTemplates`, `mail` + `onMailCreated`, `campaigns` + `sendCampaign`, inbox `users/{uid}/notifications` | admin |
| 82 | SMS Gateway Integration | `lib/sms.ts` provider-agnostic sender (Twilio API key, MSG91 Flow/DLT, Fast2SMS) chosen by `SMS_PROVIDER`; order (placed, out_for_delivery + OTP, ready_for_pickup, delivered, cancelled) and withdrawal events queue to `smsOutbox` respecting `settings/communication.events.*.sms`; `onSmsQueued` sends with bounded retries. Without credentials docs end `skipped_no_provider`. Config: ARCHITECTURE.md v1.2 | admin |
| 83 | Email Notification System | nodemailer over Gmail SMTP (`MAIL_PASSWORD` secret) with `emailTemplates`: order_placed, order_status, welcome, otp, withdrawal | system |
| 84 | Module-Wise Theme Colors | `modules.themeColor`, `settings.platform.theme` | admin |
| 85 | Social Media Icon Management | `settings.platform.social{facebook,instagram,x,youtube,linkedin}` | admin |
| 86 | Localization Management | `translations/{lang}.strings`, `languages` | admin |
| 87 | Flutter 3.47.2 App Architecture | **[n/a]** client toolchain | — |
| 88 | Next.js 16 SSR Website | **[n/a]** this platform uses Flutter web; SEO is served by `sitemap` | — |
| 89 | Laravel 12 Backend | **[n/a]** replaced by Firebase (Cloud Functions v2, Node 22) | — |
| 90 | WebP Next-Gen Images | seed stores all catalog imagery as WebP; storage rules accept `image/webp` | system |
| 91 | Force Update | `settings.platform.appVersions{customer,partner}{min,latest}`, `storeUrls` | admin |
| 92 | Module Management | `modules.enabled/order` (admin) | admin |
| 93 | Platform Configuration | `settings/platform` (fees, limits, slots, currency, contact, `autoAssign`, `riderPay`, `sellerRidersEnabled`, `maintenanceMessage`…), `taxes`, `countries` | admin |
| 94 | Technical Configuration | `settings/payments` (public keys), Secret Manager secrets, `getSystemStatus` integration health | admin |
| 95 | User & Role Management | `createStaffUser`, `setUserRole`, `staff`, `adminRoles` | admin |
| 96 | FAQ Management | `faqs` | admin |
| 97 | Demo Mode Management | `settings.platform.demoMode`, `demo.accounts[]` | admin |
| 98 | System Administration | `getSystemStatus`, `backupFirestore` (weekly export), `settings.maintenance` + `maintenanceMessage` (blocks `placeOrder`), admin Storage browse/delete | admin |

Client-only / N/A: 43, 45, 46, 49 (UI), 87, 88, 89 (stack), plus the UI halves of 16, 28, 33 and 41. Features 16, 28, 33 and 41 also have backend support, as listed in the table.
