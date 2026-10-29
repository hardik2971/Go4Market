import 'l10n.dart';

/// Strings for the product area. Each getter returns the active language: tr(en, hi, gu, ar).
class ProductStrings {
  const ProductStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  /// Arabic number agreement: 1 / 2 (dual) / 3-10 (plural) / 11+ (singular accusative).
  static String _ar(int n, String one, String two, String few, String many) {
    if (n == 1) return one;
    if (n == 2) return two;
    final m = n % 100;
    return (m >= 3 && m <= 10) ? few : many;
  }

  // ---------------------------------------------------------------- page states + SEO
  String get loadError => _t('This product could not load', 'यह प्रोडक्ट लोड नहीं हो सका', 'આ પ્રોડક્ટ લોડ થઈ શક્યું નહીં', 'تعذّر تحميل هذا المنتج');
  String get notFoundTitle => _t('Product not found', 'प्रोडक्ट नहीं मिला', 'પ્રોડક્ટ મળ્યું નથી', 'المنتج غير موجود');
  String get notAvailable => _t('This product is not available', 'यह प्रोडक्ट उपलब्ध नहीं है', 'આ પ્રોડક્ટ ઉપલબ્ધ નથી', 'هذا المنتج غير متوفر');
  String get notAvailableBody => _t('It may have sold out or been removed.', 'हो सकता है यह बिक गया हो या हटा दिया गया हो।',
      'કદાચ તે વેચાઈ ગયું હોય અથવા હટાવી દેવાયું હોય.', 'ربما نفدت الكمية أو تمت إزالته.');
  String get findSimilar => _t('Find similar products', 'मिलते-जुलते प्रोडक्ट खोजें', 'મળતાં આવતાં પ્રોડક્ટ શોધો', 'ابحث عن منتجات مشابهة');
  String seoDescription(String name, String price) => _t(
        'Buy $name online at $price on Go4Market with quick delivery.',
        'Go4Market पर $name ऑनलाइन सिर्फ़ $price में खरीदें, क्विक डिलीवरी के साथ।',
        'Go4Market પર $name ઑનલાઇન માત્ર $price માં ખરીદો, ક્વિક ડિલિવરી સાથે.',
        'اشترِ $name أونلاين بسعر $price على Go4Market مع توصيل سريع.',
      );

  // ---------------------------------------------------------------- rails
  String get similarProducts => _t('Similar products', 'मिलते-जुलते प्रोडक्ट', 'મળતાં આવતાં પ્રોડક્ટ', 'منتجات مشابهة');
  String get inStockAlternatives => _t('In-stock alternatives', 'स्टॉक में उपलब्ध विकल्प', 'સ્ટૉકમાં ઉપલબ્ધ વિકલ્પો', 'بدائل متوفرة');
  String moreFrom(String category) => _t('More from $category', '$category में और देखें', '$category માં વધુ જુઓ', 'المزيد من $category');
  String get moreFromThisCategory =>
      _t('More from this category', 'इस श्रेणी में और देखें', 'આ શ્રેણીમાં વધુ જુઓ', 'المزيد من هذه الفئة');
  String get completeBasket => _t('Complete your basket', 'अपनी टोकरी पूरी करें', 'તમારી બાસ્કેટ પૂરી કરો', 'أكمل سلتك');
  String get boughtTogether =>
      _t('Frequently bought together', 'अक्सर साथ खरीदे जाते हैं', 'ઘણીવાર સાથે ખરીદાય છે', 'يُشترى معًا غالبًا');
  String get recentlyViewed => _t('Recently viewed', 'हाल ही में देखे गए', 'તાજેતરમાં જોયેલા', 'شوهد مؤخرًا');

