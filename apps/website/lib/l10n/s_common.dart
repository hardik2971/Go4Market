import 'l10n.dart';

/// Shared strings: header, footer, navigation, the UI kit, gates, language picker and push prompts.
class CommonStrings {
  const CommonStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);
  String _k(String key, String en, String hi, String gu, String ar) => _l.k(key, en, hi, gu, ar);

  // ---------------------------------------------------------------- SEO defaults
  String get seoDefaultTitle => _t(
        'Go4Market: groceries, pharmacy, food and more, delivered fast',
        'Go4Market: किराना, दवाइयाँ, खाना और बहुत कुछ, तेज़ डिलीवरी के साथ',
        'Go4Market: કરિયાણું, દવાઓ, ભોજન અને ઘણું બધું, ઝડપી ડિલિવરી સાથે',
        'Go4Market: البقالة والصيدلية والطعام والمزيد، بتوصيل سريع',
      );
  String get seoDefaultDescription => _t(
        'Shop groceries, medicines, food and everyday essentials from trusted local sellers on Go4Market. 15 and 30 minute quick delivery, scheduled slots, wallet, COD and secure online payments.',
        'Go4Market पर भरोसेमंद स्थानीय विक्रेताओं से किराना, दवाइयाँ, खाना और रोज़मर्रा की ज़रूरतें खरीदें। 15 और 30 मिनट में क्विक डिलीवरी, शेड्यूल्ड स्लॉट, वॉलेट, कैश ऑन डिलीवरी और सुरक्षित ऑनलाइन भुगतान।',
        'Go4Market પર વિશ્વસનીય સ્થાનિક વિક્રેતાઓ પાસેથી કરિયાણું, દવાઓ, ભોજન અને રોજિંદી જરૂરિયાતો ખરીદો. 15 અને 30 મિનિટમાં ક્વિક ડિલિવરી, શેડ્યૂલ સ્લોટ, વૉલેટ, કૅશ ઑન ડિલિવરી અને સુરક્ષિત ઑનલાઇન ચુકવણી.',
        'تسوّق البقالة والأدوية والطعام والاحتياجات اليومية من بائعين محليين موثوقين على Go4Market. توصيل سريع خلال 15 و30 دقيقة، ومواعيد مجدولة، ومحفظة، والدفع عند الاستلام، ومدفوعات إلكترونية آمنة.',
      );

  // ---------------------------------------------------------------- generic
  String get retry => _t('Try again', 'फिर से कोशिश करें', 'ફરી પ્રયાસ કરો', 'حاول مرة أخرى');
  String get close => _t('Close', 'बंद करें', 'બંધ કરો', 'إغلاق');
  String get cancel => _t('Cancel', 'रद्द करें', 'રદ કરો', 'إلغاء');
  String get save => _t('Save', 'सेव करें', 'સેવ કરો', 'حفظ');
  String get continueLabel => _t('Continue', 'जारी रखें', 'આગળ વધો', 'متابعة');
  String get skip => _t('Skip for now', 'अभी छोड़ें', 'હમણાં છોડો', 'تخطَّ الآن');
  String get copied => _t('Copied', 'कॉपी हो गया', 'કૉપિ થયું', 'تم النسخ');
  String get viewAll => _t('View all', 'सभी देखें', 'બધું જુઓ', 'عرض الكل');
  String viewAllOf(String title) => _t('View all $title', 'सभी $title देखें', 'બધા $title જુઓ', 'عرض كل $title');
  String off(int pct) => _t('$pct% off', '$pct% छूट', '$pct% છૂટ', 'خصم $pct%');
  String mrpLabel(String price) => _t('M R P $price', 'एम आर पी $price', 'એમ આર પી $price', 'السعر الأصلي $price');
  String get loadErrorTitle => _t('We could not load this right now', 'अभी इसे लोड नहीं कर सके', 'અત્યારે આ લોડ કરી શક્યા નથી', 'تعذّر تحميل هذا الآن');
  String get catalogWarming => _t('Our catalogue is warming up. Please try again in a minute.', 'हमारा कैटलॉग तैयार हो रहा है। कृपया एक मिनट बाद फिर कोशिश करें।',
      'અમારું કૅટલૉગ તૈયાર થઈ રહ્યું છે. કૃપા કરી એક મિનિટ પછી ફરી પ્રયાસ કરો.', 'الكتالوج قيد التجهيز. يُرجى المحاولة مرة أخرى بعد دقيقة.');
  String get notAvailableYet => _t('This content is not available yet.', 'यह सामग्री अभी उपलब्ध नहीं है।', 'આ સામગ્રી હજી ઉપલબ્ધ નથી.', 'هذا المحتوى غير متاح بعد.');
  String get networkError => _t('Network error. Check your connection.', 'नेटवर्क त्रुटि। अपना कनेक्शन जाँचें।', 'નેટવર્ક ભૂલ. તમારું કનેક્શન તપાસો.', 'خطأ في الشبكة. تحقّق من اتصالك.');
  String get signInForCart => _t('Please sign in to use the cart.', 'कार्ट इस्तेमाल करने के लिए कृपया साइन इन करें।', 'કાર્ટ વાપરવા માટે કૃપા કરી સાઇન ઇન કરો.', 'يُرجى تسجيل الدخول لاستخدام السلة.');
  String get signInToSave => _t('Please sign in to save items.', 'आइटम सेव करने के लिए कृपया साइन इन करें।', 'આઇટમ સેવ કરવા માટે કૃપા કરી સાઇન ઇન કરો.', 'يُرجى تسجيل الدخول لحفظ المنتجات.');

  // ---------------------------------------------------------------- navigation
  String get navHome => _k('home', 'Home', 'होम', 'હોમ', 'الرئيسية');
  String get navBrowse => _t('Browse', 'ब्राउज़', 'બ્રાઉઝ', 'تصفّح');
  String get navCart => _k('cart', 'Cart', 'कार्ट', 'કાર્ટ', 'السلة');
  String get navOrders => _k('orders', 'Orders', 'ऑर्डर', 'ઓર્ડર', 'الطلبات');
  String get navAccount => _k('account', 'Account', 'खाता', 'એકાઉન્ટ', 'الحساب');
  String get homeLink => _t('Go4Market home', 'Go4Market होम', 'Go4Market હોમ', 'الصفحة الرئيسية لـ Go4Market');
  String get wishlist => _t('Wishlist', 'विशलिस्ट', 'વિશલિસ્ટ', 'قائمة الأمنيات');
  String get myOrders => _t('My orders', 'मेरे ऑर्डर', 'મારા ઓર્ડર', 'طلباتي');
  String get myAccount => _t('My account', 'मेरा खाता', 'મારું એકાઉન્ટ', 'حسابي');
  String get wallet => _k('wallet', 'Wallet', 'वॉलेट', 'વૉલેટ', 'المحفظة');
  String get referAndEarn => _t('Refer & earn', 'रेफ़र करें और कमाएँ', 'રેફર કરો અને કમાઓ', 'ادعُ واربح');
  String get signIn => _t('Sign in', 'साइन इन करें', 'સાઇન ઇન કરો', 'تسجيل الدخول');
  String get signOut => _t('Sign out', 'साइन आउट करें', 'સાઇન આઉટ કરો', 'تسجيل الخروج');
  String get createAccount => _t('Create account', 'खाता बनाएँ', 'એકાઉન્ટ બનાવો', 'إنشاء حساب');
  String get accountMenu => _t('Account menu', 'खाता मेनू', 'એકાઉન્ટ મેનુ', 'قائمة الحساب');
  String hi(String name) => _t('Hi, $name', 'नमस्ते, $name', 'નમસ્તે, $name', 'مرحبًا، $name');
  String cartItems(int n) => _t('Cart, $n items', 'कार्ट, $n आइटम', 'કાર્ટ, $n આઇટમ', 'السلة، $n منتجات');
  String get all => _t('All', 'सभी', 'બધું', 'الكل');
  String storeOf(String name) => _t('$name store', '$name स्टोर', '$name સ્ટોર', 'متجر $name');
  String get blog => _t('Blog', 'ब्लॉग', 'બ્લૉગ', 'المدونة');
  String get helpFaq => _t('Help & FAQ', 'मदद और FAQ', 'મદદ અને FAQ', 'المساعدة والأسئلة الشائعة');
  String get sellOnGo4Market => _t('Sell on Go4Market', 'Go4Market पर बेचें', 'Go4Market પર વેચો', 'بِع على Go4Market');
  String get menu => _t('Menu', 'मेनू', 'મેનુ', 'القائمة');
  String get openMenu => _t('Open menu', 'मेनू खोलें', 'મેનુ ખોલો', 'فتح القائمة');
  String get maintenance => _t(
        'We are doing some quick maintenance. You can browse, but checkout is paused for a few minutes.',
        'हम थोड़ा रखरखाव कर रहे हैं। आप ब्राउज़ कर सकते हैं, लेकिन चेकआउट कुछ मिनटों के लिए रुका है।',
        'અમે થોડું મેન્ટેનન્સ કરી રહ્યા છીએ. તમે બ્રાઉઝ કરી શકો છો, પણ ચેકઆઉટ થોડી મિનિટો માટે બંધ છે.',
        'نجري صيانة سريعة. يمكنك التصفح، لكن إتمام الشراء متوقف لبضع دقائق.',
      );

  // ---------------------------------------------------------------- search + voice
  List<String> get searchHints => [
        _t('Search "fresh milk"', '"ताज़ा दूध" खोजें', '"તાજું દૂધ" શોધો', 'ابحث عن "حليب طازج"'),
        _t('Search "paracetamol"', '"पैरासिटामोल" खोजें', '"પેરાસિટામોલ" શોધો', 'ابحث عن "باراسيتامول"'),
        _t('Search "biryani"', '"बिरयानी" खोजें', '"બિરયાની" શોધો', 'ابحث عن "برياني"'),
        _t('Search "wireless earbuds"', '"वायरलेस ईयरबड्स" खोजें', '"વાયરલેસ ઇયરબડ્સ" શોધો', 'ابحث عن "سماعات لاسلكية"'),
        _t('Try "milk, bread and eggs"', '"दूध, ब्रेड और अंडे" आज़माएँ', '"દૂધ, બ્રેડ અને ઈંડાં" અજમાવો', 'جرّب "حليب وخبز وبيض"'),
      ];
  String get searchLabel => _t('Search products', 'प्रोडक्ट खोजें', 'પ્રોડક્ટ શોધો', 'ابحث عن المنتجات');
  String get searchByVoice => _t('Search by voice', 'आवाज़ से खोजें', 'અવાજથી શોધો', 'البحث الصوتي');

  // ---------------------------------------------------------------- location
  String get chooseCity => _t('Choose your city', 'अपना शहर चुनें', 'તમારું શહેર પસંદ કરો', 'اختر مدينتك');
  String get chooseDeliveryCity => _t('Choose your delivery city', 'डिलीवरी का शहर चुनें', 'ડિલિવરીનું શહેર પસંદ કરો', 'اختر مدينة التوصيل');
  String deliveringTo(String city) => _t('Delivering to $city', '$city में डिलीवरी', '$city માં ડિલિવરી', 'التوصيل إلى $city');
  String deliveringToChange(String city) =>
      _t('Delivering to $city. Change city', '$city में डिलीवरी। शहर बदलें', '$city માં ડિલિવરી. શહેર બદલો', 'التوصيل إلى $city. تغيير المدينة');
  String get deliverTo => _k('deliver_to', 'Deliver to', 'यहाँ डिलीवर करें', 'અહીં ડિલિવર કરો', 'التوصيل إلى');
  String get selectCity => _t('Select city', 'शहर चुनें', 'શહેર પસંદ કરો', 'اختر المدينة');
  String get whereDeliver => _t('Where should we deliver?', 'हम कहाँ डिलीवर करें?', 'અમે ક્યાં ડિલિવર કરીએ?', 'إلى أين نوصّل طلبك؟');
  String get whereDeliverSub => _t('We show stores and delivery times available in your city.', 'हम आपके शहर में उपलब्ध स्टोर और डिलीवरी समय दिखाते हैं।',
      'અમે તમારા શહેરમાં ઉપલબ્ધ સ્ટોર અને ડિલિવરી સમય બતાવીએ છીએ.', 'نعرض المتاجر وأوقات التوصيل المتاحة في مدينتك.');
  String get useMyLocation => _t('Use my current location', 'मेरी मौजूदा लोकेशन इस्तेमाल करें', 'મારું વર્તમાન લોકેશન વાપરો', 'استخدم موقعي الحالي');
  String get locationDenied => _t('Location permission was not granted', 'लोकेशन की अनुमति नहीं मिली', 'લોકેશનની પરવાનગી મળી નથી', 'لم يتم منح إذن الموقع');
  String get citiesSoon => _t('Cities will appear here once they are configured.', 'शहर सेट होते ही यहाँ दिखेंगे।', 'શહેરો સેટ થતાં જ અહીં દેખાશે.', 'ستظهر المدن هنا بمجرد إعدادها.');
  String get showAllCities => _t('Show all cities', 'सभी शहर दिखाएँ', 'બધાં શહેર બતાવો', 'عرض كل المدن');
  String get closeOffer => _t('Close offer', 'ऑफ़र बंद करें', 'ઑફર બંધ કરો', 'إغلاق العرض');

  // ---------------------------------------------------------------- footer
  String footerAbout(String tagline) => _t(
        '$tagline. Groceries, medicines, food and everyday essentials from trusted local sellers, delivered in as little as 15 minutes.',
        '$tagline। भरोसेमंद स्थानीय विक्रेताओं से किराना, दवाइयाँ, खाना और रोज़मर्रा की ज़रूरतें, सिर्फ़ 15 मिनट में डिलीवर।',
        '$tagline. વિશ્વસનીય સ્થાનિક વિક્રેતાઓ પાસેથી કરિયાણું, દવાઓ, ભોજન અને રોજિંદી જરૂરિયાતો, માત્ર 15 મિનિટમાં ડિલિવર.',
        '$tagline. البقالة والأدوية والطعام والاحتياجات اليومية من بائعين محليين موثوقين، تصلك في غضون 15 دقيقة فقط.',
      );
  String get footerShop => _t('Shop', 'खरीदारी', 'ખરીદી', 'تسوّق');
  String get allCategories => _t('All categories', 'सभी श्रेणियाँ', 'બધી શ્રેણીઓ', 'كل الفئات');
  String get footerHelp => _t('Help', 'मदद', 'મદદ', 'المساعدة');
  String get aboutUs => _t('About us', 'हमारे बारे में', 'અમારા વિશે', 'من نحن');
  String get faqs => _t('FAQs', 'सामान्य प्रश्न', 'વારંવાર પૂછાતા પ્રશ્નો', 'الأسئلة الشائعة');
  String get shippingPolicy => _t('Shipping policy', 'शिपिंग नीति', 'શિપિંગ નીતિ', 'سياسة الشحن');
  String get refundPolicy => _t('Refund policy', 'रिफ़ंड नीति', 'રિફંડ નીતિ', 'سياسة الاسترداد');
  String get cancellationPolicy => _t('Cancellation policy', 'रद्दीकरण नीति', 'રદ કરવાની નીતિ', 'سياسة الإلغاء');
  String get yourAccount => _t('Your account', 'आपका खाता', 'તમારું એકાઉન્ટ', 'حسابك');
  String get referAndEarnLong => _t('Refer and earn', 'रेफ़र करें और कमाएँ', 'રેફર કરો અને કમાઓ', 'ادعُ أصدقاءك واربح');
  String get terms => _t('Terms and conditions', 'नियम और शर्तें', 'નિયમો અને શરતો', 'الشروط والأحكام');
  String get privacy => _t('Privacy policy', 'गोपनीयता नीति', 'ગોપનીયતા નીતિ', 'سياسة الخصوصية');
  String get partnerWithUs => _t('Partner with us', 'हमारे साथ जुड़ें', 'અમારી સાથે જોડાઓ', 'كن شريكًا لنا');
  String get becomeSeller => _t('Become a seller', 'विक्रेता बनें', 'વિક્રેતા બનો', 'كن بائعًا');
  String get becomeRider => _t('Become a delivery partner', 'डिलीवरी पार्टनर बनें', 'ડિલિવરી પાર્ટનર બનો', 'كن شريك توصيل');
  String get requestProduct => _t('Request a product', 'प्रोडक्ट का अनुरोध करें', 'પ્રોડક્ટની વિનંતી કરો', 'اطلب منتجًا');
  String rights(int year, String app) =>
      _t('© $year $app. All rights reserved.', '© $year $app. सर्वाधिकार सुरक्षित।', '© $year $app. સર્વાધિકાર સુરક્ષિત.', '© $year $app. جميع الحقوق محفوظة.');
  String get weAccept => _t('We accept', 'हम स्वीकार करते हैं', 'અમે સ્વીકારીએ છીએ', 'نقبل');
  List<String> get paymentBadges => [
        'UPI',
        _t('Cards', 'कार्ड', 'કાર્ડ', 'البطاقات'),
        'Razorpay',
        'Stripe',
        'PayPal',
        _t('Wallet', 'वॉलेट', 'વૉલેટ', 'المحفظة'),
        _t('Cash on delivery', 'कैश ऑन डिलीवरी', 'કૅશ ઑન ડિલિવરી', 'الدفع عند الاستلام'),
      ];
  String onSocial(String network) => _t('Go4Market on $network', '$network पर Go4Market', '$network પર Go4Market', 'Go4Market على $network');

  // ---------------------------------------------------------------- language picker
  String get language => _t('Language', 'भाषा', 'ભાષા', 'اللغة');
  String languageCurrent(String name) =>
      _t('Language: $name. Change language', 'भाषा: $name। भाषा बदलें', 'ભાષા: $name. ભાષા બદલો', 'اللغة: $name. تغيير اللغة');
  String get chooseLanguage => _t('Choose your language', 'अपनी भाषा चुनें', 'તમારી ભાષા પસંદ કરો', 'اختر لغتك');

  // ---------------------------------------------------------------- gate
  String get gateSignIn => _t('Sign in', 'साइन इन करें', 'સાઇન ઇન કરો', 'تسجيل الدخول');

  // ---------------------------------------------------------------- push prompt
  String get pushTitle => _t('Get order updates', 'ऑर्डर अपडेट पाएँ', 'ઓર્ડર અપડેટ મેળવો', 'احصل على تحديثات الطلب');
  String get pushBody => _t(
        'We will let you know when your order is packed, out for delivery and delivered. No spam.',
        'आपका ऑर्डर पैक होने, डिलीवरी के लिए निकलने और डिलीवर होने पर हम आपको बताएँगे। कोई स्पैम नहीं।',
        'તમારો ઓર્ડર પૅક થાય, ડિલિવરી માટે નીકળે અને ડિલિવર થાય ત્યારે અમે તમને જણાવીશું. કોઈ સ્પામ નહીં.',
        'سنُعلمك عند تجهيز طلبك وخروجه للتوصيل وتسليمه. بلا رسائل مزعجة.',
      );
  String get pushEnable => _t('Turn on', 'चालू करें', 'ચાલુ કરો', 'تفعيل');
  String get pushLater => _t('Not now', 'अभी नहीं', 'હમણાં નહીં', 'ليس الآن');
  String get pushOn => _t('Order updates are on.', 'ऑर्डर अपडेट चालू हैं।', 'ઓર્ડર અપડેટ ચાલુ છે.', 'تم تفعيل تحديثات الطلب.');
  String get pushBlocked => _t('Notifications are blocked in your browser settings.', 'आपके ब्राउज़र की सेटिंग में नोटिफ़िकेशन बंद हैं।',
      'તમારા બ્રાઉઝરના સેટિંગમાં નોટિફિકેશન બંધ છે.', 'الإشعارات محظورة في إعدادات المتصفح.');
  String get pushFailed => _t('Could not turn on notifications. Please try again later.', 'नोटिफ़िकेशन चालू नहीं हो सके। कृपया बाद में फिर कोशिश करें।',
      'નોટિફિકેશન ચાલુ ન થઈ શક્યાં. કૃપા કરી પછી ફરી પ્રયાસ કરો.', 'تعذّر تفعيل الإشعارات. يُرجى المحاولة لاحقًا.');
  String get paymentFailed => _t('Payment failed. Please try another method.', 'भुगतान नहीं हो सका। कृपया कोई दूसरा तरीका आज़माएँ।', 'ચુકવણી નિષ્ફળ ગઈ. કૃપા કરી બીજી રીત અજમાવો.', 'فشل الدفع. يُرجى تجربة طريقة أخرى.');
  String get view => _t('View', 'देखें', 'જુઓ', 'عرض');
}

extension CommonStringsL on L {
  CommonStrings get common => CommonStrings(this);
}
