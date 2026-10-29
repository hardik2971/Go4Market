import 'l10n.dart';

/// Strings for the cart area: cart, single-screen checkout, payment hand-off, payment return,
/// the address form and the map pin picker. Each getter returns the active language: tr(en, hi, gu, ar).
class CartStrings {
  const CartStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  // ---------------------------------------------------------------- page + SEO
  String get title => _t('Your cart', 'आपका कार्ट', 'તમારું કાર્ટ', 'سلتك');
  String get seoDescription => _t(
        'Review your Go4Market cart and check out on one screen.',
        'अपना Go4Market कार्ट देखें और एक ही स्क्रीन पर चेकआउट करें।',
        'તમારું Go4Market કાર્ટ જુઓ અને એક જ સ્ક્રીન પર ચેકઆઉટ કરો.',
        'راجع سلتك على Go4Market وأتمّ الشراء في شاشة واحدة.',
      );
  String itemsCount(int n) => n == 1
      ? _t('1 item', '1 आइटम', '1 આઇટમ', 'منتج واحد')
      : n == 2
          ? _t('2 items', '2 आइटम', '2 આઇટમ', 'منتجان')
          : (n >= 3 && n <= 10)
              ? _t('$n items', '$n आइटम', '$n આઇટમ', '$n منتجات')
              : _t('$n items', '$n आइटम', '$n આઇટમ', '$n منتجًا');

  // ---------------------------------------------------------------- empty cart
  String get emptyTitle => _t('Your cart is empty', 'आपका कार्ट खाली है', 'તમારું કાર્ટ ખાલી છે', 'سلتك فارغة');
  String get emptyMessage => _t(
        'Fill it with fresh groceries, medicines, meals and more.',
        'इसे ताज़ा किराना, दवाइयों, खाने और बहुत कुछ से भरें।',
        'તેને તાજા કરિયાણા, દવાઓ, ભોજન અને ઘણું બધું ભરો.',
        'املأها بالبقالة الطازجة والأدوية والوجبات والمزيد.',
      );
  String get startShopping => _t('Start shopping', 'खरीदारी शुरू करें', 'ખરીદી શરૂ કરો', 'ابدأ التسوق');
  String get popularNow => _t('Popular right now', 'अभी सबसे लोकप्रिय', 'અત્યારે સૌથી લોકપ્રિય', 'الأكثر رواجًا الآن');

  // ---------------------------------------------------------------- cart lines
  String kmFromStore(String km) => _t('$km km from the store', 'स्टोर से $km किमी', 'સ્ટોરથી $km કિમી', 'على بُعد $km كم من المتجر');
  String etaAbout(String mins) => _t('estimated arrival in about $mins minutes', 'लगभग $mins मिनट में पहुँचने का अनुमान',
      'આશરે $mins મિનિટમાં પહોંચવાનો અંદાજ', 'الوصول المتوقع خلال $mins دقيقة تقريبًا');
  String get productGone => _t('This product is no longer available', 'यह प्रोडक्ट अब उपलब्ध नहीं है', 'આ પ્રોડક્ટ હવે ઉપલબ્ધ નથી',
      'هذا المنتج لم يعد متاحًا');
  String get loading => _t('Loading…', 'लोड हो रहा है…', 'લોડ થઈ રહ્યું છે…', 'جارٍ التحميل…');
  String get remove => _t('Remove', 'हटाएँ', 'દૂર કરો', 'إزالة');
  String soldBy(String seller) => _t('Sold by $seller', 'विक्रेता: $seller', 'વિક્રેતા: $seller', 'يبيعه $seller');
  String get outOfStock => _t('Out of stock', 'स्टॉक में नहीं', 'સ્ટૉકમાં નથી', 'نفد من المخزون');
  String get removeOne => _t('Remove one', 'एक कम करें', 'એક ઓછું કરો', 'إزالة واحد');
  String get addOneMore => _t('Add one more', 'एक और जोड़ें', 'એક વધુ ઉમેરો', 'إضافة واحد آخر');
  String replacedWith(String name) => _t('Replaced with $name', '$name से बदल दिया गया', '$name સાથે બદલાયું', 'تم الاستبدال بـ $name');
  String get similarInStock => _t('Similar items in stock', 'स्टॉक में मौजूद मिलते-जुलते आइटम', 'સ્ટૉકમાં ઉપલબ્ધ મળતી આવતી આઇટમ',
      'منتجات مشابهة متوفرة');
  String get replace => _t('Replace', 'बदलें', 'બદલો', 'استبدال');

