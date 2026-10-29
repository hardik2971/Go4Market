// Marketing, CMS and configuration content for the Go4Market seed.
// Image keys (img) resolve through data/images.json, or a generated illustration when missing.

export const cities = [
  ['ahmedabad', 'Ahmedabad', 'Gujarat', 23.0225, 72.5714, 30],
  ['gandhinagar', 'Gandhinagar', 'Gujarat', 23.2156, 72.6369, 20],
  ['surat', 'Surat', 'Gujarat', 21.1702, 72.8311, 25],
  ['vadodara', 'Vadodara', 'Gujarat', 22.3072, 73.1812, 20],
  ['rajkot', 'Rajkot', 'Gujarat', 22.3039, 70.8022, 18],
  ['mumbai', 'Mumbai', 'Maharashtra', 19.0760, 72.8777, 35],
  ['pune', 'Pune', 'Maharashtra', 18.5204, 73.8567, 25],
  ['bengaluru', 'Bengaluru', 'Karnataka', 12.9716, 77.5946, 35],
  ['hyderabad', 'Hyderabad', 'Telangana', 17.3850, 78.4867, 30],
  ['chennai', 'Chennai', 'Tamil Nadu', 13.0827, 80.2707, 30],
  ['new-delhi', 'New Delhi', 'Delhi', 28.6139, 77.2090, 35],
  ['jaipur', 'Jaipur', 'Rajasthan', 26.9124, 75.7873, 20],
].map(([id, name, state, lat, lng, radiusKm], i) => ({ id, name, state, lat, lng, radiusKm, active: i < 5 || ['mumbai', 'pune', 'bengaluru'].includes(id), order: i + 1 }));

export const languages = [
  { code: 'en', name: 'English', nativeName: 'English', isDefault: true, rtl: false, active: true },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', isDefault: false, rtl: false, active: true },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', isDefault: false, rtl: false, active: true },
  { code: 'ar', name: 'Arabic', nativeName: 'العربية', isDefault: false, rtl: true, active: true },
];

export const translations = {
  en: { home: 'Home', categories: 'Categories', cart: 'Cart', orders: 'Orders', account: 'Account', search_hint: 'Search for milk, biryani, medicines…', add_to_cart: 'Add to cart', checkout: 'Checkout', wallet: 'Wallet', track_order: 'Track order', deliver_to: 'Deliver to', free_delivery: 'Free delivery', out_of_stock: 'Out of stock' },
  hi: { home: 'होम', categories: 'श्रेणियाँ', cart: 'कार्ट', orders: 'ऑर्डर', account: 'खाता', search_hint: 'दूध, बिरयानी, दवाइयाँ खोजें…', add_to_cart: 'कार्ट में डालें', checkout: 'चेकआउट', wallet: 'वॉलेट', track_order: 'ऑर्डर ट्रैक करें', deliver_to: 'यहाँ डिलीवर करें', free_delivery: 'मुफ़्त डिलीवरी', out_of_stock: 'स्टॉक में नहीं' },
  gu: { home: 'હોમ', categories: 'શ્રેણીઓ', cart: 'કાર્ટ', orders: 'ઓર્ડર', account: 'એકાઉન્ટ', search_hint: 'દૂધ, બિરયાની, દવાઓ શોધો…', add_to_cart: 'કાર્ટમાં ઉમેરો', checkout: 'ચેકઆઉટ', wallet: 'વૉલેટ', track_order: 'ઓર્ડર ટ્રેક કરો', deliver_to: 'અહીં ડિલિવર કરો', free_delivery: 'મફત ડિલિવરી', out_of_stock: 'સ્ટોકમાં નથી' },
  ar: { home: 'الرئيسية', categories: 'الفئات', cart: 'السلة', orders: 'الطلبات', account: 'الحساب', search_hint: 'ابحث عن الحليب، البرياني، الأدوية…', add_to_cart: 'أضف إلى السلة', checkout: 'الدفع', wallet: 'المحفظة', track_order: 'تتبع الطلب', deliver_to: 'التوصيل إلى', free_delivery: 'توصيل مجاني', out_of_stock: 'غير متوفر' },
};

