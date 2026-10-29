import 'package:g4m_core/g4m_core.dart' show Fmt;

import 'l10n.dart';

/// Strings for the account area (account tabs + wallet). Each getter returns the active language: tr(en, hi, gu, ar).
class AccountStrings {
  const AccountStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  // ---------------------------------------------------------------- page + tabs
  String get profile => _t('Profile', 'प्रोफ़ाइल', 'પ્રોફાઇલ', 'الملف الشخصي');
  String get addresses => _t('Addresses', 'पते', 'સરનામાં', 'العناوين');
  String get notifications => _t('Notifications', 'नोटिफ़िकेशन', 'નોટિફિકેશન', 'الإشعارات');
  String get membership => _t('Membership', 'मेंबरशिप', 'મેમ્બરશિપ', 'العضوية');
  String get subscriptions => _t('Subscriptions', 'सब्सक्रिप्शन', 'સબ્સ્ક્રિપ્શન', 'الاشتراكات');
  String get returns => _t('Returns', 'रिटर्न', 'રિટર્ન', 'المرتجعات');
  String get signInTitle => _t('Sign in to your account', 'अपने खाते में साइन इन करें', 'તમારા એકાઉન્ટમાં સાઇન ઇન કરો', 'سجّل الدخول إلى حسابك');
  String get signInMessage => _t('Manage addresses, rewards, subscriptions and more.', 'पते, रिवॉर्ड, सब्सक्रिप्शन और बहुत कुछ मैनेज करें।',
      'સરનામાં, રિવોર્ડ, સબ્સ્ક્રિપ્શન અને ઘણું બધું મેનેજ કરો.', 'أدِر عناوينك ومكافآتك واشتراكاتك والمزيد.');

  // ---------------------------------------------------------------- profile
  String get none => _t('None', 'कोई नहीं', 'કોઈ નહીં', 'لا يوجد');
  String get active => _t('Active', 'सक्रिय', 'સક્રિય', 'نشطة');
  String get fullName => _t('Full name', 'पूरा नाम', 'પૂરું નામ', 'الاسم الكامل');
  String get mobileNumber => _t('Mobile number', 'मोबाइल नंबर', 'મોબાઇલ નંબર', 'رقم الجوال');
  String get email => _t('Email', 'ईमेल', 'ઇમેઇલ', 'البريد الإلكتروني');
  String get saveChanges => _t('Save changes', 'बदलाव सेव करें', 'ફેરફારો સેવ કરો', 'حفظ التغييرات');
  String get profileSaved => _t('Profile saved', 'प्रोफ़ाइल सेव हो गई', 'પ્રોફાઇલ સેવ થઈ ગઈ', 'تم حفظ الملف الشخصي');
  String get changePassword => _t('Change password', 'पासवर्ड बदलें', 'પાસવર્ડ બદલો', 'تغيير كلمة المرور');
  String resetLinkSent(String email) => _t('Password reset link sent to $email', 'पासवर्ड रीसेट लिंक $email पर भेज दिया गया है',
      'પાસવર્ડ રીસેટ લિંક $email પર મોકલી દીધી છે', 'تم إرسال رابط إعادة تعيين كلمة المرور إلى $email');

  // ---------------------------------------------------------------- addresses
  String get savedAddresses => _t('Saved addresses', 'सेव किए गए पते', 'સેવ કરેલાં સરનામાં', 'العناوين المحفوظة');
  String get addAddress => _t('Add address', 'पता जोड़ें', 'સરનામું ઉમેરો', 'إضافة عنوان');
  String get noAddresses => _t('No addresses yet', 'अभी कोई पता नहीं', 'હજી કોઈ સરનામું નથી', 'لا توجد عناوين بعد');
  String get noAddressesMsg => _t('Add one to speed up checkout.', 'चेकआउट तेज़ करने के लिए एक पता जोड़ें।', 'ચેકઆઉટ ઝડપી બનાવવા માટે એક સરનામું ઉમેરો.',
      'أضف عنوانًا لتسريع إتمام الشراء.');
  String get defaultLabel => _t('Default', 'डिफ़ॉल्ट', 'ડિફૉલ્ટ', 'الافتراضي');
  String get editAddress => _t('Edit address', 'पता बदलें', 'સરનામું બદલો', 'تعديل العنوان');
  String get deleteAddress => _t('Delete address', 'पता हटाएँ', 'સરનામું કાઢી નાખો', 'حذف العنوان');