  // ---------------------------------------------------------------- signed out
  String get almostThere => _t('Almost there', 'बस थोड़ा और', 'બસ થોડું જ બાકી', 'أوشكت على الانتهاء');
  String get signInToChoose => _t(
        'Sign in to choose an address and pay. Your cart comes with you.',
        'पता चुनने और भुगतान करने के लिए साइन इन करें। आपका कार्ट आपके साथ रहेगा।',
        'સરનામું પસંદ કરવા અને ચુકવણી કરવા સાઇન ઇન કરો. તમારું કાર્ટ તમારી સાથે જ રહેશે.',
        'سجّل الدخول لاختيار العنوان والدفع. ستبقى سلتك معك.',
      );
  String get signInToCheckout => _t('Sign in to check out', 'चेकआउट के लिए साइन इन करें', 'ચેકઆઉટ માટે સાઇન ઇન કરો', 'سجّل الدخول لإتمام الشراء');
  String get createAnAccount => _t('Create an account', 'खाता बनाएँ', 'એકાઉન્ટ બનાવો', 'أنشئ حسابًا');

  // ---------------------------------------------------------------- checkout steps
  String get howWouldYouLikeIt => _t('How would you like it?', 'आप इसे कैसे लेना चाहेंगे?', 'તમે તે કેવી રીતે મેળવવા માંગો છો?', 'كيف تريد استلام طلبك؟');
  String get homeDelivery => _t('Home delivery', 'होम डिलीवरी', 'હોમ ડિલિવરી', 'توصيل للمنزل');
  String get selfPickup => _t('Self pickup', 'खुद पिकअप करें', 'જાતે પિકઅપ', 'استلام بنفسك');
  String get deliveryAddress => _t('Delivery address', 'डिलीवरी का पता', 'ડિલિવરીનું સરનામું', 'عنوان التوصيل');
  String get deliverySpeed => _t('Delivery speed', 'डिलीवरी की स्पीड', 'ડિલિવરીની ઝડપ', 'سرعة التوصيل');
  String get pickup => _t('Pickup', 'पिकअप', 'પિકઅપ', 'الاستلام');
  String pickupFrom(String sellers) => _t(
        'Collect your order from $sellers. We will notify you when it is ready.',
        'अपना ऑर्डर $sellers से लें। तैयार होने पर हम आपको सूचित करेंगे।',
        'તમારો ઓર્ડર $sellers પાસેથી લઈ જાઓ. તૈયાર થશે ત્યારે અમે તમને જાણ કરીશું.',
        'استلم طلبك من $sellers. سنُعلمك عندما يصبح جاهزًا.',
      );
  String get offersAndWallet => _t('Offers & wallet', 'ऑफ़र और वॉलेट', 'ઑફર અને વૉલેટ', 'العروض والمحفظة');
  String get payment => _t('Payment', 'भुगतान', 'ચુકવણી', 'الدفع');

  // ---------------------------------------------------------------- delivery speeds
  String get speedStandard => _t('Standard', 'स्टैंडर्ड', 'સ્ટાન્ડર્ડ', 'عادي');
  String get todayOrTomorrow => _t('Today or tomorrow', 'आज या कल', 'આજે કે કાલે', 'اليوم أو غدًا');
  String minutesShort(int n) => _t('$n min', '$n मिनट', '$n મિનિટ', '$n دقيقة');
  String plusFee(String fee) => '+ $fee';
  String get speedScheduled => _t('Scheduled', 'शेड्यूल्ड', 'શેડ્યૂલ', 'مجدول');
  String get pickASlot => _t('Pick a slot', 'स्लॉट चुनें', 'સ્લોટ પસંદ કરો', 'اختر موعدًا');
  String get today => _t('Today', 'आज', 'આજે', 'اليوم');

  // ---------------------------------------------------------------- coupons + wallet
  String get couponCode => _t('Coupon code', 'कूपन कोड', 'કૂપન કોડ', 'رمز القسيمة');
  String get removeCoupon => _t('Remove coupon', 'कूपन हटाएँ', 'કૂપન દૂર કરો', 'إزالة القسيمة');
  String get apply => _t('Apply', 'लागू करें', 'લાગુ કરો', 'تطبيق');
  String get checking => _t('Checking…', 'जाँच हो रही है…', 'તપાસ થઈ રહી છે…', 'جارٍ التحقق…');
  String youSave(String amount) => _t('You save $amount', 'आपकी बचत $amount', 'તમારી બચત $amount', 'وفّرت $amount');
  String get couponInvalid => _t('This code is not valid', 'यह कोड मान्य नहीं है', 'આ કોડ માન્ય નથી', 'هذا الرمز غير صالح');
  String minOrder(String amount) => _t('Min order $amount', 'न्यूनतम ऑर्डर $amount', 'ન્યૂનતમ ઓર્ડર $amount', 'الحد الأدنى للطلب $amount');

