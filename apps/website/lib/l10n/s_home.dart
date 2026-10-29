import 'l10n.dart';

/// Strings for the home area. Each getter returns the active language: tr(en, hi, gu, ar).
class HomeStrings {
  const HomeStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  // ---------------------------------------------------------------- SEO (module pages)
  String moduleSeoTitle(String module) =>
      _t('$module delivery online', '$module की ऑनलाइन डिलीवरी', '$module ની ઑનલાઇન ડિલિવરી', 'توصيل $module أونلاين');
  String moduleSeoDescription(String module, String tagline) =>
      _t('$module on Go4Market: $tagline', 'Go4Market पर $module: $tagline', 'Go4Market પર $module: $tagline', '$module على Go4Market: $tagline');

  // ---------------------------------------------------------------- hero
  String get heroPill => _t('Grocery · Pharmacy · Food · Everything', 'किराना · फ़ार्मेसी · खाना · सब कुछ', 'કરિયાણું · ફાર્મસી · ભોજન · બધું જ',
      'بقالة · صيدلية · طعام · كل شيء');
  String get heroBody => _t(
        'Fresh groceries, medicines, meals and more from sellers near you.',
        'आपके आस-पास के विक्रेताओं से ताज़ा किराना, दवाइयाँ, खाना और बहुत कुछ।',
        'તમારી નજીકના વિક્રેતાઓ પાસેથી તાજું કરિયાણું, દવાઓ, ભોજન અને ઘણું બધું.',
        'بقالة طازجة وأدوية ووجبات والمزيد من بائعين بالقرب منك.',
      );
  String get startShopping => _t('Start shopping', 'खरीदारी शुरू करें', 'ખરીદી શરૂ કરો', 'ابدأ التسوق');
  String showSlide(int n) => _t('Show slide $n', 'स्लाइड $n दिखाएँ', 'સ્લાઇડ $n બતાવો', 'عرض الشريحة $n');
  String get previousSlide => _t('Previous slide', 'पिछली स्लाइड', 'પાછલી સ્લાઇડ', 'الشريحة السابقة');
  String get nextSlide => _t('Next slide', 'अगली स्लाइड', 'આગલી સ્લાઇડ', 'الشريحة التالية');
  String get featuredOffer => _t('Featured offer', 'ख़ास ऑफ़र', 'ખાસ ઑફર', 'عرض مميز');
  String get offer => _t('Offer', 'ऑफ़र', 'ઑફર', 'عرض');

  // ---------------------------------------------------------------- hero side tiles
  String get quickDelivery => _t('Quick delivery', 'क्विक डिलीवरी', 'ક્વિક ડિલિવરી', 'توصيل سريع');
  String get sameDayDelivery => _t('Same-day delivery', 'उसी दिन डिलीवरी', 'એ જ દિવસે ડિલિવરી', 'توصيل في اليوم نفسه');
  String deliveredInMinutes(String mins) =>
      _t('Delivered in $mins minutes', '$mins मिनट में डिलीवरी', '$mins મિનિટમાં ડિલિવરી', 'التوصيل خلال $mins دقيقة');
  String freeDeliveryAbove(String amount) =>
      _t('Free delivery above $amount', '$amount से ऊपर फ़्री डिलीवरी', '$amount થી વધુ પર ફ્રી ડિલિવરી', 'توصيل مجاني للطلبات فوق $amount');
  String get referAndEarnLink => _t('Refer and earn', 'रेफ़र करें और कमाएँ', 'રેફર કરો અને કમાઓ', 'ادعُ أصدقاءك واربح');
  String get referAndEarn => _t('Refer & earn', 'रेफ़र करें और कमाएँ', 'રેફર કરો અને કમાઓ', 'ادعُ واربح');
  String referReward(String amount) =>
      _t('Get $amount for every friend', 'हर दोस्त पर पाएँ $amount', 'દરેક મિત્ર પર મેળવો $amount', 'احصل على $amount عن كل صديق');