export const sliders = [
  { id: 'fresh-everyday', title: 'Farm-fresh, every morning', subtitle: 'Fruits & vegetables picked at dawn, at your door in 30 minutes', ctaText: 'Shop fresh', link: '/c/fruits-vegetables', moduleId: 'grocery', bgColor: '#E8F5EE', img: 'slider:grocery-fresh' },
  { id: 'quick-15', title: 'Groceries in 15 minutes', subtitle: 'Quick Delivery is live across Ahmedabad — free above ₹499', ctaText: 'Order now', link: '/m/grocery', moduleId: 'grocery', bgColor: '#FFF4E6', img: 'slider:quick-delivery' },
  { id: 'dairy-breakfast', title: 'Breakfast, sorted', subtitle: 'Milk, curd, paneer and fresh bread — subscribe and never run out', ctaText: 'Subscribe', link: '/c/dairy-bakery', moduleId: 'grocery', bgColor: '#F2F7FF', img: 'slider:dairy-breakfast' },
  { id: 'biryani-fest', title: 'Biryani Fest is here', subtitle: 'Flat 20% off on dum biryanis from Spice Route Kitchen', ctaText: 'Order food', link: '/m/food', moduleId: 'food', bgColor: '#FFF1E5', img: 'slider:food-feast' },
  { id: 'pharmacy-care', title: 'Your pharmacy, delivered', subtitle: 'Genuine medicines and wellness essentials in 45 minutes', ctaText: 'Shop health', link: '/m/pharmacy', moduleId: 'pharmacy', bgColor: '#E6F7F6', img: 'slider:pharmacy' },
  { id: 'gadget-days', title: 'Gadget Days', subtitle: 'Up to 50% off on audio, wearables and power banks', ctaText: 'Explore deals', link: '/c/electronics', moduleId: 'ecommerce', bgColor: '#EEF2FF', img: 'slider:electronics' },
  { id: 'style-edit', title: 'The Summer Style Edit', subtitle: 'Linen shirts, block-print kurtas and sunglasses', ctaText: 'Shop fashion', link: '/c/fashion', moduleId: 'ecommerce', bgColor: '#FDF2F8', img: 'slider:fashion' },
  { id: 'kitchen-upgrade', title: 'Upgrade your kitchen', subtitle: 'Tri-ply cookware and smart appliances from ChefPro', ctaText: 'Shop kitchen', link: '/c/home-kitchen', moduleId: 'ecommerce', bgColor: '#F5F5F4', img: 'slider:home-kitchen' },
];

export const offers = [
  { id: 'fruit-basket', title: 'Fruits under ₹99', image: 'offer:fruits', link: '/c/fresh-fruits', moduleId: 'grocery', position: 'home_top' },
  { id: 'snack-o-clock', title: 'Snack o’clock: buy 2, save 15%', image: 'offer:snacks', link: '/c/chips-namkeen', moduleId: 'grocery', position: 'home_mid' },
  { id: 'pizza-party', title: 'Pizza party — 2 large at ₹699', image: 'offer:pizza', link: '/c/pizzas', moduleId: 'food', position: 'home_top' },
  { id: 'vitamin-week', title: 'Vitamin week: up to 30% off', image: 'offer:vitamins', link: '/c/vitamins-supplements', moduleId: 'pharmacy', position: 'home_mid' },
  { id: 'sneaker-drop', title: 'Sneakers from ₹1,999', image: 'offer:sneakers', link: '/c/men-footwear', moduleId: 'ecommerce', position: 'category' },
  { id: 'glow-up', title: 'Skincare essentials, 20% off', image: 'offer:skincare', link: '/c/skincare', moduleId: 'ecommerce', position: 'home_mid' },
];

export const coupons = [
  { id: 'WELCOME50', message: 'Flat ₹50 off on your first order above ₹299', discountType: 'flat', value: 50, maxDiscount: 50, minOrder: 299, usageLimit: 0, perUserLimit: 1, image: '' },
  { id: 'G4MSAVE20', message: '20% off up to ₹150 on orders above ₹499', discountType: 'percent', value: 20, maxDiscount: 150, minOrder: 499, usageLimit: 5000, perUserLimit: 3, image: '' },
  { id: 'FREESHIP', message: 'Free delivery on orders above ₹199 (up to ₹49)', discountType: 'flat', value: 49, maxDiscount: 49, minOrder: 199, usageLimit: 0, perUserLimit: 5, freeDelivery: true, image: '' },
  { id: 'BIRYANI20', message: '20% off up to ₹120 at Spice Route Kitchen', discountType: 'percent', value: 20, maxDiscount: 120, minOrder: 300, usageLimit: 1000, perUserLimit: 2, sellerId: 'seller-spiceroute', image: '' },
  { id: 'HEALTH10', message: '10% off up to ₹200 on MediPlus Pharmacy orders above ₹499', discountType: 'percent', value: 10, maxDiscount: 200, minOrder: 499, usageLimit: 0, perUserLimit: 0, sellerId: 'seller-mediplus', image: '' },
  { id: 'GADGET500', message: 'Flat ₹500 off on electronics above ₹4,999', discountType: 'flat', value: 500, maxDiscount: 500, minOrder: 4999, usageLimit: 500, perUserLimit: 1, sellerId: 'seller-urbantrend', image: '' },
];

export const membershipPlans = [
  { id: 'g4m-plus-monthly', name: 'Go4 Plus Monthly', price: 99, durationDays: 30, benefits: ['Free delivery on every order', 'Extra 5% off on groceries', 'Priority support'], freeDelivery: true, discountPct: 5, active: true, order: 1 },
  { id: 'g4m-plus-quarterly', name: 'Go4 Plus Quarterly', price: 249, durationDays: 90, benefits: ['Free delivery on every order', 'Extra 5% off', 'Priority support', 'Early access to sales'], freeDelivery: true, discountPct: 5, active: true, order: 2 },
  { id: 'g4m-plus-annual', name: 'Go4 Plus Annual', price: 899, durationDays: 365, benefits: ['Free delivery on every order', 'Extra 7% off', 'Priority support', 'Early access to sales', 'Birthday cashback ₹200'], freeDelivery: true, discountPct: 7, active: true, order: 3 },
];

