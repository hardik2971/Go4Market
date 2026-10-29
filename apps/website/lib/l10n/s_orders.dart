import 'package:g4m_core/g4m_core.dart' show Fmt;

import 'l10n.dart';

/// Strings for the orders area (list + order detail / live tracking). tr(en, hi, gu, ar).
class OrdersStrings {
  const OrdersStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  // ---------------------------------------------------------------- list
  String get myOrders => _t('My orders', 'मेरे ऑर्डर', 'મારા ઓર્ડર', 'طلباتي');
  String get signInTitle => _t('Sign in to see your orders', 'अपने ऑर्डर देखने के लिए साइन इन करें', 'તમારા ઓર્ડર જોવા માટે સાઇન ઇન કરો', 'سجّل الدخول لعرض طلباتك');
  String get signInMessage => _t(
        'Track deliveries live, reorder favourites and request returns.',
        'डिलीवरी लाइव ट्रैक करें, पसंदीदा चीज़ें दोबारा ऑर्डर करें और रिटर्न का अनुरोध करें।',
        'ડિલિવરી લાઇવ ટ્રેક કરો, મનપસંદ વસ્તુઓ ફરી ઓર્ડર કરો અને રિટર્નની વિનંતી કરો.',
        'تتبّع التوصيل مباشرةً، وأعد طلب منتجاتك المفضلة، واطلب الإرجاع.',
      );
  String activeTab(int n) => _t('Active (${_l.number(n)})', 'चालू (${_l.number(n)})', 'ચાલુ (${_l.number(n)})', 'الحالية (${_l.number(n)})');
  String pastTab(int n) => _t('Past (${_l.number(n)})', 'पिछले (${_l.number(n)})', 'અગાઉના (${_l.number(n)})', 'السابقة (${_l.number(n)})');
  String get noActive => _t('No active orders', 'कोई चालू ऑर्डर नहीं', 'કોઈ ચાલુ ઓર્ડર નથી', 'لا توجد طلبات حالية');
  String get noPast => _t('No past orders yet', 'अभी तक कोई पिछला ऑर्डर नहीं', 'હજી સુધી કોઈ અગાઉનો ઓર્ડર નથી', 'لا توجد طلبات سابقة بعد');
  String get emptyMessage => _t('When you place an order it shows up here.', 'ऑर्डर देने पर वह यहाँ दिखेगा।', 'તમે ઓર્ડર કરશો ત્યારે તે અહીં દેખાશે.', 'ستظهر طلباتك هنا عند تقديمها.');
  String get startShopping => _t('Start shopping', 'खरीदारी शुरू करें', 'ખરીદી શરૂ કરો', 'ابدأ التسوق');
  String orderCardLabel(String no, String status) =>
      _t('Order $no, $status', 'ऑर्डर $no, $status', 'ઓર્ડર $no, $status', 'الطلب $no، $status');
  String orderNo(String no) => _t('Order #$no', 'ऑर्डर #$no', 'ઓર્ડર #$no', 'الطلب #$no');
  String items(int n) => _t(
        '${_l.number(n)} item${n == 1 ? '' : 's'}',
        '${_l.number(n)} आइटम',
        '${_l.number(n)} આઇટમ',
        switch (n) {
          1 => 'منتج واحد',
          2 => 'منتجان',
          >= 3 && <= 10 => '${_l.number(n)} منتجات',
          _ => '${_l.number(n)} منتج',
        },
      );
  String get trackOrderArrow => _t('Track order →', 'ऑर्डर ट्रैक करें →', 'ઓર્ડર ટ્રેક કરો →', 'تتبع الطلب ←');
  String get viewDetailsArrow => _t('View details →', 'विवरण देखें →', 'વિગતો જુઓ →', 'عرض التفاصيل ←');