  /// Built-in address labels are translated; custom labels are shown as typed.
  String addressLabel(String label) => switch (label.trim().toLowerCase()) {
        'home' => _t('Home', 'घर', 'ઘર', 'المنزل'),
        'work' => _t('Work', 'ऑफ़िस', 'ઑફિસ', 'العمل'),
        'other' => _t('Other', 'अन्य', 'અન્ય', 'أخرى'),
        _ => label,
      };

  // ---------------------------------------------------------------- notifications
  String get notificationsSub => _t('Order updates, offers and account alerts', 'ऑर्डर अपडेट, ऑफ़र और खाते से जुड़ी सूचनाएँ',
      'ઓર્ડર અપડેટ, ઑફર અને એકાઉન્ટ સંબંધિત સૂચનાઓ', 'تحديثات الطلبات والعروض وتنبيهات الحساب');
  String get markAllRead => _t('Mark all read', 'सभी को पढ़ा हुआ मार्क करें', 'બધાને વાંચેલા તરીકે માર્ક કરો', 'تعليم الكل كمقروء');
  String get allCaughtUp => _t('You are all caught up', 'आपने सब कुछ देख लिया है', 'તમે બધું જોઈ લીધું છે', 'لا جديد لديك');

  // ---------------------------------------------------------------- refer
  String giveGet(String give, String get) =>
      _t('Give $give, get $get', '$give दें, $get पाएँ', '$give આપો, $get મેળવો', 'امنح $give واحصل على $get');
  String get referBody => _t(
        'Your friend gets wallet credit when they join with your code, and you earn a reward once they sign up.',
        'आपके कोड से जुड़ने पर आपके दोस्त को वॉलेट क्रेडिट मिलता है, और उनके साइन अप करते ही आपको रिवॉर्ड मिलता है।',
        'તમારા કોડથી જોડાય ત્યારે તમારા મિત્રને વૉલેટ ક્રેડિટ મળે છે, અને તેઓ સાઇન અપ કરે કે તરત તમને રિવોર્ડ મળે છે.',
        'يحصل صديقك على رصيد في المحفظة عند انضمامه برمزك، وتحصل أنت على مكافأة بمجرد تسجيله.',
      );
  String get yourCode => _t('Your code', 'आपका कोड', 'તમારો કોડ', 'رمزك');
  String get generating => _t('Generating…', 'बन रहा है…', 'બની રહ્યો છે…', 'جارٍ الإنشاء…');
  String get copyCode => _t('Copy code', 'कोड कॉपी करें', 'કોડ કૉપિ કરો', 'نسخ الرمز');
  String get codeCopied => _t('Code copied', 'कोड कॉपी हो गया', 'કોડ કૉપિ થયો', 'تم نسخ الرمز');
  String get shareTitle => _t('Join me on Go4Market', 'Go4Market पर मेरे साथ जुड़ें', 'Go4Market પર મારી સાથે જોડાઓ', 'انضم إليّ على Go4Market');
  String shareText(String code, String amount) => _t('Use my code $code to get $amount on Go4Market', 'Go4Market पर $amount पाने के लिए मेरा कोड $code इस्तेमाल करें',
      'Go4Market પર $amount મેળવવા માટે મારો કોડ $code વાપરો', 'استخدم رمزي $code لتحصل على $amount على Go4Market');
  String get inviteLinkCopied => _t('Invite link copied', 'इनवाइट लिंक कॉपी हो गया', 'આમંત્રણ લિંક કૉપિ થઈ', 'تم نسخ رابط الدعوة');
  String get shareInvite => _t('Share invite link', 'इनवाइट लिंक शेयर करें', 'આમંત્રણ લિંક શેર કરો', 'مشاركة رابط الدعوة');
  String get copyLink => _t('Copy link', 'लिंक कॉपी करें', 'લિંક કૉપિ કરો', 'نسخ الرابط');
  String get howItWorks => _t('How it works', 'यह कैसे काम करता है', 'આ કેવી રીતે કામ કરે છે', 'كيف يعمل');
  String get howItWorksSteps => _t(
        '1. Share your link or code with friends.\n2. They sign up on Go4Market using it.\n3. You both receive wallet credit, ready to spend on your next order.',
        '1. अपना लिंक या कोड दोस्तों के साथ शेयर करें।\n2. वे उससे Go4Market पर साइन अप करें।\n3. आप दोनों को वॉलेट क्रेडिट मिलेगा, जिसे अगले ऑर्डर पर खर्च कर सकते हैं।',
        '1. તમારી લિંક અથવા કોડ મિત્રો સાથે શેર કરો.\n2. તેઓ તેનાથી Go4Market પર સાઇન અપ કરે.\n3. તમને બંનેને વૉલેટ ક્રેડિટ મળશે, જે આગલા ઓર્ડરમાં વાપરી શકો છો.',
        '1. شارك رابطك أو رمزك مع أصدقائك.\n2. يسجّلون في Go4Market باستخدامه.\n3. يحصل كلاكما على رصيد في المحفظة جاهز للإنفاق على طلبك التالي.',
      );