export const faqs = [
  ['Orders', 'How fast will my order arrive?', 'Grocery, food and pharmacy orders in Ahmedabad usually arrive in 15–45 minutes depending on the speed you choose at checkout (Quick 15, Quick 30 or Standard). Electronics, fashion and home items ship in 1–3 days. You can see a live countdown and your rider’s location on the order screen.'],
  ['Orders', 'Can I schedule a delivery for later?', 'Yes. Choose “Scheduled” at checkout and pick a date and a time slot. We will deliver within the slot you select.'],
  ['Orders', 'How do I cancel an order?', 'You can cancel from My Orders until the store packs it. If you paid online or used your wallet, the refund goes to your Go4Market wallet instantly.'],
  ['Orders', 'What is the delivery OTP?', 'Every home delivery has a 4-digit OTP shown on your order screen. Share it with the rider only when you receive your order — it confirms the hand-over.'],
  ['Payments', 'Which payment methods do you accept?', 'UPI, cards and net banking through Razorpay, international cards through Stripe, PayPal, your Go4Market wallet, and cash on delivery for orders up to ₹5,000.'],
  ['Payments', 'Can I pay partly with my wallet?', 'Yes. Turn on “Use wallet balance” at checkout and pay the rest with any other method.'],
  ['Wallet', 'How do I add money to my wallet?', 'Open Wallet → Add money, enter an amount between ₹10 and ₹50,000 and pay with any online method. The balance never expires.'],
  ['Wallet', 'How does Refer & Earn work?', 'Share your referral code. When your friend signs up with it and their first order is delivered, you both get ₹50 in your wallets.'],
  ['Returns', 'What is your return policy?', 'Most packaged products and shopping items can be returned within 7 days of delivery. Fresh produce, food and opened medicines are not returnable, but we will make it right if anything arrives damaged. See our Refund Policy for details.'],
  ['Returns', 'When will I get my refund?', 'Refunds for approved returns are credited to your Go4Market wallet as soon as the return is picked up — usually within 48 hours.'],
  ['Membership', 'What do I get with Go4 Plus?', 'Free delivery on every order, an extra 5–7% off on eligible items, priority support and early access to sales.'],
  ['Sellers', 'How can I sell on Go4Market?', 'Create an account, open “Sell on Go4Market” and submit your store details and GSTIN. Our team reviews applications within 48 hours.'],
].map(([category, question, answer], i) => ({ id: `faq-${String(i + 1).padStart(2, '0')}`, category, question, answer, order: i + 1, active: true }));

export const blogCategories = [
  { id: 'healthy-living', name: 'Healthy Living', slug: 'healthy-living', order: 1 },
  { id: 'recipes', name: 'Recipes & Food', slug: 'recipes', order: 2 },
  { id: 'smart-shopping', name: 'Smart Shopping', slug: 'smart-shopping', order: 3 },
  { id: 'lifestyle', name: 'Lifestyle & Tech', slug: 'lifestyle', order: 4 },
];