  // ---------------------------------------------------------------- detail
  String get orderDetails => _t('Order details', 'ऑर्डर विवरण', 'ઓર્ડરની વિગતો', 'تفاصيل الطلب');
  String get signInTrackTitle => _t('Sign in to track this order', 'यह ऑर्डर ट्रैक करने के लिए साइन इन करें', 'આ ઓર્ડર ટ્રેક કરવા માટે સાઇન ઇન કરો', 'سجّل الدخول لتتبّع هذا الطلب');
  String get signInTrackMessage => _t('Orders are private to your account.', 'ऑर्डर सिर्फ़ आपके खाते में दिखते हैं।', 'ઓર્ડર ફક્ત તમારા એકાઉન્ટમાં જ દેખાય છે.', 'الطلبات خاصة بحسابك.');
  String get notFound => _t('Order not found', 'ऑर्डर नहीं मिला', 'ઓર્ડર મળ્યો નથી', 'لم يتم العثور على الطلب');
  String get shareOtp => _t('Share this code with your rider at delivery', 'डिलीवरी के समय यह कोड अपने राइडर को बताएँ', 'ડિલિવરી વખતે આ કોડ તમારા રાઇડરને જણાવો', 'شارك هذا الرمز مع المندوب عند التسليم');
  String get orderPlaced => _t('Order placed!', 'ऑर्डर हो गया!', 'ઓર્ડર થઈ ગયો!', 'تم تقديم الطلب!');
  String get thanks => _t('Thanks for shopping with Go4Market. Track it live below.', 'Go4Market से खरीदारी के लिए धन्यवाद। नीचे इसे लाइव ट्रैक करें।',
      'Go4Market સાથે ખરીદી કરવા બદલ આભાર. નીચે તેને લાઇવ ટ્રેક કરો.', 'شكرًا لتسوقك مع Go4Market. تتبّع طلبك مباشرةً أدناه.');
  String get allOrdersBack => _t('← All orders', '← सभी ऑर्डर', '← બધા ઓર્ડર', '→ كل الطلبات');
  String placedOn(String when, String channel) =>
      _t('Placed $when · $channel', '$when को दिया गया · $channel', '$when ના રોજ મૂક્યો · $channel', 'تم الطلب في $when · $channel');
  String channel(String c) => switch (c) {
        'web' => _t('Website', 'वेबसाइट', 'વેબસાઇટ', 'الموقع الإلكتروني'),
        'app' || 'android' || 'ios' || 'customer_app' => _t('App', 'ऐप', 'ઍપ', 'التطبيق'),
        'pos' => _t('In store', 'स्टोर पर', 'સ્ટોર પર', 'في المتجر'),
        'phone' => _t('Phone', 'फ़ोन', 'ફોન', 'الهاتف'),
        _ => Fmt.titleCase(c),
      };