  // ---------------------------------------------------------------- promises
  String minuteDelivery(int mins) => _t('$mins-minute delivery', '$mins मिनट में डिलीवरी', '$mins મિનિટમાં ડિલિવરી', 'توصيل خلال $mins دقيقة');
  String get onEverydayEssentials => _t('On everyday essentials', 'रोज़मर्रा की ज़रूरी चीज़ों पर', 'રોજિંદી જરૂરી વસ્તુઓ પર', 'على الاحتياجات اليومية');
  String get freeDelivery => _t('Free delivery', 'फ़्री डिलीवरी', 'ફ્રી ડિલિવરી', 'توصيل مجاني');
  String onOrdersAbove(String amount) =>
      _t('On orders above $amount', '$amount से ऊपर के ऑर्डर पर', '$amount થી વધુના ઓર્ડર પર', 'على الطلبات فوق $amount');
  String get scheduledSlots => _t('Scheduled slots', 'शेड्यूल्ड स्लॉट', 'શેડ્યૂલ સ્લોટ', 'مواعيد مجدولة');
  String get pickATime => _t('Pick a time that suits you', 'अपनी सुविधा का समय चुनें', 'તમને અનુકૂળ સમય પસંદ કરો', 'اختر الوقت الذي يناسبك');
  String get payYourWay => _t('Pay your way', 'जैसे चाहें भुगतान करें', 'તમારી રીતે ચુકવણી કરો', 'ادفع بطريقتك');
  String get payMethods => _t('UPI, cards, wallet or cash', 'UPI, कार्ड, वॉलेट या कैश', 'UPI, કાર્ડ, વૉલેટ કે રોકડ', 'UPI أو البطاقات أو المحفظة أو نقدًا');