export const blogs = [
  {
    id: 'seasonal-produce-guide', slug: 'seasonal-produce-guide', categoryId: 'healthy-living', img: 'blog:seasonal-produce', author: 'Riya Desai', daysAgo: 3,
    title: 'Eat with the Seasons: A Month-by-Month Produce Guide for Gujarat',
    excerpt: 'Seasonal fruits and vegetables taste better, cost less and pack more nutrition. Here is what to buy, and when.',
    tags: ['seasonal', 'vegetables', 'fruits', 'nutrition'],
    content: `Walk into any market in Ahmedabad in December and you will find mountains of *lilva*, fresh green garlic and purple yam — the backbone of a good *undhiyu*. Come back in May and it is all Kesar and Alphonso mangoes. Eating with the seasons is not just tradition; it is the simplest way to get fresher, tastier and cheaper food.

## Why seasonal produce is better

- **Flavour:** fruit that ripens naturally on the plant develops more sugars and aromatics than produce picked early for long-distance transport.
- **Nutrition:** vitamin C and folate start to fall soon after harvest. Local, in-season produce reaches you faster.
- **Price:** when supply peaks, prices drop. Tomatoes in winter can cost half of what they do in the monsoon.

## A quick calendar

| Season | Best vegetables | Best fruits |
|---|---|---|
| Winter (Nov–Feb) | Carrots, green peas, cauliflower, spinach, methi, lilva | Oranges, guava, strawberries, amla |
| Summer (Mar–Jun) | Bottle gourd, cucumber, okra, raw mango | Mangoes, watermelon, muskmelon, jamun |
| Monsoon (Jul–Oct) | Corn, ridge gourd, colocasia leaves, mushrooms | Pomegranate, pears, plums, custard apple |

## How to store what you buy

1. **Leafy greens:** remove rubber bands, wrap loosely in a cotton cloth and refrigerate. Use within three days.
2. **Tomatoes:** keep them at room temperature until fully ripe, then refrigerate.
3. **Onions and potatoes:** store separately in a cool, dark, ventilated basket — together they spoil faster.
4. **Herbs:** stand coriander and mint in a glass of water like flowers, cover loosely and refrigerate.

## Shop smarter on Go4Market

Our Fresh Mart partners buy directly from farms in Kheda, Anand and Nashik every morning, so what you see in the app is what is in season. Look for the **“Picked today”** badge, and subscribe to milk and daily greens so they arrive before breakfast.`,
  },
  {
    id: 'indian-spice-pantry', slug: 'indian-spice-pantry', categoryId: 'recipes', img: 'blog:spice-pantry', author: 'Chef Imran Qureshi', daysAgo: 8,
    title: 'Build Your Indian Spice Pantry: 12 Essentials and How to Keep Them Fresh',
    excerpt: 'You do not need fifty jars. These twelve spices cover almost every Indian recipe — here is how to buy, store and use them.',
    tags: ['spices', 'cooking', 'pantry', 'masala'],
    content: `A good spice box (*masala dabba*) is the most valuable tool in an Indian kitchen. Get the basics right and every dal, sabzi and biryani improves overnight.

## The twelve essentials

**Whole spices:** cumin (jeera), mustard seeds, black peppercorns, cinnamon, green cardamom, cloves.
**Ground spices:** turmeric, Kashmiri red chilli, coriander powder, garam masala.
**Extras that punch above their weight:** hing (asafoetida) and kasuri methi.

## Whole vs. ground

Whole spices keep their essential oils for up to a year; ground spices lose their aroma within three to six months. Buy whole when you can and grind small batches in a dry mixer jar.

## Bloom them properly

Spices release flavour into fat, not water. For a tadka, heat ghee or oil until it shimmers, add mustard seeds and wait for them to pop, then cumin, then hing — in that order, within thirty seconds. Ground spices burn quickly; add them with a splash of water or after the onions.

## Storage rules

1. Airtight glass or steel containers, away from the stove.
2. Never dip a wet spoon into the jar.
3. Write the purchase date on the lid.
4. Smell test: if you cannot smell it when you open the jar, it will not flavour your food.

## A five-minute garam masala

Dry-roast 2 tbsp coriander seeds, 1 tbsp cumin, 1 tsp black pepper, 6 cloves, 6 green cardamom pods and a 2-inch cinnamon stick on low heat until fragrant. Cool, grind and store in a small jar. It is the difference between a good curry and a great one.

You will find Unjha jeera, Salem turmeric and our 13-spice Royal Garam Masala under **Masalas & Spices** — delivered in under 30 minutes.`,
  },
  {
    id: 'immunity-foods-monsoon', slug: 'immunity-foods-monsoon', categoryId: 'healthy-living', img: 'blog:immunity', author: 'Dr. Ankit Shah', daysAgo: 14,
    title: '7 Everyday Foods That Support Your Immunity This Monsoon',
    excerpt: 'No miracle cures — just simple, evidence-backed foods that help your body stay resilient through the rainy season.',
    tags: ['immunity', 'monsoon', 'health', 'vitamin c'],
    content: `The monsoon brings relief from the heat, but also colds, coughs and stomach bugs. There is no single “immunity booster”, but a varied diet rich in a few key nutrients genuinely helps.

## 1. Citrus fruits
Oranges, sweet lime and amla are rich in vitamin C, which supports the normal function of immune cells. One amla has more vitamin C than two oranges.

## 2. Curd
Fresh dahi contains live cultures that support gut health — and a large part of the immune system lives in the gut.

## 3. Turmeric
Curcumin has anti-inflammatory properties. Pair turmeric with black pepper and a little fat (like haldi doodh) to improve absorption.

## 4. Garlic and ginger
Both have been used for centuries in Indian kitchens for colds. Add them generously to dals and soups.

## 5. Nuts and seeds
Almonds and sunflower seeds provide vitamin E; pumpkin seeds and cashews provide zinc.

## 6. Leafy greens
Spinach and methi bring folate, iron and vitamin A. Wash them thoroughly in the monsoon and always cook them.

## 7. Protein
Dal, paneer, eggs and chicken provide the amino acids your body needs to build antibodies.

## Simple monsoon habits

- Drink boiled or purified water, and carry your own bottle.
- Avoid cut fruit and street food that has been sitting out.
- Sleep 7–8 hours — sleep matters as much as diet.

> **Note:** Supplements such as vitamin C or zinc can help if your diet falls short, but they are not a substitute for food. Speak to your doctor before starting any supplement, especially if you are pregnant or on medication.

*Dr. Ankit Shah is the supervising pharmacist at MediPlus Pharmacy, Ahmedabad.*`,
  },
  {
    id: 'perfect-dum-biryani', slug: 'perfect-dum-biryani', categoryId: 'recipes', img: 'blog:biryani', author: 'Chef Imran Qureshi', daysAgo: 21,
    title: 'The Secrets Behind a Perfect Hyderabadi Dum Biryani',
    excerpt: 'Long grains, layered flavour and a sealed pot. Our head chef shares the techniques that make every grain count.',
    tags: ['biryani', 'recipe', 'hyderabadi', 'chicken'],
    content: `Biryani is our most-ordered dish, and the question we hear most is: *why does yours taste different from the one I make at home?* The answer is a handful of techniques, not a secret ingredient.

## 1. Choose aged basmati
Rice aged for at least a year has less moisture and elongates without breaking. Soak it for 30 minutes before cooking.

## 2. Marinate overnight
Chicken goes into thick curd, ginger-garlic paste, Kashmiri chilli, garam masala, fried onions, mint, coriander and lemon juice. Eight hours in the fridge lets the curd tenderise the meat.

## 3. Cook the rice to 70%
Boil the rice in heavily salted water with whole spices (bay leaf, cardamom, cloves, shahi jeera). Drain it when a grain breaks easily but still has a firm white core.

## 4. Layer generously
Raw marinated chicken at the bottom of a heavy pot, then rice, then saffron milk, ghee, fried onions and mint. Repeat once.

## 5. Seal and dum
Seal the lid with dough and cook on high for 5 minutes, then on the lowest flame over a tawa for 35–40 minutes. The steam cooks the chicken and perfumes every grain.

## 6. Rest before opening
Give it ten minutes off the heat. Open at the table — that first burst of aroma is half the experience.

## What to serve with it
Mirchi ka salan, a cool boondi raita and sliced onions with lemon. Finish with gulab jamun.

Do not have eight hours? Our **Hyderabadi Chicken Dum Biryani** is cooked fresh every two hours at Spice Route Kitchen — use code **BIRYANI20** for 20% off.`,
  },
  {
    id: 'work-from-home-setup', slug: 'work-from-home-setup', categoryId: 'lifestyle', img: 'blog:wfh-setup', author: 'Nisha Mehta', daysAgo: 30,
    title: 'A Productive Work-From-Home Setup Under ₹10,000',
    excerpt: 'Better audio, fewer cables and a desk that does not hurt your back — without spending a fortune.',
    tags: ['work from home', 'gadgets', 'headphones', 'productivity'],
    content: `Remote and hybrid work is here to stay, but many of us still work from the dining table with a laptop and a tangle of chargers. A few smart upgrades make a big difference.

## Audio first (₹1,800–₹5,000)
Clear calls matter more than anything else. **True wireless earbuds with ENC mics** handle quick calls; for long meetings, **over-ear ANC headphones** block the pressure cooker whistle and the neighbour’s drill.

## One charger for everything (₹2,000)
A **65 W GaN USB-C charger** powers a laptop, phone and earbuds from a single socket and fits in your pocket. Pair it with a couple of braided USB-C cables.

## Backup power (₹1,500)
Power cuts happen. A **20,000 mAh power bank** with 22.5 W output keeps your phone and earbuds going through the afternoon.

## Ergonomics on a budget
- Raise your laptop so the top of the screen is at eye level — a stack of books works.
- Use a separate keyboard and mouse to keep your wrists straight.
- Sit with your feet flat and knees at 90°. A cushion for your lower back helps.

## Look after yourself
Follow the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds. A **smartwatch** with stand reminders and hydration alerts quietly keeps you honest.

## Our picks
| Item | Approx. price |
|---|---|
| SoundWave Buds Air | ₹1,799 |
| Voltix 65 W GaN charger | ₹1,999 |
| Voltix 20,000 mAh power bank | ₹1,499 |
| PulseFit Active smartwatch | ₹2,799 |
| **Total** | **₹8,096** |

Everything above ships from UrbanTrend Lifestyle with a GST invoice and 7-day returns.`,
  },
  {
    id: 'summer-skincare-routine', slug: 'summer-skincare-routine', categoryId: 'lifestyle', img: 'blog:summer-skincare', author: 'Riya Desai', daysAgo: 45,
    title: 'A Simple 4-Step Summer Skincare Routine for Indian Weather',
    excerpt: 'Heat, humidity and strong UV call for a lighter routine. Here is a dermatologist-approved approach that takes five minutes.',
    tags: ['skincare', 'summer', 'sunscreen', 'beauty'],
    content: `Indian summers are hard on skin: sweat, oil, pollution and a UV index that regularly hits 10+. The answer is not more products — it is the right four.

## Morning

### 1. Cleanse gently
Use a mild gel cleanser with ingredients like neem or tea tree if you are oily. Avoid harsh scrubs; they strip the skin and make it produce more oil.

### 2. Vitamin C serum
A few drops of a stabilised 10% vitamin C serum help fight pollution damage and brighten dull skin. Let it absorb for a minute.

### 3. Light moisturiser
Even oily skin needs hydration. Choose a lightweight gel or a ceramide moisturiser that does not feel heavy.

### 4. Sunscreen — every single day
Use SPF 50 with PA++++ protection, two finger-lengths for face and neck, 15 minutes before stepping out. Reapply every 2–3 hours if you are outdoors. **This is the step that matters most.**

## Night
Cleanse to remove sunscreen and sweat, then moisturise. That is it.

## Summer skin tips
- Drink plenty of water and eat water-rich fruit like watermelon and cucumber.
- Blot, do not wash, your face during the day — over-washing causes irritation.
- Change your pillowcase twice a week.
- Patch-test every new product on your inner arm for 24 hours.

> If you have persistent acne, pigmentation or a skin condition, consult a dermatologist. Over-the-counter products are not a substitute for medical advice.

Find gentle cleansers, vitamin C serums and matte SPF 50 sunscreens in **Beauty → Skincare**.`,
  },
];