  // ---------------------------------------------------------------- status
  String status(String s) => switch (s) {
        'pending' => awaitingPayment,
        'placed' => _t('Order placed', 'ऑर्डर दिया गया', 'ઓર્ડર થયો', 'تم تقديم الطلب'),
        'confirmed' => _t('Confirmed', 'कन्फ़र्म हुआ', 'કન્ફર્મ થયો', 'تم التأكيد'),
        'packed' => _t('Packed', 'पैक हुआ', 'પૅક થયો', 'تم التجهيز'),
        'assigned' => _t('Rider assigned', 'राइडर तय हुआ', 'રાઇડર સોંપાયો', 'تم تعيين المندوب'),
        'picked_up' => _t('Picked up', 'पिक अप हुआ', 'પિક અપ થયો', 'تم الاستلام من المتجر'),
        'out_for_delivery' => _t('Out for delivery', 'डिलीवरी के लिए निकला', 'ડિલિવરી માટે નીકળ્યો', 'خرج للتوصيل'),
        'ready_for_pickup' => _t('Ready for pickup', 'पिकअप के लिए तैयार', 'પિકઅપ માટે તૈયાર', 'جاهز للاستلام'),
        'delivered' => _t('Delivered', 'डिलीवर हो गया', 'ડિલિવર થયો', 'تم التوصيل'),
        'cancelled' => _t('Cancelled', 'रद्द हुआ', 'રદ થયો', 'أُلغي'),
        'returned' => _t('Returned', 'वापस किया गया', 'પરત કર્યો', 'تم الإرجاع'),
        // Return request statuses.
        'requested' => _t('Return requested', 'रिटर्न का अनुरोध किया', 'રિટર્નની વિનંતી કરી', 'تم طلب الإرجاع'),
        'approved' => _t('Approved', 'मंज़ूर', 'મંજૂર', 'تمت الموافقة'),
        'rejected' => _t('Rejected', 'अस्वीकार', 'નામંજૂર', 'مرفوض'),
        'completed' => _t('Completed', 'पूरा हुआ', 'પૂર્ણ થયું', 'مكتمل'),
        _ => Fmt.titleCase(s),
      };
  String get awaitingPayment => _t('Awaiting payment', 'भुगतान बाकी', 'ચુકવણી બાકી', 'بانتظار الدفع');
  String paymentStatus(String s) => switch (s) {
        'pending' => _t('Pending', 'बाकी', 'બાકી', 'قيد الانتظار'),
        'paid' => _t('Paid', 'भुगतान हुआ', 'ચુકવણી થઈ', 'مدفوع'),
        'failed' => _t('Failed', 'असफल', 'નિષ્ફળ', 'فشل'),
        'refunded' => _t('Refunded', 'रिफ़ंड हुआ', 'રિફંડ થયું', 'تم الاسترداد'),
        'partially_refunded' => _t('Partly refunded', 'आंशिक रिफ़ंड', 'આંશિક રિફંડ', 'استرداد جزئي'),
        'cod' => _t('Pay on delivery', 'डिलीवरी पर भुगतान', 'ડિલિવરી પર ચુકવણી', 'الدفع عند الاستلام'),
        _ => Fmt.titleCase(s),
      };
  String paymentMethod(String m) => switch (m) {
        'cod' => _t('Cash on delivery', 'कैश ऑन डिलीवरी', 'કૅશ ઑન ડિલિવરી', 'الدفع عند الاستلام'),
        'wallet' => _t('Wallet', 'वॉलेट', 'વૉલેટ', 'المحفظة'),
        'upi' => 'UPI',
        'card' => _t('Card', 'कार्ड', 'કાર્ડ', 'بطاقة'),
        'netbanking' => _t('Net banking', 'नेट बैंकिंग', 'નેટ બૅન્કિંગ', 'الخدمات المصرفية عبر الإنترنت'),
        'razorpay' => 'Razorpay',
        'stripe' => 'Stripe',
        'paypal' => 'PayPal',
        'online' => _t('Paid online', 'ऑनलाइन भुगतान', 'ઑનલાઇન ચુકવણી', 'مدفوع إلكترونيًا'),
        _ => Fmt.titleCase(m),
      };
  String get orderStatus => _t('Order status', 'ऑर्डर की स्थिति', 'ઓર્ડરની સ્થિતિ', 'حالة الطلب');
  String get refundProcessed => _t('Your refund has been processed.', 'आपका रिफ़ंड प्रोसेस हो गया है।', 'તમારું રિફંડ પ્રોસેસ થઈ ગયું છે.', 'تمت معالجة المبلغ المسترد.');

  // ---------------------------------------------------------------- countdown
  String get scheduledDelivery => _t('Scheduled delivery', 'शेड्यूल्ड डिलीवरी', 'શેડ્યૂલ ડિલિવરી', 'توصيل مجدول');
  String minuteDelivery(int m) =>
      _t('${_l.number(m)}-minute delivery', '${_l.number(m)} मिनट में डिलीवरी', '${_l.number(m)} મિનિટમાં ડિલિવરી', 'توصيل خلال ${_l.number(m)} دقيقة');
  String get estimatedArrival => _t('Estimated arrival', 'अनुमानित आगमन', 'અંદાજિત આગમન', 'الوصول المتوقع');
  String get arrivingAnyMoment => _t('Arriving any moment', 'बस पहुँचने ही वाला है', 'બસ પહોંચવાની તૈયારીમાં', 'سيصل في أي لحظة');
  String arrivingIn(int m) => _t(
        'Arriving in ${_l.number(m)} minute${m == 1 ? '' : 's'}',
        '${_l.number(m)} मिनट में पहुँच रहा है',
        '${_l.number(m)} મિનિટમાં પહોંચી રહ્યો છે',
        'يصل خلال ${_arMinutes(m)}',
      );
  String eta(String time) => _t('ETA $time', 'पहुँचने का समय $time', 'પહોંચવાનો સમય $time', 'الوصول المتوقع $time');
  String kmAway(String km) => _t('$km km away', '$km कि.मी. दूर', '$km કિ.મી. દૂર', 'على بُعد $km كم');

  String _arMinutes(int m) => switch (m) {
        1 => 'دقيقة واحدة',
        2 => 'دقيقتين',
        >= 3 && <= 10 => '${_l.number(m)} دقائق',
        _ => '${_l.number(m)} دقيقة',
      };