  // ---------------------------------------------------------------- membership
  String get membershipSub => _t('Free delivery and extra savings on every order', 'हर ऑर्डर पर फ़्री डिलीवरी और अतिरिक्त बचत',
      'દરેક ઓર્ડર પર ફ્રી ડિલિવરી અને વધારાની બચત', 'توصيل مجاني وتوفير إضافي على كل طلب');
  String joinPlan(String name) => _t('Join $name?', '$name से जुड़ें?', '$name માં જોડાવું છે?', 'الانضمام إلى $name؟');
  String joinBody(String price, String balance) => _t(
        '$price will be paid from your Go4Market wallet (balance $balance).',
        '$price आपके Go4Market वॉलेट से चुकाए जाएँगे (बैलेंस $balance)।',
        '$price તમારા Go4Market વૉલેટમાંથી ચૂકવાશે (બેલેન્સ $balance).',
        'سيتم دفع $price من محفظة Go4Market (الرصيد $balance).',
      );
  String get notNow => _t('Not now', 'अभी नहीं', 'હમણાં નહીં', 'ليس الآن');
  String get payAndJoin => _t('Pay & join', 'भुगतान करें और जुड़ें', 'ચુકવણી કરો અને જોડાઓ', 'ادفع وانضم');
  String welcomePlan(String name) => _t('Welcome to $name! Your benefits are active.', '$name में आपका स्वागत है! आपके फ़ायदे चालू हो गए हैं।',
      '$name માં તમારું સ્વાગત છે! તમારા લાભ ચાલુ થઈ ગયા છે.', 'مرحبًا بك في $name! مزاياك مفعّلة الآن.');
  String get topUp => _t('Top up', 'पैसे जोड़ें', 'પૈસા ઉમેરો', 'اشحن');
  String get membershipActive => _t('Your membership is active.', 'आपकी मेंबरशिप सक्रिय है।', 'તમારી મેમ્બરશિપ સક્રિય છે.', 'عضويتك نشطة.');
  String membershipActiveUntil(String date) => _t('Your membership is active until $date.', 'आपकी मेंबरशिप $date तक सक्रिय है।',
      'તમારી મેમ્બરશિપ $date સુધી સક્રિય છે.', 'عضويتك نشطة حتى $date.');
  String get plansSoon => _t('Plans are coming soon', 'प्लान जल्द आ रहे हैं', 'પ્લાન ટૂંક સમયમાં આવી રહ્યા છે', 'الخطط قادمة قريبًا');
  String perDays(int n) => _t(' / $n days', ' / $n दिन', ' / $n દિવસ', n >= 3 && n <= 10 ? ' / $n أيام' : ' / $n يومًا');
  String get freeDeliveryAll => _t('Free delivery on all orders', 'सभी ऑर्डर पर फ़्री डिलीवरी', 'બધા ઓર્ડર પર ફ્રી ડિલિવરી', 'توصيل مجاني لجميع الطلبات');
  String extraOff(String pct) => _t('Extra $pct off', '$pct अतिरिक्त छूट', '$pct વધારાની છૂટ', 'خصم إضافي $pct');
  String get currentPlan => _t('Current plan', 'मौजूदा प्लान', 'હાલનો પ્લાન', 'الخطة الحالية');
  String get joinNow => _t('Join now', 'अभी जुड़ें', 'હમણાં જોડાઓ', 'انضم الآن');