const P = (title, body) => ({ title, content: body.trim() });
export const pages = {
  about: P('About Go4Market', `
# About Go4Market

Go4Market is a multi-vendor marketplace from Gujarat that brings your neighbourhood’s best stores into one app — groceries, freshly cooked food, medicines, electronics, fashion and home essentials, delivered in as little as 15 minutes.

## What we believe
- **Local first.** Every order supports an independent store, kitchen or pharmacy near you.
- **Fast, but fair.** Quick delivery should never mean underpaid riders. Our delivery partners earn per order with transparent payouts.
- **Honest prices.** The price you see includes GST. Delivery fees are shown before you pay.

## How it works
1. Choose a module — Grocery, Food, Pharmacy or Shopping.
2. Add items from one or more stores to a single cart.
3. Pay online, with your wallet or cash on delivery.
4. Track your rider live until the doorbell rings.

## Contact
Go4Market, 3rd Floor, Shivalik Shilp, Iscon Cross Road, S.G. Highway, Ahmedabad, Gujarat 380015, India
Email: support@go4market.com · Phone: +91 79 4000 4000
`),
  terms: P('Terms of Service', `
# Terms of Service

_Last updated: October 2026_

These Terms govern your use of the Go4Market website and apps (the “Platform”) operated from Ahmedabad, Gujarat, India. By creating an account or placing an order you agree to them.

## 1. The marketplace
Go4Market is a marketplace. Products are sold by independent sellers (“Sellers”) listed on the Platform. Each Seller is responsible for the quality, legality and description of its products. Go4Market facilitates ordering, payment and delivery.

## 2. Accounts
You must be at least 18 years old, provide accurate information and keep your password confidential. You are responsible for activity on your account. We may suspend accounts that misuse the Platform.

## 3. Orders and pricing
An order is an offer to buy. It is accepted when the Seller confirms it. Prices include applicable taxes unless stated. We may cancel orders affected by pricing errors, stock issues or suspected fraud and will refund any amount paid.

## 4. Payments
Payments are processed by Razorpay, Stripe and PayPal. Go4Market does not store your card details. Wallet balances are non-transferable, cannot be withdrawn as cash and do not expire.

## 5. Delivery
Delivery estimates are indicative. Risk passes to you on delivery, confirmed by the OTP you share with the rider.

## 6. Medicines
Pharmacy products are sold by licensed pharmacies. Prescription medicines are dispensed only against a valid prescription verified by a registered pharmacist.

## 7. Returns and refunds
Returns are governed by our Refund Policy and Cancellation Policy.

## 8. Acceptable use
You may not misuse the Platform, scrape it, interfere with its security or post unlawful, abusive or misleading reviews.

## 9. Liability
To the extent permitted by law, Go4Market’s liability for any claim is limited to the value of the order concerned.

## 10. Governing law
These Terms are governed by the laws of India. Courts at Ahmedabad, Gujarat have exclusive jurisdiction.

Questions? Write to support@go4market.com.
`),
  privacy: P('Privacy Policy', `
# Privacy Policy

_Last updated: October 2026_

This policy explains what personal data Go4Market collects, why, and the choices you have. It is written to comply with India’s Digital Personal Data Protection Act, 2023.

## Data we collect
- **Account:** name, email, phone number and password (stored securely by Firebase Authentication).
- **Orders:** delivery addresses, items, payment status and order history.
- **Location:** your delivery location, and — for delivery partners — live location while online.
- **Device:** app version, device type and a notification token to send you order updates.

## How we use it
To process and deliver orders, provide support, prevent fraud, send transactional messages, and — only with your consent — send offers. We do not sell your personal data.

## Sharing
We share only what is needed: the store receives your order and name; the rider receives your name, phone and address for delivery; payment processors receive payment details. Card data is handled by Razorpay, Stripe or PayPal and never stored by us.

## Retention
We keep order records for as long as required by tax law (currently eight years). You may delete your account at any time; we then erase or anonymise data we are not required to keep.

## Your rights
You can access, correct or erase your data and withdraw consent for marketing in the app or by writing to privacy@go4market.com.

## Security
Data is encrypted in transit and at rest on Google Cloud infrastructure in India. Access is restricted by role.

## Contact
Grievance Officer, Go4Market, Ahmedabad, Gujarat, India · privacy@go4market.com
`),
  refund: P('Refund Policy', `
# Refund Policy

We want you to love every order. If something is not right, here is how refunds work.

## Eligible for return (within 7 days of delivery)
- Packaged grocery items that are damaged, expired or incorrect
- Electronics, fashion, beauty and home products in original condition with tags and packaging
- Health devices that are defective on arrival

## Not returnable
- Fresh fruits, vegetables, dairy and bakery items (report issues within 24 hours for a replacement or refund)
- Food from restaurants and kitchens (contact support within 2 hours for any issue)
- Opened medicines, supplements and personal-care items, unless defective
- Innerwear and items marked “non-returnable”

## How to request a return
Go to **My Orders → Select order → Return items**, choose the items and reason and upload a photo. The seller reviews the request within 24 hours.

## Refund timelines
| Payment method | Refund to | Time |
|---|---|---|
| Any method | Go4Market wallet | Within 24 hours of pick-up |
| Card / UPI (on request) | Original source | 5–7 business days |
| Cash on delivery | Go4Market wallet | Within 24 hours of pick-up |

Cancellation refunds are always instant to your wallet. For help, contact support@go4market.com.
`),
  shipping: P('Shipping & Delivery Policy', `
# Shipping & Delivery Policy

## Delivery speeds
| Speed | Available for | Typical time | Fee |
|---|---|---|---|
| Quick 15 | Grocery, Food, Pharmacy within 4 km | 15 minutes | ₹25 extra |
| Quick 30 | Grocery, Food, Pharmacy within 8 km | 30 minutes | ₹25 extra |
| Standard | All items | 30–60 min (local) / 1–3 days (shopping) | ₹30 + ₹6/km after 3 km |
| Scheduled | All items | Your chosen slot | Standard fee |
| Store pickup | All items | Ready in 15–30 min | Free |

## Free delivery
Orders above ₹499 get free standard delivery. Go4 Plus members get free delivery on every order.

## Service area
We currently deliver across Ahmedabad, Gandhinagar, Surat, Vadodara and Rajkot, with Mumbai, Pune and Bengaluru launching soon. Each store delivers within 25 km.

## Tracking
Follow your rider live on the map from pick-up to your door. Share the 4-digit OTP only when you receive your order.

## Failed deliveries
If we cannot reach you after two attempts the order may be cancelled. Prepaid amounts are refunded to your wallet, minus the delivery fee.
`),
  cancellation: P('Cancellation Policy', `
# Cancellation Policy

## Cancelling as a customer
You can cancel any order from **My Orders** until the store marks it **Packed**. After that, the order is on its way and cannot be cancelled — you may refuse delivery or request a return where eligible.

Food orders can be cancelled only until the kitchen confirms them, because preparation starts immediately.

## Refunds on cancellation
Any amount paid online or from your wallet is refunded to your Go4Market wallet instantly. Coupons used on a cancelled order are restored.

## Cancellations by the store or Go4Market
A store may cancel an order if an item is out of stock or the address is outside its delivery area. We may cancel orders that look fraudulent. You will always receive a full refund.

## Unpaid orders
Online orders not paid within 30 minutes are cancelled automatically and any reserved stock is released.
`),
  'seller-policy': P('Seller Policy', `
# Seller Policy

By selling on Go4Market you agree to:

1. **Sell genuine products** with accurate descriptions, images, prices and stock. Counterfeits lead to permanent suspension.
2. **Hold valid licences:** GSTIN for all sellers; FSSAI for food and grocery; drug licence for pharmacies.
3. **Confirm orders within 10 minutes** for quick-commerce modules and within 24 hours for shopping items.
4. **Pack safely** and hand orders to riders with the invoice.
5. **Honour returns** under the Refund Policy.
6. **Commission:** Go4Market charges the commission agreed at onboarding (6–15% by category) on each delivered order. Earnings are credited to your balance on delivery and can be withdrawn weekly.
7. **Customer data** may be used only to fulfil orders. Marketing to customers outside the Platform is not permitted.
8. **Ratings:** stores that stay below 3.5 stars for 30 days may be reviewed.

Violations may lead to warnings, withheld payouts or suspension.
`),
};