  // ---------------------------------------------------------------- rider
  String get yourRider => _t('Your rider', 'आपका राइडर', 'તમારો રાઇડર', 'مندوب التوصيل');
  String get waitingLocation => _t('Waiting for the rider\'s live location…', 'राइडर की लाइव लोकेशन का इंतज़ार है…', 'રાઇડરના લાઇવ લોકેશનની રાહ જોઈએ છીએ…', 'بانتظار الموقع المباشر للمندوب…');
  String get locationAppears => _t('Live location appears once your rider starts moving', 'राइडर के चलना शुरू करते ही लाइव लोकेशन दिखेगी',
      'રાઇડર ચાલવાનું શરૂ કરે એટલે લાઇવ લોકેશન દેખાશે', 'سيظهر الموقع المباشر بمجرد أن يبدأ المندوب التحرك');
  String get liveLocation => _t('Live location', 'लाइव लोकेशन', 'લાઇવ લોકેશન', 'الموقع المباشر');
  String updatedAgo(String ago) => _t('updated $ago', '$ago अपडेट हुई', '$ago અપડેટ થયું', 'آخر تحديث $ago');
  String get callRider => _t('Call rider', 'राइडर को कॉल करें', 'રાઇડરને કૉલ કરો', 'اتصل بالمندوب');

  // ---------------------------------------------------------------- items + bill
  String itemsHeading(int n) => _t('Items (${_l.number(n)})', 'आइटम (${_l.number(n)})', 'આઇટમ (${_l.number(n)})', 'المنتجات (${_l.number(n)})');
  String get paymentSummary => _t('Payment summary', 'भुगतान सारांश', 'ચુકવણીનો સારાંશ', 'ملخص الدفع');
  String get itemsTotal => _t('Items total', 'आइटम का कुल', 'આઇટમનો કુલ', 'إجمالي المنتجات');
  String get deliveryFee => _t('Delivery fee', 'डिलीवरी शुल्क', 'ડિલિવરી ફી', 'رسوم التوصيل');
  String get free => _t('FREE', 'मुफ़्त', 'મફત', 'مجانًا');
  String get discount => _t('Discount', 'छूट', 'છૂટ', 'الخصم');
  String discountWithCode(String code) => _t('Discount ($code)', 'छूट ($code)', 'છૂટ ($code)', 'الخصم ($code)');
  String get taxes => _t('Taxes', 'टैक्स', 'ટૅક્સ', 'الضرائب');
  String get paidFromWallet => _t('Paid from wallet', 'वॉलेट से भुगतान', 'વૉલેટમાંથી ચુકવણી', 'مدفوع من المحفظة');
  String get total => _t('Total', 'कुल', 'કુલ', 'الإجمالي');

  // ---------------------------------------------------------------- delivery
  String get selfPickup => _t('Self pickup', 'खुद पिकअप', 'જાતે પિકઅપ', 'استلام شخصي');
  String get deliveryAddress => _t('Delivery address', 'डिलीवरी का पता', 'ડિલિવરીનું સરનામું', 'عنوان التوصيل');
  String collectFrom(String stores) => _t('Collect from $stores', '$stores से लें', '$stores પરથી લો', 'استلم من $stores');
  String get quick15 => _t('Quick delivery · 15 minutes', 'क्विक डिलीवरी · 15 मिनट', 'ક્વિક ડિલિવરી · 15 મિનિટ', 'توصيل سريع · 15 دقيقة');
  String get quick30 => _t('Quick delivery · 30 minutes', 'क्विक डिलीवरी · 30 मिनट', 'ક્વિક ડિલિવરી · 30 મિનિટ', 'توصيل سريع · 30 دقيقة');
  String scheduledAt(String slot) => _t('Scheduled · $slot', 'शेड्यूल्ड · $slot', 'શેડ્યૂલ · $slot', 'مجدول · $slot');
  String get standardDelivery => _t('Standard delivery', 'सामान्य डिलीवरी', 'સામાન્ય ડિલિવરી', 'توصيل عادي');