  /// Translated replacement for `Coupon.label` ("10% OFF" / "₹50 OFF").
  String couponOff(String discountType, double value) {
    final v = discountType == 'percent' ? _l.pct(value.round()) : _l.money(value.roundToDouble());
    return _t('$v OFF', '$v छूट', '$v છૂટ', 'خصم $v');
  }

  String get useWallet => _t('Use wallet balance', 'वॉलेट बैलेंस इस्तेमाल करें', 'વૉલેટ બેલેન્સ વાપરો', 'استخدم رصيد المحفظة');
  String walletAvailable(String amount) => _t('Available $amount', 'उपलब्ध $amount', 'ઉપલબ્ધ $amount', 'المتاح $amount');

  // ---------------------------------------------------------------- payment methods
  String get payFromWallet => _t('Paid fully from wallet', 'पूरा भुगतान वॉलेट से', 'સંપૂર્ણ ચુકવણી વૉલેટથી', 'مدفوع بالكامل من المحفظة');
  String get payRazorpay => _t('UPI, cards & netbanking (Razorpay)', 'UPI, कार्ड और नेटबैंकिंग (Razorpay)', 'UPI, કાર્ડ અને નેટબેંકિંગ (Razorpay)',
      'UPI والبطاقات والخدمات المصرفية عبر الإنترنت (Razorpay)');
  String get payStripe => _t('Credit / debit card (Stripe)', 'क्रेडिट / डेबिट कार्ड (Stripe)', 'ક્રેડિટ / ડેબિટ કાર્ડ (Stripe)', 'بطاقة ائتمان / خصم (Stripe)');
  String get payPaypal => 'PayPal';
  String get payCod => _t('Cash on delivery', 'कैश ऑन डिलीवरी', 'કૅશ ઑન ડિલિવરી', 'الدفع عند الاستلام');
  String get paymentsSettingUp => _t(
        'Online payments are being set up. Please try again shortly.',
        'ऑनलाइन भुगतान सेट किए जा रहे हैं। कृपया थोड़ी देर बाद फिर कोशिश करें।',
        'ઑનલાઇન ચુકવણી સેટ થઈ રહી છે. કૃપા કરી થોડી વાર પછી ફરી પ્રયાસ કરો.',
        'يجري إعداد المدفوعات الإلكترونية. يُرجى المحاولة مرة أخرى بعد قليل.',
      );
  String get placeOrder => _t('Place order', 'ऑर्डर करें', 'ઓર્ડર કરો', 'تأكيد الطلب');
  String payAmount(String amount) => _t('Pay $amount', '$amount का भुगतान करें', '$amount ચૂકવો', 'ادفع $amount');
  String get verifiedSecurely => _t(
        'Prices, stock and offers are verified securely at checkout',
        'चेकआउट पर कीमत, स्टॉक और ऑफ़र सुरक्षित रूप से जाँचे जाते हैं',
        'ચેકઆઉટ વખતે કિંમત, સ્ટૉક અને ઑફર સુરક્ષિત રીતે ચકાસાય છે',
        'يتم التحقق من الأسعار والمخزون والعروض بأمان عند إتمام الشراء',
      );

  // ---------------------------------------------------------------- toasts
  String get noPaymentMethod => _t('No payment method is available right now', 'अभी कोई भुगतान तरीका उपलब्ध नहीं है',
      'અત્યારે કોઈ ચુકવણી પદ્ધતિ ઉપલબ્ધ નથી', 'لا تتوفر أي وسيلة دفع حاليًا');
  String get addOrChooseAddress => _t('Add or choose a delivery address', 'डिलीवरी का पता जोड़ें या चुनें', 'ડિલિવરીનું સરનામું ઉમેરો અથવા પસંદ કરો',
      'أضف عنوان توصيل أو اختر واحدًا');
  String get pickDeliverySlot => _t('Pick a delivery slot', 'डिलीवरी स्लॉट चुनें', 'ડિલિવરી સ્લોટ પસંદ કરો', 'اختر موعد التوصيل');
  String get removeUnavailableFirst => _t('Remove or replace unavailable items first', 'पहले अनुपलब्ध आइटम हटाएँ या बदलें',
      'પહેલાં અનુપલબ્ધ આઇટમ દૂર કરો અથવા બદલો', 'أزل المنتجات غير المتوفرة أو استبدلها أولًا');
  String get paymentNotCompleted => _t(
        'Payment was not completed. Your order is waiting for payment.',
        'भुगतान पूरा नहीं हुआ। आपका ऑर्डर भुगतान का इंतज़ार कर रहा है।',
        'ચુકવણી પૂર્ણ થઈ નથી. તમારો ઓર્ડર ચુકવણીની રાહ જોઈ રહ્યો છે.',
        'لم يكتمل الدفع. طلبك بانتظار الدفع.',
      );