const shell = (title, inner) => `<!doctype html><html><body style="margin:0;background:#F7FAF8;font-family:'Plus Jakarta Sans',Segoe UI,Arial,sans-serif;color:#0F1A14">
<table width="100%" cellpadding="0" cellspacing="0" style="padding:24px 0"><tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background:#FFFFFF;border-radius:16px;overflow:hidden;border:1px solid #E3EBE6">
<tr><td style="background:#0A4A33;padding:20px 28px;font-size:22px;font-weight:800;color:#FFFFFF">Go<span style="color:#F7860F">4</span><span style="color:#5FD49A">Market</span></td></tr>
<tr><td style="padding:28px">
<h1 style="margin:0 0 12px;font-size:22px;color:#0A4A33">${title}</h1>
${inner}
</td></tr>
<tr><td style="background:#F7FAF8;padding:18px 28px;font-size:12px;color:#5B6B62">Need help? Reply to this email or write to {{supportEmail}}.<br/>Go4Market · Ahmedabad, Gujarat, India</td></tr>
</table></td></tr></table></body></html>`;
const btn = (href, label) => `<p style="margin:24px 0"><a href="${href}" style="background:#0B8A4F;color:#FFFFFF;text-decoration:none;padding:12px 22px;border-radius:12px;font-weight:700;display:inline-block">${label}</a></p>`;