  // ---------------------------------------------------------------- subscriptions
  String get subscriptionsSub => _t('Repeat deliveries of your everyday essentials', 'रोज़मर्रा की ज़रूरतों की नियमित डिलीवरी',
      'રોજિંદી જરૂરિયાતોની નિયમિત ડિલિવરી', 'توصيل متكرر لاحتياجاتك اليومية');
  String get noSubscriptions => _t('No subscriptions yet', 'अभी कोई सब्सक्रिप्शन नहीं', 'હજી કોઈ સબ્સ્ક્રિપ્શન નથી', 'لا توجد اشتراكات بعد');
  String get noSubscriptionsMsg => _t('Open any grocery or pharmacy product and tap "Subscribe".', 'किसी भी किराना या फ़ार्मेसी प्रोडक्ट को खोलें और "सब्सक्राइब" पर टैप करें।',
      'કોઈ પણ કરિયાણા કે ફાર્મસી પ્રોડક્ટ ખોલો અને "સબ્સ્ક્રાઇબ" પર ટૅપ કરો.', 'افتح أي منتج بقالة أو صيدلية واضغط "اشترك".');
  String get browseGrocery => _t('Browse grocery', 'किराना देखें', 'કરિયાણું જુઓ', 'تصفّح البقالة');
  String get product => _t('Product', 'प्रोडक्ट', 'પ્રોડક્ટ', 'منتج');
  String frequency(String f) => switch (f) {
        'daily' => _t('Daily', 'रोज़ाना', 'રોજ', 'يوميًا'),
        'weekly' => _t('Weekly', 'साप्ताहिक', 'સાપ્તાહિક', 'أسبوعيًا'),
        'monthly' => _t('Monthly', 'मासिक', 'માસિક', 'شهريًا'),
        'alternate' || 'alternate_days' => _t('Alternate days', 'एक दिन छोड़कर', 'એકાંતરે દિવસે', 'كل يومين'),
        _ => Fmt.titleCase(f),
      };
  String subLine(String qty, String freq, String next) =>
      _t('$qty × $freq · next $next', '$qty × $freq · अगली $next', '$qty × $freq · આગળની $next', '$qty × $freq · التالي $next');
  String get manageSubscription => _t('Manage subscription', 'सब्सक्रिप्शन मैनेज करें', 'સબ્સ્ક્રિપ્શન મેનેજ કરો', 'إدارة الاشتراك');
  String get pause => _t('Pause', 'रोकें', 'થોભાવો', 'إيقاف مؤقت');
  String get resume => _t('Resume', 'फिर शुरू करें', 'ફરી શરૂ કરો', 'استئناف');
  String get cancelSubscription => _t('Cancel subscription', 'सब्सक्रिप्शन रद्द करें', 'સબ્સ્ક્રિપ્શન રદ કરો', 'إلغاء الاشتراك');