  // ---------------------------------------------------------------- bill summary
  String get billSummary => _t('Bill summary', 'बिल का सारांश', 'બિલનો સારાંશ', 'ملخص الفاتورة');
  String get itemsTotal => _t('Items total', 'आइटम का कुल', 'આઇટમનો કુલ', 'إجمالي المنتجات');
  String quoteUnavailable(String reason) => _t('Live delivery quote unavailable: $reason', 'लाइव डिलीवरी कोट उपलब्ध नहीं: $reason',
      'લાઇવ ડિલિવરી ક્વોટ ઉપલબ્ધ નથી: $reason', 'تعذّر الحصول على تسعيرة التوصيل المباشرة: $reason');
  String get calculatedAtCheckout => _t('Delivery and taxes are calculated at checkout.', 'डिलीवरी और टैक्स चेकआउट पर जोड़े जाते हैं।',
      'ડિલિવરી અને ટેક્સ ચેકઆઉટ વખતે ગણાય છે.', 'تُحسب رسوم التوصيل والضرائب عند إتمام الشراء.');
  String get deliveryFee => _t('Delivery fee', 'डिलीवरी शुल्क', 'ડિલિવરી ચાર્જ', 'رسوم التوصيل');
  String get free => _t('FREE', 'मुफ़्त', 'મફત', 'مجانًا');
  String get couponDiscount => _t('Coupon discount', 'कूपन छूट', 'કૂપન છૂટ', 'خصم القسيمة');
  String get memberSavings => _t('Member savings', 'मेंबर बचत', 'મેમ્બર બચત', 'توفير الأعضاء');
  String get discount => _t('Discount', 'छूट', 'છૂટ', 'الخصم');
  String get youSaveOnMrp => _t('You save on MRP', 'MRP पर आपकी बचत', 'MRP પર તમારી બચત', 'توفيرك من السعر الأصلي');
  String get taxes => _t('Taxes', 'टैक्स', 'ટેક્સ', 'الضرائب');
  String get paidFromWallet => _t('Paid from wallet', 'वॉलेट से भुगतान', 'વૉલેટથી ચુકવણી', 'مدفوع من المحفظة');
  String get toPay => _t('To pay', 'देय राशि', 'ચૂકવવાની રકમ', 'المبلغ المستحق');
  String addMoreForFreeDelivery(String amount) => _t('Add $amount more for free delivery', 'फ़्री डिलीवरी के लिए $amount का और सामान जोड़ें',
      'ફ્રી ડિલિવરી માટે $amount નું વધુ ઉમેરો', 'أضف $amount أخرى للحصول على توصيل مجاني');

  // ---------------------------------------------------------------- addresses
  /// Maps the stored address labels ('Home' / 'Work' / 'Other') to translations; custom labels stay as typed.
  String addressLabel(String label) => switch (label) {
        'Home' => _t('Home', 'घर', 'ઘર', 'المنزل'),
        'Work' => _t('Work', 'ऑफ़िस', 'ઑફિસ', 'العمل'),
        'Other' => _t('Other', 'अन्य', 'અન્ય', 'أخرى'),
        _ => label,
      };
  String addressSemantics(String label, String line) => _t('$label address: $line', '$label का पता: $line', '$label નું સરનામું: $line', 'عنوان $label: $line');
  String get pinMissing => _t('Pin location missing: edit to add it', 'पिन लोकेशन नहीं है: जोड़ने के लिए एडिट करें', 'પિન લોકેશન નથી: ઉમેરવા માટે એડિટ કરો',
      'موقع الدبوس مفقود: عدّل العنوان لإضافته');
  String get editAddress => _t('Edit address', 'पता एडिट करें', 'સરનામું એડિટ કરો', 'تعديل العنوان');
  String get addDeliveryAddress => _t('Add delivery address', 'डिलीवरी का पता जोड़ें', 'ડિલિવરીનું સરનામું ઉમેરો', 'إضافة عنوان التوصيل');
  String get addNewAddress => _t('Add new address', 'नया पता जोड़ें', 'નવું સરનામું ઉમેરો', 'إضافة عنوان جديد');

