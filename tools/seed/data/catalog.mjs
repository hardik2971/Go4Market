// Go4Market seed catalog: modules, categories (nested), brands, sellers and products.
// Every entity has a stable id so the seed is idempotent. `img` is the image key resolved
// through data/images.json (key -> verified images.unsplash.com photo URL).

export const modules = [
  { id: 'grocery', name: 'Grocery', tagline: 'Daily essentials in minutes', icon: 'shopping_basket', themeColor: '#0B8A4F', order: 1 },
  { id: 'food', name: 'Food', tagline: 'Hot meals from local kitchens', icon: 'restaurant', themeColor: '#F7860F', order: 2 },
  { id: 'pharmacy', name: 'Pharmacy', tagline: 'Medicines & wellness, delivered', icon: 'local_pharmacy', themeColor: '#0E9F9A', order: 3 },
  { id: 'ecommerce', name: 'Shopping', tagline: 'Electronics, fashion & home', icon: 'shopping_bag', themeColor: '#2563EB', order: 4 },
];

// [id, name, children?] — tree per module. Image key for a category is `cat:<id>`.
export const categoryTree = {
  grocery: [
    ['fruits-vegetables', 'Fruits & Vegetables', [
      ['fresh-fruits', 'Fresh Fruits'],
      ['fresh-vegetables', 'Fresh Vegetables'],
      ['leafy-herbs', 'Leafy Greens & Herbs'],
    ]],
    ['dairy-bakery', 'Dairy, Bread & Eggs', [
      ['milk-curd', 'Milk & Curd'],
      ['paneer-cheese-butter', 'Paneer, Cheese & Butter'],
      ['breads-eggs', 'Breads & Eggs'],
    ]],
    ['staples', 'Atta, Rice, Oil & Dals', [
      ['rice-grains', 'Rice & Grains'],
      ['atta-flours', 'Atta & Flours'],
      ['dals-pulses', 'Dals & Pulses'],
      ['oils-ghee', 'Oils & Ghee'],
      ['masalas-spices', 'Masalas & Spices', [
        ['whole-spices', 'Whole Spices'],
        ['ground-spices', 'Powdered Masalas'],
      ]],
    ]],
    ['snacks-beverages', 'Snacks & Beverages', [
      ['tea-coffee', 'Tea & Coffee'],
      ['biscuits-cookies', 'Biscuits & Cookies'],
      ['chips-namkeen', 'Chips & Namkeen'],
      ['juices-drinks', 'Juices & Drinks'],
      ['dry-fruits', 'Dry Fruits & Nuts'],
    ]],
  ],
  food: [
    ['north-indian', 'North Indian', [
      ['curries', 'Curries & Gravies'],
      ['biryani-rice', 'Biryani & Rice'],
      ['indian-breads', 'Rotis & Naans'],
    ]],
    ['south-indian', 'South Indian', [
      ['dosa-idli', 'Dosa, Idli & Vada'],
    ]],
    ['pizza-burgers', 'Pizzas & Burgers', [
      ['pizzas', 'Pizzas'],
      ['burgers-wraps', 'Burgers & Wraps'],
    ]],
    ['chinese', 'Chinese', [
      ['noodles-rice', 'Noodles & Fried Rice'],
      ['momos-starters', 'Momos & Starters'],
    ]],
    ['desserts-beverages', 'Desserts & Beverages', [
      ['desserts', 'Desserts'],
      ['shakes-coffee', 'Shakes & Cold Coffee'],
    ]],
  ],
  pharmacy: [
    ['medicines', 'Medicines', [
      ['pain-relief', 'Pain Relief'],
      ['cold-cough', 'Cold & Cough'],
      ['digestive-care', 'Digestive Care'],
    ]],
    ['vitamins-supplements', 'Vitamins & Supplements', [
      ['multivitamins', 'Multivitamins'],
      ['protein-fitness', 'Protein & Fitness'],
    ]],
    ['personal-health', 'Personal Care', [
      ['oral-care', 'Oral Care'],
      ['derma-care', 'Skin & Derma Care'],
    ]],
    ['health-devices', 'Health Devices', [
      ['monitoring-devices', 'BP & Glucose Monitors'],
      ['first-aid', 'First Aid'],
    ]],
    ['baby-care', 'Baby Care'],
  ],
  ecommerce: [
    ['electronics', 'Electronics', [
      ['mobiles-accessories', 'Mobiles & Accessories', [
        ['smartphones', 'Smartphones'],
        ['chargers-powerbanks', 'Chargers & Power Banks'],
      ]],
      ['audio', 'Audio', [
        ['headphones-earbuds', 'Headphones & Earbuds'],
        ['bluetooth-speakers', 'Bluetooth Speakers'],
      ]],
      ['wearables', 'Smartwatches & Wearables'],
      ['laptops-tablets', 'Laptops & Tablets'],
    ]],
    ['fashion', 'Fashion', [
      ['men-fashion', 'Men', [
        ['men-tshirts', 'T-Shirts & Shirts'],
        ['men-footwear', 'Footwear'],
      ]],
      ['women-fashion', 'Women', [
        ['women-kurtas', 'Kurtas & Ethnic Wear'],
        ['women-handbags', 'Handbags'],
      ]],
      ['fashion-accessories', 'Accessories', [
        ['sunglasses', 'Sunglasses'],
        ['watches', 'Watches'],
      ]],
    ]],
    ['home-kitchen', 'Home & Kitchen', [
      ['cookware', 'Cookware'],
      ['kitchen-appliances', 'Kitchen Appliances'],
      ['home-decor', 'Home Decor'],
    ]],
    ['beauty', 'Beauty', [
      ['skincare', 'Skincare'],
      ['fragrances', 'Fragrances'],
    ]],
  ],
};

export const brands = [
  ['farmfresh', 'FarmFresh'], ['desi-dairy', 'Desi Dairy'], ['kisan-gold', 'Kisan Gold'], ['golden-harvest', 'Golden Harvest'],
  ['masala-mantra', 'Masala Mantra'], ['chai-bagan', 'Chai Bagan'], ['crunchy-co', 'Crunchy Co.'], ['nutri-nest', 'NutriNest'],
  ['bake-house', 'The Bake House'], ['spice-route', 'Spice Route Kitchen'], ['medicura', 'MediCura'], ['vitalife', 'VitaLife'],
  ['dentacare', 'DentaCare'], ['healthtrack', 'HealthTrack'], ['tiny-tots', 'Tiny Tots'], ['voltix', 'Voltix'],
  ['soundwave', 'SoundWave'], ['pulsefit', 'PulseFit'], ['urbantrend', 'UrbanTrend'], ['stridex', 'StrideX'],
  ['kalaa', 'Kalaa'], ['luxe-leather', 'Luxe Leather'], ['sunray', 'SunRay Optics'], ['chefpro', 'ChefPro'],
  ['nestaura', 'Nestaura'], ['glow-botanica', 'Glow Botanica'], ['aroma-house', 'Aroma House'],
].map(([id, name]) => ({ id, name }));