  /// Status chip text for subscriptions, returns and product requests.
  String status(String s) => switch (s) {
        'active' => _t('Active', 'सक्रिय', 'સક્રિય', 'نشط'),
        'paused' => _t('Paused', 'रुका हुआ', 'થોભાવેલું', 'متوقف مؤقتًا'),
        'cancelled' || 'canceled' => _t('Cancelled', 'रद्द', 'રદ', 'ملغى'),
        'pending' => _t('Pending', 'लंबित', 'બાકી', 'قيد الانتظار'),
        'requested' => _t('Requested', 'अनुरोध किया गया', 'વિનંતી કરેલ', 'تم الطلب'),
        'open' => _t('Open', 'खुला', 'ખુલ્લું', 'مفتوح'),
        'approved' => _t('Approved', 'मंज़ूर', 'મંજૂર', 'مقبول'),
        'rejected' => _t('Rejected', 'अस्वीकृत', 'નામંજૂર', 'مرفوض'),
        'picked_up' || 'pickedUp' => _t('Picked up', 'पिकअप हो गया', 'પિકઅપ થયું', 'تم الاستلام'),
        'received' => _t('Received', 'मिल गया', 'મળી ગયું', 'تم الاستلام'),
        'refunded' => _t('Refunded', 'रिफ़ंड हो गया', 'રિફંડ થયું', 'تم الاسترداد'),
        'completed' || 'done' => _t('Completed', 'पूरा हुआ', 'પૂર્ણ', 'مكتمل'),
        'added' || 'fulfilled' => _t('Added', 'जोड़ा गया', 'ઉમેરાયું', 'تمت الإضافة'),
        'reviewing' || 'in_review' => _t('In review', 'समीक्षा में', 'સમીક્ષા હેઠળ', 'قيد المراجعة'),
        'processing' => _t('Processing', 'प्रोसेस हो रहा है', 'પ્રોસેસ થઈ રહ્યું છે', 'قيد المعالجة'),
        'failed' => _t('Failed', 'विफल', 'નિષ્ફળ', 'فشل'),
        _ => Fmt.titleCase(s),
      };

  // ---------------------------------------------------------------- returns
  String get returnsTitle => _t('Returns & refunds', 'रिटर्न और रिफ़ंड', 'રિટર્ન અને રિફંડ', 'المرتجعات والاسترداد');
  String get returnsSub => _t('Request returns from a delivered order page', 'डिलीवर हुए ऑर्डर के पेज से रिटर्न का अनुरोध करें',
      'ડિલિવર થયેલા ઓર્ડરના પેજ પરથી રિટર્નની વિનંતી કરો', 'اطلب الإرجاع من صفحة طلب تم توصيله');
  String get noReturns => _t('No return requests', 'कोई रिटर्न अनुरोध नहीं', 'કોઈ રિટર્ન વિનંતી નથી', 'لا توجد طلبات إرجاع');
  String get returnForOrder => _t('Return for order', 'ऑर्डर का रिटर्न', 'ઓર્ડરનું રિટર્ન', 'إرجاع للطلب');
  String items(int n) => _t(n == 1 ? '1 item' : '$n items', '$n आइटम', '$n આઇટમ', switch (n) {
        1 => 'منتج واحد',
        2 => 'منتجان',
        >= 3 && <= 10 => '$n منتجات',
        _ => '$n منتجًا',
      });
  String refundDest(String to) => switch (to) {
        'wallet' => _t('wallet', 'वॉलेट', 'વૉલેટ', 'المحفظة'),
        'source' || 'original' || 'bank' => _t('original payment method', 'मूल भुगतान माध्यम', 'મૂળ ચુકવણી પદ્ધતિ', 'وسيلة الدفع الأصلية'),
        _ => to,
      };
  String refundTo(String amount, String to) =>
      _t('Refund $amount to $to', '$amount का रिफ़ंड $to में', '$amount નું રિફંડ $to માં', 'استرداد $amount إلى $to');

