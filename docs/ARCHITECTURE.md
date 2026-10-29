# Go4Market — Architecture & Data Contract

This file is the single source of truth shared by the backend, the website, the panels and the mobile apps.
Anything that reads or writes Firestore, or calls a Cloud Function, must follow it.

Firebase project: `go4market` · Region for functions: `asia-south1` · Currency: INR (₹) · TZ: Asia/Kolkata

## Repository layout

```
firebase.json / .firebaserc        hosting targets, functions, firestore, storage
firestore.rules / firestore.indexes.json / storage.rules
functions/                         TypeScript Cloud Functions (the "API")
tools/seed/                        Node seed script (Admin SDK) – demo + real catalog data
packages/g4m_core/                 Shared Dart package: brand theme, models, repositories, API client
apps/website/                      Flutter web – customer storefront      → https://go4market.web.app
apps/panel/                        Flutter web – 3 entrypoints:
    lib/main_admin.dart                                                  → https://go4market-admin.web.app
    lib/main_seller.dart                                                 → https://go4market-seller.web.app
    lib/main_delivery.dart                                               → https://go4market-delivery.web.app
apps/customer_app/                 Flutter Android/iOS – com.go4market.customer
apps/partner_app/                  Flutter Android/iOS – com.go4market.partner (Seller + Delivery roles)
playstore/                         store listing assets, screenshots, videos, upload guide
secret/                            .env + service account (never commit, never ship to clients)
```

## Brand

| Token | Hex | Use |
|---|---|---|
| primary | `#0B8A4F` | brand green (bag) – primary actions, links |
| primaryDeep | `#0A4A33` | deep green (arrow) – headings, dark surfaces, footer |
| accent | `#F7860F` | orange (chevrons) – offers, badges, CTAs that need heat |
| background | `#F7FAF8` | light mint-tinted canvas |
| surface | `#FFFFFF` | cards |
| ink | `#0F1A14` | primary text · `inkMuted #5B6B62` secondary text |
| line | `#E3EBE6` | borders/dividers |
| success `#16A34A` · warning `#F59E0B` · danger `#DC2626` · info `#2563EB` |

Font: **Plus Jakarta Sans** (google_fonts). Radii: 12 / 16 / 24. Motion: 220 ms standard, 420 ms emphasized, curve `easeOutCubic`.
Logo: `logo.png` (transparent, use on light) · App icon: `icons_512.png`. Wordmark: "Go4Market" with "Go4" in primaryDeep and "Market" in primary, the "4" in accent.

## Roles & Auth

Firebase Auth email/password, phone-number OTP and Google (+ anonymous browsing on website/customer app). After a first phone or Google sign-in (or after linking an anonymous account) the client calls `completeProfile` — see v1.2 below.
Role lives in **custom claim** `role` ∈ `customer | seller | delivery | admin` and mirrored on `users/{uid}.role`.
Custom claims are only set by Cloud Functions (`registerSeller`, `registerDeliveryPartner`, `setUserRole`, `onUserCreated`).
After a claim change the client must call `user.getIdToken(true)`.

Demo accounts (seeded):

| Role | Email | Password |
|---|---|---|
| Admin | admin@go4market.com | Go4Market@123 |
| Seller | seller@go4market.com | Go4Market@123 |
| Delivery | delivery@go4market.com | Go4Market@123 |
| Customer | customer@go4market.com | Go4Market@123 |

## Firestore collections

All docs have `createdAt` / `updatedAt` (server timestamps). Money = number in rupees (2 dp). IDs are auto-ids unless noted.