// Sellers (uid = doc id). The first one is the demo seller account.
export const sellers = [
  {
    uid: 'demo-seller', email: 'seller@go4market.com', storeName: 'Go4 Fresh Mart', slug: 'go4-fresh-mart', ownerName: 'Rakesh Patel',
    phone: '+919825011111', city: 'Ahmedabad', address: 'Shop 4, Shivalik Plaza, IIM Road, Ambawadi, Ahmedabad, Gujarat 380015',
    lat: 23.0300, lng: 72.5290, commissionPct: 8, gstin: '24AABCG1234F1Z5',
    description: 'Neighbourhood supermarket for farm-fresh produce, dairy, staples and household essentials — packed fresh every morning and delivered in under 30 minutes across Ahmedabad.',
    modules: ['grocery'], extraRoots: ['home-kitchen'],
  },
  {
    uid: 'seller-urbantrend', email: 'urbantrend@go4market.com', storeName: 'UrbanTrend Lifestyle', slug: 'urbantrend-lifestyle', ownerName: 'Nisha Mehta',
    phone: '+919825022222', city: 'Surat', address: '2nd Floor, Rahul Raj Mall, Piplod, Surat, Gujarat 395007',
    lat: 21.1600, lng: 72.7800, commissionPct: 12, gstin: '24AAECU5678K1Z2',
    description: 'Curated electronics, fashion and beauty from trusted labels. Genuine products, GST invoice on every order and easy 7-day returns.',
    modules: ['ecommerce'], excludeRoots: ['home-kitchen'],
  },
  {
    uid: 'seller-mediplus', email: 'mediplus@go4market.com', storeName: 'MediPlus Pharmacy', slug: 'mediplus-pharmacy', ownerName: 'Dr. Ankit Shah',
    phone: '+919825033333', city: 'Ahmedabad', address: 'Ground Floor, Satyam Complex, CG Road, Navrangpura, Ahmedabad, Gujarat 380009',
    lat: 23.0350, lng: 72.5610, commissionPct: 6, gstin: '24AAFCM9012L1Z8',
    description: 'Licensed pharmacy (DL No. GJ-AHM-20B-114) with a registered pharmacist on every shift. OTC medicines, supplements, devices and baby care.',
    modules: ['pharmacy'],
  },
  {
    uid: 'seller-spiceroute', email: 'spiceroute@go4market.com', storeName: 'Spice Route Kitchen', slug: 'spice-route-kitchen', ownerName: 'Imran Qureshi',
    phone: '+919825044444', city: 'Ahmedabad', address: '12, Law Garden Road, Ellisbridge, Ahmedabad, Gujarat 380006',
    lat: 23.0260, lng: 72.5560, commissionPct: 15, gstin: '24AAKFS3456M1Z1',
    description: 'Cloud kitchen serving slow-cooked North Indian curries, dum biryanis, crisp dosas, wood-fired pizzas and Indo-Chinese favourites — cooked to order.',
    modules: ['food'],
  },
];

