import 'l10n.dart';

/// Strings for the catalog area: category pages, filters, search, stores, wishlist and product cards.
class CatalogStrings {
  const CatalogStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);
  String _n(int n) => _l.number(n);

  /// Arabic counted noun: 1 and 2 have their own forms, 3-10 take the plural, 11+ the singular accusative.
  String _ar(int n, String one, String two, String few, String many) {
    if (n == 1) return one;
    if (n == 2) return two;
    final m = n % 100;
    return (m >= 3 && m <= 10) || n == 0 ? '${_n(n)} $few' : '${_n(n)} $many';
  }

  String _arProducts(int n) => _ar(n, 'منتج واحد', 'منتجان', 'منتجات', 'منتجًا');

  // ---------------------------------------------------------------- shared counts
  String productsCount(int n) => _t(
        n == 1 ? '1 product' : '${_n(n)} products',
        '${_n(n)} प्रोडक्ट',
        '${_n(n)} પ્રોડક્ટ',
        _arProducts(n),
      );

  // ---------------------------------------------------------------- breadcrumbs + categories
  String get breadcrumb => _t('Breadcrumb', 'नेविगेशन पथ', 'નેવિગેશન પાથ', 'مسار التنقل');
  String get categories => _t('Categories', 'श्रेणियाँ', 'શ્રેણીઓ', 'الفئات');
  String get allCategoriesSeoDescription => _t(
        'Browse every Go4Market category: groceries, fresh produce, pharmacy and wellness, restaurants and food, electronics, fashion, home and more.',
        'Go4Market की हर श्रेणी देखें: किराना, ताज़े फल-सब्ज़ियाँ, दवाइयाँ और वेलनेस, रेस्टोरेंट और खाना, इलेक्ट्रॉनिक्स, फ़ैशन, घर का सामान और बहुत कुछ।',
        'Go4Market ની દરેક શ્રેણી જુઓ: કરિયાણું, તાજાં ફળ-શાકભાજી, દવાઓ અને વેલનેસ, રેસ્ટોરન્ટ અને ભોજન, ઇલેક્ટ્રોનિક્સ, ફૅશન, ઘરવખરી અને ઘણું બધું.',
        'تصفّح كل فئات Go4Market: البقالة والمنتجات الطازجة والصيدلية والعناية الصحية والمطاعم والطعام والإلكترونيات والأزياء والمنزل والمزيد.',
      );
  String get categoriesSubtitle => _t('Pick a store, then drill down as deep as you like.', 'कोई स्टोर चुनें, फिर जितना चाहें उतना अंदर तक देखें।',
      'કોઈ સ્ટોર પસંદ કરો, પછી જેટલું ઊંડાણમાં જોવું હોય તેટલું જુઓ.', 'اختر متجرًا، ثم تعمّق في التصفح كما تشاء.');
  String get categoriesSoonTitle => _t('Categories are on their way', 'श्रेणियाँ जल्द आ रही हैं', 'શ્રેણીઓ જલદી આવી રહી છે', 'الفئات في الطريق');
  String get categoriesSoonMessage => _t('Our catalogue is being set up. Please check back shortly.', 'हमारा कैटलॉग तैयार किया जा रहा है। कृपया थोड़ी देर बाद फिर देखें।',
      'અમારું કૅટલૉગ તૈયાર થઈ રહ્યું છે. કૃપા કરી થોડી વાર પછી ફરી જુઓ.', 'نقوم بإعداد الكتالوج. يُرجى العودة بعد قليل.');
  String visitStore(String name) => _t('Visit $name store', '$name स्टोर पर जाएँ', '$name સ્ટોર પર જાઓ', 'زيارة متجر $name');

  // ---------------------------------------------------------------- sort
  String sortLabel(String key) => switch (key) {
        'popular' => _t('Popularity', 'लोकप्रियता', 'લોકપ્રિયતા', 'الأكثر رواجًا'),
        'price_asc' => _t('Price: low to high', 'कीमत: कम से ज़्यादा', 'કિંમત: ઓછીથી વધુ', 'السعر: من الأقل إلى الأعلى'),
        'price_desc' => _t('Price: high to low', 'कीमत: ज़्यादा से कम', 'કિંમત: વધુથી ઓછી', 'السعر: من الأعلى إلى الأقل'),
        'rating' => customerRating,
        'discount' => _t('Biggest discount', 'सबसे ज़्यादा छूट', 'સૌથી વધુ છૂટ', 'أكبر خصم'),
        _ => _t('Newest first', 'सबसे नए पहले', 'સૌથી નવા પહેલાં', 'الأحدث أولًا'),
      };
  String sortPrefixed(String label) => _t('Sort: $label', 'क्रम: $label', 'ક્રમ: $label', 'الترتيب: $label');

  // ---------------------------------------------------------------- filters
  String get filters => _t('Filters', 'फ़िल्टर', 'ફિલ્ટર', 'عوامل التصفية');
  String filtersCount(int n) => _t('Filters (${_n(n)})', 'फ़िल्टर (${_n(n)})', 'ફિલ્ટર (${_n(n)})', 'عوامل التصفية (${_n(n)})');
  String get clearAll => _t('Clear all', 'सब हटाएँ', 'બધું દૂર કરો', 'مسح الكل');
  String get price => _t('Price', 'कीमत', 'કિંમત', 'السعر');
  String get availability => _t('Availability', 'उपलब्धता', 'ઉપલબ્ધતા', 'التوفر');
  String get inStockOnly => _t('In stock only', 'सिर्फ़ स्टॉक में उपलब्ध', 'ફક્ત સ્ટોકમાં ઉપલબ્ધ', 'المتوفر فقط');
  String get dietaryPreference => _t('Dietary preference', 'खान-पान की पसंद', 'ખોરાકની પસંદગી', 'التفضيل الغذائي');
  String get any => _t('Any', 'कोई भी', 'કોઈ પણ', 'الكل');
  String get veg => _t('Veg', 'शाकाहारी', 'શાકાહારી', 'نباتي');
  String get nonVeg => _t('Non-veg', 'मांसाहारी', 'માંસાહારી', 'غير نباتي');
  String get customerRating => _t('Customer rating', 'ग्राहक रेटिंग', 'ગ્રાહક રેટિંગ', 'تقييم العملاء');
  String ratingAndUp(num r) {
    final s = _l.number(r);
    return _t('$s★ & up', '$s★ और उससे ऊपर', '$s★ અને તેથી વધુ', '$s★ فأكثر');
  }

  String get brand => _t('Brand', 'ब्रांड', 'બ્રાન્ડ', 'العلامة التجارية');
  String get gridView => _t('Grid view', 'ग्रिड व्यू', 'ગ્રિડ વ્યૂ', 'عرض شبكي');
  String get listView => _t('List view', 'लिस्ट व्यू', 'લિસ્ટ વ્યૂ', 'عرض القائمة');
  String showProducts(int n) => _t(
        n == 1 ? 'Show 1 product' : 'Show ${_n(n)} products',
        '${_n(n)} प्रोडक्ट दिखाएँ',
        '${_n(n)} પ્રોડક્ટ બતાવો',
        'عرض ${_arProducts(n)}',
      );
  String get clearFilters => _t('Clear filters', 'फ़िल्टर हटाएँ', 'ફિલ્ટર દૂર કરો', 'مسح عوامل التصفية');
  String get noFilterMatch => _t('No products match these filters', 'इन फ़िल्टर से कोई प्रोडक्ट मेल नहीं खाता', 'આ ફિલ્ટર સાથે કોઈ પ્રોડક્ટ મેળ ખાતી નથી',
      'لا توجد منتجات تطابق عوامل التصفية هذه');
  String get tryRemovingFilter => _t('Try removing a filter.', 'कोई फ़िल्टर हटाकर देखें।', 'કોઈ ફિલ્ટર દૂર કરી જુઓ.', 'جرّب إزالة أحد عوامل التصفية.');

  // ---------------------------------------------------------------- category page
  String get categoryNotFound => _t('Category not found', 'श्रेणी नहीं मिली', 'શ્રેણી મળી નથી', 'الفئة غير موجودة');
  String get categoryNotFoundTitle => _t('We could not find that category', 'हमें यह श्रेणी नहीं मिली', 'અમને આ શ્રેણી મળી નથી', 'لم نعثر على هذه الفئة');
  String get categoryNotFoundMessage => _t('It may have been renamed. Try browsing all categories.', 'हो सकता है इसका नाम बदल गया हो। सभी श्रेणियाँ देखकर आज़माएँ।',
      'કદાચ તેનું નામ બદલાઈ ગયું હોય. બધી શ્રેણીઓ જોઈ જુઓ.', 'ربما تمت إعادة تسميتها. جرّب تصفّح كل الفئات.');
  String get productsLoadError => _t('Products could not load', 'प्रोडक्ट लोड नहीं हो सके', 'પ્રોડક્ટ લોડ થઈ શકી નથી', 'تعذّر تحميل المنتجات');
  String get noProductsHere => _t('No products here yet', 'यहाँ अभी कोई प्रोडक्ट नहीं है', 'અહીં હજી કોઈ પ્રોડક્ટ નથી', 'لا توجد منتجات هنا بعد');
  String sellersAdding(String category) => _t('Sellers are adding products to $category. Check back soon.', 'विक्रेता $category में प्रोडक्ट जोड़ रहे हैं। जल्द ही फिर देखें।',
      'વિક્રેતાઓ $category માં પ્રોડક્ટ ઉમેરી રહ્યા છે. જલદી ફરી જુઓ.', 'يضيف البائعون منتجات إلى $category. عُد قريبًا.');
  String categorySeoDescription(String name, int count) => _t(
        'Buy ${name.toLowerCase()} online on Go4Market. ${count > 0 ? productsCount(count) : 'Great prices'} from trusted sellers with quick delivery.',
        'Go4Market पर $name ऑनलाइन खरीदें। भरोसेमंद विक्रेताओं से ${count > 0 ? productsCount(count) : 'बेहतरीन दाम'}, क्विक डिलीवरी के साथ।',
        'Go4Market પર $name ઑનલાઇન ખરીદો. વિશ્વસનીય વિક્રેતાઓ પાસેથી ${count > 0 ? productsCount(count) : 'શ્રેષ્ઠ કિંમતો'}, ક્વિક ડિલિવરી સાથે.',
        'اشترِ $name عبر الإنترنت على Go4Market. ${count > 0 ? productsCount(count) : 'أسعار رائعة'} من بائعين موثوقين مع توصيل سريع.',
      );
  String exploreFrom(String name) => _t('Explore ${name.toLowerCase()} from trusted sellers near you.', 'अपने आस-पास के भरोसेमंद विक्रेताओं से $name देखें।',
      'તમારી નજીકના વિશ્વસનીય વિક્રેતાઓ પાસેથી $name જુઓ.', 'استكشف $name من بائعين موثوقين بالقرب منك.');
  String subCategories(int n) => _t(
        n == 1 ? '1 sub-category to explore' : '${_n(n)} sub-categories to explore',
        n == 1 ? 'देखने के लिए 1 उप-श्रेणी' : 'देखने के लिए ${_n(n)} उप-श्रेणियाँ',
        n == 1 ? 'જોવા માટે 1 પેટા-શ્રેણી' : 'જોવા માટે ${_n(n)} પેટા-શ્રેણીઓ',
        '${_ar(n, 'فئة فرعية واحدة', 'فئتان فرعيتان', 'فئات فرعية', 'فئة فرعية')} للاستكشاف',
      );

  // ---------------------------------------------------------------- product cards
  String get outOfStock => _t('Out of stock', 'स्टॉक में नहीं', 'સ્ટોકમાં નથી', 'نفد من المخزون');
  String addNameToCart(String name) => _t('Add $name to cart', '$name कार्ट में जोड़ें', '$name કાર્ટમાં ઉમેરો', 'أضف $name إلى السلة');
  String get add => _t('Add', 'जोड़ें', 'ઉમેરો', 'أضف');
  String get addToCart => _t('Add to cart', 'कार्ट में जोड़ें', 'કાર્ટમાં ઉમેરો', 'أضف إلى السلة');
  String removeOne(String name) => _t('Remove one $name', 'एक $name कम करें', 'એક $name ઓછું કરો', 'إزالة قطعة واحدة من $name');
  String addOneMore(String name) => _t('Add one more $name', 'एक और $name जोड़ें', 'એક વધુ $name ઉમેરો', 'أضف قطعة أخرى من $name');
  String inCart(int q) => _t('${_n(q)} in cart', 'कार्ट में ${_n(q)}', 'કાર્ટમાં ${_n(q)}', '${_n(q)} في السلة');
  String onlyInStock(int n) => _t('Only ${_n(n)} in stock', 'स्टॉक में सिर्फ़ ${_n(n)} बचे हैं', 'સ્ટોકમાં ફક્ત ${_n(n)} બાકી છે', 'المتوفر في المخزون ${_n(n)} فقط');
  String get chooseOption => _t('Choose an option', 'एक विकल्प चुनें', 'એક વિકલ્પ પસંદ કરો', 'اختر خيارًا');
  String get removeFromWishlist => _t('Remove from wishlist', 'विशलिस्ट से हटाएँ', 'વિશલિસ્ટમાંથી દૂર કરો', 'إزالة من قائمة الأمنيات');
  String get saveToWishlist => _t('Save to wishlist', 'विशलिस्ट में सेव करें', 'વિશલિસ્ટમાં સેવ કરો', 'حفظ في قائمة الأمنيات');
  String minutes(int n) => _t('${_n(n)} min', '${_n(n)} मिनट', '${_n(n)} મિનિટ', '${_n(n)} دقيقة');
  String get vegetarian => _t('Vegetarian', 'शाकाहारी', 'શાકાહારી', 'نباتي');
  String get nonVegetarian => _t('Non-vegetarian', 'मांसाहारी', 'માંસાહારી', 'غير نباتي');
  String get scrollBack => _t('Scroll back', 'पीछे स्क्रॉल करें', 'પાછળ સ્ક્રોલ કરો', 'التمرير للخلف');
  String get scrollForward => _t('Scroll forward', 'आगे स्क्रॉल करें', 'આગળ સ્ક્રોલ કરો', 'التمرير للأمام');

  // ---------------------------------------------------------------- search
  String get noProductsFound => _t('No products found', 'कोई प्रोडक्ट नहीं मिला', 'કોઈ પ્રોડક્ટ મળી નથી', 'لم يتم العثور على منتجات');
  String get bestSellers => _t('Best sellers', 'बेस्ट सेलर', 'બેસ્ટ સેલર', 'الأكثر مبيعًا');
  String get topDeals => _t('Top deals', 'टॉप डील्स', 'ટોપ ડીલ્સ', 'أفضل العروض');
  String get topRated => _t('Top rated', 'टॉप रेटेड', 'ટોપ રેટેડ', 'الأعلى تقييمًا');
  String get allProducts => _t('All products', 'सभी प्रोडक्ट', 'બધી પ્રોડક્ટ', 'كل المنتجات');
  String get yourShoppingList => _t('Your shopping list', 'आपकी शॉपिंग लिस्ट', 'તમારી શોપિંગ લિસ્ટ', 'قائمة تسوّقك');
  String resultsFor(String q) => _t('Results for "$q"', '"$q" के नतीजे', '"$q" માટેનાં પરિણામો', 'نتائج البحث عن "$q"');
  String searchSeoTitle(String q) => _t('Search: $q', 'खोज: $q', 'શોધ: $q', 'بحث: $q');
  String browseSeoDescription(String title) => _t('Browse $title on Go4Market with quick delivery.', 'Go4Market पर $title देखें, क्विक डिलीवरी के साथ।',
      'Go4Market પર $title જુઓ, ક્વિક ડિલિવરી સાથે.', 'تصفّح $title على Go4Market مع توصيل سريع.');
  String searchSeoDescription(String q) => _t(
        'Search results for $q on Go4Market: compare prices and get it delivered fast.',
        'Go4Market पर $q के खोज नतीजे: दाम की तुलना करें और तेज़ डिलीवरी पाएँ।',
        'Go4Market પર $q માટેનાં શોધ પરિણામો: કિંમતોની સરખામણી કરો અને ઝડપી ડિલિવરી મેળવો.',
        'نتائج البحث عن $q على Go4Market: قارن الأسعار واحصل عليه بتوصيل سريع.',
      );
  String splitInto(String q, int n) => _t(
        'We split "$q" into ${_n(n)} items. Add the best match for each, or pick another.',
        'हमने "$q" को ${_n(n)} आइटम में बाँटा है। हर एक के लिए सबसे सही प्रोडक्ट जोड़ें, या कोई दूसरा चुनें।',
        'અમે "$q" ને ${_n(n)} આઇટમમાં વહેંચ્યું છે. દરેક માટે સૌથી યોગ્ય પ્રોડક્ટ ઉમેરો, અથવા બીજી પસંદ કરો.',
        'قسّمنا "$q" إلى ${_ar(n, 'عنصر واحد', 'عنصرين', 'عناصر', 'عنصرًا')}. أضف أفضل تطابق لكل عنصر، أو اختر غيره.',
      );
  String get searchUnavailable => _t('Search is unavailable right now', 'खोज अभी उपलब्ध नहीं है', 'શોધ અત્યારે ઉપલબ્ધ નથી', 'البحث غير متاح الآن');
  String noMatchesFor(String q) => _t('No matches for "$q"', '"$q" के लिए कुछ नहीं मिला', '"$q" માટે કંઈ મળ્યું નથી', 'لا توجد نتائج لـ "$q"');
  String get noMatchesMessage => _t(
        'Check the spelling, try a shorter word, or request this product and we will try to stock it.',
        'स्पेलिंग जाँचें, छोटा शब्द आज़माएँ, या इस प्रोडक्ट का अनुरोध करें, हम इसे स्टॉक में लाने की कोशिश करेंगे।',
        'સ્પેલિંગ તપાસો, નાનો શબ્દ અજમાવો, અથવા આ પ્રોડક્ટની વિનંતી કરો, અમે તેને સ્ટોકમાં લાવવાનો પ્રયાસ કરીશું.',
        'تحقّق من الإملاء، أو جرّب كلمة أقصر، أو اطلب هذا المنتج وسنحاول توفيره.',
      );
  String get requestThisProduct => _t('Request this product', 'इस प्रोडक्ट का अनुरोध करें', 'આ પ્રોડક્ટની વિનંતી કરો', 'اطلب هذا المنتج');
  String get voiceTip => _t(
        'Tip: tap the microphone and read out your whole list, like "milk, bread and eggs". We will find each item for you.',
        'सुझाव: माइक्रोफ़ोन पर टैप करें और अपनी पूरी लिस्ट बोलें, जैसे "दूध, ब्रेड और अंडे"। हम हर आइटम आपके लिए ढूँढ देंगे।',
        'ટિપ: માઇક્રોફોન પર ટૅપ કરો અને તમારી આખી લિસ્ટ બોલો, જેમ કે "દૂધ, બ્રેડ અને ઈંડાં". અમે દરેક આઇટમ તમારા માટે શોધી આપીશું.',
        'نصيحة: اضغط على الميكروفون واقرأ قائمتك كاملة، مثل "حليب وخبز وبيض". وسنجد لك كل منتج.',
      );
  String get popularNow => _t('Popular right now', 'अभी लोकप्रिय', 'અત્યારે લોકપ્રિય', 'الأكثر رواجًا الآن');
  String get allAlreadyInCart => _t('Everything is already in your cart', 'सब कुछ पहले से आपके कार्ट में है', 'બધું પહેલેથી તમારા કાર્ટમાં છે', 'كل شيء موجود في سلتك بالفعل');
  String addedItems(int n) => _t(
        n == 1 ? 'Added 1 item to your cart' : 'Added ${_n(n)} items to your cart',
        n == 1 ? '1 आइटम आपके कार्ट में जोड़ा गया' : '${_n(n)} आइटम आपके कार्ट में जोड़े गए',
        n == 1 ? '1 આઇટમ તમારા કાર્ટમાં ઉમેરાઈ' : '${_n(n)} આઇટમ તમારા કાર્ટમાં ઉમેરાઈ',
        'تمت إضافة ${_arProducts(n)} إلى سلتك',
      );
  String get viewCart => _t('View cart', 'कार्ट देखें', 'કાર્ટ જુઓ', 'عرض السلة');
  String get addBestMatchAll => _t('Add best match for every item', 'हर आइटम के लिए सबसे सही प्रोडक्ट जोड़ें', 'દરેક આઇટમ માટે સૌથી યોગ્ય પ્રોડક્ટ ઉમેરો', 'أضف أفضل تطابق لكل عنصر');
  String allResultsFor(String t) => _t('All results for $t', '$t के सभी नतीजे', '$t માટેનાં બધાં પરિણામો', 'كل نتائج $t');
  String noMatchTryAnother(String t) =>
      _t('No match for "$t". Try a different word.', '"$t" के लिए कुछ नहीं मिला। कोई दूसरा शब्द आज़माएँ।', '"$t" માટે કંઈ મળ્યું નથી. બીજો શબ્દ અજમાવો.', 'لا توجد نتائج لـ "$t". جرّب كلمة أخرى.');

  // ---------------------------------------------------------------- store page
  String get storeUnavailable => _t('Store unavailable', 'स्टोर उपलब्ध नहीं है', 'સ્ટોર ઉપલબ્ધ નથી', 'المتجر غير متاح');
  String get storeNotFound => _t('Store not found', 'स्टोर नहीं मिला', 'સ્ટોર મળ્યો નથી', 'المتجر غير موجود');
  String get storeNotAvailableTitle => _t('This store is not available', 'यह स्टोर उपलब्ध नहीं है', 'આ સ્ટોર ઉપલબ્ધ નથી', 'هذا المتجر غير متاح');
  String get storeClosedMessage => _t('It may be closed or under review.', 'हो सकता है यह बंद हो या इसकी समीक्षा चल रही हो।', 'કદાચ તે બંધ હોય અથવા તેની સમીક્ષા ચાલી રહી હોય.',
      'ربما يكون مغلقًا أو قيد المراجعة.');
  String storeSeoDescription(String name, int count) => _t(
        'Shop $name on Go4Market. ${productsCount(count)} with quick delivery.',
        'Go4Market पर $name से खरीदारी करें। क्विक डिलीवरी के साथ ${productsCount(count)}।',
        'Go4Market પર $name પરથી ખરીદી કરો. ક્વિક ડિલિવરી સાથે ${productsCount(count)}.',
        'تسوّق من $name على Go4Market. ${productsCount(count)} مع توصيل سريع.',
      );
  String get stores => _t('Stores', 'स्टोर', 'સ્ટોર', 'المتاجر');
  String storeBanner(String name) => _t('$name banner', '$name बैनर', '$name બેનર', 'لافتة $name');
  String storeLogo(String name) => _t('$name logo', '$name लोगो', '$name લોગો', 'شعار $name');
  String shopOnGo4Market(String name) => _t('Shop $name on Go4Market', 'Go4Market पर $name से खरीदारी करें', 'Go4Market પર $name પરથી ખરીદી કરો', 'تسوّق من $name على Go4Market');
  String get storeLinkCopied => _t('Store link copied', 'स्टोर लिंक कॉपी हो गया', 'સ્ટોર લિંક કૉપિ થઈ', 'تم نسخ رابط المتجر');
  String get shareStore => _t('Share store', 'स्टोर शेयर करें', 'સ્ટોર શેર કરો', 'مشاركة المتجر');
  String get noProductsYet => _t('No products yet', 'अभी कोई प्रोडक्ट नहीं', 'હજી કોઈ પ્રોડક્ટ નથી', 'لا توجد منتجات بعد');
  String stockingUp(String name) => _t('$name is stocking up. Check back soon.', '$name अपना स्टॉक भर रहा है। जल्द ही फिर देखें।', '$name પોતાનો સ્ટોક ભરી રહ્યું છે. જલદી ફરી જુઓ.',
      'يعمل $name على تجهيز مخزونه. عُد قريبًا.');

  // ---------------------------------------------------------------- wishlist
  String get yourWishlist => _t('Your wishlist', 'आपकी विशलिस्ट', 'તમારી વિશલિસ્ટ', 'قائمة أمنياتك');
  String savedCount(int n) => _t('${_n(n)} saved', '${_n(n)} सेव किए गए', '${_n(n)} સેવ કરેલ', 'المحفوظ: ${_n(n)}');
  String get nothingSaved => _t('Nothing saved yet', 'अभी तक कुछ सेव नहीं किया', 'હજી સુધી કંઈ સેવ કર્યું નથી', 'لم تحفظ أي شيء بعد');
  String get tapHeart => _t(
        'Tap the heart on any product to keep it here for later.',
        'किसी भी प्रोडक्ट पर दिल के निशान पर टैप करें, ताकि वह बाद के लिए यहाँ सेव रहे।',
        'કોઈ પણ પ્રોડક્ટ પર હૃદયના નિશાન પર ટૅપ કરો, જેથી તે પછી માટે અહીં સેવ રહે.',
        'اضغط على رمز القلب في أي منتج لحفظه هنا لوقت لاحق.',
      );
  String get exploreProducts => _t('Explore products', 'प्रोडक्ट देखें', 'પ્રોડક્ટ જુઓ', 'استكشف المنتجات');
}

extension CatalogStringsL on L {
  CatalogStrings get catalog => CatalogStrings(this);
}