  // ---------------------------------------------------------------- product request
  String get requestSub => _t("Can't find something? Tell us and we will ask our sellers to stock it.", 'कुछ नहीं मिल रहा? हमें बताएँ, हम अपने विक्रेताओं से उसे रखने को कहेंगे।',
      'કંઈક મળતું નથી? અમને જણાવો, અમે અમારા વિક્રેતાઓને તે રાખવા કહીશું.', 'لا تجد ما تبحث عنه؟ أخبرنا وسنطلب من بائعينا توفيره.');
  String get productName => _t('Product name', 'प्रोडक्ट का नाम', 'પ્રોડક્ટનું નામ', 'اسم المنتج');
  String get productDetails => _t('Brand, size or any details (optional)', 'ब्रांड, साइज़ या कोई और जानकारी (वैकल्पिक)', 'બ્રાન્ડ, સાઇઝ કે અન્ય વિગતો (વૈકલ્પિક)',
      'العلامة التجارية أو الحجم أو أي تفاصيل (اختياري)');
  String get enterProductName => _t('Enter the product name', 'प्रोडक्ट का नाम डालें', 'પ્રોડક્ટનું નામ લખો', 'أدخل اسم المنتج');
  String get requestSent => _t('Request sent. Thank you!', 'अनुरोध भेज दिया गया। धन्यवाद!', 'વિનંતી મોકલી દીધી. આભાર!', 'تم إرسال الطلب. شكرًا لك!');
  String get sendRequest => _t('Send request', 'अनुरोध भेजें', 'વિનંતી મોકલો', 'إرسال الطلب');