// Product rows: [id, categoryId, name, brandId, price, mrp, unit, stock, shortDescription, extras]
// extras: v = variants [[name, price, mrp, stock]], veg, cf = customFields, tags, featured, mins = deliveryMinutes, sold, rating, rc
export const products = [
  // ───────── GROCERY: fruits & vegetables
  ['shimla-apples', 'fresh-fruits', 'Shimla Apples', 'farmfresh', 189, 220, '1 kg', 60, 'Crisp, juicy red apples hand-picked from Himachal orchards.', { v: [['500 g', 99, 115, 40], ['1 kg', 189, 220, 60]], veg: true, cf: { Origin: 'Himachal Pradesh', Storage: 'Refrigerate for up to 2 weeks' }, featured: true, sold: 420, rating: 4.5, rc: 86 }],
  ['robusta-bananas', 'fresh-fruits', 'Robusta Bananas', 'farmfresh', 49, 60, '6 pcs', 120, 'Naturally ripened, sweet bananas — perfect for breakfast and smoothies.', { v: [['6 pcs', 49, 60, 120], ['12 pcs', 92, 120, 80]], veg: true, cf: { Origin: 'Anand, Gujarat', Ripeness: 'Ready to eat' }, sold: 910, rating: 4.4, rc: 132 }],
  ['alphonso-mangoes', 'fresh-fruits', 'Alphonso Mangoes (Hapus)', 'farmfresh', 699, 850, '1 dozen', 4, 'GI-tagged Ratnagiri Alphonso with rich aroma and saffron pulp.', { veg: true, cf: { Origin: 'Ratnagiri, Maharashtra', Season: 'April – June' }, featured: true, sold: 210, rating: 4.8, rc: 64 }],
  ['nagpur-oranges', 'fresh-fruits', 'Nagpur Oranges', 'farmfresh', 89, 110, '1 kg', 70, 'Tangy-sweet, easy-peel oranges loaded with Vitamin C.', { veg: true, cf: { Origin: 'Nagpur, Maharashtra' }, sold: 260, rating: 4.3, rc: 41 }],
  ['green-grapes', 'fresh-fruits', 'Seedless Green Grapes', 'farmfresh', 79, 99, '500 g', 45, 'Plump, seedless Nashik grapes washed and packed in a vented box.', { veg: true, cf: { Origin: 'Nashik, Maharashtra' }, sold: 180, rating: 4.2, rc: 29 }],
  ['pomegranate', 'fresh-fruits', 'Bhagwa Pomegranate', 'farmfresh', 159, 190, '1 kg', 35, 'Deep-red arils, sweet and juicy — great for juices and salads.', { veg: true, cf: { Origin: 'Solapur, Maharashtra' }, sold: 150, rating: 4.4, rc: 37 }],
  ['tomatoes', 'fresh-vegetables', 'Hybrid Tomatoes', 'farmfresh', 34, 45, '1 kg', 150, 'Firm, ripe red tomatoes for curries, salads and chutneys.', { v: [['500 g', 18, 24, 100], ['1 kg', 34, 45, 150]], veg: true, cf: { Origin: 'Kheda, Gujarat' }, featured: true, sold: 1300, rating: 4.3, rc: 210 }],
  ['onions', 'fresh-vegetables', 'Red Onions', 'farmfresh', 39, 50, '1 kg', 200, 'Pungent Nashik red onions, a kitchen staple for every Indian meal.', { v: [['1 kg', 39, 50, 200], ['2 kg', 74, 100, 90]], veg: true, cf: { Origin: 'Nashik, Maharashtra' }, sold: 1500, rating: 4.4, rc: 240 }],
  ['potatoes', 'fresh-vegetables', 'Potatoes', 'farmfresh', 32, 40, '1 kg', 180, 'Versatile, starchy potatoes for sabzi, fries and parathas.', { veg: true, cf: { Origin: 'Deesa, Gujarat' }, sold: 1400, rating: 4.3, rc: 198 }],
  ['carrots', 'fresh-vegetables', 'Orange Carrots', 'farmfresh', 45, 55, '500 g', 80, 'Sweet, crunchy carrots — ideal for halwa, salads and juices.', { veg: true, sold: 340, rating: 4.2, rc: 52 }],
  ['capsicum', 'fresh-vegetables', 'Green Capsicum', 'farmfresh', 29, 38, '250 g', 3, 'Glossy, thick-walled bell peppers for stir-fries and pizzas.', { veg: true, sold: 220, rating: 4.1, rc: 33 }],
  ['broccoli', 'fresh-vegetables', 'Broccoli', 'farmfresh', 69, 85, '1 pc (~300 g)', 25, 'Tight green florets, rich in fibre and antioxidants.', { veg: true, sold: 120, rating: 4.3, rc: 18 }],
  ['spinach', 'leafy-herbs', 'Palak (Spinach)', 'farmfresh', 25, 30, '1 bunch', 60, 'Tender spinach leaves, cleaned and bundled the same morning.', { veg: true, sold: 480, rating: 4.2, rc: 71 }],
  ['coriander', 'leafy-herbs', 'Coriander Leaves', 'farmfresh', 15, 20, '100 g', 90, 'Fragrant dhaniya for garnishing curries and chaats.', { veg: true, sold: 900, rating: 4.4, rc: 120 }],
  ['mint', 'leafy-herbs', 'Mint Leaves (Pudina)', 'farmfresh', 15, 20, '100 g', 0, 'Cool, aromatic mint for chutneys, raita and mojitos.', { veg: true, sold: 330, rating: 4.3, rc: 44 }],
  // dairy & bakery
  ['toned-milk', 'milk-curd', 'Toned Milk', 'desi-dairy', 29, 29, '500 ml', 200, 'Pasteurised toned milk with 3% fat, sourced from local co-operatives.', { v: [['500 ml', 29, 29, 200], ['1 L', 56, 56, 150]], veg: true, cf: { Fat: '3.0%', Shelf_life: '2 days refrigerated' }, featured: true, sold: 2400, rating: 4.6, rc: 380 }],
  ['dahi', 'milk-curd', 'Fresh Dahi (Curd)', 'desi-dairy', 45, 50, '400 g', 90, 'Thick, creamy set curd made from pasteurised milk.', { veg: true, cf: { Shelf_life: '5 days refrigerated' }, sold: 860, rating: 4.5, rc: 140 }],
  ['malai-paneer', 'paneer-cheese-butter', 'Malai Paneer', 'desi-dairy', 95, 110, '200 g', 70, 'Soft, fresh paneer that stays tender in tikka and curries.', { veg: true, cf: { Protein: '18 g per 100 g' }, sold: 700, rating: 4.6, rc: 115 }],
  ['salted-butter', 'paneer-cheese-butter', 'Salted Butter', 'desi-dairy', 58, 60, '100 g', 110, 'Creamy salted butter, churned from fresh cream.', { v: [['100 g', 58, 60, 110], ['500 g', 275, 285, 40]], veg: true, sold: 650, rating: 4.7, rc: 98 }],
  ['cheese-slices', 'paneer-cheese-butter', 'Cheddar Cheese Slices', 'desi-dairy', 140, 160, '200 g (10 slices)', 2, 'Melt-in-the-mouth processed cheddar slices for sandwiches and burgers.', { veg: true, sold: 260, rating: 4.4, rc: 46 }],
  ['brown-bread', 'breads-eggs', 'Whole Wheat Brown Bread', 'bake-house', 50, 55, '400 g', 40, 'Soft whole-wheat loaf baked fresh daily, no maida.', { veg: true, cf: { Shelf_life: '4 days' }, sold: 540, rating: 4.3, rc: 77 }],
  ['farm-eggs', 'breads-eggs', 'Farm Fresh Brown Eggs', 'farmfresh', 96, 110, '12 pcs', 60, 'Protein-rich brown eggs from free-range hens.', { v: [['6 pcs', 52, 60, 50], ['12 pcs', 96, 110, 60]], veg: false, sold: 610, rating: 4.5, rc: 92 }],
  ['multigrain-pav', 'breads-eggs', 'Multigrain Ladi Pav', 'bake-house', 35, 40, '6 pcs', 30, 'Pillowy multigrain pav, perfect for pav bhaji and vada pav.', { veg: true, sold: 300, rating: 4.2, rc: 39 }],
  // staples
  ['basmati-rice', 'rice-grains', 'Classic Basmati Rice', 'kisan-gold', 549, 699, '5 kg', 50, 'Aged long-grain basmati that cooks fluffy and fragrant.', { v: [['1 kg', 129, 160, 80], ['5 kg', 549, 699, 50]], veg: true, cf: { Grain: 'Extra long', Aged: '12 months' }, featured: true, sold: 520, rating: 4.6, rc: 133 }],
  ['sona-masoori', 'rice-grains', 'Sona Masoori Rice', 'kisan-gold', 329, 380, '5 kg', 40, 'Light, aromatic everyday rice for South Indian meals.', { veg: true, sold: 260, rating: 4.4, rc: 51 }],
  ['rolled-oats', 'rice-grains', 'Rolled Oats', 'kisan-gold', 175, 199, '1 kg', 45, 'Wholegrain oats high in fibre — a hearty, quick breakfast.', { veg: true, sold: 210, rating: 4.3, rc: 40 }],
  ['chakki-atta', 'atta-flours', 'Chakki Fresh Whole Wheat Atta', 'kisan-gold', 249, 295, '5 kg', 70, 'Stone-ground MP Sharbati wheat for soft, fluffy rotis.', { v: [['5 kg', 249, 295, 70], ['10 kg', 475, 580, 30]], veg: true, featured: true, sold: 880, rating: 4.6, rc: 190 }],
  ['besan', 'atta-flours', 'Besan (Gram Flour)', 'kisan-gold', 89, 105, '1 kg', 60, 'Finely milled chana dal flour for pakoras, dhokla and laddoos.', { veg: true, sold: 300, rating: 4.4, rc: 55 }],
  ['toor-dal', 'dals-pulses', 'Unpolished Toor Dal', 'kisan-gold', 179, 210, '1 kg', 80, 'Protein-rich arhar dal, unpolished for natural taste.', { veg: true, sold: 760, rating: 4.5, rc: 140 }],
  ['moong-dal', 'dals-pulses', 'Yellow Moong Dal', 'kisan-gold', 149, 175, '1 kg', 70, 'Quick-cooking split moong, light on the stomach.', { veg: true, sold: 420, rating: 4.4, rc: 66 }],
  ['kabuli-chana', 'dals-pulses', 'Kabuli Chana', 'kisan-gold', 139, 160, '1 kg', 5, 'Bold white chickpeas for chole and salads.', { veg: true, sold: 290, rating: 4.3, rc: 48 }],
  ['groundnut-oil', 'oils-ghee', 'Filtered Groundnut Oil', 'golden-harvest', 199, 235, '1 L', 60, 'Cold-filtered groundnut oil with a nutty Gujarati taste.', { v: [['1 L', 199, 235, 60], ['5 L', 960, 1150, 20]], veg: true, sold: 560, rating: 4.5, rc: 101 }],
  ['cow-ghee', 'oils-ghee', 'Pure Cow Ghee', 'desi-dairy', 315, 349, '500 ml', 40, 'Granular, aromatic ghee slow-cooked from cultured cream.', { v: [['500 ml', 315, 349, 40], ['1 L', 615, 680, 25]], veg: true, featured: true, sold: 480, rating: 4.7, rc: 122 }],
  ['mustard-oil', 'oils-ghee', 'Kachi Ghani Mustard Oil', 'golden-harvest', 179, 199, '1 L', 50, 'Pungent cold-pressed mustard oil for pickles and tadkas.', { veg: true, sold: 210, rating: 4.4, rc: 35 }],
  ['jeera', 'whole-spices', 'Jeera (Cumin Seeds)', 'masala-mantra', 89, 110, '200 g', 70, 'Bold, aromatic cumin from Unjha — the heart of every tadka.', { veg: true, cf: { Origin: 'Unjha, Gujarat' }, sold: 430, rating: 4.6, rc: 80 }],
  ['black-pepper', 'whole-spices', 'Black Peppercorns', 'masala-mantra', 129, 150, '100 g', 40, 'Bold Malabar peppercorns with a sharp, warm heat.', { veg: true, cf: { Origin: 'Wayanad, Kerala' }, sold: 180, rating: 4.5, rc: 28 }],
  ['cinnamon', 'whole-spices', 'Cinnamon Sticks', 'masala-mantra', 75, 90, '50 g', 35, 'Sweet, woody cinnamon quills for biryani and chai.', { veg: true, sold: 150, rating: 4.4, rc: 21 }],
  ['turmeric', 'ground-spices', 'Haldi (Turmeric Powder)', 'masala-mantra', 55, 65, '200 g', 90, 'High-curcumin Salem turmeric with a vibrant golden colour.', { veg: true, cf: { Curcumin: '3.5%+' }, sold: 690, rating: 4.6, rc: 104 }],
  ['red-chilli', 'ground-spices', 'Kashmiri Red Chilli Powder', 'masala-mantra', 95, 115, '200 g', 70, 'Brilliant red colour with mild heat — perfect for tandoori dishes.', { veg: true, sold: 520, rating: 4.5, rc: 88 }],
  ['garam-masala', 'ground-spices', 'Royal Garam Masala', 'masala-mantra', 85, 99, '100 g', 60, 'A 13-spice blend roasted in small batches for depth and warmth.', { veg: true, sold: 400, rating: 4.7, rc: 77 }],
  // snacks & beverages
  ['assam-tea', 'tea-coffee', 'Assam CTC Tea', 'chai-bagan', 265, 310, '500 g', 80, 'Strong, malty CTC tea for the perfect kadak masala chai.', { v: [['250 g', 140, 160, 60], ['500 g', 265, 310, 80]], veg: true, featured: true, sold: 760, rating: 4.6, rc: 156 }],
  ['green-tea', 'tea-coffee', 'Darjeeling Green Tea', 'chai-bagan', 199, 249, '25 bags', 50, 'Delicate first-flush green tea, rich in antioxidants.', { veg: true, sold: 180, rating: 4.3, rc: 30 }],
  ['filter-coffee', 'tea-coffee', 'South Indian Filter Coffee', 'chai-bagan', 230, 260, '250 g', 40, 'Coffee-chicory blend (80:20) roasted in Chikmagalur.', { veg: true, sold: 260, rating: 4.6, rc: 58 }],
  ['butter-cookies', 'biscuits-cookies', 'Danish Butter Cookies', 'bake-house', 149, 175, '300 g', 50, 'Golden, buttery cookies baked with real butter.', { veg: true, sold: 240, rating: 4.4, rc: 40 }],
  ['digestive-biscuits', 'biscuits-cookies', 'Wheat Digestive Biscuits', 'bake-house', 60, 70, '250 g', 90, 'High-fibre wheat biscuits for guilt-free tea time.', { veg: true, sold: 420, rating: 4.3, rc: 61 }],
  ['potato-chips', 'chips-namkeen', 'Classic Salted Potato Chips', 'crunchy-co', 50, 50, '150 g', 120, 'Thin-cut, kettle-cooked chips with just the right salt.', { veg: true, sold: 900, rating: 4.3, rc: 130 }],
  ['bhujia', 'chips-namkeen', 'Bikaneri Bhujia', 'crunchy-co', 99, 115, '400 g', 70, 'Crisp moth-bean sev spiced the traditional Bikaner way.', { veg: true, sold: 510, rating: 4.5, rc: 84 }],
  ['orange-juice', 'juices-drinks', '100% Orange Juice', 'farmfresh', 125, 140, '1 L', 40, 'No added sugar, not-from-concentrate orange juice.', { veg: true, sold: 210, rating: 4.2, rc: 34 }],
  ['coconut-water', 'juices-drinks', 'Tender Coconut Water', 'farmfresh', 60, 70, '1 pc', 30, 'Naturally sweet tender coconut, full of electrolytes.', { veg: true, sold: 340, rating: 4.4, rc: 46 }],
  ['almonds', 'dry-fruits', 'California Almonds', 'nutri-nest', 449, 560, '500 g', 40, 'Crunchy, premium-grade almonds — rich in Vitamin E.', { v: [['250 g', 235, 290, 30], ['500 g', 449, 560, 40]], veg: true, featured: true, sold: 380, rating: 4.6, rc: 90 }],
  ['cashews', 'dry-fruits', 'Whole Cashews W320', 'nutri-nest', 525, 640, '500 g', 35, 'Creamy, whole W320 cashews from Goa.', { veg: true, sold: 290, rating: 4.6, rc: 66 }],
  ['raisins', 'dry-fruits', 'Golden Raisins', 'nutri-nest', 159, 190, '250 g', 4, 'Seedless golden raisins for kheer, halwa and snacking.', { veg: true, sold: 160, rating: 4.3, rc: 24 }],

  // ───────── FOOD (Spice Route Kitchen)
  ['butter-chicken', 'curries', 'Butter Chicken', 'spice-route', 349, 399, 'Serves 1–2', 50, 'Tandoori chicken simmered in a velvety tomato-butter-cream gravy.', { v: [['Half', 249, 289, 50], ['Full', 349, 399, 50]], veg: false, cf: { Spice: 'Mild', Allergens: 'Dairy, Nuts' }, featured: true, mins: 35, sold: 820, rating: 4.7, rc: 260 }],
  ['paneer-butter-masala', 'curries', 'Paneer Butter Masala', 'spice-route', 289, 329, 'Serves 1–2', 50, 'Soft paneer cubes in a rich, mildly sweet makhani gravy.', { v: [['Half', 199, 229, 50], ['Full', 289, 329, 50]], veg: true, cf: { Spice: 'Mild', Allergens: 'Dairy, Nuts' }, featured: true, mins: 30, sold: 760, rating: 4.6, rc: 230 }],
  ['dal-makhani', 'curries', 'Dal Makhani', 'spice-route', 239, 269, 'Serves 2', 50, 'Black lentils slow-cooked overnight with butter and cream.', { veg: true, cf: { Spice: 'Mild', Allergens: 'Dairy' }, mins: 30, sold: 640, rating: 4.6, rc: 180 }],
  ['chole', 'curries', 'Amritsari Chole', 'spice-route', 219, 249, 'Serves 2', 50, 'Tangy, dark chickpea curry with whole spices and tea-brewed depth.', { veg: true, cf: { Spice: 'Medium' }, mins: 30, sold: 380, rating: 4.4, rc: 92 }],
  ['chicken-biryani', 'biryani-rice', 'Hyderabadi Chicken Dum Biryani', 'spice-route', 329, 379, 'Serves 1', 50, 'Saffron basmati layered with marinated chicken and sealed on dum.', { v: [['Regular', 329, 379, 50], ['Family pack (serves 3)', 849, 949, 20]], veg: false, cf: { Spice: 'Medium-hot', Served_with: 'Raita & salan' }, featured: true, mins: 40, sold: 1120, rating: 4.8, rc: 410 }],
  ['veg-biryani', 'biryani-rice', 'Subz Dum Biryani', 'spice-route', 259, 299, 'Serves 1', 50, 'Seasonal vegetables and fragrant rice cooked on dum with mint and fried onions.', { veg: true, cf: { Spice: 'Medium', Served_with: 'Raita' }, mins: 35, sold: 450, rating: 4.4, rc: 120 }],
  ['jeera-rice', 'biryani-rice', 'Jeera Rice', 'spice-route', 159, 179, 'Serves 1', 50, 'Basmati tempered with cumin and ghee — pairs with any curry.', { veg: true, mins: 25, sold: 300, rating: 4.3, rc: 60 }],
  ['butter-naan', 'indian-breads', 'Butter Naan', 'spice-route', 59, 69, '1 pc', 100, 'Tandoor-baked leavened bread brushed with butter.', { v: [['Plain', 49, 59, 100], ['Butter', 59, 69, 100], ['Garlic', 69, 79, 100]], veg: true, cf: { Allergens: 'Gluten, Dairy' }, mins: 25, sold: 1500, rating: 4.5, rc: 300 }],
  ['tandoori-roti', 'indian-breads', 'Tandoori Roti', 'spice-route', 29, 35, '1 pc', 100, 'Whole-wheat roti baked in the clay oven.', { veg: true, mins: 20, sold: 1300, rating: 4.4, rc: 210 }],
  ['masala-dosa', 'dosa-idli', 'Mysore Masala Dosa', 'spice-route', 169, 189, '1 plate', 50, 'Crisp dosa with red chutney spread, potato masala, sambar and chutneys.', { veg: true, cf: { Spice: 'Medium', Served_with: 'Sambar & 2 chutneys' }, featured: true, mins: 25, sold: 690, rating: 4.6, rc: 190 }],
  ['idli-sambar', 'dosa-idli', 'Idli Sambar', 'spice-route', 99, 119, '3 pcs', 50, 'Steamed rice cakes, soft as clouds, with hot sambar and coconut chutney.', { veg: true, mins: 20, sold: 420, rating: 4.4, rc: 110 }],
  ['medu-vada', 'dosa-idli', 'Medu Vada', 'spice-route', 109, 129, '2 pcs', 50, 'Crisp urad-dal doughnuts with sambar and chutney.', { veg: true, mins: 20, sold: 260, rating: 4.3, rc: 70 }],
  ['margherita-pizza', 'pizzas', 'Margherita Pizza', 'spice-route', 299, 349, '10 inch', 50, 'San Marzano tomato sauce, fresh mozzarella and basil on a wood-fired crust.', { v: [['7 inch', 199, 229, 50], ['10 inch', 299, 349, 50], ['12 inch', 399, 449, 30]], veg: true, cf: { Allergens: 'Gluten, Dairy' }, featured: true, mins: 30, sold: 580, rating: 4.5, rc: 150 }],
  ['farmhouse-pizza', 'pizzas', 'Farmhouse Veggie Pizza', 'spice-route', 349, 399, '10 inch', 50, 'Loaded with capsicum, onion, mushroom, sweet corn and olives.', { v: [['7 inch', 229, 259, 50], ['10 inch', 349, 399, 50]], veg: true, mins: 30, sold: 330, rating: 4.4, rc: 88 }],
  ['chicken-burger', 'burgers-wraps', 'Crispy Chicken Burger', 'spice-route', 199, 229, '1 pc', 50, 'Buttermilk-fried chicken, slaw and chipotle mayo in a toasted brioche bun.', { veg: false, mins: 25, sold: 470, rating: 4.4, rc: 120 }],
  ['veg-burger', 'burgers-wraps', 'Aloo Tikki Burger', 'spice-route', 129, 149, '1 pc', 50, 'Spiced potato patty with mint mayo, onions and tomato.', { veg: true, mins: 20, sold: 520, rating: 4.3, rc: 130 }],
  ['paneer-wrap', 'burgers-wraps', 'Paneer Tikka Wrap', 'spice-route', 179, 199, '1 pc', 50, 'Charred paneer tikka, pickled onions and mint chutney in a soft roomali.', { veg: true, mins: 20, sold: 300, rating: 4.4, rc: 75 }],
  ['hakka-noodles', 'noodles-rice', 'Veg Hakka Noodles', 'spice-route', 189, 219, '1 plate', 50, 'Wok-tossed noodles with crunchy vegetables and soy-garlic sauce.', { veg: true, mins: 25, sold: 540, rating: 4.4, rc: 140 }],
  ['chicken-fried-rice', 'noodles-rice', 'Chicken Fried Rice', 'spice-route', 229, 259, '1 plate', 50, 'Smoky wok-fried rice with egg, chicken and spring onions.', { veg: false, mins: 25, sold: 410, rating: 4.4, rc: 100 }],
  ['veg-momos', 'momos-starters', 'Steamed Veg Momos', 'spice-route', 139, 159, '8 pcs', 50, 'Thin-skinned dumplings stuffed with cabbage, carrot and ginger, with fiery red chutney.', { veg: true, mins: 25, sold: 620, rating: 4.5, rc: 170 }],
  ['chilli-paneer', 'momos-starters', 'Chilli Paneer (Dry)', 'spice-route', 249, 279, '1 plate', 50, 'Crispy paneer tossed with peppers, onions and chilli-soy glaze.', { veg: true, cf: { Spice: 'Hot' }, mins: 25, sold: 380, rating: 4.5, rc: 96 }],
  ['gulab-jamun', 'desserts', 'Gulab Jamun', 'spice-route', 89, 99, '2 pcs', 60, 'Soft khoya dumplings soaked in cardamom-rose syrup, served warm.', { veg: true, mins: 15, sold: 560, rating: 4.7, rc: 150 }],
  ['chocolate-brownie', 'desserts', 'Walnut Chocolate Brownie', 'spice-route', 129, 149, '1 pc', 40, 'Fudgy dark-chocolate brownie with toasted walnuts.', { veg: true, cf: { Allergens: 'Nuts, Gluten, Dairy' }, mins: 15, sold: 300, rating: 4.6, rc: 80 }],
  ['cold-coffee', 'shakes-coffee', 'Classic Cold Coffee', 'spice-route', 149, 169, '350 ml', 50, 'Thick, frothy cold coffee blended with vanilla ice cream.', { veg: true, mins: 15, sold: 440, rating: 4.5, rc: 120 }],
  ['mango-lassi', 'shakes-coffee', 'Mango Lassi', 'spice-route', 119, 139, '350 ml', 50, 'Creamy yoghurt smoothie with Alphonso mango pulp.', { veg: true, mins: 10, sold: 390, rating: 4.6, rc: 104 }],
  ['strawberry-shake', 'shakes-coffee', 'Strawberry Milkshake', 'spice-route', 159, 179, '350 ml', 50, 'Fresh strawberries blended with chilled milk and ice cream.', { veg: true, mins: 15, sold: 180, rating: 4.3, rc: 40 }],

  // ───────── PHARMACY (MediPlus)
  ['paracetamol-650', 'pain-relief', 'MediCura Paracetamol 650 mg Tablets', 'medicura', 32, 35, 'Strip of 15', 200, 'Relieves fever and mild-to-moderate pain such as headache and body ache.', { cf: { Composition: 'Paracetamol 650 mg', Prescription: 'Not required', Storage: 'Below 25°C, dry place' }, sold: 980, rating: 4.6, rc: 210 }],
  ['ibuprofen-400', 'pain-relief', 'MediCura Ibuprofen 400 mg Tablets', 'medicura', 28, 30, 'Strip of 10', 150, 'Anti-inflammatory pain reliever for muscle, joint and dental pain.', { cf: { Composition: 'Ibuprofen 400 mg', Prescription: 'Not required', Warning: 'Take after food' }, sold: 420, rating: 4.4, rc: 80 }],
  ['pain-relief-spray', 'pain-relief', 'Instant Pain Relief Spray', 'medicura', 199, 235, '55 g', 60, 'Fast-acting cooling spray for sprains, back pain and stiff necks.', { cf: { Composition: 'Diclofenac, Methyl salicylate, Menthol', Usage: 'External use only' }, sold: 260, rating: 4.3, rc: 55 }],
  ['cough-syrup', 'cold-cough', 'Herbal Cough Syrup', 'medicura', 115, 130, '100 ml', 90, 'Soothes dry and wet cough with tulsi, mulethi and honey.', { cf: { Composition: 'Tulsi, Mulethi, Vasaka, Honey', Prescription: 'Not required' }, sold: 340, rating: 4.3, rc: 70 }],
  ['vapour-rub', 'cold-cough', 'Vapour Rub Balm', 'medicura', 89, 99, '50 ml', 100, 'Eucalyptus and menthol balm that clears a blocked nose.', { cf: { Composition: 'Menthol, Camphor, Eucalyptus oil', Usage: 'External use only' }, sold: 520, rating: 4.6, rc: 120 }],
  ['steam-inhaler', 'cold-cough', 'Steam Vaporizer & Inhaler', 'healthtrack', 349, 499, '1 unit', 25, 'Compact 3-in-1 vaporizer for steam inhalation and facial sauna.', { cf: { Warranty: '1 year', Power: '120 W' }, sold: 140, rating: 4.2, rc: 33 }],
  ['ors-sachets', 'digestive-care', 'ORS Electrolyte Sachets (Orange)', 'medicura', 99, 120, 'Pack of 10', 80, 'WHO-formula oral rehydration salts to restore fluids and energy.', { cf: { Composition: 'Sodium chloride, Potassium chloride, Dextrose', Prescription: 'Not required' }, sold: 450, rating: 4.5, rc: 95 }],
  ['antacid', 'digestive-care', 'Antacid Mint Gel', 'medicura', 129, 145, '170 ml', 70, 'Fast relief from acidity, heartburn and gas.', { cf: { Composition: 'Aluminium hydroxide, Magnesium hydroxide, Simethicone' }, sold: 290, rating: 4.3, rc: 60 }],
  ['isabgol', 'digestive-care', 'Psyllium Husk (Isabgol)', 'vitalife', 149, 175, '200 g', 45, 'Natural fibre supplement for regularity and gut health.', { cf: { Usage: '1–2 tsp in water at bedtime' }, sold: 210, rating: 4.4, rc: 40 }],
  ['multivitamin-men', 'multivitamins', 'VitaLife Daily Multivitamin for Men', 'vitalife', 499, 650, '60 tablets', 40, '24 vitamins and minerals with ginseng for daily energy and immunity.', { cf: { Dosage: '1 tablet daily after breakfast', Diet: 'Vegetarian' }, featured: true, sold: 230, rating: 4.4, rc: 58 }],
  ['multivitamin-women', 'multivitamins', 'VitaLife Daily Multivitamin for Women', 'vitalife', 499, 650, '60 tablets', 40, 'Iron, folic acid, calcium and biotin for women’s wellness.', { cf: { Dosage: '1 tablet daily after breakfast', Diet: 'Vegetarian' }, sold: 210, rating: 4.5, rc: 52 }],
  ['vitamin-c', 'multivitamins', 'Vitamin C 1000 mg Effervescent', 'vitalife', 199, 249, '20 tablets', 60, 'Orange-flavoured effervescent tablets with zinc for immunity.', { cf: { Composition: 'Vitamin C 1000 mg, Zinc 10 mg' }, sold: 380, rating: 4.5, rc: 77 }],
  ['omega-3', 'multivitamins', 'Omega-3 Fish Oil 1000 mg', 'vitalife', 599, 799, '60 softgels', 3, 'Triple-strength EPA & DHA for heart, brain and joint health.', { cf: { Composition: 'EPA 330 mg, DHA 220 mg', Diet: 'Non-vegetarian' }, sold: 160, rating: 4.4, rc: 38 }],
  ['whey-protein', 'protein-fitness', 'VitaLife Whey Protein (Chocolate)', 'vitalife', 2199, 2899, '1 kg', 20, '24 g protein per scoop with digestive enzymes, no added sugar.', { v: [['1 kg', 2199, 2899, 20], ['2 kg', 3999, 5299, 10]], cf: { Protein: '24 g per 32 g scoop', Flavour: 'Double rich chocolate' }, featured: true, sold: 150, rating: 4.5, rc: 61 }],
  ['peanut-butter', 'protein-fitness', 'High-Protein Peanut Butter', 'nutri-nest', 349, 425, '1 kg', 35, 'Crunchy peanut butter with 30% protein and no palm oil.', { veg: true, sold: 260, rating: 4.5, rc: 70 }],
  ['toothpaste', 'oral-care', 'DentaCare Herbal Toothpaste', 'dentacare', 99, 115, '150 g', 120, 'Clove, neem and babool for strong gums and fresh breath.', { cf: { Fluoride: 'Yes' }, sold: 610, rating: 4.4, rc: 105 }],
  ['toothbrush', 'oral-care', 'Soft Bristle Toothbrush (Pack of 4)', 'dentacare', 129, 160, '4 pcs', 90, 'Tapered soft bristles that clean gently along the gumline.', { sold: 380, rating: 4.3, rc: 66 }],
  ['mouthwash', 'oral-care', 'Antiseptic Mouthwash', 'dentacare', 149, 180, '250 ml', 0, 'Kills 99.9% of germs for 12-hour fresh breath.', { cf: { Alcohol: 'Free' }, sold: 190, rating: 4.2, rc: 35 }],
  ['sunscreen-spf50', 'derma-care', 'Matte Sunscreen SPF 50 PA++++', 'glow-botanica', 399, 499, '50 g', 50, 'Lightweight, non-greasy broad-spectrum sun protection for oily skin.', { cf: { Skin_type: 'Oily & combination' }, sold: 330, rating: 4.5, rc: 88 }],
  ['moisturiser', 'derma-care', 'Ceramide Daily Moisturiser', 'glow-botanica', 349, 425, '100 ml', 45, 'Repairs the skin barrier with ceramides and hyaluronic acid.', { cf: { Skin_type: 'All, including sensitive' }, sold: 210, rating: 4.5, rc: 47 }],
  ['bp-monitor', 'monitoring-devices', 'HealthTrack Digital BP Monitor', 'healthtrack', 1699, 2499, '1 unit', 20, 'Clinically validated upper-arm BP monitor with irregular heartbeat detection.', { cf: { Warranty: '5 years', Memory: '2 × 60 readings' }, featured: true, sold: 120, rating: 4.6, rc: 44 }],
  ['glucometer', 'monitoring-devices', 'HealthTrack Glucometer Kit', 'healthtrack', 899, 1299, '1 kit', 25, 'Accurate blood glucose meter with 25 strips and lancets.', { cf: { Warranty: 'Lifetime', Result_time: '5 seconds' }, sold: 140, rating: 4.4, rc: 39 }],
  ['thermometer', 'monitoring-devices', 'Digital Thermometer', 'healthtrack', 199, 299, '1 unit', 60, 'Flexible-tip thermometer with 10-second reading and fever alarm.', { sold: 400, rating: 4.4, rc: 85 }],
  ['first-aid-kit', 'first-aid', 'Home First Aid Kit (60 pcs)', 'medicura', 499, 699, '1 kit', 30, 'Bandages, antiseptic, gauze, scissors and more in a sturdy case.', { cf: { Contents: '60 items' }, sold: 170, rating: 4.5, rc: 41 }],
  ['bandages', 'first-aid', 'Waterproof Bandages', 'medicura', 79, 95, '100 strips', 80, 'Breathable, waterproof adhesive strips for minor cuts.', { sold: 300, rating: 4.3, rc: 50 }],
  ['baby-diapers', 'baby-care', 'Tiny Tots Pant Diapers (M)', 'tiny-tots', 699, 899, '56 pcs', 40, 'Up to 12 hours of dryness with a soft, rash-free cotton feel.', { v: [['S (42 pcs)', 649, 799, 30], ['M (56 pcs)', 699, 899, 40], ['L (48 pcs)', 699, 899, 35]], sold: 260, rating: 4.5, rc: 72 }],
  ['baby-wipes', 'baby-care', 'Tiny Tots Water Wipes', 'tiny-tots', 149, 199, '72 wipes', 70, '99% water, fragrance-free wipes gentle on newborn skin.', { sold: 310, rating: 4.6, rc: 64 }],
  ['baby-lotion', 'baby-care', 'Tiny Tots Baby Lotion', 'tiny-tots', 225, 260, '200 ml', 50, 'Mild, 24-hour moisturising lotion with shea butter and almond oil.', { sold: 180, rating: 4.5, rc: 36 }],

  // ───────── ECOMMERCE (UrbanTrend + Go4 Fresh Mart home & kitchen)
  ['voltix-x5', 'smartphones', 'Voltix X5 5G (8 GB RAM)', 'voltix', 18999, 22999, '1 unit', 25, '6.7" 120 Hz AMOLED, 50 MP OIS camera and 5000 mAh battery with 45 W charging.', { v: [['8 GB + 128 GB · Midnight Black', 18999, 22999, 15], ['8 GB + 256 GB · Ocean Blue', 20999, 24999, 10]], cf: { Display: '6.7" AMOLED 120 Hz', Processor: 'Octa-core 5G', Battery: '5000 mAh', Warranty: '1 year' }, featured: true, sold: 140, rating: 4.4, rc: 92 }],
  ['voltix-lite', 'smartphones', 'Voltix Lite 4G', 'voltix', 9499, 11999, '1 unit', 30, 'Everyday phone with a 6.5" display, 13 MP dual camera and 2-day battery.', { cf: { Display: '6.5" HD+', Battery: '5000 mAh', Warranty: '1 year' }, sold: 210, rating: 4.1, rc: 64 }],
  ['powerbank-20k', 'chargers-powerbanks', 'Voltix 20000 mAh Power Bank', 'voltix', 1499, 2499, '1 unit', 50, '22.5 W fast charging, USB-C PD in/out and charges 3 devices at once.', { cf: { Capacity: '20000 mAh', Output: '22.5 W', Warranty: '6 months' }, sold: 330, rating: 4.4, rc: 120 }],
  ['gan-charger', 'chargers-powerbanks', '65 W GaN USB-C Charger', 'voltix', 1999, 2999, '1 unit', 35, 'Pocket-size charger that powers a laptop, phone and earbuds together.', { cf: { Ports: '2 × USB-C, 1 × USB-A', Warranty: '1 year' }, sold: 150, rating: 4.5, rc: 48 }],
  ['usb-c-cable', 'chargers-powerbanks', 'Braided USB-C to USB-C Cable (1.5 m)', 'voltix', 349, 599, '1 unit', 100, 'Nylon-braided 60 W cable tested for 20,000 bends.', { sold: 520, rating: 4.3, rc: 98 }],
  ['anc-headphones', 'headphones-earbuds', 'SoundWave Pro ANC Headphones', 'soundwave', 4999, 7999, '1 unit', 20, 'Hybrid active noise cancellation, 40 mm drivers and 40-hour battery.', { v: [['Matte Black', 4999, 7999, 12], ['Silver Grey', 4999, 7999, 8]], cf: { Battery: '40 h (ANC on)', Bluetooth: '5.3', Warranty: '1 year' }, featured: true, sold: 180, rating: 4.5, rc: 77 }],
  ['tws-earbuds', 'headphones-earbuds', 'SoundWave Buds Air', 'soundwave', 1799, 3499, '1 unit', 45, 'True wireless earbuds with ENC mics, low-latency game mode and 36 h playback.', { cf: { Battery: '36 h with case', Water_resistance: 'IPX5' }, sold: 450, rating: 4.3, rc: 160 }],
  ['neckband', 'headphones-earbuds', 'SoundWave Flex Neckband', 'soundwave', 999, 1999, '1 unit', 4, 'Magnetic earbuds, 30 h battery and 10-minute fast charge for 10 h play.', { sold: 260, rating: 4.2, rc: 70 }],
  ['bt-speaker', 'bluetooth-speakers', 'SoundWave Boom 20 W Speaker', 'soundwave', 2499, 3999, '1 unit', 30, 'Punchy 20 W stereo sound, IPX7 waterproof and 15-hour battery.', { v: [['Black', 2499, 3999, 15], ['Teal', 2499, 3999, 15]], cf: { Output: '20 W', Water_resistance: 'IPX7' }, sold: 190, rating: 4.4, rc: 58 }],
  ['smart-speaker', 'bluetooth-speakers', 'SoundWave Mini Smart Speaker', 'soundwave', 2999, 4499, '1 unit', 0, 'Voice-assistant speaker with room-filling 360° sound.', { sold: 90, rating: 4.2, rc: 22 }],
  ['smartwatch', 'wearables', 'PulseFit Active Smartwatch', 'pulsefit', 2799, 4999, '1 unit', 40, '1.96" AMOLED, Bluetooth calling, SpO2 and 100+ sports modes.', { v: [['Black strap', 2799, 4999, 20], ['Olive strap', 2799, 4999, 20]], cf: { Display: '1.96" AMOLED', Battery: 'Up to 7 days', Water_resistance: 'IP68' }, featured: true, sold: 310, rating: 4.3, rc: 110 }],
  ['fitness-band', 'wearables', 'PulseFit Band 3', 'pulsefit', 1499, 2499, '1 unit', 50, 'Slim fitness tracker with heart-rate, sleep and stress tracking.', { sold: 240, rating: 4.2, rc: 66 }],
  ['laptop-14', 'laptops-tablets', 'Voltix Book 14 (Core i5, 16 GB)', 'voltix', 52990, 64990, '1 unit', 10, 'Thin-and-light 14" FHD+ laptop with 512 GB SSD and backlit keyboard.', { cf: { Processor: 'Intel Core i5 13th Gen', RAM: '16 GB', Storage: '512 GB SSD', Weight: '1.4 kg' }, featured: true, sold: 40, rating: 4.5, rc: 21 }],
  ['tablet-11', 'laptops-tablets', 'Voltix Tab 11', 'voltix', 17999, 21999, '1 unit', 15, '11" 2K display, quad speakers and 8000 mAh battery for study and streaming.', { cf: { Display: '11" 2K', Storage: '128 GB' }, sold: 60, rating: 4.3, rc: 26 }],
  ['cotton-tee', 'men-tshirts', 'Men’s Supima Cotton Crew T-Shirt', 'urbantrend', 599, 999, '1 pc', 120, 'Breathable, pre-shrunk Supima cotton tee in a regular fit.', { v: [['S · Navy', 599, 999, 30], ['M · Navy', 599, 999, 30], ['L · White', 599, 999, 30], ['XL · Black', 599, 999, 30]], cf: { Fabric: '100% Supima cotton', Fit: 'Regular', Care: 'Machine wash cold' }, sold: 430, rating: 4.3, rc: 140 }],
  ['linen-shirt', 'men-tshirts', 'Men’s Linen Casual Shirt', 'urbantrend', 1299, 1999, '1 pc', 60, 'Pure linen shirt with a relaxed fit — cool through the Indian summer.', { v: [['M · Sky Blue', 1299, 1999, 20], ['L · Sky Blue', 1299, 1999, 20], ['XL · Beige', 1299, 1999, 20]], cf: { Fabric: '100% Linen', Fit: 'Relaxed' }, sold: 180, rating: 4.4, rc: 52 }],
  ['running-shoes', 'men-footwear', 'StrideX Cloudrun Running Shoes', 'stridex', 2499, 3999, '1 pair', 40, 'Lightweight knit upper and responsive foam for daily runs.', { v: [['UK 7', 2499, 3999, 10], ['UK 8', 2499, 3999, 10], ['UK 9', 2499, 3999, 10], ['UK 10', 2499, 3999, 10]], cf: { Sole: 'EVA foam', Weight: '260 g' }, featured: true, sold: 260, rating: 4.4, rc: 95 }],
  ['leather-loafers', 'men-footwear', 'Men’s Tan Leather Loafers', 'luxe-leather', 2199, 3299, '1 pair', 20, 'Hand-stitched full-grain leather loafers with a cushioned insole.', { v: [['UK 8', 2199, 3299, 10], ['UK 9', 2199, 3299, 10]], cf: { Material: 'Full-grain leather' }, sold: 70, rating: 4.3, rc: 19 }],
  ['anarkali-kurta', 'women-kurtas', 'Kalaa Block-Print Anarkali Kurta', 'kalaa', 1499, 2499, '1 pc', 45, 'Hand block-printed cotton anarkali from Jaipur with a flared silhouette.', { v: [['S', 1499, 2499, 15], ['M', 1499, 2499, 15], ['L', 1499, 2499, 15]], cf: { Fabric: 'Cotton cambric', Craft: 'Sanganeri block print' }, featured: true, sold: 210, rating: 4.5, rc: 66 }],
  ['silk-saree', 'women-kurtas', 'Kalaa Banarasi Art Silk Saree', 'kalaa', 2799, 4499, '1 pc', 15, 'Zari-woven art silk saree with an unstitched blouse piece.', { cf: { Fabric: 'Art silk', Length: '5.5 m + 0.8 m blouse' }, sold: 80, rating: 4.4, rc: 24 }],
  ['tote-bag', 'women-handbags', 'Luxe Leather Structured Tote', 'luxe-leather', 2499, 3999, '1 pc', 25, 'Spacious vegan-leather tote with a laptop sleeve and zip pocket.', { v: [['Tan', 2499, 3999, 12], ['Black', 2499, 3999, 13]], cf: { Material: 'Vegan leather', Fits: '14" laptop' }, sold: 120, rating: 4.4, rc: 37 }],
  ['sling-bag', 'women-handbags', 'Quilted Mini Sling Bag', 'luxe-leather', 1199, 1799, '1 pc', 30, 'Chain-strap quilted sling for evenings out.', { sold: 140, rating: 4.3, rc: 30 }],
  ['aviator-sunglasses', 'sunglasses', 'SunRay Polarised Aviators', 'sunray', 1299, 2499, '1 pc', 35, 'UV400 polarised lenses in a lightweight metal frame.', { v: [['Gold / Green', 1299, 2499, 18], ['Gunmetal / Grey', 1299, 2499, 17]], cf: { Protection: 'UV400, polarised' }, sold: 190, rating: 4.3, rc: 54 }],
  ['wayfarer', 'sunglasses', 'SunRay Classic Wayfarers', 'sunray', 999, 1999, '1 pc', 40, 'Timeless acetate wayfarers with scratch-resistant lenses.', { sold: 160, rating: 4.2, rc: 41 }],
  ['analog-watch', 'watches', 'Luxe Leather Chronograph Watch', 'luxe-leather', 3499, 5999, '1 pc', 15, 'Stainless-steel chronograph with a genuine leather strap, 50 m water resistant.', { cf: { Movement: 'Japanese quartz', Water_resistance: '5 ATM' }, sold: 60, rating: 4.5, rc: 22 }],
  ['vitamin-c-serum', 'skincare', 'Glow Botanica 10% Vitamin C Serum', 'glow-botanica', 549, 699, '30 ml', 50, 'Brightening serum with stabilised vitamin C and ferulic acid.', { cf: { Skin_type: 'All', Cruelty_free: 'Yes' }, featured: true, sold: 340, rating: 4.4, rc: 120 }],
  ['face-wash', 'skincare', 'Glow Botanica Neem Face Wash', 'glow-botanica', 199, 249, '150 ml', 80, 'Gentle gel cleanser with neem and tea tree for clear skin.', { sold: 420, rating: 4.3, rc: 110 }],
  ['perfume-oud', 'fragrances', 'Aroma House Royal Oud Eau de Parfum', 'aroma-house', 1499, 2499, '100 ml', 30, 'Warm oud, saffron and amber — long-lasting 8+ hours.', { cf: { Concentration: 'EDP', Longevity: '8+ hours' }, sold: 150, rating: 4.4, rc: 45 }],
  ['perfume-citrus', 'fragrances', 'Aroma House Citrus Breeze EDT', 'aroma-house', 899, 1499, '100 ml', 35, 'Fresh bergamot, neroli and vetiver for everyday wear.', { cf: { Concentration: 'EDT' }, sold: 120, rating: 4.2, rc: 30 }],
  // Home & kitchen (sold by Go4 Fresh Mart — makes the demo seller multi-module)
  ['pressure-cooker', 'cookware', 'ChefPro Stainless Steel Pressure Cooker', 'chefpro', 2199, 2999, '5 L', 20, 'Tri-ply induction-ready cooker with a safety valve and 5-year warranty.', { v: [['3 L', 1799, 2499, 10], ['5 L', 2199, 2999, 10]], cf: { Material: 'Tri-ply stainless steel', Warranty: '5 years' }, sold: 110, rating: 4.6, rc: 48 }],
  ['nonstick-tawa', 'cookware', 'ChefPro Non-Stick Dosa Tawa', 'chefpro', 899, 1299, '28 cm', 30, 'PFOA-free granite coating for crisp dosas with little oil.', { cf: { Coating: 'Granite, PFOA-free', Induction: 'Yes' }, sold: 160, rating: 4.4, rc: 52 }],
  ['cast-iron-kadai', 'cookware', 'Pre-Seasoned Cast Iron Kadai', 'chefpro', 1299, 1799, '24 cm', 3, 'Naturally non-stick cast-iron kadai that adds iron to food.', { sold: 80, rating: 4.5, rc: 25 }],
  ['mixer-grinder', 'kitchen-appliances', 'ChefPro 750 W Mixer Grinder', 'chefpro', 3299, 4999, '3 jars', 15, 'Powerful 750 W motor with 3 stainless-steel jars for wet and dry grinding.', { cf: { Power: '750 W', Warranty: '2 years (motor 5 years)' }, featured: true, sold: 90, rating: 4.4, rc: 36 }],
  ['electric-kettle', 'kitchen-appliances', 'ChefPro 1.5 L Electric Kettle', 'chefpro', 899, 1499, '1.5 L', 40, 'Boils water in 4 minutes with auto shut-off and dry-boil protection.', { cf: { Power: '1500 W' }, sold: 210, rating: 4.3, rc: 61 }],
  ['air-fryer', 'kitchen-appliances', 'ChefPro Digital Air Fryer 4.2 L', 'chefpro', 4999, 7999, '4.2 L', 12, 'Crisp fries and tikkas with up to 90% less oil, 8 presets.', { cf: { Capacity: '4.2 L', Power: '1400 W' }, sold: 70, rating: 4.5, rc: 29 }],
  ['ceramic-vase', 'home-decor', 'Nestaura Ceramic Bud Vase Set', 'nestaura', 799, 1299, 'Set of 3', 25, 'Matte ceramic vases in earthy tones for shelves and tables.', { sold: 60, rating: 4.4, rc: 18 }],
  ['scented-candle', 'home-decor', 'Nestaura Sandalwood Soy Candle', 'nestaura', 499, 799, '200 g', 40, 'Hand-poured soy wax candle with 40-hour burn time.', { cf: { Burn_time: '40 hours', Wax: 'Soy' }, sold: 140, rating: 4.5, rc: 33 }],
  ['cushion-covers', 'home-decor', 'Nestaura Handloom Cushion Covers', 'nestaura', 699, 999, 'Set of 2', 30, 'Handwoven cotton cushion covers, 16 × 16 inch, with hidden zip.', { sold: 90, rating: 4.3, rc: 21 }],
];