  // ---------------------------------------------------------------- section headers
  String get bestEyebrow => _t('Loved by shoppers', 'ग्राहकों की पसंद', 'ગ્રાહકોની પસંદ', 'المفضّل لدى المتسوقين');
  String get bestTitle => _t('Best sellers', 'सबसे ज़्यादा बिकने वाले', 'સૌથી વધુ વેચાતા', 'الأكثر مبيعًا');
  String get bestSubtitle => _t('The products people keep coming back for', 'वे प्रोडक्ट जिन्हें लोग बार-बार खरीदते हैं',
      'એ પ્રોડક્ટ જે લોકો વારંવાર ખરીદે છે', 'المنتجات التي يعود إليها الناس مرارًا');
  String get browseEyebrow => _t('Browse', 'ब्राउज़ करें', 'બ્રાઉઝ કરો', 'تصفّح');
  String get shopByCategory => _t('Shop by category', 'श्रेणी के अनुसार खरीदें', 'શ્રેણી પ્રમાણે ખરીદો', 'تسوّق حسب الفئة');
  String get shopByCategorySub => _t('Everything you need, neatly organised', 'आपकी ज़रूरत की हर चीज़, सलीके से सजी हुई',
      'તમારી જરૂરિયાતની દરેક વસ્તુ, વ્યવસ્થિત રીતે ગોઠવેલી', 'كل ما تحتاجه، مرتّب بعناية');
  String get freshInEyebrow => _t('Fresh in', 'नया आया', 'નવું આવ્યું', 'وصل حديثًا');
  String get justArrived => _t('Just arrived', 'अभी-अभी आए', 'હમણાં જ આવ્યાં', 'وصل للتو');
  String get justArrivedSub => _t('New products from our sellers this week', 'इस हफ़्ते हमारे विक्रेताओं के नए प्रोडक्ट',
      'આ અઠવાડિયે અમારા વિક્રેતાઓની નવી પ્રોડક્ટ', 'منتجات جديدة من بائعينا هذا الأسبوع');
  String get marketplace => _t('Marketplace', 'मार्केटप्लेस', 'માર્કેટપ્લેસ', 'السوق');
  String nearYouIn(String city) => _t('Near you in $city', '$city में आपके पास', '$city માં તમારી નજીક', 'بالقرب منك في $city');
  String get shopByStore => _t('Shop by store', 'स्टोर के अनुसार खरीदें', 'સ્ટોર પ્રમાણે ખરીદો', 'تسوّق حسب المتجر');
  String get shopByStoreSub => _t('Trusted local sellers, each with their own storefront', 'भरोसेमंद स्थानीय विक्रेता, हर एक का अपना स्टोर',
      'વિશ્વસનીય સ્થાનિક વિક્રેતાઓ, દરેકનો પોતાનો સ્ટોર', 'بائعون محليون موثوقون، لكلٍّ منهم متجره الخاص');
  String storeLogo(String store) => _t('$store logo', '$store का लोगो', '$store નો લોગો', 'شعار $store');
  String productsCount(int n) => n == 1
      ? _t('1 product', '1 प्रोडक्ट', '1 પ્રોડક્ટ', 'منتج واحد')
      : _t('$n products', '$n प्रोडक्ट', '$n પ્રોડક્ટ', switch (n) { 2 => 'منتجان', >= 3 && <= 10 => '$n منتجات', _ => '$n منتجًا' });
  String get dealsEyebrow => _t('Biggest savings today', 'आज की सबसे बड़ी बचत', 'આજની સૌથી મોટી બચત', 'أكبر التوفيرات اليوم');
  String get trendingDeals => _t('Trending deals', 'ट्रेंडिंग डील्स', 'ટ્રેન્ડિંગ ડીલ્સ', 'العروض الرائجة');
  String get trendingDealsSub => _t('Popular products at their lowest prices', 'लोकप्रिय प्रोडक्ट, सबसे कम दामों पर',
      'લોકપ્રિય પ્રોડક્ટ, સૌથી ઓછા ભાવે', 'منتجات شائعة بأقل أسعارها');
  String get recentEyebrow => _t('Pick up where you left off', 'जहाँ छोड़ा था, वहीं से शुरू करें', 'જ્યાં છોડ્યું હતું ત્યાંથી આગળ વધો', 'تابع من حيث توقفت');
  String get recentlyViewed => _t('Recently viewed', 'हाल ही में देखे गए', 'તાજેતરમાં જોયેલાં', 'شوهدت مؤخرًا');
  String get journalEyebrow => _t('From the journal', 'हमारे ब्लॉग से', 'અમારા બ્લૉગમાંથી', 'من المدونة');
  String get journalTitle => _t('Tips, recipes and guides', 'टिप्स, रेसिपी और गाइड', 'ટિપ્સ, રેસિપી અને ગાઇડ', 'نصائح ووصفات وأدلة');
  String get readArticle => _t('Read article →', 'लेख पढ़ें →', 'લેખ વાંચો →', 'اقرأ المقال ←');

  // ---------------------------------------------------------------- app band
  String get appPill => _t('Go4Market app', 'Go4Market ऐप', 'Go4Market ઍપ', 'تطبيق Go4Market');
  String get appTitle => _t('Shop faster on the app', 'ऐप पर और तेज़ी से खरीदें', 'ઍપ પર વધુ ઝડપથી ખરીદો', 'تسوّق أسرع عبر التطبيق');
  String get appBody => _t(
        'Live rider tracking, voice search for your whole list, instant reorders and app-only offers.',
        'राइडर की लाइव ट्रैकिंग, पूरी लिस्ट के लिए वॉइस सर्च, झटपट दोबारा ऑर्डर और सिर्फ़ ऐप पर मिलने वाले ऑफ़र।',
        'રાઇડરનું લાઇવ ટ્રૅકિંગ, આખી યાદી માટે વૉઇસ સર્ચ, તરત ફરી ઓર્ડર અને ફક્ત ઍપ પરની ઑફર.',
        'تتبّع مباشر للمندوب، وبحث صوتي لقائمتك كاملة، وإعادة طلب فورية، وعروض حصرية للتطبيق.',
      );
  String get getItOn => _t('GET IT ON', 'अभी पाएँ', 'હમણાં મેળવો', 'احصل عليه من');
  String getItOnStore(String store) => _t('Get it on $store', '$store पर पाएँ', '$store પર મેળવો', 'احصل عليه من $store');

