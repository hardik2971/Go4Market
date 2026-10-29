# Go4Market — Google Play upload guide

Two apps go to Google Play:

| App | Package | Play listing name | Folder |
|---|---|---|---|
| Customer app | `com.go4market.customer` | Go4Market: Grocery, Food & More | `playstore/customer_app/` |
| Partner app (Seller + Delivery) | `com.go4market.partner` | Go4Market Partner | `playstore/partner_app/` |

Each folder contains:

- `screenshots/` — phone screenshots, 1080×2400 PNG, taken on the emulator from the live app (upload 4–8 per app).
- `video/` — screen recordings of the live app on the emulator (MP4). Play only accepts a YouTube link for the promo video, so upload the MP4 to YouTube (Public or Unlisted) and paste the link.
- `graphics/` — `icon_512.png` (512×512 app icon) and `feature_graphic.png` (1024×500).
- `listing.md` — title, short description and full description, ready to paste.

---

## 1. One-time setup: create your upload key

Play requires every release to be signed with **your** key. The APKs in this repo are currently signed with the debug key, which Play rejects.

Run once per app (keep the password safe — losing it means you can't ship updates without contacting Google support):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore F:\DI_Local_Project\Go4Market\secret\go4market-upload.jks `
  -alias go4market -keyalg RSA -keysize 2048 -validity 10000
```

One keystore can sign both apps. Then create `android/key.properties` in **each** app (`apps/customer_app/android/` and `apps/partner_app/android/`):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=go4market
storeFile=F:/DI_Local_Project/Go4Market/secret/go4market-upload.jks
```

`key.properties`, `*.jks` and `secret/` are git-ignored. Back the keystore up somewhere outside this PC.

## 2. Build the release bundles (AAB)

Play takes Android App Bundles, not APKs:

```powershell
cd F:\DI_Local_Project\Go4Market\apps\customer_app
flutter build appbundle --release
# -> build\app\outputs\bundle\release\app-release.aab

cd F:\DI_Local_Project\Go4Market\apps\partner_app
flutter build appbundle --release
# -> build\app\outputs\bundle\release\app-release.aab
```

For every later update, raise the version in `pubspec.yaml` first (`version: 1.0.1+2` — the number after `+` must go up each upload). Also raise `settings/platform.appVersions.<app>.latest` in the admin panel (Settings → App versions); raise `.min` only when you want to force everyone to update.

## 3. Create each app in Play Console

https://play.google.com/console → **Create app**

| Field | Customer app | Partner app |
|---|---|---|
| App name | Go4Market: Grocery, Food & More | Go4Market Partner |
| Default language | English (United States) – en-US | same |
| App or game | App | App |
| Free or paid | Free | Free |

Then, in **Setup → App signing**, keep "Google-managed app signing key" (recommended). Your upload key from step 1 signs the uploads.

## 4. Store listing (Grow → Store presence → Main store listing)

Paste from `listing.md` in each app folder, then upload:

- **App icon:** `graphics/icon_512.png`
- **Feature graphic:** `graphics/feature_graphic.png`
- **Phone screenshots:** everything in `screenshots/` (order by filename)
- **Video:** the YouTube link of `video/*.mp4`
- **Category:** Customer → *Shopping*; Partner → *Business*
- **Contact email:** support@go4market.com (change in admin → Settings → Platform if you use another)
- **Website:** https://go4market.web.app
- **Privacy policy:** https://go4market.web.app/page/privacy

## 5. App content (Policy → App content)

Answer these forms; suggested answers:

- **Privacy policy:** https://go4market.web.app/page/privacy
- **App access:** "All or some functionality is restricted" → add the demo logins so reviewers can sign in:
  - Customer app: `customer@go4market.com` / `Go4Market@123`
  - Partner app: seller `seller@go4market.com` / `Go4Market@123`, delivery `delivery@go4market.com` / `Go4Market@123`
  - Keep `settings/platform.demoMode` on while the review runs.
- **Ads:** No ads.
- **Content rating:** fill in the questionnaire — category *Utility, Productivity, Communication or Other*; answer "No" to violence/sexual/etc.; Yes to "users can purchase goods" (customer app). Expected rating: Everyone / 3+.
- **Target audience:** 18 and over.
- **News app:** No.
- **Data safety** (both apps):
  - Collected: Name, Email, Phone number, Address/approximate & precise location, Purchase history, App interactions, Device ID (FCM token). Partner app also: Photos (product images / documents), precise location in the background (delivery partners while online).
  - Payment card data: **not collected** by the app — Razorpay, Stripe and PayPal handle it.
  - All data encrypted in transit: Yes. Users can request deletion: Yes (support email).
  - Shared with third parties: payment processors only (for processing payments).
- **Financial features:** Customer app → "My app provides... digital wallet / stored value for purchases on the platform" if asked; no lending/crypto.
- **Location permissions (Partner app only — important):** the delivery role uses *background location* while a partner is online. Play requires a declaration:
  - Feature description: "Delivery partners share live location while they are marked Online so customers can track their order and the platform can assign nearby deliveries. Tracking stops when the partner goes Offline."
  - Video: record a short clip showing Online toggle → permission prompt → location in use notification → Offline toggle. You can use `partner_app/video/` as a base.
  - If you'd rather avoid the background-location review, remove `ACCESS_BACKGROUND_LOCATION` from `apps/partner_app/android/app/src/main/AndroidManifest.xml`; tracking will then work while the app is on screen or the foreground notification is showing.
- **Foreground service (Partner app):** declare type *Location* with the same explanation.

## 6. Release

1. **Testing → Internal testing → Create new release**, upload the `.aab`, add release notes ("First release of Go4Market").
2. Add yourself and testers by email, install from the opt-in link and check sign-in, ordering and notifications on a real phone.
3. New personal developer accounts must run a **closed test with at least 12 testers for 14 days** before production access is granted. Organisation accounts can go straight to production.
4. **Production → Create release**, promote the tested build, set countries (India first), submit for review. Reviews usually take 1–7 days.

## 7. Before you submit — checklist

- [ ] Upload key created and backed up; `key.properties` in both apps
- [ ] `flutter build appbundle` succeeds for both apps
- [ ] Payment keys switched from test to **live** (Razorpay/Stripe/PayPal) — see the backend notes in `docs/ARCHITECTURE.md`; secrets are in Secret Manager, public keys in admin → Settings → Payments
- [ ] Register the payment webhook URL `https://asia-south1-go4market.cloudfunctions.net/paymentWebhook` in the Razorpay, Stripe and PayPal dashboards
- [ ] Privacy policy, terms and refund pages reviewed in admin → Content → Pages
- [ ] Demo accounts work and `demoMode` is on for the review
- [ ] Screenshots and feature graphic uploaded; video on YouTube
- [ ] Data safety and location declarations submitted