export const reviewsSeed = [
  ['shimla-apples', 'Priya S.', 5, 'Super crisp and sweet, every apple was perfect. Delivered within 20 minutes!'],
  ['shimla-apples', 'Vikram J.', 4, 'Good quality, a couple were slightly small but tasty.'],
  ['chicken-biryani', 'Aarav M.', 5, 'Best biryani in Ahmedabad. Rice was fluffy, chicken tender and the salan is a must.'],
  ['chicken-biryani', 'Sneha R.', 5, 'Arrived piping hot. Family pack easily fed three of us.'],
  ['paneer-butter-masala', 'Kunal D.', 5, 'Restaurant quality makhani gravy, paneer was really soft.'],
  ['voltix-x5', 'Rohan T.', 4, 'Great display and battery for the price. Camera is good in daylight.'],
  ['anc-headphones', 'Meera K.', 5, 'ANC is excellent on flights and calls are clear. Very comfortable.'],
  ['toned-milk', 'Hetal P.', 5, 'Fresh every morning, never had a sour packet.'],
  ['paracetamol-650', 'Anil V.', 5, 'Genuine product with long expiry, fast delivery at night.'],
  ['running-shoes', 'Dev A.', 4, 'Light and comfortable for 5K runs. Size runs true.'],
  ['bp-monitor', 'Suresh N.', 5, 'Readings match my doctor’s machine. Easy for my parents to use.'],
  ['assam-tea', 'Komal B.', 5, 'Strong and malty, exactly how I like my chai.'],
];