export const emailTemplates = {
  order_placed: {
    subject: 'Order {{orderNo}} placed — thank you, {{name}}!',
    html: shell('Thanks for your order!', `<p style="margin:0 0 16px;color:#5B6B62">Hi {{name}}, we have received order <b>{{orderNo}}</b>. The store will confirm it shortly.</p>
<table width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #E3EBE6;border-bottom:1px solid #E3EBE6;margin:8px 0 12px">{{itemsHtml}}</table>
<p style="margin:4px 0"><b>Total:</b> ₹{{total}} &nbsp;·&nbsp; <b>To pay:</b> ₹{{payable}} ({{paymentMethod}})</p>
<p style="margin:4px 0;color:#5B6B62"><b>Deliver to:</b> {{address}}</p>${btn('{{orderUrl}}', 'Track your order')}`),
  },
  order_status: {
    subject: 'Order {{orderNo}}: {{status}}',
    html: shell('{{status}}', `<p style="margin:0 0 16px;color:#5B6B62">Hi {{name}}, {{message}}</p>${btn('{{orderUrl}}', 'View order')}`),
  },
  welcome: {
    subject: 'Welcome to Go4Market, {{name}}!',
    html: shell('Welcome to Go4Market', `<p style="margin:0 0 12px;color:#5B6B62">Hi {{name}}, your account is ready. Groceries in 15 minutes, hot meals, medicines and everything else — all in one app.</p>
<p style="margin:0 0 12px">Use code <b style="color:#F7860F">WELCOME50</b> for ₹50 off your first order above ₹299.</p>
<p style="margin:0 0 12px">Your referral code is <b>{{referralCode}}</b>. Share it — you and your friend each get ₹50 when their first order is delivered.</p>${btn('{{websiteUrl}}', 'Start shopping')}`),
  },
  otp: {
    subject: 'Your Go4Market verification code: {{otp}}',
    html: shell('Your verification code', `<p style="margin:0 0 12px;color:#5B6B62">Use this code to continue. It expires in 10 minutes.</p>
<p style="font-size:32px;letter-spacing:8px;font-weight:800;color:#0A4A33;margin:12px 0">{{otp}}</p>
<p style="color:#5B6B62;font-size:13px">If you did not request this, you can ignore this email.</p>`),
  },
  withdrawal: {
    subject: 'Withdrawal {{status}}: ₹{{amount}}',
    html: shell('Withdrawal {{status}}', `<p style="margin:0 0 12px;color:#5B6B62">Hi {{name}}, your withdrawal request of <b>₹{{amount}}</b> is now <b>{{status}}</b>.</p><p style="color:#5B6B62">{{note}}</p>`),
  },
};