  // ---------------------------------------------------------------- grow band
  String get growEyebrow => _t('Grow with Go4Market', 'Go4Market के साथ आगे बढ़ें', 'Go4Market સાથે આગળ વધો', 'انمُ مع Go4Market');
  String get partnerWithUs => _t('Partner with us', 'हमारे साथ जुड़ें', 'અમારી સાથે જોડાઓ', 'كن شريكًا لنا');
  String get partnerSub => _t('Sell, deliver and grow with a fast-moving local marketplace', 'तेज़ी से बढ़ते स्थानीय मार्केटप्लेस के साथ बेचें, डिलीवर करें और आगे बढ़ें',
      'ઝડપથી વિકસતા સ્થાનિક માર્કેટપ્લેસ સાથે વેચો, ડિલિવર કરો અને આગળ વધો', 'بِع ووصّل وانمُ مع سوق محلي سريع النمو');
  String get becomeSeller => _t('Become a seller', 'विक्रेता बनें', 'વિક્રેતા બનો', 'كن بائعًا');
  String get sellerBody => _t(
        'Open your storefront on Go4Market and reach thousands of nearby shoppers.',
        'Go4Market पर अपना स्टोर खोलें और आस-पास के हज़ारों ग्राहकों तक पहुँचें।',
        'Go4Market પર તમારો સ્ટોર ખોલો અને નજીકના હજારો ગ્રાહકો સુધી પહોંચો.',
        'افتح متجرك على Go4Market وتواصل مع آلاف المتسوقين القريبين منك.',
      );
  List<String> get sellerPoints => [
        _t('Your own store page and dashboard', 'आपका अपना स्टोर पेज और डैशबोर्ड', 'તમારું પોતાનું સ્ટોર પેજ અને ડૅશબોર્ડ', 'صفحة متجر ولوحة تحكم خاصة بك'),
        _t('Fast weekly settlements', 'हर हफ़्ते तेज़ भुगतान', 'દર અઠવાડિયે ઝડપી ચુકવણી', 'تسويات أسبوعية سريعة'),
        _t('POS for in-store sales', 'दुकान में बिक्री के लिए POS', 'દુકાનમાં વેચાણ માટે POS', 'نظام نقاط بيع للمبيعات داخل المتجر'),
      ];
  String get startSelling => _t('Start selling', 'बेचना शुरू करें', 'વેચાણ શરૂ કરો', 'ابدأ البيع');
  String get becomeRider => _t('Become a delivery partner', 'डिलीवरी पार्टनर बनें', 'ડિલિવરી પાર્ટનર બનો', 'كن شريك توصيل');
  String get riderBody => _t(
        'Deliver in your city on your own schedule and earn on every order.',
        'अपने शहर में अपने समय पर डिलीवरी करें और हर ऑर्डर पर कमाएँ।',
        'તમારા શહેરમાં તમારા સમયે ડિલિવરી કરો અને દરેક ઓર્ડર પર કમાઓ.',
        'وصّل الطلبات في مدينتك وفق جدولك الخاص واربح من كل طلب.',
      );
  List<String> get riderPoints => [
        _t('Flexible hours, multiple cities', 'अपनी सुविधा के घंटे, कई शहर', 'અનુકૂળ કલાકો, અનેક શહેરો', 'ساعات مرنة ومدن متعددة'),
        _t('Earnings per order or monthly', 'हर ऑर्डर पर या मासिक कमाई', 'દરેક ઓર્ડર પર કે માસિક કમાણી', 'أرباح لكل طلب أو شهريًا'),
        _t('Instant withdrawals', 'तुरंत पैसे निकालें', 'તરત ઉપાડ', 'سحب فوري للأرباح'),
      ];
  String get joinAsRider => _t('Join as a rider', 'राइडर के रूप में जुड़ें', 'રાઇડર તરીકે જોડાઓ', 'انضم كمندوب توصيل');
}

extension HomeStringsL on L {
  HomeStrings get home => HomeStrings(this);
}