  // ---------------------------------------------------------------- actions
  String get cancelTitle => _t('Cancel this order?', 'यह ऑर्डर रद्द करें?', 'આ ઓર્ડર રદ કરવો છે?', 'إلغاء هذا الطلب؟');
  String get reasonOptional => _t('Reason (optional)', 'कारण (वैकल्पिक)', 'કારણ (વૈકલ્પિક)', 'السبب (اختياري)');
  String get keepOrder => _t('Keep order', 'ऑर्डर रखें', 'ઓર્ડર રાખો', 'الاحتفاظ بالطلب');
  String get cancelOrder => _t('Cancel order', 'ऑर्डर रद्द करें', 'ઓર્ડર રદ કરો', 'إلغاء الطلب');
  String get cancelledByCustomer => _t('Cancelled by customer', 'ग्राहक ने रद्द किया', 'ગ્રાહકે રદ કર્યો', 'ألغاه العميل');
  String get orderCancelled => _t('Order cancelled', 'ऑर्डर रद्द हो गया', 'ઓર્ડર રદ થયો', 'تم إلغاء الطلب');
  String get requestReturn => _t('Request a return', 'रिटर्न का अनुरोध करें', 'રિટર્નની વિનંતી કરો', 'طلب إرجاع');
  String get whichItems => _t('Which items?', 'कौन-से आइटम?', 'કઈ આઇટમ?', 'أي المنتجات؟');
  String get whatWentWrong => _t('What went wrong?', 'क्या गड़बड़ हुई?', 'શું ખોટું થયું?', 'ما المشكلة؟');
  String get refundToWallet => _t('Approved refunds go to your Go4Market wallet.', 'मंज़ूर रिफ़ंड आपके Go4Market वॉलेट में जाते हैं।',
      'મંજૂર થયેલાં રિફંડ તમારા Go4Market વૉલેટમાં જમા થાય છે.', 'تُضاف المبالغ المستردة المعتمدة إلى محفظة Go4Market.');
  String get submitRequest => _t('Submit request', 'अनुरोध भेजें', 'વિનંતી મોકલો', 'إرسال الطلب');
  String get tellReason => _t('Please tell us the reason', 'कृपया कारण बताएँ', 'કૃપા કરી કારણ જણાવો', 'يُرجى إخبارنا بالسبب');
  String get returnRequested => _t('Return requested. We will update you soon.', 'रिटर्न का अनुरोध हो गया। हम जल्द ही आपको अपडेट देंगे।',
      'રિટર્નની વિનંતી થઈ ગઈ. અમે જલદી તમને અપડેટ આપીશું.', 'تم طلب الإرجاع. سنوافيك بالمستجدات قريبًا.');
  String get outOfStock => _t('These items are out of stock right now', 'ये आइटम अभी स्टॉक में नहीं हैं', 'આ આઇટમ અત્યારે સ્ટોકમાં નથી', 'هذه المنتجات غير متوفرة حاليًا');
  String addedToCart(int n) => _t(
        'Added ${_l.number(n)} item${n == 1 ? '' : 's'} to your cart',
        '${_l.number(n)} आइटम कार्ट में जोड़े गए',
        '${_l.number(n)} આઇટમ કાર્ટમાં ઉમેરાઈ',
        switch (n) {
          1 => 'تمت إضافة منتج واحد إلى السلة',
          2 => 'تمت إضافة منتجين إلى السلة',
          >= 3 && <= 10 => 'تمت إضافة ${_l.number(n)} منتجات إلى السلة',
          _ => 'تمت إضافة ${_l.number(n)} منتج إلى السلة',
        },
      );
  String get viewCart => _t('View cart', 'कार्ट देखें', 'કાર્ટ જુઓ', 'عرض السلة');
  String get orderAgain => _t('Order again', 'फिर से ऑर्डर करें', 'ફરી ઓર્ડર કરો', 'اطلب مرة أخرى');
  String get returnItems => _t('Return items', 'आइटम वापस करें', 'આઇટમ પરત કરો', 'إرجاع المنتجات');
  String get printReceipt => _t('Print receipt', 'रसीद प्रिंट करें', 'રસીદ પ્રિન્ટ કરો', 'طباعة الإيصال');
  String get needHelp => _t('Need help?', 'मदद चाहिए?', 'મદદ જોઈએ છે?', 'تحتاج مساعدة؟');
}

extension OrdersStringsL on L {
  OrdersStrings get orders => OrdersStrings(this);
}