  // ---------------------------------------------------------------- address form
  String get addADeliveryAddress => _t('Add a delivery address', 'डिलीवरी का पता जोड़ें', 'ડિલિવરીનું સરનામું ઉમેરો', 'أضف عنوان توصيل');
  String get movePinToDoor => _t('Move the map so the pin sits on your door', 'मैप को इस तरह खिसकाएँ कि पिन आपके दरवाज़े पर हो',
      'નકશો એવી રીતે ખસેડો કે પિન તમારા દરવાજા પર આવે', 'حرّك الخريطة حتى يستقر الدبوس على باب منزلك');
  String get requiredField => _t('Required', 'ज़रूरी है', 'જરૂરી છે', 'مطلوب');
  String get fullName => _t('Full name', 'पूरा नाम', 'પૂરું નામ', 'الاسم الكامل');
  String get phone => _t('Phone', 'फ़ोन', 'ફોન', 'الهاتف');
  String get invalidPhone => _t('Enter a valid phone', 'सही फ़ोन नंबर डालें', 'સાચો ફોન નંબર દાખલ કરો', 'أدخل رقم هاتف صالحًا');
  String get line1 => _t('House / flat, building', 'मकान / फ़्लैट, बिल्डिंग', 'મકાન / ફ્લેટ, બિલ્ડિંગ', 'المنزل / الشقة، المبنى');
  String get line2 => _t('Street, area (optional)', 'गली, इलाका (वैकल्पिक)', 'શેરી, વિસ્તાર (વૈકલ્પિક)', 'الشارع، المنطقة (اختياري)');
  String get landmark => _t('Landmark (optional)', 'लैंडमार्क (वैकल्पिक)', 'લેન્ડમાર્ક (વૈકલ્પિક)', 'معلم قريب (اختياري)');
  String get city => _t('City', 'शहर', 'શહેર', 'المدينة');
  String get state => _t('State', 'राज्य', 'રાજ્ય', 'الولاية');
  String get pin => _t('PIN', 'पिन कोड', 'પિન કોડ', 'الرمز البريدي');
  String get sixDigits => _t('6 digits', '6 अंक', '6 અંક', '6 أرقام');
  String get makeDefault => _t('Make this my default address', 'इसे मेरा डिफ़ॉल्ट पता बनाएँ', 'આને મારું ડિફૉલ્ટ સરનામું બનાવો', 'اجعله عنواني الافتراضي');
  String get saving => _t('Saving…', 'सेव हो रहा है…', 'સેવ થઈ રહ્યું છે…', 'جارٍ الحفظ…');
  String get saveAddress => _t('Save address', 'पता सेव करें', 'સરનામું સેવ કરો', 'حفظ العنوان');

  // ---------------------------------------------------------------- maps
  String get osmContributors => _t('OpenStreetMap contributors', 'OpenStreetMap योगदानकर्ता', 'OpenStreetMap યોગદાનકર્તાઓ', 'مساهمو OpenStreetMap');
  String get movePinHint => _t('Move the map to place the pin', 'पिन लगाने के लिए मैप खिसकाएँ', 'પિન મૂકવા માટે નકશો ખસેડો', 'حرّك الخريطة لتحديد موقع الدبوس');

