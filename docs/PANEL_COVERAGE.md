# Go4Market Panels — Coverage Map

Panels: **Admin** (go4market-admin), **Seller** (go4market-seller), **Delivery** (go4market-delivery). One Flutter web codebase, `apps/panel`.
Every route below is a real screen, so no placeholders remain. Routes marked *(drawer)* are side-sheet editors opened from the listed page.

Status: ✅ built · ◐ built, but depends on backend work noted · ✖ not built (reason given)

## 1. Reference screenshots → our routes

| # | Reference module / page | Our route (admin unless noted) | Status |
|---|---|---|---|
| 1 | Dashboard: today tiles, sales overview, order status, business performance | `/dashboard` | ✅ |
| 2 | Dashboard: top categories, catalog & inventory, customers by platform, top selling/rated, top sellers | `/dashboard` | ✅ |
| 3 | Dashboard: recent orders | `/dashboard` | ✅ |
| 4 | Orders › order list | `/orders`, `/orders/:id`, `/print/invoice/:id` | ✅ |
| 5 | Self-pickup orders | `/orders/pickup` | ✅ |
| 6 | Categories › add category (modal) | `/catalog/categories` *(drawer)* | ✅ |
| 7 | Categories › manage (tree, drag order, bg colours) | `/catalog/categories` | ✅ |
| 8 | Products › add product (AI description) | `/catalog/products/new` | ✅ |
| 9 | Products › manage products | `/catalog/products` | ✅ |
| 10 | Products › approve requests | `/catalog/approvals` | ✅ |
| 11 | Products › product ratings | `/catalog/ratings` | ✅ |
| 12 | Products › media | `/catalog/media` | ✅ |
| 13 | Products › bulk upload (+ variant combo generator) | `/catalog/bulk`; variant generator is in `/catalog/products/new` | ✅ |
| 14 | Products › bulk update | `/catalog/bulk` (export → edit → import) | ✅ |
| 15 | Products › taxes | `/catalog/taxes` | ✅ |
| 16 | Products › brands | `/catalog/brands` | ✅ |
| 17 | Products › attributes | `/catalog/attributes` | ✅ |
| 18 | Products › product order | `/catalog/sort` | ✅ |
| 19 | Stock management | `/catalog/stock` | ✅ |
| 20 | Sellers › add seller | `/sellers` → "Add seller" | ✅ |
| 21 | Sellers › seller requests | `/sellers/requests` | ✅ |
| 22 | Sellers › manage sellers | `/sellers`, `/sellers/:id` | ✅ |
| 23 | Sellers › seller wallet transactions | `/sellers/wallet` | ✅ |
| 24 | Sellers › seller policies | `/sellers/policies` | ✅ |
| 25 | Home sliders › manage | `/marketing/sliders` | ✅ |
| 26 | Home sliders › add (modal) | `/marketing/sliders` *(drawer)* | ✅ |
| 27 | Offer images › add (modal) | `/marketing/offers` *(drawer)* | ✅ |
| 28 | Offer images › manage | `/marketing/offers` | ✅ |
| 29 | Popup offer | `/marketing/popups` | ✅ |
| 30 | Promo code › add (modal) | `/marketing/coupons` *(drawer)* | ✅ |
| 31 | Promo code › manage | `/marketing/coupons` | ✅ |
| 32 | Featured sections › add (modal) | `/marketing/featured` *(drawer, product picker)* | ✅ |
| 33 | Featured sections › manage | `/marketing/featured` | ✅ |
| 34 | Return requests | `/returns` | ✅ |
| 35 | Custom fields (sellers/delivery/customers/products tabs) | `/catalog/custom-fields` | ✅ |
| 36 | Withdrawal requests | `/finance/withdrawals` | ✅ |
| 37 | Theme settings | `/settings/theme` | ✅ |
| 38 | Delivery settings › time slots | `/delivery/settings` (also `/settings/platform`) | ✅ |
| 39 | Delivery settings › seller delivery boys toggle | `/delivery/settings`; seller fleets tab in `/delivery/partners` | ✅ |
| 40 | Blogs › blog categories | `/content/blog-categories` | ✅ |
| 41 | Blogs › blogs | `/content/blogs` | ✅ |
| 42 | Modules | `/settings/modules` | ✅ |
| 43 | Delivery boys › add | `/delivery/partners` → "Add partner" | ✅ |
| 44 | Delivery boys › requests | `/delivery/requests` | ✅ |
| 45 | Delivery boys › manage | `/delivery/partners`, `/delivery/partners/:id` | ✅ |
| 46 | Delivery boys › fund transfers | `/finance/transfers` | ✅ |
| 47 | Delivery boys › cash collection | `/delivery/cash` | ✅ |
| 48 | Delivery boys › policies | `/delivery/policies` | ✅ |
| 49 | Delivery boys › salary | `/delivery/salary` | ✅ |
| 50 | Notifications › send | `/marketing/campaigns` → "Send now" (`sendCampaign`) | ✅ |
| 51 | Notifications › manage | `/marketing/campaigns` | ✅ |
| 52 | Email › templates | `/content/email-templates` | ✅ |
| 53 | Email › manage / send email | `/content/emails` | ◐ needs the Trigger Email extension or a function on `mail` |
| 54 | Settings hub: store, address, other, app, frontend home, cart, refer & earn, theme | `/settings` hub → `/settings/platform`, `/settings/app-versions`, `/settings/theme`, `/marketing/featured` | ✅ (login-method toggles ✖: email/password auth only) |
| 55 | Settings hub: delivery, payments, SMTP, Firebase, notification templates, SMS | `/delivery/settings`, `/settings/payments`, `/settings/communication`, `/content/email-templates` | ◐ secrets stay in Functions config, not the client |
| 56 | Settings hub: SMS templates, realtime, integrations, content & policies | `/settings/communication`, `/settings/seo`, `/content/pages` | ◐ as above |
| 57 | Settings hub: delivery policies, web settings, social, seller setting, system registration/updater | `/delivery/policies`, `/settings/social`, `/settings/platform`, `/system` | ✅ (licence registration and self-updater don't apply: deploys go through Firebase Hosting) |
| 58 | Subscriptions › plans | `/marketing/membership` (customer product subscriptions: `/marketing/subscriptions`) | ✅ |
| 59 | Subscriptions › FAQs | `/content/faqs` (category field) | ✅ |
| 60 | Languages › add (modal) | `/settings/languages` *(drawer, JSON upload)* | ✅ |
| 61 | Languages › manage | `/settings/languages` | ✅ |
| 62 | Countries › add (modal) | `/settings/countries` *(drawer)* | ✅ |
| 63 | Countries › manage | `/settings/countries` | ✅ |
| 64 | Location › add city (map) | `/settings/cities` *(drawer, OSM picker + radius)* | ✅ |
| 65 | Location › manage cities | `/settings/cities` | ✅ |
| 66 | Customers | `/customers`, `/customers/:id` | ✅ |
| 67 | Customers › wishlists | `/customers/wishlists` | ✅ |
| 68 | Customers › product requests | `/customers/product-requests` | ✅ |
| 69 | Customers › wallet transactions | `/finance/wallet` | ✅ |
| 70 | Customers › payment transactions | `/finance/transactions` | ✅ |
| 71 | Customers › customer policies | `/content/pages` (privacy, refund, customer-policy, …) | ✅ |
| 72 | Reports › product sales | `/reports/products` | ✅ |
| 73 | Reports › sales | `/reports/sales` | ✅ |
| 74 | Reports › commission | `/reports/commission` | ✅ |
| 75 | System users | `/staff` | ✅ |
| 76 | Role | `/staff/roles` | ✅ |
| 77 | FAQs | `/content/faqs` | ✅ |
| 78 | Module switcher dropdown | top-bar module switcher (re-themes the panel, scopes dashboard/catalog) | ✅ |
| 79 | Add product (Grocery theme) | `/catalog/products/new` with module colour | ✅ |
| 80 | Dashboard (Grocery) | `/dashboard` + module switcher | ✅ |
| 81 | Dashboard (Pharmacy) | `/dashboard` + module switcher | ✅ |
| 82 | Dashboard (Food) | `/dashboard` + module switcher | ✅ |
| 83 | Dashboard + language dropdown | `/dashboard`; panel UI language switch ✖ (panel is English; customer languages managed at `/settings/languages`) | ◐ |
| 84 | Profile › order mail settings, change password | `/account` | ✅ |
| 85 | Seller dashboard + seller menu | Seller: `/dashboard` and full seller nav (see §3) | ✅ |
| 86 | Delivery dashboard + delivery menu | Delivery: `/dashboard` and full delivery nav (see §3) | ✅ |

**Screenshot coverage: 86 / 86 mapped to working routes.** 82 fully, 4 partial (◐: #53, #55, #56, #83), for the email-send backend, SMTP/SMS secrets kept server-side, and no in-panel UI language switch.

## 2. FEATURES.md → panel routes

"Client-side" means the feature lives in the website or apps; the panel supplies the configuration listed.

| # | Feature | Panel route(s) | Status |
|---|---|---|---|
| 01 | Multi-module commerce | `/settings/modules`, top-bar module switcher, module field on catalog/marketing | ✅ |
| 02 | Multi-vendor marketplace | `/sellers*`, seller panel | ✅ |
| 03 | Quick delivery 15/30 | `/settings/platform`, `/delivery/settings` (toggles, fees); speed tags in `/orders` | ✅ |
| 04 | Food delivery module | `food` module, veg/non-veg and custom fields (add-ons) in product editor | ✅ |
| 05 | POS | Admin `/pos`, Seller `/pos`, `/orders/pos` | ✅ |
| 06 | Real-time rider location | `/live-map`; Delivery dashboard location beacon | ✅ |
| 07 | Live order tracking | `/orders/:id` timeline + map (customer tracking is client-side) | ✅ |
| 08 | AI product descriptions | `/catalog/products/new` "Generate with AI" → `generateDescription` | ✅ |
| 09 | Multiple payment gateways | `/settings/payments` | ✅ |
| 10 | Membership plans | `/marketing/membership` | ✅ |
| 11 | Customer subscriptions | `/marketing/subscriptions` | ✅ |
| 12 | Refer & earn | `/settings/platform` (referral rewards) | ✅ |
| 13 | Single-screen checkout | client-side | — |
| 14 | Cart management | `/customers/:id` cart tab, `/marketing/abandoned-carts` | ✅ |
| 15 | Smart search | client-side; product `keywords` written by editor | — |
| 16 | Voice search | client-side | — |
| 17 | Similar product replacement | client-side (uses categories) | — |
| 18 | Abandoned carts | Admin and Seller `/marketing/abandoned-carts` | ✅ |
| 19 | Cross-selling | client-side (uses tags/categories) | — |
| 20 | Coupons & discounts | Admin and Seller `/marketing/coupons` | ✅ |
| 21 | Offer management | `/marketing/offers` | ✅ |
| 22 | Promo codes | `/marketing/coupons` | ✅ |
| 23 | Digital wallet | `/finance/wallet`, `/customers/:id` (adjust wallet) | ✅ |
| 24 | Partial wallet payment | client-side; `walletUsed` shown in `/orders/:id` | ✅ |
| 25 | Add funds to wallet | client-side; top-ups in `/finance/wallet` | ✅ |
| 26 | COD | `/settings/platform` (codEnabled/codMax), `/settings/payments`; cash flow in `/delivery/cash` | ✅ |
| 27 | Location-based shopping | `/settings/cities` | ✅ |
| 28 | Quick delivery countdown | ETA countdown on `/orders/:id` (customer UI is client-side) | ✅ |
| 29 | Scheduled delivery | slots in `/settings/platform`, `/delivery/settings` | ✅ |
| 30 | Home delivery | `/orders`, rider assignment | ✅ |
| 31 | Self-pickup orders | `/orders/pickup`; Seller `/orders/pickup` | ✅ |
| 32 | Distance & estimates | distance in rider picker, Delivery pool; per-km fee in settings | ✅ |
| 33 | OpenStreetMap | `/live-map`, `/settings/cities`, Delivery `/map`, `/orders/:id` | ✅ |
| 34 | Dynamic homepage | `/marketing/featured`, `/marketing/sliders`, `/marketing/offers` | ✅ |
| 35 | Home sliders | `/marketing/sliders` | ✅ |
| 36 | Featured sections | `/marketing/featured` | ✅ |
| 37 | Popups | `/marketing/popups` | ✅ |
| 38 | Push notifications | `/marketing/campaigns` → `sendCampaign`; bell inbox in every panel | ✅ |
| 39 | Ratings & reviews | `/catalog/ratings`; Seller `/catalog/reviews` | ✅ |
| 40 | Recently viewed | client-side | — |
| 41 | Barcode scanner | `/pos` barcode entry (USB scanners type plus Enter); barcode field in product editor | ✅ |
| 42 | Product variants | product editor variant editor and generator | ✅ |
| 43 | Grid & list view | client-side (panel tables also have a card/table toggle) | ✅ |
| 44 | Multi-language | `/settings/languages` | ◐ panel UI itself is English |
| 45 | Dark & light mode | top-bar toggle in all panels (persisted) | ✅ |
| 46 | Liquid Glass iOS 26 | client-side | — |
| 47 | Secure login | `/login` (all panels), Firebase Auth with role claims and guards | ✅ |
| 48 | Role-based dashboards | three panels; staff permission filtering of the nav | ✅ |
| 49 | Responsive panels, dark mode, card/table | all panels | ◐ no RTL layout |
| 50 | Unified order management | `/orders`, `/orders/:id` | ✅ |
| 51 | Business reports | `/dashboard`, `/reports/*` | ✅ |
| 52 | Sales reports | `/reports/sales` | ✅ |
| 53 | Product sales reports | `/reports/products` (best and worst) | ✅ |
| 54 | POS reports | `/reports/pos` (Admin and Seller) | ✅ |
| 55 | Product management | `/catalog/products*` | ✅ |
| 56 | Stock management | `/catalog/stock` | ✅ |
| 57 | Category management | `/catalog/categories` | ✅ |
| 58 | Infinite categories | `/catalog/categories` (nested tree) | ✅ |
| 59 | Category navigation | tree picker in product editor (storefront nav is client-side) | ✅ |
| 60 | Veg/non-veg and custom fields | product editor, `/catalog/custom-fields` | ✅ |
| 61 | Product requests | `/customers/product-requests` | ✅ |
| 62 | Return requests | `/returns` (Admin and Seller) | ✅ |
| 63 | Customer management | `/customers`, `/customers/:id` | ✅ |
| 64 | Customer financials | `/customers/:id` wallet tab, `/finance/wallet` | ✅ |
| 65 | Wallet transactions | `/finance/wallet` | ✅ |
| 66 | Seller onboarding | Seller `/register` wizard → `/pending` | ✅ |
| 67 | Seller requests | `/sellers/requests`, `/catalog/approvals` | ✅ |
| 68 | Seller accounts | `/sellers`, `/sellers/:id` | ✅ |
| 69 | Seller attributes & custom fields | Seller `/catalog/attributes` | ✅ |
| 70 | Seller policies | `/sellers/policies`; acceptance in Seller `/register` and `/store` | ✅ |
| 71 | Global attribute migration alerts | Seller `/catalog/attributes` banner | ✅ |
| 72 | Withdrawals | `/finance/withdrawals`; Seller and Delivery `/finance/withdrawals` | ✅ |
| 73 | Delivery partner management | `/delivery/*`; Delivery `/register` → `/pending` | ✅ |
| 74 | Multi-city riders | cities multi-select in `/delivery/partners` and Delivery `/register` | ✅ |
| 75 | Admin-wise / seller-wise riders | fleet switch in `/delivery/partners`; Seller `/riders` | ◐ sellers can't create rider accounts (no callable) |
| 76 | Cash collection | `/delivery/cash` (`settleCash`); Delivery `/finance/cash` | ✅ |
| 77 | Fund transfers | `/finance/transfers` (`transferFunds`) | ✅ |
| 78 | Salary | `/delivery/salary` | ✅ |
| 79 | SEO | `/settings/seo` | ✅ |
| 80 | Blogs | `/content/blogs`, `/content/blog-categories` | ✅ |
| 81 | Communication management | `/settings/communication`, `/marketing/campaigns`, `/content/email-templates` | ✅ |
| 82 | SMS gateway | `/settings/communication` (provider + toggles) | ◐ gateway credentials and sending are backend |
| 83 | Email notifications | `/content/email-templates`, `/content/emails`, `/account` order-mail matrix | ◐ SMTP is backend |
| 84 | Module theme colours | `/settings/modules`, `/settings/theme`; panel re-themes per module | ✅ |
| 85 | Social icons | `/settings/social` | ✅ |
| 86 | Localization | `/settings/languages` (translation JSON upload) | ✅ |
| 87 | Flutter app architecture | n/a (tech) | — |
| 88 | Next.js website | n/a (tech) | — |
| 89 | Laravel backend | n/a (tech; Firebase here) | — |
| 90 | WebP support | all image uploads accept WebP | ✅ |
| 91 | Force update | `/settings/app-versions` | ✅ |
| 92 | Module management | `/settings/modules` | ✅ |
| 93 | Platform configuration | `/settings/platform` | ✅ |
| 94 | Technical configuration | `/settings/payments` (public keys), `/settings/communication`, `/system` | ✅ |
| 95 | User & role management | `/staff`, `/staff/roles` | ✅ |
| 96 | FAQ management | `/content/faqs` | ✅ |
| 97 | Demo mode | `/settings/system-mode` | ✅ |
| 98 | System administration | `/system` (health, latency, counts, missing indexes) | ✅ |

**Feature coverage (panel-relevant features only)**

- 98 features in total.
- 10 are client-side or tech-only (—): #13, 15, 16, 17, 19, 40, 46, 87, 88, 89.
- That leaves 88 that need a panel screen:
  - 83 are fully built (✅).
  - 5 are built, but part of the feature needs backend work or isn't done (◐): #44, 49 (RTL), 75, 82, 83.
  - 0 are missing.

## 3. Route maps

**Admin:**
- Overview: `/dashboard`, `/pos`, `/live-map`
- Orders: `/orders`, `/orders/pickup`, `/orders/pos`, `/orders/:id`, `/returns`, `/print/invoice/:id`
- Catalog: `/catalog/{products, products/new, products/:id/edit, approvals, categories, brands, attributes, custom-fields, taxes, stock, ratings, media, bulk, sort}`
- Sellers: `/sellers`, `/sellers/{requests, wallet, policies, :id}`
- Delivery: `/delivery/{partners, requests, partners/:id, cash, salary, settings, policies}`
- Customers: `/customers`, `/customers/{wishlists, product-requests, :id}`
- Finance: `/finance/{wallet, withdrawals, transfers, payouts, transactions}`
- Marketing: `/marketing/{sliders, offers, popups, featured, coupons, campaigns, membership, subscriptions, abandoned-carts}`
- Content: `/content/{blogs, blog-categories, faqs, pages, email-templates, emails}`
- Reports: `/reports/{sales, products, categories, sellers, commission, pos}`
- Settings: `/settings`, `/settings/{platform, payments, modules, theme, seo, social, app-versions, languages, cities, countries, communication, system-mode}`
- Staff and system: `/staff`, `/staff/roles`, `/system`, `/account`
- Auth: `/login`

**Seller:**
- Auth and onboarding: `/login`, `/register`, `/pending`
- Overview: `/dashboard`, `/pos`
- Orders: `/orders`, `/orders/pickup`, `/orders/pos`, `/orders/:id`, `/returns`, `/print/invoice/:id`
- Catalog: `/catalog/{products, products/new, products/:id/edit, attributes, stock, reviews, bulk}`
- Growth: `/marketing/coupons`, `/marketing/abandoned-carts`, `/riders`
- Money: `/finance/earnings`, `/finance/withdrawals`
- Reports: `/reports/{sales, products, pos}`
- Store: `/store`

**Delivery:**
- Auth and onboarding: `/login`, `/register`, `/pending`
- Work: `/dashboard`, `/orders/available`, `/orders`, `/orders/:id`, `/map`
- Money: `/finance/earnings`, `/finance/cash`, `/finance/withdrawals`
- Account: `/profile`

## Localization, partner sign-in and web push (panels v1.3)

- Languages: English (default), हिन्दी, ગુજરાતી, العربية (full RTL). The picker is in the top bar and on the login screen. Only languages with `languages/{code}.active == true` are offered. The choice is saved to localStorage `g4m.lang`, `users/{uid}.lang`, and `staff/{uid}.lang` when that doc exists.
- Strings: `lib/l10n/l10n.dart` holds the typed `S` getters plus `tr()` / `trf()`. `dict_*.dart` maps each English key to `[hi, gu, ar]`, and a missing key falls back to English. Shared widgets (`PanelPage`, `SectionCard`, `KpiCard`, `DataView` columns/actions/filters, `EntityForm` labels, dialogs, toasts, status pills) translate automatically.
- `g4m_core`'s `Fmt`, `EmptyState` and `StatusChip` are English/en_IN-only. Panel files import g4m_core with `hide Fmt, EmptyState, StatusChip` and use the locale-aware versions in `package:panel/l10n/overrides.dart`. ₹ is kept, and Arabic uses Latin digits.
- Charts are wrapped in an LTR `Directionality`, so time and number axes read left to right in Arabic too.
- Seller and delivery login also offer Google (`signInWithPopup`) and phone OTP (invisible reCAPTCHA, +91 default). New users go to `/register`. Admin stays email-only.
- Web push: the profile menu has an "Enable notifications" toggle that calls `registerPushToken` and falls back to `users/{uid}.fcmTokens` arrayUnion. `web/firebase-messaging-sw.js` is written into each `build/<panel>/` by `tool/build_all.ps1`. Clicking a notification opens `/orders/{orderId}`. An optional VAPID key can be passed with `--dart-define=FCM_VAPID_KEY=...`.