| Path | Key fields |
|---|---|
| `users/{uid}` | name, email, phone, photoUrl, role, status(`active/blocked`), walletBalance, referralCode, referredBy, membership{planId,expiresAt}, fcmTokens[], recentlyViewed[productId] (max 20), city, defaultAddressId |
| `users/{uid}/addresses/{id}` | label(Home/Work/Other), name, phone, line1, line2, landmark, city, state, pincode, lat, lng, isDefault |
| `users/{uid}/cart/{itemId}` | itemId = `${productId}_${variantId}`; productId, variantId, qty, sellerId, addedAt |
| `users/{uid}/wishlist/{productId}` | addedAt |
| `users/{uid}/notifications/{id}` | title, body, type, data{}, read, createdAt |
| `sellers/{uid}` | storeName, slug, logo, banner, description, ownerName, email, phone, status(`pending/approved/rejected/suspended`), commissionPct, address, city, lat, lng, rating, ratingCount, balance, totalSales, productCount, policiesAccepted, gstin, bank{holder,account,ifsc} |
| `deliveryPartners/{uid}` | name, email, phone, photoUrl, vehicleType, vehicleNo, cities[], ownerType(`admin/seller`), sellerId, status(`pending/approved/suspended`), online, lat, lng, locationUpdatedAt, cashInHand, balance, rating, completedCount, salary{type:`per_order/monthly`, amount} |
| `modules/{id}` | id ∈ `ecommerce, grocery, pharmacy, food`; name, tagline, icon, themeColor (hex), enabled, order |
| `categories/{id}` | name, slug, image, moduleId, parentId (null = root), path[] (ancestor ids), depth, order, active, productCount |
| `brands/{id}` | name, logo, active |
| `attributes/{id}` | name, values[], sellerId (null = global) |
| `products/{id}` | name, slug, shortDescription, description, moduleId, categoryId, categoryPath[], brandId, brandName, sellerId, sellerName, images[], price, mrp, stock, lowStockAt, unit, variants[{id,name,price,mrp,stock,sku}], tags[], isVeg (bool|null), customFields{}, rating, ratingCount, soldCount, viewCount, featured, status(`active/pending/rejected/draft`), barcode, keywords[] (lowercase tokens for search), deliveryMinutes |
| `products/{id}/reviews/{uid}` | userId, userName, rating 1-5, comment, images[], createdAt |
| `sliders/{id}` | title, subtitle, image, ctaText, link, moduleId, order, active, bgColor |
| `offers/{id}` | offer banners: title, image, link, moduleId, position(`home_top/home_mid/category`), order, active, startAt, endAt |
| `featuredSections/{id}` | title, subtitle, moduleId, type(`manual/category/bestsellers/newest/top_rated/deals`), productIds[], categoryId, style(`carousel/grid/banner_left`), bannerImage, bgColor, order, active |
| `coupons/{CODE}` | id = uppercase code; message, discountType(`percent/flat`), value, maxDiscount, minOrder, startAt, endAt, usageLimit, perUserLimit, usedCount, active, image, sellerId(null = platform) |
| `orders/{id}` | orderNo (`G4M` + 6 digits), userId, customer{name,phone,email}, channel(`web/app/pos`), items[{productId,variantId,name,variantName,image,price,mrp,qty,sellerId,sellerName}], sellerIds[], subtotal, deliveryFee, discount, couponCode, walletUsed, tax, total, payable, paymentMethod(`cod/razorpay/stripe/paypal/wallet`), paymentStatus(`pending/paid/failed/refunded`), paymentRef, status (see below), deliveryType(`home/pickup`), speed(`standard/quick15/quick30/scheduled`), scheduledSlot{date,from,to}, address{...}, distanceKm, etaAt, deliveryPartnerId, deliveryPartnerName, deliveryOtp, cashCollected, timeline[{status,at,by,note}], cancelReason, createdAt |
| `returns/{id}` | orderId, userId, items[], reason, images[], status(`requested/approved/rejected/picked/refunded`), refundAmount, refundTo(`wallet/source`) |
| `walletTransactions/{id}` | userId, type(`credit/debit`), amount, reason(`topup/order/refund/referral/cashback/admin`), refId, balanceAfter |
| `withdrawals/{id}` | userId, role(`seller/delivery`), amount, method, status(`pending/approved/rejected/paid`), note |
| `fundTransfers/{id}` | toUserId, role, amount, note, by |
| `cashCollections/{id}` | deliveryPartnerId, orderId, amount, status(`collected/settled`) |
| `productRequests/{id}` | userId, name, description, status(`open/added/rejected`) |
| `subscriptions/{id}` | userId, productId, variantId, qty, frequency(`daily/weekly/monthly`), nextRunAt, status(`active/paused/cancelled`), addressId |
| `membershipPlans/{id}` | name, price, durationDays, benefits[], freeDelivery, discountPct, active |
| `blogs/{id}` | title, slug, excerpt, content (markdown), cover, categoryId, tags[], published, publishedAt, author · `blogCategories/{id}` |
| `faqs/{id}` | question, answer, category, order, active |
| `pages/{slug}` | slug ∈ `about, terms, privacy, refund, shipping, cancellation`; title, content (markdown) |
| `popups/{id}` | title, image, link, showOn(`web/app/both`), active, startAt, endAt |
| `campaigns/{id}` | push broadcast: title, body, image, audience(`all/customers/sellers/delivery`), sentAt, status |
| `emailTemplates/{id}` | id ∈ `order_placed, order_status, welcome, otp, withdrawal`; subject, html |
| `cities/{id}` | name, state, active, lat, lng, radiusKm |
| `languages/{code}` | name, nativeName, isDefault, rtl, active |
| `staff/{uid}` | admin staff: name, email, roleId · `adminRoles/{id}` name, permissions[] |
| `settings/platform` | appName, tagline, currency, currencySymbol, contactEmail, contactPhone, address, social{facebook,instagram,x,youtube,linkedin}, deliveryFee, freeDeliveryAbove, quickDeliveryFee, perKmFee, maxDeliveryKm, taxPct, minOrder, codEnabled, codMax, walletEnabled, referralReward, refereeReward, pickupEnabled, scheduledEnabled, quick15Enabled, quick30Enabled, slots[{from,to}], seo{title,description,keywords,ogImage}, theme{primary,accent}, appVersions{customer{min,latest},partner{min,latest}}, demoMode, maintenance |
| `settings/payments` | public only: razorpay{enabled,keyId}, stripe{enabled,publishableKey}, paypal{enabled,clientId,env}, cod{enabled} |
| `stats/daily_{yyyyMMdd}` | orders, revenue, delivered, cancelled, returns, newUsers, byChannel{web,app,pos}, byCategory{}, byModule{} (written only by functions) |
| `stats/overview` | totals: orders, revenue, customers, sellers, products, delivered, pending, cancelled, byStatus{} |
| `counters/orders` | seq |