  // ---------------------------------------------------------------- payment hand-off + return
  String get razorpayOrder => _t('Order payment', 'ऑर्डर का भुगतान', 'ઓર્ડરની ચુકવણી', 'دفع الطلب');
  String get razorpayTopup => _t('Wallet top-up', 'वॉलेट टॉप-अप', 'વૉલેટ ટૉપ-અપ', 'شحن المحفظة');
  String get noCheckoutLink => _t('The payment provider did not return a checkout link.', 'पेमेंट प्रोवाइडर से चेकआउट लिंक नहीं मिला।',
      'પેમેન્ટ પ્રોવાઇડર તરફથી ચેકઆઉટ લિંક મળી નથી.', 'لم يُرجع مزوّد الدفع رابطًا لإتمام الدفع.');
  String get paymentSeoTitle => _t('Payment', 'भुगतान', 'ચુકવણી', 'الدفع');
  String get noPaymentDetails => _t('We could not find the payment details in this link.', 'इस लिंक में भुगतान का विवरण नहीं मिला।',
      'આ લિંકમાં ચુકવણીની વિગતો મળી નથી.', 'لم نعثر على تفاصيل الدفع في هذا الرابط.');
  String providerStatus(String status) => _t('The payment provider reported status "$status".', 'पेमेंट प्रोवाइडर ने स्टेटस "$status" बताया।',
      'પેમેન્ટ પ્રોવાઇડરે સ્ટેટસ "$status" જણાવ્યું.', 'أفاد مزوّد الدفع بالحالة "$status".');
  String get signInAgainToConfirm => _t('Please sign in again to finish confirming your payment.', 'भुगतान की पुष्टि पूरी करने के लिए कृपया फिर से साइन इन करें।',
      'ચુકવણીની પુષ્ટિ પૂરી કરવા કૃપા કરી ફરી સાઇન ઇન કરો.', 'يُرجى تسجيل الدخول مرة أخرى لإكمال تأكيد الدفع.');
  String get walletToppedUp => _t('Wallet topped up', 'वॉलेट टॉप-अप हो गया', 'વૉલેટ ટૉપ-અપ થઈ ગયું', 'تم شحن المحفظة');
  String get paymentSuccessful => _t('Payment successful', 'भुगतान सफल रहा', 'ચુકવણી સફળ થઈ', 'تم الدفع بنجاح');
  String get balanceReady => _t('Your new balance is ready to use.', 'आपका नया बैलेंस इस्तेमाल के लिए तैयार है।', 'તમારું નવું બેલેન્સ વાપરવા માટે તૈયાર છે.',
      'رصيدك الجديد جاهز للاستخدام.');
  String get orderConfirmed => _t('Your order is confirmed. We are getting it ready.', 'आपका ऑर्डर कन्फ़र्म हो गया है। हम इसे तैयार कर रहे हैं।',
      'તમારો ઓર્ડર કન્ફર્મ થઈ ગયો છે. અમે તેને તૈયાર કરી રહ્યા છીએ.', 'تم تأكيد طلبك. نحن نجهّزه الآن.');
  String get paymentCancelled => _t('Payment cancelled', 'भुगतान रद्द हुआ', 'ચુકવણી રદ થઈ', 'تم إلغاء الدفع');
  String get noMoneyTaken => _t('No money was taken. You can try again any time.', 'कोई पैसा नहीं कटा। आप कभी भी फिर से कोशिश कर सकते हैं।',
      'કોઈ પૈસા કપાયા નથી. તમે ગમે ત્યારે ફરી પ્રયાસ કરી શકો છો.', 'لم يتم خصم أي مبلغ. يمكنك المحاولة مرة أخرى في أي وقت.');
  String get couldNotConfirm => _t('We could not confirm the payment', 'हम भुगतान की पुष्टि नहीं कर सके', 'અમે ચુકવણીની પુષ્ટિ કરી શક્યા નથી',
      'تعذّر علينا تأكيد الدفع');
  String get autoReconciled => _t('If money was deducted it will be reconciled automatically.', 'अगर पैसा कटा है तो वह अपने-आप समायोजित हो जाएगा।',
      'જો પૈસા કપાયા હશે તો તે આપમેળે સમાયોજિત થઈ જશે.', 'إذا تم خصم أي مبلغ فستتم تسويته تلقائيًا.');
  String get confirmingPayment => _t('Confirming your payment…', 'आपके भुगतान की पुष्टि हो रही है…', 'તમારી ચુકવણીની પુષ્ટિ થઈ રહી છે…', 'جارٍ تأكيد الدفع…');
  String get keepPageOpen => _t('Please keep this page open.', 'कृपया यह पेज खुला रखें।', 'કૃપા કરી આ પેજ ખુલ્લું રાખો.', 'يُرجى إبقاء هذه الصفحة مفتوحة.');
  String get goToWallet => _t('Go to wallet', 'वॉलेट पर जाएँ', 'વૉલેટ પર જાઓ', 'الانتقال إلى المحفظة');
  String get viewOrder => _t('View order', 'ऑर्डर देखें', 'ઓર્ડર જુઓ', 'عرض الطلب');
  String get continueShopping => _t('Continue shopping', 'खरीदारी जारी रखें', 'ખરીદી ચાલુ રાખો', 'متابعة التسوق');
}

extension CartStringsL on L {
  CartStrings get cart => CartStrings(this);
}