  // ---------------------------------------------------------------- info
  String get vegetarian => _t('Vegetarian', 'शाकाहारी', 'શાકાહારી', 'نباتي');
  String get nonVegetarian => _t('Non-vegetarian', 'मांसाहारी', 'માંસાહારી', 'غير نباتي');
  String soldCount(String n) => _t('$n+ sold', '$n+ बिक चुके', '$n+ વેચાયા', 'بيع منه $n+');
  String ratingsCount(int n, String formatted) => _t(
        n == 1 ? '1 rating' : '$formatted ratings',
        '$formatted रेटिंग',
        '$formatted રેટિંગ',
        _ar(n, 'تقييم واحد', 'تقييمان', '$formatted تقييمات', '$formatted تقييمًا'),
      );
  String get inclusiveTaxes => _t('Inclusive of all taxes', 'सभी टैक्स शामिल', 'બધા ટૅક્સ સહિત', 'شامل جميع الضرائب');
  String youSave(String amount) => _t('You save $amount · Inclusive of all taxes', 'आपकी बचत $amount · सभी टैक्स शामिल',
      'તમારી બચત $amount · બધા ટૅક્સ સહિત', 'توفّر $amount · شامل جميع الضرائب');
  String get chooseOption => _t('Choose an option', 'एक विकल्प चुनें', 'એક વિકલ્પ પસંદ કરો', 'اختر خيارًا');
  String variantLabel(String name, String price, bool outOfStock) => outOfStock
      ? _t('$name, $price, out of stock', '$name, $price, स्टॉक में नहीं', '$name, $price, સ્ટૉકમાં નથી', '$name، $price، غير متوفر')
      : _t('$name, $price', '$name, $price', '$name, $price', '$name، $price');
  String get outOfStock => _t('Out of stock', 'स्टॉक में नहीं', 'સ્ટૉકમાં નથી', 'نفدت الكمية');
  String get inStock => _t('In stock', 'स्टॉक में है', 'સ્ટૉકમાં છે', 'متوفر');
  String onlyLeft(int n) => _t(
        'Hurry, only $n left',
        'जल्दी करें, सिर्फ़ $n बचे हैं',
        'જલદી કરો, માત્ર $n બાકી છે',
        _ar(n, 'أسرع، بقيت قطعة واحدة فقط', 'أسرع، بقيت قطعتان فقط', 'أسرع، بقيت $n قطع فقط', 'أسرع، بقيت $n قطعة فقط'),
      );
  String get customise => _t('Customise it', 'अपने हिसाब से बनाएँ', 'તમારી રીતે બનાવો', 'خصّصه');
  String get addExtras => _t('Add extras and modifiers', 'एक्स्ट्रा और बदलाव जोड़ें', 'એક્સ્ટ્રા અને ફેરફારો ઉમેરો', 'أضف الإضافات والتعديلات');
  String get addedToCart => _t('Added to cart', 'कार्ट में जोड़ दिया', 'કાર્ટમાં ઉમેર્યું', 'تمت الإضافة إلى السلة');
  String get viewCart => _t('View cart', 'कार्ट देखें', 'કાર્ટ જુઓ', 'عرض السلة');
  String addToCartFor(String price) =>
      _t('Add to cart · $price', 'कार्ट में जोड़ें · $price', 'કાર્ટમાં ઉમેરો · $price', 'أضف إلى السلة · $price');
  String get share => _t('Share', 'शेयर करें', 'શેર કરો', 'مشاركة');
  String shareText(String name) =>
      _t('Check out $name on Go4Market', 'Go4Market पर $name देखें', 'Go4Market પર $name જુઓ', 'اطّلع على $name على Go4Market');
  String get linkCopied => _t('Link copied', 'लिंक कॉपी हो गया', 'લિંક કૉપિ થઈ ગઈ', 'تم نسخ الرابط');
  String get subscribeRegularly =>
      _t('Subscribe & get it regularly', 'सब्सक्राइब करें और नियमित रूप से पाएँ', 'સબ્સ્ક્રાઇબ કરો અને નિયમિત મેળવો', 'اشترك واحصل عليه بانتظام');

  // ---------------------------------------------------------------- perks
  String quickDelivery(int minutes) => _t('Quick delivery in $minutes minutes', '$minutes मिनट में क्विक डिलीवरी', '$minutes મિનિટમાં ક્વિક ડિલિવરી',
      'توصيل سريع خلال $minutes دقيقة');
  String deliveredAbout(int minutes) => _t(
        'Delivered in about $minutes minutes',
        'लगभग $minutes मिनट में डिलीवरी',
        'આશરે $minutes મિનિટમાં ડિલિવરી',
        _ar(minutes, 'يصلك خلال دقيقة تقريبًا', 'يصلك خلال دقيقتين تقريبًا', 'يصلك خلال $minutes دقائق تقريبًا', 'يصلك خلال $minutes دقيقة تقريبًا'),
      );
  String get etaNote => _t('Exact ETA is calculated at checkout from your address', 'सही डिलीवरी समय चेकआउट पर आपके पते से तय होता है',
      'ચોક્કસ ડિલિવરી સમય ચેકઆઉટ વખતે તમારા સરનામા પરથી નક્કી થાય છે', 'يُحسب موعد الوصول الدقيق عند إتمام الشراء بناءً على عنوانك');
  String freeDeliveryAbove(String amount) =>
      _t('Free delivery above $amount', '$amount से ऊपर फ़्री डिलीवरी', '$amount થી વધુ પર ફ્રી ડિલિવરી', 'توصيل مجاني للطلبات فوق $amount');
  String get scheduledSlot => _t('Or choose a scheduled slot that suits you', 'या अपनी सुविधा का डिलीवरी स्लॉट चुनें',
      'અથવા તમારી અનુકૂળતાનો ડિલિવરી સ્લોટ પસંદ કરો', 'أو اختر موعد توصيل يناسبك');
  String get standardDelivery => _t('Standard delivery available', 'स्टैंडर्ड डिलीवरी उपलब्ध', 'સ્ટાન્ડર્ડ ડિલિવરી ઉપલબ્ધ', 'التوصيل العادي متاح');
  String get selfPickup => _t('Self pickup available', 'ख़ुद पिकअप की सुविधा उपलब्ध', 'જાતે પિકઅપની સુવિધા ઉપલબ્ધ', 'الاستلام من المتجر متاح');
  String get pickupBody => _t('Collect from the store at your convenience', 'अपनी सुविधा से स्टोर से ले जाएँ', 'તમારી અનુકૂળતાએ સ્ટોરમાંથી લઈ જાઓ',
      'استلم طلبك من المتجر في الوقت الذي يناسبك');