Abandoned carts = collectionGroup `cart` where `addedAt < now-6h`.

### Order status flow

`pending` (awaiting online payment) → `placed` → `confirmed` (seller) → `packed` → `assigned` (delivery partner set) → `picked_up` → `out_for_delivery` → `delivered`
Side exits: `cancelled` (customer before `packed`, seller/admin anytime before delivered), `returned`.
Pickup orders: `placed → confirmed → packed → ready_for_pickup → delivered`.
Every change appends to `timeline` and is done **only** through the `updateOrderStatus` callable (never direct client writes).

## Cloud Functions API (callable, region asia-south1)

Call from Dart with `FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable(name)`. All return JSON maps. Errors use `HttpsError` codes.

| Function | Who | Input → Output |
|---|---|---|
| `getCheckoutQuote` | any signed-in | {addressId?, couponCode?, useWallet, speed, deliveryType} → {subtotal, deliveryFee, discount, walletUsed, tax, total, payable, distanceKm, etaMinutes, couponError?, unavailable[]} (uses user cart) |
| `placeOrder` | any signed-in | same as quote + {paymentMethod, scheduledSlot?, channel, notes?} → {orderId, orderNo, total, payable, walletUsed, status, paymentMethod, payment?} (`payment` = the provider payload in the hand-off table below; Stripe returns {checkoutUrl, sessionId}, not a clientSecret) — validates server-side prices/stock/coupon, debits wallet, clears cart, reserves stock |
| `confirmPayment` | owner | {orderId, provider, razorpayOrderId?, razorpayPaymentId?, razorpaySignature?, sessionId?, paymentIntentId? (legacy), paypalOrderId?} → {ok, status, paymentStatus, reason?} |
| `walletTopup` / `confirmWalletTopup` | signed-in | {amount (10–50000), provider} → {topupId, orderId (= topupId), amount, payment} / {topupId or orderId, provider, …provider fields} → {ok, balance} |
| `validateCoupon` | signed-in | {code, subtotal} → {valid, discount, message} |
| `updateOrderStatus` | seller (own items) / delivery (assigned) / admin / customer (cancel only) | {orderId, status, note?, otp?, cashCollected?} → {ok} — on delivered: credits seller balance minus commission, delivery earnings, cash collection record |
| `assignDeliveryPartner` | admin / seller | {orderId, partnerId? (null = auto nearest online)} → {partnerId} |
| `acceptDelivery` | delivery | {orderId} → {ok} (self-assign from available pool) |
| `requestReturn` / `processReturn` | customer / admin+seller | … refund to wallet |
| `registerSeller` | signed-in | {storeName, ownerName, phone, city, address, gstin?, …} → creates `sellers/{uid}` pending, claim role=seller |
| `createSellerRider` | seller | {name, email, password, phone, vehicleType?, vehicleNo?, cities?} → {uid} (approved rider in the store's own fleet) |
| `registerDeliveryPartner` | signed-in | {name, phone, vehicleType, vehicleNo, cities[]} → pending partner, claim role=delivery |
| `reviewSeller` / `reviewDeliveryPartner` | admin | {uid, status, commissionPct?} |
| `setUserRole` | admin | {uid, role} |
| `createStaffUser` | admin | {email, password, name, role} → creates Auth user + claims |
| `requestWithdrawal` / `processWithdrawal` | seller,delivery / admin | |
| `transferFunds` | admin | {toUserId, amount, note} |
| `settleCash` | admin | {partnerId, amount} |
| `adjustWallet` | admin | {userId, amount, type, note} |
| `sendCampaign` | admin | {campaignId} → FCM to topic `all`/`customers`/`sellers`/`delivery` |
| `generateDescription` | admin/seller | {name, category, keywords[]} → {short, long} (Gemini if `GEMINI_API_KEY` set, else template) |
| `posCheckout` | admin/seller | {items[], customer?, paymentMethod(cash/card/upi), discount} → order with channel pos |
| `submitReview` | customer who received the product | {productId, rating, comment} |
| `sitemap` (HTTP GET) | public | XML sitemap for website — hosting rewrite `/sitemap.xml` |
| `paymentWebhook` (HTTP) | Razorpay/Stripe | marks orders paid |

### Payment hand-off (same for orders and wallet top-ups)

`placeOrder` / `walletTopup` return `payment`:

| provider | payload | client action | then |
|---|---|---|---|
| `razorpay` | {razorpayOrderId, keyId, amount (paise), currency, name, prefill{name,email,phone}} | app: `razorpay_flutter`; web: checkout.js via JS interop | `confirmPayment {orderId, provider:'razorpay', razorpayOrderId, razorpayPaymentId, razorpaySignature}` |
| `stripe` | {checkoutUrl, sessionId} (Stripe Checkout Session, hosted) | open URL (web: same tab; app: in-app browser) | return URL `https://go4market.web.app/payment/return?provider=stripe&orderId=…` → `confirmPayment {orderId, provider:'stripe', sessionId}`; app calls it when the browser closes |
| `paypal` | {approveUrl, paypalOrderId} | open URL | return URL `…/payment/return?provider=paypal&orderId=…` → `confirmPayment {orderId, provider:'paypal', paypalOrderId}` (server captures) |
| `cod` / `wallet` | none | — | order is `placed` immediately |

For wallet top-ups `orderId` is the `topupId` returned by `walletTopup` and the call is `confirmWalletTopup` with the same fields.
Stripe/PayPal charge in their configured currencies (`STRIPE_CURRENCY`, `PAYPAL_CURRENCY`) converted from INR using `settings/platform.fx` ({usd: 0.012}) when the currency is not INR.

Firestore triggers: `onUserCreated` (Auth → users doc, referral code, claim customer), `onOrderWritten` (stats, notifications FCM + inbox, email), `onReviewWritten` (product rating aggregate), `onProductWritten` (keywords, category productCount, low-stock alert), scheduled `runSubscriptions` (daily), `cleanupPendingOrders` (hourly).

## Security model (firestore.rules summary)

- Public read: products(status active), categories, brands, modules, sliders, offers, featuredSections, blogs(published), faqs, pages, popups, membershipPlans, cities, languages, settings/*, sellers (approved), reviews, coupons(active, read-only).
- Owner read/write: `users/{uid}` (except role, walletBalance, membership, status), its subcollections.
- Orders: read if owner, if seller in `sellerIds`, if assigned delivery partner, or admin. **No client writes** (functions only).
- Sellers: write own products (status forced to `pending` unless admin auto-approve), own sliders? no. Seller writes own `sellers/{uid}` profile fields except status/commission/balance.
- Delivery: update own `deliveryPartners/{uid}` online/lat/lng/locationUpdatedAt only.
- Admin (`token.role == 'admin'`): read/write everything except `stats`, `walletTransactions`, `counters` (functions only).

## Web hosting

| Target | Site | Build dir |
|---|---|---|
| website | go4market | apps/website/build/web |
| admin | go4market-admin | apps/panel/build/admin |
| seller | go4market-seller | apps/panel/build/seller |
| delivery | go4market-delivery | apps/panel/build/delivery |


## Backend implementation notes (v1, binding additions)

Everything above still holds. The items below are **additions** made while building the backend, plus the few places where the original text was ambiguous. `docs/API.md` maps every feature to its functions and collections.

### Extra callables (region asia-south1)

| Function | Who | Input → Output |
|---|---|---|
| `purchaseMembership` | signed-in | {planId} → {ok, expiresAt (ISO), balance}. Paid from the wallet. If the balance is short it fails with `failed-precondition` and `details.shortBy`. Sets `users.membership {planId, name, expiresAt, freeDelivery, discountPct, purchasedAt}` |
| `searchProducts` | public | {query, moduleId?, multi?, limit?} → {groups:[{term, products[]}], products[]}. `multi:true` splits "milk, bread and 2 eggs" into separate terms (voice search) |
| `getRecommendations` | public | {productId, type: similar\|cross_sell\|replacement, limit?} → {products[]} |
| `getNearbyStores` | public | {lat, lng, moduleId?, radiusKm?} → {stores:[{id, storeName, slug, logo, banner, city, modules, rating, distanceKm, etaMinutes}]} |
| `salesReport` | admin, seller (own items only) | {from:'yyyy-MM-dd', to, channel?, moduleId?, sellerId? (admin)} → {totals, byDay[], byStatus, byChannel, byPaymentMethod, byModule, topProducts[], slowProducts[]} |
| `abandonedCarts` | admin, seller (own products) | {olderThanHours?=6, limit?} → {carts:[{userId, name, phone, email, items[], value, lastAddedAt}], count} |
| `getSystemStatus` | admin | {} → {integrations{razorpay,stripe,paypal,smtp,gemini (booleans)}, stats, flags, lastBackup} |

### Extra triggers / jobs
`onUserWritten` subscribes FCM tokens to topics `all` plus the role topic (`customers`, `sellers`, `delivery`, `admins`). `onDeliveryPartnerWritten` mirrors the rider's lat/lng into `orders/{id}.riderLocation {lat, lng, heading, at}` for active orders, because customers cannot read `deliveryPartners`. `onAttributeWritten` raises `attributeAlerts` when a global attribute loses values, is renamed or is deleted. Scheduled: `remindAbandonedCarts` (daily 18:00 IST), `runMonthlySalaries` (1st, 09:00 IST), `backupFirestore` (Sun 02:30 IST, exports to `gs://go4market.firebasestorage.app/backups/`). `paymentWebhook` re-verifies every event against the provider API with our secret key. It never trusts the payload. The webhook URL is `https://asia-south1-go4market.cloudfunctions.net/paymentWebhook`; register it in the Razorpay, Stripe and PayPal dashboards.

### Field additions
- **products**: `addons[{id,name,price,active}]` (food modifiers), `ratingSum`, `barcode` (EAN-13), `keywords` include 2–10 character prefixes so partial typing matches.
- **cart line**: optional `addonIds[]`. Each add-on's price is added to the unit price.
- **order items**: also carry `addons[], basePrice, moduleId, categoryId, rootCategoryId, unit, sku`.
- **orders**:
  - Added fields: `moduleIds[], mrpTotal, couponDiscount, couponSellerId, etaMinutes, notes, gateway{provider,id,currency,amount}, paidAt, assignedAt, deliveredAt, deliveryPartnerPhone, riderLocation, settlement{sellers{uid:{gross,commissionPct,commission,couponShare,net}}, delivery{partnerId,earning,cash}}, refundAmount, returnIds[], returnedQty{}`.
  - `deliveryPartnerId` is `null` (not missing) until a rider is assigned.
  - POS orders use `userId:'pos'` and `channel:'pos'`, with `paymentMethod` set to `cash`, `card` or `upi`, and are created already `delivered`. They also carry `cashierId` and `posDiscount`.
- **coupons**: optional `freeDelivery:true` means the discount equals the delivery fee, capped at `value`/`maxDiscount`. Per-user usage lives in `coupons/{CODE}/usages/{uid}` `{count}`. A coupon with `sellerId` applies only to that seller's items, and its cost is deducted from that seller's settlement.
- **getCheckoutQuote output** also returns `mrpTotal, couponDiscount, membershipDiscount, walletBalance, itemCount, couponCode, speedError?, minOrderError?, outOfRange?, codAllowed, items[]`. `unavailable[]` = `{itemId, productId, variantId, name, reason: not_found|inactive|out_of_stock|insufficient_stock|invalid_variant, available}`.
- **settings/platform** extras:
  - Delivery and limits: `baseKm, quick15MaxKm, quick30MaxKm, taxInclusive, returnWindowDays, deliveryPerOrderDefault, autoApproveProducts`.
  - Payments: `fx{usd}`.
  - Integrations: `maps{provider:'osm', tileUrl}`, `sms{enabled, provider}` (an SMS gateway is not configured; when `enabled`, messages are queued in `smsOutbox`).
  - Demo and stores: `demo{accounts[]}`, `storeUrls`.
- **settings/payments**: each provider also has `currency`.
- **stats/daily_***:
  - Counts: `byChannel{}` is order counts and `byPaymentMethod{}` is counts.
  - Revenue: `revenueByChannel{}` is revenue, and `byModule{}`/`byCategory{}` are item revenue keyed by moduleId / root categoryId.
  - Exclusions: pending (unpaid) orders count for nothing, and cancelled/returned orders count toward `orders` but add 0 revenue.
  - Deleting an order reverses its contribution.
- **stats/overview**: also has `byChannel{}`, `customers, sellers, products` and `returns`.
- **pages**: also `seller-policy`.

### New collections
- `walletTopups/{id}` = {userId, amount, provider, status (pending/paid/failed/expired), gateway, paymentRef}.
- `cashSettlements/{id}`.
- `coPurchase/{productId}` = {counts{productId:n}} (functions only).
- `attributeAlerts/{id}`.
- `translations/{lang}` = {strings{}}.
- `smsOutbox`, `system/backup`, `_events` (trigger idempotency).

Clients read the first four as their rules allow; the rest are server-only.

### Behaviour clarifications
- **Status changes**: `assigned` is reachable only through `assignDeliveryPartner` / `acceptDelivery` (from `confirmed` or `packed`). Sellers move the order one step at a time (confirmed → packed → ready_for_pickup → delivered, the last for pickup only). Riders do picked_up → out_for_delivery → delivered. Admins may jump forward.
- **Delivery OTP**: `delivered` requires the `otp` for everyone except admins. The rider can read the order doc, so riders could see `deliveryOtp`. The partner app must **not** display it.
- **Cancelling and refunds**: cancelling restores stock and the coupon. It refunds `walletUsed`, plus any captured online payment, to the **wallet**. Unpaid online orders are auto-cancelled after 30 min.
- **Delivery pool query** (partner app, allowed by rules): `orders where deliveryPartnerId == null && deliveryType == 'home' && status in ['confirmed','packed']`. Sellers may read their own fleet in `deliveryPartners` (`sellerId == uid`); only approved, online riders may read the pool (see v1.1 below).
- **Anonymous users**: they get no `users` doc or claim; anonymous callers can only quote. `placeOrder` and other writes require an email account.
- **Error codes**: `unauthenticated` (not signed in / anonymous), `permission-denied` (role/ownership, wrong OTP), `invalid-argument` (validation), `failed-precondition` (business rule: empty cart, unavailable items with `details.unavailable`, coupon error, COD limit, out of range, wrong status transition), `not-found`, `already-exists`, `unavailable` (payment gateway error).
- **Payment return URLs**: `https://go4market.web.app/payment/return?provider=stripe|paypal&orderId=<id>` (+ `&kind=topup` for wallet top-ups, `&session_id=` for Stripe, `&cancelled=1` on cancel).
- **Website routes used by `sitemap`**: `/`, `/m/{moduleId}`, `/c/{categorySlug}`, `/p/{productSlug}`, `/store/{sellerSlug}`, `/blog`, `/blog/{slug}`, `/page/{slug}`, `/faqs`.
- **Withdrawals**: `requestWithdrawal` {amount ≥ 100, method bank|upi|cash, note?} holds the amount from the balance immediately, and `processWithdrawal` `rejected` returns it. `transferFunds` takes `type: payout` (default; debits the earnings balance) or `credit` (salary/bonus). `settleCash` {partnerId, amount} may also be called by the seller who owns the rider.
- **registerSeller** requires `policiesAccepted:true`. **registerDeliveryPartner** accepts optional `sellerId` (joins that store's fleet, `ownerType:'seller'`). `reviewDeliveryPartner` may be called by that seller. Both return `{ok, status, refreshToken:true}`; call `getIdToken(true)` afterwards.
- **Secrets**: `RAZORPAY_KEY_SECRET`, `STRIPE_SECRET_KEY`, `PAYPAL_CLIENT_SECRET`, `MAIL_PASSWORD`, `AUTH_SECRET` (reserved) and the SMS secrets (`TWILIO_API_KEY_SID`, `TWILIO_API_KEY_SECRET`, `SMS_API_KEY`, `SMS_AUTH_TOKEN`; see v1.2) are in Secret Manager. Non-secret config is in `functions/.env` (gitignored).

### Panel integration additions (v1.1)
- **`createSellerRider`** (seller, approved store; `settings/platform.sellerRidersEnabled !== false`): {name, email, password (≥ 8), phone, vehicleType?, vehicleNo?, cities?[]} → {uid}. It creates an Auth user with claim `delivery`, a `users` doc and an **approved** `deliveryPartners/{uid}` with `ownerType:'seller'`, `sellerId` = the caller, `cities` (defaults to the store city) and `salary` from `settings/platform.riderPay`.
- **`orders.riderLocation`** = {lat, lng, heading, at, updatedAt} (`at` and `updatedAt` hold the same timestamp). It is written by `onDeliveryPartnerWritten` whenever the assigned rider moves while the order is `assigned`, `picked_up` or `out_for_delivery`. Customers read it from the order doc for live tracking; they never read `deliveryPartners`.
- **`purchaseMembership`** {planId} → {ok, expiresAt (ISO), balance}. It is paid from the wallet. If the balance is short it fails with `failed-precondition` and `details.shortBy`. On success it sets `users.membership {planId, name, expiresAt, freeDelivery, discountPct, purchasedAt}`, which `getCheckoutQuote` applies automatically. Extra input such as `paymentMethod:'wallet'` is ignored.
- **`processReturn`** {returnId (or id), status, refundAmount?, refundTo?: wallet|source, note?} → {ok, status, refundAmount, refundTo}.
  - `refundAmount`: admins may set it up to the order total; sellers may only lower it.
  - `refundTo:'source'` refunds the original Razorpay, Stripe or PayPal payment through the gateway (idempotent per return). The wallet-paid part, and any COD or wallet order, always goes back to the wallet.
  - The return stores `refundTo`, `walletRefund` and `sourceRefund{provider,id,status,amount}`. Returns keep `sellerIds[]`.
- **`transferFunds`** {toUserId, amount, note?, role?: seller|delivery, type?: payout|credit}. `role` picks the profile when needed. A `payout` debits the earnings balance only up to the amount (never below 0), and any excess, such as a monthly salary, is recorded as `direct` on the `fundTransfers` doc.
- **`reviewSeller`** also accepts `note` and `role` (`role` is ignored). **`processWithdrawal`** allows `pending → paid` directly and emails the `withdrawal` template. **`requestWithdrawal`** `details` may be a string or a flat object (bank/UPI fields). **`posCheckout`** returns {orderId, orderNo, total, …}. **`createStaffUser`** returns {uid, role, staffRole}.
- **`registerSeller`** accepts `moduleIds[]` as an alias of `modules[]`, plus `pincode` and `bank.upi`. **`registerDeliveryPartner`**: `cities[]` is optional (empty = any city) and `vehicleType` adds `ev`.
- **settings/platform** is read by functions for:
  - `autoAssign` (bool): when an order becomes `packed` (home), the nearest online approved rider is assigned automatically. If none is online, the sellers are notified.
  - `riderPay {type: per_order|monthly, amount, perKm, bonusPct}`: the default salary for new riders. Per-order earnings = `amount + perKm × distanceKm + bonusPct% × deliveryFee` (rider-specific `salary` overrides type/amount).
  - `sellerRidersEnabled` (bool).
  - `maintenance` + `maintenanceMessage`: `placeOrder` fails with `unavailable` and that message.
- **settings/communication** (admin-only read/write) has `email{enabled, fromName, fromAddress, replyTo, adminCopy}`, `sms{enabled, provider, senderId, dltEntityId}`, `push{…}` and `events{}`.
  - `email.enabled:false` stops transactional emails.
  - `fromName` and `replyTo` are applied.
  - `adminCopy` gets a BCC of every new-order email.
  - `sms.enabled` must be true for queued SMS to be sent (see v1.2 for the gateway).
  - The From address is always the authenticated Gmail account, because Gmail rewrites it.
- **`mail/{id}`** is admin-only and sent by the `onMailCreated` trigger. Input: `{to?: string|string[], audience?: all|customers|sellers|delivery, bcc?, message:{subject, html?, text?}, replyTo?}`. The result is written back as `delivery {state: PROCESSING|SUCCESS|ERROR, recipients, error?, endTime}` and `status: sent|failed`. Audience mail goes out as BCC batches of 50, capped at 450 recipients per document (Gmail's daily limit).
- **New admin-managed collections**: `taxes/{id}` {title, percent, description}, `countries/{ISO}` {name, code, dialCode, currency, flag}, and `customFields/{id}` {target, name, key, type, options[], required, sellerId?}. Sellers create, update and delete their own (`sellerId == uid`). All three are publicly readable. Seeded: GST 0/5/12/18/28 and IN/AE/US/GB.
- **Rules changes**:
  - Sellers read only **their own** riders (`deliveryPartners.sellerId == uid`). Use `assignDeliveryPartner {partnerId:null}` to request a Go4Market rider.
  - The delivery pool is readable only by riders whose `deliveryPartners/{uid}` is `approved` and `online == true`.
  - Admins can read the `wishlist` collection group.
  - `settings/communication` and `settings/notifications` are admin-only.
- **Storage changes**:
  - Admins may get, list and delete any object and upload images anywhere (≤ 10 MB).
  - `i18n/*.json` is public read and admin write.
  - Sellers may only **create** files in `sellers/logo/` and `sellers/banner/`.
  - Riders: `deliveryPartners/{uid}/*` (photo, readable by signed-in users) and `deliveryPartners/{uid}/docs/**` (owner/admin only).
- **Mobile apps**:
  - `users/{uid}.documents` (partner KYC map) is owner-writable.
  - `subscriptions`: the owner creates them (`userId == uid`, `status` active|paused, `frequency` daily|weekly|monthly, int `qty` 1–50) and updates their status (active/paused/cancelled).
  - Sellers may update stock-only fields (`{stock, variants, updatedAt}`) on their own products without the status changing. A seller can never set `active` unless `autoApproveProducts` is on.
  - Sellers and riders read their own `walletTransactions`.
  - `posCheckout` ignores client `name`/`price` on items and recomputes everything server-side.

### Notifications, SMS and sign-in (v1.2)

**New callables (asia-south1)**

| Function | Who | Input → Output |
|---|---|---|
| `registerPushToken` | any signed-in, **incl. anonymous** | `{token, platform: 'web'\|'android'\|'ios'}` → `{ok:true, topics: string[]}`. Subscribes the token server-side to `all` + the role topic (`customers` / `sellers` / `delivery`; admins → `all` only; anonymous → customers), then stores it in `users/{uid}.fcmTokens` (de-duplicated, newest last, max 10) and `pushPlatforms.{platform}` = timestamp. Anonymous callers get a minimal `users/{uid}` doc `{fcmTokens, anonymous:true}` (no role/status). A token FCM rejects fails with `invalid-argument`, message `FCM rejected the token (messaging/…)`, `details.code`. Call it on every app start / token refresh. |
| `unregisterPushToken` | any signed-in, incl. anonymous | `{token}` → `{ok:true, removed: boolean}`. Removes it from `fcmTokens` and unsubscribes it from every topic. Call before sign-out. |
| `completeProfile` | signed-in, **not** anonymous | `{name, email?, phone?, referralCode?}` → `{ok:true, profile:{name,email,phone,photoUrl,referralCode,referredBy}, referral:{applied, reason?: already_referred\|own_code\|has_orders\|invalid_code}, warnings: ('email_in_use'\|'phone_in_use')[]}`. Initialises `users/{uid}` if missing (anonymous → linked accounts never fire `onUserCreated` again): referral code, `customer` claim, stats. Sets `name` (also Auth displayName), `email` (lowercased), `phone` (E.164, +91 default; falls back to the Auth phone number), `profileCompleted:true`. Applies `referredBy` only when the user has no orders and no referrer yet. Uniqueness is advisory: clashes are returned in `warnings`, never enforced. Phone users who add an email here get the `welcome` email once (`welcomeSentAt`). |

**Sign-in providers.** `onUserCreated` handles email/password, phone OTP and Google: phone-only users get `phone = user.phoneNumber` (E.164), no email and `name: 'Customer'`; Google users get name, email and `photoUrl` from the provider. `authProviders[]` is stored on creation. Referral-code and role-claim logic is unchanged; the welcome email goes out only when there is an email. Owners may edit `name`, `phone`, `email`, `photoUrl` on their own `users` doc directly (rules unchanged).

**Push payload** (`notifyUser` for order/wallet/payout events and `notifyTopic` for `sendCampaign`), identical for app and web tokens:
```
notification {title, body, imageUrl?}
data         {type, …note data (all strings), link (relative app route, e.g. /orders/{id}), url (absolute)}
android      {priority: high, notification {channelId: 'go4market_default', color: '#0B8A4F'}}
apns         {payload {aps {sound: default}}}
webpush      {headers {Urgency: high}, notification {title, body, icon, badge, image?}, fcmOptions {link: url}}
```
`url` / `fcmOptions.link` is absolute on the site of the recipient's role: customers `https://go4market.web.app` (`WEBSITE_URL`), sellers `https://go4market-seller.web.app` (`SELLER_URL`), riders `https://go4market-delivery.web.app` (`DELIVERY_URL`), admins `https://go4market-admin.web.app` (`ADMIN_URL`). Order notifications link to `{site}/orders/{orderId}`. Campaigns use the website (or the panel for `sellers`/`delivery`) plus the campaign `link`. Tokens that fail with `messaging/registration-token-not-registered` or `messaging/invalid-registration-token` are pruned from `fcmTokens`. Web clients need `firebase-messaging-sw.js` at the site root and must call `registerPushToken` (browsers cannot subscribe to topics). `onUserWritten` still subscribes tokens that clients write straight into `fcmTokens`; admins are no longer put in an `admins` topic.

**SMS gateway (FEATURES #82).** Producers queue to `smsOutbox/{id}`; the `onSmsQueued` trigger (onCreate) sends.
- Outbox doc: `{to (E.164), event, text, vars{}, orderId, userId, refId, status, provider, providerMessageId, error, attempts, createdAt, updatedAt, sentAt}`. `status`: `queued → sending → sent | failed | skipped_no_provider | skipped_disabled | invalid_number`.
- Events queued: order `placed`, `out_for_delivery` (with delivery OTP), `ready_for_pickup` (OTP), `delivered`, `cancelled` (to `orders.customer.phone`, falling back to `users.phone`), and `withdrawal` (from `processWithdrawal`, to the payee). Each respects `settings/communication.events.{event}.sms` (unset = on, `false` = not queued). `settings/communication.sms.enabled:false` stops queuing entirely.
- Sending requires a configured provider **and** `settings/communication.sms.enabled == true`; otherwise the doc ends `skipped_no_provider` / `skipped_disabled`. Admins can create a test doc `{to, text, test:true}` from the panel (bypasses `enabled`). Retries are bounded: 3 attempts in-process for network/429/5xx errors; trigger retries are off. Nothing ever throws into the order flow.
- Numbers are normalised to E.164; numbers without a country code get `+91` (`SMS_DEFAULT_COUNTRY_CODE`).
- Admin-editable (non-secret) in `settings/communication.sms`: `enabled`, `provider` (used only when `SMS_PROVIDER` is empty), `senderId`, and `templates.{event}` = `{enabled?, text? ({{var}} placeholders), msg91TemplateId?, dltTemplateId?, fast2smsRoute?, vars?[] (positional order)}`. Vars per event: placed `name, orderNo, amount`; out_for_delivery / ready_for_pickup `orderNo, otp`; delivered `orderNo`; cancelled `orderNo, reason`; withdrawal `amount, status` (all also get `link`, `rider`, `name` where known).
- Provider config (secrets in Secret Manager; the value `unset` = not configured; non-secrets in `functions/.env`):

| Provider | `SMS_PROVIDER` | Secrets | `.env` |
|---|---|---|---|
| Twilio (chosen) | `twilio` | `TWILIO_API_KEY_SID` (SK…), `TWILIO_API_KEY_SECRET` — or, alternatively, `SMS_AUTH_TOKEN` (Account Auth Token) | `TWILIO_ACCOUNT_SID` (AC…), and `TWILIO_MESSAGING_SERVICE_SID` (MG…) **or** `TWILIO_FROM` (+E.164 number / alphanumeric sender) |
| MSG91 | `msg91` | `SMS_API_KEY` (authkey) | `MSG91_TEMPLATE_ID` (default Flow template; per-event `msg91TemplateId` overrides). Recipient vars are sent by name and as `var1…varN` |
| Fast2SMS | `fast2sms` | `SMS_API_KEY` | `FAST2SMS_ROUTE` = `q` (quick, no DLT) or `dlt` + `SMS_SENDER_ID` + `FAST2SMS_TEMPLATE_ID` (DLT message id). +91 only |
| none | `none` / empty | — | everything is recorded as `skipped_no_provider` |

  `getSystemStatus.integrations` now also returns `sms` (bool, ready) and `smsProvider`.

**Deploy notes.** The F: drive is slow for `npm ci`/`tsc`/discovery. Deploy from a mirror on C:: copy `functions/{src,package.json,package-lock.json,tsconfig.json,.env}` plus `.firebaserc` and a `firebase.json` without hosting/predeploy, run `npm ci && npx tsc -p .` in the mirror, then `FUNCTIONS_DISCOVERY_TIMEOUT=300 firebase deploy --only functions --project go4market --force`. Every secret a function binds must exist in Secret Manager first (create placeholders with `firebase functions:secrets:set NAME --data-file <file containing unset>`). Changing a secret value needs a redeploy of the functions that bind it (`onSmsQueued`, `getSystemStatus`).