export const adminRoles = [
  { id: 'super_admin', name: 'Super Admin', permissions: ['*'] },
  { id: 'catalog_manager', name: 'Catalog Manager', permissions: ['products', 'categories', 'brands', 'attributes', 'productRequests'] },
  { id: 'order_manager', name: 'Order Manager', permissions: ['orders', 'returns', 'deliveryPartners', 'cashCollections'] },
  { id: 'finance', name: 'Finance', permissions: ['walletTransactions', 'withdrawals', 'fundTransfers', 'reports'] },
  { id: 'marketing', name: 'Marketing', permissions: ['sliders', 'offers', 'featuredSections', 'coupons', 'popups', 'campaigns', 'blogs', 'faqs', 'pages'] },
  { id: 'support', name: 'Support', permissions: ['orders.read', 'users.read', 'returns'] },
];

export const globalAttributes = [
  { id: 'size', name: 'Size', values: ['XS', 'S', 'M', 'L', 'XL', 'XXL'] },
  { id: 'color', name: 'Color', values: ['Black', 'White', 'Navy', 'Red', 'Green', 'Blue', 'Grey', 'Beige', 'Tan'] },
  { id: 'weight', name: 'Weight', values: ['100 g', '200 g', '250 g', '500 g', '1 kg', '2 kg', '5 kg'] },
  { id: 'spice-level', name: 'Spice', values: ['Mild', 'Medium', 'Medium-hot', 'Hot'] },
  { id: 'allergens', name: 'Allergens', values: ['Dairy', 'Nuts', 'Gluten', 'Soy', 'Egg'] },
];

// Food add-ons (custom dish modifiers) by product id.
export const foodAddons = {
  'butter-chicken': [['extra-gravy', 'Extra gravy', 49], ['butter-naan-2', '2 Butter naan', 99], ['jeera-rice', 'Jeera rice', 99]],
  'paneer-butter-masala': [['extra-paneer', 'Extra paneer', 69], ['butter-naan-2', '2 Butter naan', 99]],
  'chicken-biryani': [['extra-raita', 'Extra raita', 29], ['salan', 'Mirchi ka salan', 39], ['egg', 'Boiled egg', 25]],
  'veg-biryani': [['extra-raita', 'Extra raita', 29], ['salan', 'Mirchi ka salan', 39]],
  'margherita-pizza': [['extra-cheese', 'Extra cheese', 59], ['jalapenos', 'Jalapeños', 39], ['olives', 'Black olives', 39], ['garlic-dip', 'Garlic dip', 25]],
  'farmhouse-pizza': [['extra-cheese', 'Extra cheese', 59], ['paneer-topping', 'Paneer topping', 69]],
  'chicken-burger': [['cheese-slice', 'Cheese slice', 25], ['fries', 'Peri-peri fries', 79]],
  'veg-burger': [['cheese-slice', 'Cheese slice', 25], ['fries', 'Peri-peri fries', 79]],
  'masala-dosa': [['butter', 'Butter', 20], ['cheese', 'Cheese', 40]],
  'cold-coffee': [['ice-cream', 'Extra scoop of ice cream', 40], ['hazelnut', 'Hazelnut shot', 30]],
};