  // ---------------------------------------------------------------- seller
  String get soldBy => _t('Sold by', 'विक्रेता', 'વિક્રેતા', 'يبيعه');
  String sellerRating(String rating, String city) {
    final c = city.isEmpty ? '' : ' · $city';
    return _t('$rating seller rating$c', '$rating विक्रेता रेटिंग$c', '$rating વિક્રેતા રેટિંગ$c', 'تقييم البائع $rating$c');
  }

  String logoOf(String name) => _t('$name logo', '$name का लोगो', '$name નો લોગો', 'شعار $name');
  String visitStore(String name) => _t('Visit $name store', '$name स्टोर पर जाएँ', '$name સ્ટોરની મુલાકાત લો', 'زيارة متجر $name');

  // ---------------------------------------------------------------- gallery
  String openViewer(String name) =>
      _t('Open image viewer for $name', '$name की तस्वीरें बड़ी करके देखें', '$name ના ફોટા મોટા કરીને જુઓ', 'فتح عارض الصور لـ $name');
  String showImage(int n) => _t('Show image $n', 'तस्वीर $n दिखाएँ', 'ફોટો $n બતાવો', 'عرض الصورة $n');
  String get closeViewer => _t('Close viewer', 'व्यूअर बंद करें', 'વ્યૂઅર બંધ કરો', 'إغلاق العارض');
  String get previousImage => _t('Previous image', 'पिछली तस्वीर', 'પાછલો ફોટો', 'الصورة السابقة');
  String get nextImage => _t('Next image', 'अगली तस्वीर', 'આગલો ફોટો', 'الصورة التالية');

  // ---------------------------------------------------------------- details
  String get brand => _t('Brand', 'ब्रांड', 'બ્રાન્ડ', 'العلامة التجارية');
  String get packSize => _t('Pack size', 'पैक साइज़', 'પૅક સાઇઝ', 'حجم العبوة');
  String get dietary => _t('Dietary', 'आहार', 'આહાર', 'النظام الغذائي');
  String get aboutProduct => _t('About this product', 'इस प्रोडक्ट के बारे में', 'આ પ્રોડક્ટ વિશે', 'عن هذا المنتج');
  String get noDescription => _t('The seller has not added a description yet.', 'विक्रेता ने अभी तक विवरण नहीं जोड़ा है।',
      'વિક્રેતાએ હજી સુધી વર્ણન ઉમેર્યું નથી.', 'لم يُضِف البائع وصفًا بعد.');
  String get specifications => _t('Specifications', 'स्पेसिफ़िकेशन', 'સ્પષ્ટીકરણો', 'المواصفات');