  // ---------------------------------------------------------------- wallet
  String get walletHeading => _t('Go4Market wallet', 'Go4Market वॉलेट', 'Go4Market વૉલેટ', 'محفظة Go4Market');
  String get walletSignInTitle => _t('Sign in to use your wallet', 'वॉलेट इस्तेमाल करने के लिए साइन इन करें', 'વૉલેટ વાપરવા માટે સાઇન ઇન કરો', 'سجّل الدخول لاستخدام محفظتك');
  String get walletSignInMessage => _t('Pay faster, get refunds instantly and earn referral rewards.', 'तेज़ी से भुगतान करें, तुरंत रिफ़ंड पाएँ और रेफ़रल रिवॉर्ड कमाएँ।',
      'ઝડપથી ચુકવણી કરો, તરત રિફંડ મેળવો અને રેફરલ રિવોર્ડ કમાઓ.', 'ادفع أسرع، واسترد أموالك فورًا، واربح مكافآت الدعوة.');
  String minTopup(String amount) => _t('Enter at least $amount', 'कम से कम $amount डालें', 'ઓછામાં ઓછા $amount લખો', 'أدخل $amount على الأقل');
  String get onlineUnavailable => _t('Online payments are not available yet', 'ऑनलाइन भुगतान अभी उपलब्ध नहीं है', 'ઑનલાઇન ચુકવણી હજી ઉપલબ્ધ નથી',
      'المدفوعات الإلكترونية غير متاحة بعد');
  String addedToWallet(String amount) => _t('$amount added to your wallet', '$amount आपके वॉलेट में जुड़ गए', '$amount તમારા વૉલેટમાં ઉમેરાયા',
      'تمت إضافة $amount إلى محفظتك');
  String get topupCancelled => _t('Top-up cancelled', 'टॉप-अप रद्द हो गया', 'ટૉપ-અપ રદ થયું', 'تم إلغاء الشحن');
  String get providerRazorpay => _t('UPI / cards (Razorpay)', 'UPI / कार्ड (Razorpay)', 'UPI / કાર્ડ (Razorpay)', 'UPI / البطاقات (Razorpay)');
  String get providerStripe => _t('Card (Stripe)', 'कार्ड (Stripe)', 'કાર્ડ (Stripe)', 'بطاقة (Stripe)');
  String get availableBalance => _t('Available balance', 'उपलब्ध बैलेंस', 'ઉપલબ્ધ બેલેન્સ', 'الرصيد المتاح');
  String get balanceHint => _t('Use it at checkout, alone or together with another payment method.', 'चेकआउट पर इसे अकेले या किसी दूसरे भुगतान माध्यम के साथ इस्तेमाल करें।',
      'ચેકઆઉટ વખતે તેને એકલું કે બીજી ચુકવણી પદ્ધતિ સાથે વાપરો.', 'استخدمه عند الدفع، وحده أو مع وسيلة دفع أخرى.');
  String get addMoney => _t('Add money', 'पैसे जोड़ें', 'પૈસા ઉમેરો', 'إضافة رصيد');
  String get amount => _t('Amount', 'रकम', 'રકમ', 'المبلغ');
  String get gatewaysSetup => _t('Online payment gateways are being set up.', 'ऑनलाइन पेमेंट गेटवे सेट किए जा रहे हैं।', 'ઑનલાઇન પેમેન્ટ ગેટવે સેટ થઈ રહ્યા છે.',
      'يجري إعداد بوابات الدفع الإلكتروني.');
  String get processing => _t('Processing…', 'प्रोसेस हो रहा है…', 'પ્રોસેસ થઈ રહ્યું છે…', 'جارٍ المعالجة…');
  String get addToWallet => _t('Add to wallet', 'वॉलेट में जोड़ें', 'વૉલેટમાં ઉમેરો', 'إضافة إلى المحفظة');
  String get transactions => _t('Transactions', 'लेन-देन', 'વ્યવહારો', 'المعاملات');
  String get noTransactions => _t('No transactions yet.', 'अभी कोई लेन-देन नहीं।', 'હજી કોઈ વ્યવહાર નથી.', 'لا توجد معاملات بعد.');
  String txnReason(String reason) => switch (reason) {
        'topup' => _t('Money added', 'पैसे जोड़े गए', 'પૈસા ઉમેરાયા', 'تمت إضافة رصيد'),
        'order' => _t('Paid for order', 'ऑर्डर का भुगतान', 'ઓર્ડરની ચુકવણી', 'دفع مقابل طلب'),
        'refund' => _t('Refund', 'रिफ़ंड', 'રિફંડ', 'استرداد'),
        'referral' => _t('Referral reward', 'रेफ़रल रिवॉर्ड', 'રેફરલ રિવોર્ડ', 'مكافأة دعوة'),
        'cashback' => _t('Cashback', 'कैशबैक', 'કૅશબૅક', 'استرداد نقدي'),
        'admin' => _t('Adjustment by Go4Market', 'Go4Market द्वारा समायोजन', 'Go4Market દ્વારા ગોઠવણ', 'تسوية من Go4Market'),
        'membership' => _t('Membership purchase', 'मेंबरशिप खरीद', 'મેમ્બરશિપ ખરીદી', 'شراء العضوية'),
        _ => Fmt.titleCase(reason),
      };
  String balanceAfter(String amount) => _t('Balance $amount', 'बैलेंस $amount', 'બેલેન્સ $amount', 'الرصيد $amount');
  String credit(String amount) => _t('Credit $amount', 'क्रेडिट $amount', 'ક્રેડિટ $amount', 'إيداع $amount');
  String debit(String amount) => _t('Debit $amount', 'डेबिट $amount', 'ડેબિટ $amount', 'خصم $amount');
}

extension AccountStringsL on L {
  AccountStrings get account => AccountStrings(this);
}