  // ---------------------------------------------------------------- reviews
  String get ratingsReviews => _t('Ratings & reviews', 'रेटिंग और समीक्षाएँ', 'રેટિંગ અને રિવ્યૂ', 'التقييمات والمراجعات');
  String get rateProduct => _t('Rate this product', 'इस प्रोडक्ट को रेट करें', 'આ પ્રોડક્ટને રેટ કરો', 'قيّم هذا المنتج');
  String get reviewsOpenTo => _t('Reviews are open to shoppers who received this item.', 'जिन ग्राहकों को यह आइटम मिल चुका है, वही समीक्षा लिख सकते हैं।',
      'જે ગ્રાહકોને આ આઇટમ મળી ચૂકી છે, તેઓ જ રિવ્યૂ લખી શકે છે.', 'يمكن للمتسوقين الذين استلموا هذا المنتج كتابة مراجعة.');
  String get signInToReview => _t('Sign in to write a review', 'समीक्षा लिखने के लिए साइन इन करें', 'રિવ્યૂ લખવા માટે સાઇન ઇન કરો', 'سجّل الدخول لكتابة مراجعة');
  String stars(int n) => _t(
        n == 1 ? '1 star' : '$n stars',
        '$n स्टार',
        '$n સ્ટાર',
        _ar(n, 'نجمة واحدة', 'نجمتان', '$n نجوم', '$n نجمة'),
      );
  String get reviewHint => _t('What did you like or dislike?', 'आपको क्या पसंद आया या क्या नहीं?', 'તમને શું ગમ્યું કે શું ન ગમ્યું?', 'ما الذي أعجبك أو لم يعجبك؟');
  String get yourReview => _t('Your review', 'आपकी समीक्षा', 'તમારો રિવ્યૂ', 'مراجعتك');
  String get submitReview => _t('Submit review', 'समीक्षा भेजें', 'રિવ્યૂ મોકલો', 'إرسال المراجعة');
  String get tapStars => _t('Tap the stars to rate', 'रेटिंग देने के लिए स्टार पर टैप करें', 'રેટિંગ આપવા માટે સ્ટાર પર ટૅપ કરો', 'اضغط على النجوم للتقييم');
  String get reviewLive => _t('Thanks! Your review is live.', 'धन्यवाद! आपकी समीक्षा प्रकाशित हो गई है।', 'આભાર! તમારો રિવ્યૂ પ્રકાશિત થઈ ગયો છે.', 'شكرًا! تم نشر مراجعتك.');
  String get noReviews => _t('No reviews yet. Be the first to share your experience.', 'अभी कोई समीक्षा नहीं है। अपना अनुभव शेयर करने वाले पहले व्यक्ति बनें।',
      'હજી કોઈ રિવ્યૂ નથી. તમારો અનુભવ શેર કરનાર પહેલા બનો.', 'لا توجد مراجعات بعد. كن أول من يشارك تجربته.');

  /// Avatar initial when a reviewer has no name ("Customer").
  String get customerInitial => _t('C', 'ग', 'ગ', 'ع');

  // ---------------------------------------------------------------- subscriptions
  String get signInForSubscription => _t('Sign in to set up a subscription', 'सब्सक्रिप्शन शुरू करने के लिए साइन इन करें',
      'સબ્સ્ક્રિપ્શન શરૂ કરવા માટે સાઇન ઇન કરો', 'سجّل الدخول لإعداد اشتراك');
  String get subscribeTitle => _t('Subscribe & relax', 'सब्सक्राइब करें और बेफ़िक्र रहें', 'સબ્સ્ક્રાઇબ કરો અને નિશ્ચિંત રહો', 'اشترك وارتَح');
  String get howOften => _t('How often?', 'कितनी बार?', 'કેટલી વાર?', 'كم مرة؟');
  String get daily => _t('Daily', 'रोज़', 'રોજ', 'يوميًا');
  String get weekly => _t('Weekly', 'हर हफ़्ते', 'દર અઠવાડિયે', 'أسبوعيًا');
  String get monthly => _t('Monthly', 'हर महीने', 'દર મહિને', 'شهريًا');
  String get quantity => _t('Quantity', 'मात्रा', 'જથ્થો', 'الكمية');
  String get decrease => _t('Decrease', 'कम करें', 'ઘટાડો', 'إنقاص');
  String get increase => _t('Increase', 'बढ़ाएँ', 'વધારો', 'زيادة');
  String get subscribeNote => _t(
        'Orders are placed automatically to your default address and paid from your wallet. Pause or cancel anytime from your account.',
        'ऑर्डर अपने-आप आपके डिफ़ॉल्ट पते पर दिए जाते हैं और भुगतान आपके वॉलेट से होता है। अपने खाते से कभी भी रोकें या रद्द करें।',
        'ઓર્ડર આપમેળે તમારા ડિફૉલ્ટ સરનામા પર મુકાય છે અને ચુકવણી તમારા વૉલેટમાંથી થાય છે. તમારા એકાઉન્ટમાંથી ગમે ત્યારે થોભાવો કે રદ કરો.',
        'تُرسَل الطلبات تلقائيًا إلى عنوانك الافتراضي وتُدفع من محفظتك. يمكنك الإيقاف المؤقت أو الإلغاء في أي وقت من حسابك.',
      );
  String get subscribe => _t('Subscribe', 'सब्सक्राइब करें', 'સબ્સ્ક્રાઇબ કરો', 'اشترك');
  String get subscribed => _t('Subscribed! First delivery is tomorrow.', 'सब्सक्राइब हो गया! पहली डिलीवरी कल होगी।',
      'સબ્સ્ક્રાઇબ થઈ ગયું! પહેલી ડિલિવરી આવતીકાલે થશે.', 'تم الاشتراك! أول توصيل غدًا.');
  String get manage => _t('Manage', 'मैनेज करें', 'મેનેજ કરો', 'إدارة');
}

extension ProductStringsL on L {
  ProductStrings get product => ProductStrings(this);
}
