import 'l10n.dart';

/// Sign in, sign up, phone OTP, Google, complete-profile and password reset.
class AuthStrings {
  const AuthStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  // ---------------------------------------------------------------- brand panel
  String get heroLine => _t('Everything you need,\ndelivered fast.', 'आपकी हर ज़रूरत,\nतेज़ी से डिलीवर।', 'તમારી દરેક જરૂરિયાત,\nઝડપથી ડિલિવર.', 'كل ما تحتاجه،\nيصلك بسرعة.');
  String get benefitQuick => _t('15 and 30 minute quick delivery', '15 और 30 मिनट में क्विक डिलीवरी', '15 અને 30 મિનિટમાં ક્વિક ડિલિવરી', 'توصيل سريع خلال 15 و30 دقيقة');
  String get benefitTracking => _t('Live rider tracking on the map', 'मैप पर राइडर की लाइव ट्रैकिंग', 'મૅપ પર રાઇડરનું લાઇવ ટ્રૅકિંગ', 'تتبّع مباشر لمندوب التوصيل على الخريطة');
  String get benefitWallet => _t('Wallet, rewards and easy refunds', 'वॉलेट, रिवॉर्ड और आसान रिफ़ंड', 'વૉલેટ, રિવોર્ડ અને સરળ રિફંડ', 'محفظة ومكافآت واسترداد سهل');
  String get benefitSellers => _t('Hundreds of trusted local sellers', 'सैकड़ों भरोसेमंद स्थानीय विक्रेता', 'સેંકડો વિશ્વસનીય સ્થાનિક વિક્રેતાઓ', 'مئات البائعين المحليين الموثوقين');

  // ---------------------------------------------------------------- errors
  String get errBadCredentials => _t('Email or password is incorrect.', 'ईमेल या पासवर्ड गलत है।', 'ઇમેઇલ અથવા પાસવર્ડ ખોટો છે.', 'البريد الإلكتروني أو كلمة المرور غير صحيحة.');
  String get errEmailInUse => _t('An account already exists with this email. Try signing in.', 'इस ईमेल से पहले से खाता है। साइन इन करके देखें।',
      'આ ઇમેઇલથી એકાઉન્ટ પહેલેથી છે. સાઇન ઇન કરી જુઓ.', 'يوجد حساب بهذا البريد الإلكتروني بالفعل. جرّب تسجيل الدخول.');
  String get errWeakPassword => _t('Choose a stronger password (at least 6 characters).', 'मज़बूत पासवर्ड चुनें (कम से कम 6 अक्षर)।',
      'મજબૂત પાસવર્ડ પસંદ કરો (ઓછામાં ઓછા 6 અક્ષર).', 'اختر كلمة مرور أقوى (6 أحرف على الأقل).');
  String get errInvalidEmail => _t('That email address does not look right.', 'यह ईमेल पता सही नहीं लगता।', 'આ ઇમેઇલ સરનામું સાચું લાગતું નથી.', 'يبدو أن عنوان البريد الإلكتروني غير صحيح.');
  String get errTooMany => _t('Too many attempts. Please wait a minute and try again.', 'बहुत ज़्यादा कोशिशें हुईं। एक मिनट रुककर फिर कोशिश करें।',
      'ઘણા બધા પ્રયાસ થયા. એક મિનિટ રાહ જોઈને ફરી પ્રયાસ કરો.', 'محاولات كثيرة جدًا. انتظر دقيقة ثم حاول مرة أخرى.');
  String get errNetwork => _t('Network error. Check your connection.', 'नेटवर्क त्रुटि। अपना कनेक्शन जाँचें।', 'નેટવર્ક ભૂલ. તમારું કનેક્શન તપાસો.', 'خطأ في الشبكة. تحقّق من اتصالك.');
  String get errPhoneSoon => _t('Phone login is coming soon. Please use Google or email for now.', 'फ़ोन से लॉगिन जल्द आ रहा है। अभी Google या ईमेल से साइन इन करें।',
      'ફોનથી લૉગિન ટૂંક સમયમાં આવી રહ્યું છે. હમણાં Google અથવા ઇમેઇલથી સાઇન ઇન કરો.', 'تسجيل الدخول بالهاتف قادم قريبًا. استخدم Google أو البريد الإلكتروني حاليًا.');
  String get errProviderOff => _t('This sign-in method is not available yet. Please use email.', 'यह साइन-इन तरीका अभी उपलब्ध नहीं है। कृपया ईमेल इस्तेमाल करें।',
      'આ સાઇન-ઇન રીત હજી ઉપલબ્ધ નથી. કૃપા કરી ઇમેઇલ વાપરો.', 'طريقة تسجيل الدخول هذه غير متاحة بعد. يُرجى استخدام البريد الإلكتروني.');
  String get errInvalidPhone => _t('Enter a valid mobile number with country code.', 'देश कोड के साथ सही मोबाइल नंबर डालें।', 'દેશ કોડ સાથે સાચો મોબાઇલ નંબર દાખલ કરો.', 'أدخل رقم جوال صحيحًا مع رمز الدولة.');
  String get errBadCode => _t('That code is not right. Check the SMS and try again.', 'यह कोड सही नहीं है। SMS देखकर फिर कोशिश करें।',
      'આ કોડ સાચો નથી. SMS તપાસીને ફરી પ્રયાસ કરો.', 'الرمز غير صحيح. تحقّق من الرسالة وحاول مرة أخرى.');
  String get errCodeExpired => _t('This code has expired. Tap Resend to get a new one.', 'यह कोड समाप्त हो गया है। नया कोड पाने के लिए दोबारा भेजें दबाएँ।',
      'આ કોડની મુદત પૂરી થઈ ગઈ છે. નવો કોડ મેળવવા ફરી મોકલો દબાવો.', 'انتهت صلاحية هذا الرمز. اضغط إعادة الإرسال للحصول على رمز جديد.');
  String get errCaptcha => _t('We could not verify this browser. Refresh the page and try again.', 'हम इस ब्राउज़र को सत्यापित नहीं कर सके। पेज रिफ़्रेश करके फिर कोशिश करें।',
      'અમે આ બ્રાઉઝરની ચકાસણી કરી શક્યા નથી. પેજ રિફ્રેશ કરીને ફરી પ્રયાસ કરો.', 'تعذّر التحقق من هذا المتصفح. حدّث الصفحة وحاول مرة أخرى.');
  String get errQuota => _t('We are sending too many codes right now. Please try again later.', 'अभी बहुत सारे कोड भेजे जा रहे हैं। कृपया थोड़ी देर बाद कोशिश करें।',
      'અત્યારે ઘણા બધા કોડ મોકલાઈ રહ્યા છે. કૃપા કરી થોડી વાર પછી પ્રયાસ કરો.', 'نرسل عددًا كبيرًا من الرموز حاليًا. يُرجى المحاولة لاحقًا.');
  String get errPopupClosed => _t('The Google window was closed before signing in.', 'साइन इन से पहले Google विंडो बंद हो गई।', 'સાઇન ઇન પહેલાં Google વિન્ડો બંધ થઈ ગઈ.', 'أُغلقت نافذة Google قبل تسجيل الدخول.');
  String get errOtherAccount => _t('This email is already registered with a different sign-in method. Sign in with email and password.',
      'यह ईमेल किसी दूसरे साइन-इन तरीके से रजिस्टर है। ईमेल और पासवर्ड से साइन इन करें।',
      'આ ઇમેઇલ બીજી સાઇન-ઇન રીતથી રજિસ્ટર છે. ઇમેઇલ અને પાસવર્ડથી સાઇન ઇન કરો.',
      'هذا البريد مسجّل بطريقة دخول أخرى. سجّل الدخول بالبريد الإلكتروني وكلمة المرور.');
  String get errGeneric => _t('Something went wrong. Please try again.', 'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।', 'કંઈક ખોટું થયું. કૃપા કરી ફરી પ્રયાસ કરો.', 'حدث خطأ ما. يُرجى المحاولة مرة أخرى.');

  // ---------------------------------------------------------------- fields
  String get email => _t('Email', 'ईमेल', 'ઇમેઇલ', 'البريد الإلكتروني');
  String get enterEmail => _t('Enter your email', 'अपना ईमेल डालें', 'તમારો ઇમેઇલ દાખલ કરો', 'أدخل بريدك الإلكتروني');
  String get enterValidEmail => _t('Enter a valid email', 'सही ईमेल डालें', 'સાચો ઇમેઇલ દાખલ કરો', 'أدخل بريدًا إلكترونيًا صحيحًا');
  String get password => _t('Password', 'पासवर्ड', 'પાસવર્ડ', 'كلمة المرور');
  String get atLeast6 => _t('At least 6 characters', 'कम से कम 6 अक्षर', 'ઓછામાં ઓછા 6 અક્ષર', '6 أحرف على الأقل');
  String get showPassword => _t('Show password', 'पासवर्ड दिखाएँ', 'પાસવર્ડ બતાવો', 'إظهار كلمة المرور');
  String get hidePassword => _t('Hide password', 'पासवर्ड छिपाएँ', 'પાસવર્ડ છુપાવો', 'إخفاء كلمة المرور');
  String get fullName => _t('Full name', 'पूरा नाम', 'પૂરું નામ', 'الاسم الكامل');
  String get enterName => _t('Enter your name', 'अपना नाम डालें', 'તમારું નામ દાખલ કરો', 'أدخل اسمك');
  String get mobileOptional => _t('Mobile number (optional)', 'मोबाइल नंबर (वैकल्पिक)', 'મોબાઇલ નંબર (વૈકલ્પિક)', 'رقم الجوال (اختياري)');
  String get emailOptional => _t('Email (optional)', 'ईमेल (वैकल्पिक)', 'ઇમેઇલ (વૈકલ્પિક)', 'البريد الإلكتروني (اختياري)');
  String get enterValidPhone => _t('Enter a valid phone', 'सही फ़ोन नंबर डालें', 'સાચો ફોન નંબર દાખલ કરો', 'أدخل رقم هاتف صحيحًا');
  String get referralOptional => _t('Referral code (optional)', 'रेफ़रल कोड (वैकल्पिक)', 'રેફરલ કોડ (વૈકલ્પિક)', 'رمز الإحالة (اختياري)');

  // ---------------------------------------------------------------- login
  String get loginSeoTitle => _t('Sign in', 'साइन इन', 'સાઇન ઇન', 'تسجيل الدخول');
  String get loginSeoDesc => _t('Sign in to Go4Market to track orders, use your wallet and check out faster.', 'ऑर्डर ट्रैक करने, वॉलेट इस्तेमाल करने और तेज़ चेकआउट के लिए Go4Market में साइन इन करें।',
      'ઓર્ડર ટ્રેક કરવા, વૉલેટ વાપરવા અને ઝડપી ચેકઆઉટ માટે Go4Market માં સાઇન ઇન કરો.', 'سجّل الدخول إلى Go4Market لتتبّع طلباتك واستخدام محفظتك وإتمام الشراء أسرع.');
  String get welcomeBack => _t('Welcome back', 'फिर से स्वागत है', 'ફરી સ્વાગત છે', 'مرحبًا بعودتك');
  String get loginSubtitle => _t('Sign in to continue. Your cart is saved.', 'जारी रखने के लिए साइन इन करें। आपका कार्ट सुरक्षित है।', 'આગળ વધવા માટે સાઇન ઇન કરો. તમારું કાર્ટ સચવાયેલું છે.', 'سجّل الدخول للمتابعة. سلتك محفوظة.');
  String get forgotPassword => _t('Forgot password?', 'पासवर्ड भूल गए?', 'પાસવર્ડ ભૂલી ગયા?', 'نسيت كلمة المرور؟');
  String get signingIn => _t('Signing in…', 'साइन इन हो रहा है…', 'સાઇન ઇન થઈ રહ્યું છે…', 'جارٍ تسجيل الدخول…');
  String get newHere => _t('New to Go4Market?', 'Go4Market पर नए हैं?', 'Go4Market પર નવા છો?', 'جديد على Go4Market؟');
  String get createAnAccount => _t('Create an account', 'खाता बनाएँ', 'એકાઉન્ટ બનાવો', 'أنشئ حسابًا');
  String demoMode(String email) => _t('Demo mode: try $email', 'डेमो मोड: $email आज़माएँ', 'ડેમો મોડ: $email અજમાવો', 'الوضع التجريبي: جرّب $email');
  String get fill => _t('Fill', 'भरें', 'ભરો', 'تعبئة');

  // ---------------------------------------------------------------- tabs + social
  String get tabEmail => _t('Email', 'ईमेल', 'ઇમેઇલ', 'البريد');
  String get tabPhone => _t('Phone', 'फ़ोन', 'ફોન', 'الهاتف');
  String get signInWith => _t('Sign-in method', 'साइन-इन का तरीका', 'સાઇન-ઇનની રીત', 'طريقة تسجيل الدخول');
  String get continueGoogle => _t('Continue with Google', 'Google के साथ जारी रखें', 'Google સાથે આગળ વધો', 'المتابعة باستخدام Google');
  String get openingGoogle => _t('Opening Google…', 'Google खुल रहा है…', 'Google ખૂલી રહ્યું છે…', 'جارٍ فتح Google…');
  String get or => _t('or', 'या', 'અથવા', 'أو');

  // ---------------------------------------------------------------- phone OTP
  String get countryCode => _t('Country code', 'देश कोड', 'દેશ કોડ', 'رمز الدولة');
  String get mobileNumber => _t('Mobile number', 'मोबाइल नंबर', 'મોબાઇલ નંબર', 'رقم الجوال');
  String get sendOtp => _t('Send OTP', 'OTP भेजें', 'OTP મોકલો', 'إرسال الرمز');
  String get sendingOtp => _t('Sending OTP…', 'OTP भेजा जा रहा है…', 'OTP મોકલાઈ રહ્યો છે…', 'جارٍ إرسال الرمز…');
  String get otpHint => _t('We will text you a 6-digit code to verify your number.', 'नंबर सत्यापित करने के लिए हम आपको 6 अंकों का कोड SMS करेंगे।',
      'નંબર ચકાસવા માટે અમે તમને 6 અંકનો કોડ SMS કરીશું.', 'سنرسل إليك رمزًا من 6 أرقام للتحقق من رقمك.');
  String otpSentTo(String phone) => _t('Enter the 6-digit code sent to $phone', '$phone पर भेजा गया 6 अंकों का कोड डालें', '$phone પર મોકલેલો 6 અંકનો કોડ દાખલ કરો', 'أدخل الرمز المكوّن من 6 أرقام المرسل إلى $phone');
  String get otpLabel => _t('6-digit code', '6 अंकों का कोड', '6 અંકનો કોડ', 'رمز من 6 أرقام');
  String get otpInvalid => _t('Enter all 6 digits', 'सभी 6 अंक डालें', 'બધા 6 અંક દાખલ કરો', 'أدخل الأرقام الستة كلها');
  String get verify => _t('Verify and continue', 'सत्यापित करें और जारी रखें', 'ચકાસો અને આગળ વધો', 'تحقّق وتابِع');
  String get verifying => _t('Verifying…', 'सत्यापित हो रहा है…', 'ચકાસણી થઈ રહી છે…', 'جارٍ التحقق…');
  String resendIn(int s) => _t('Resend code in ${s}s', '$s सेकंड में दोबारा भेजें', '$s સેકન્ડમાં ફરી મોકલો', 'إعادة الإرسال بعد $s ث');
  String get resend => _t('Resend code', 'कोड दोबारा भेजें', 'કોડ ફરી મોકલો', 'إعادة إرسال الرمز');
  String get codeResent => _t('A new code is on its way.', 'नया कोड भेज दिया गया है।', 'નવો કોડ મોકલી દીધો છે.', 'رمز جديد في الطريق إليك.');
  String get changeNumber => _t('Change number', 'नंबर बदलें', 'નંબર બદલો', 'تغيير الرقم');

  // ---------------------------------------------------------------- complete profile
  String get completeTitle => _t('Complete your profile', 'अपनी प्रोफ़ाइल पूरी करें', 'તમારી પ્રોફાઇલ પૂરી કરો', 'أكمل ملفك الشخصي');
  String get completeSubtitle => _t('Just a few details so riders and sellers know who to deliver to.', 'बस कुछ जानकारी, ताकि राइडर और विक्रेता जानें कि किसे डिलीवर करना है।',
      'બસ થોડી માહિતી, જેથી રાઇડર અને વિક્રેતાઓ જાણે કે કોને ડિલિવર કરવું.', 'بعض التفاصيل فقط ليعرف المندوبون والبائعون لمن يوصّلون الطلب.');
  String get saveAndContinue => _t('Save and continue', 'सेव करें और जारी रखें', 'સેવ કરો અને આગળ વધો', 'حفظ ومتابعة');
  String get saving => _t('Saving…', 'सेव हो रहा है…', 'સેવ થઈ રહ્યું છે…', 'جارٍ الحفظ…');
  String signedInAs(String who) => _t('Signed in as $who', '$who के रूप में साइन इन', '$who તરીકે સાઇન ઇન', 'تم تسجيل الدخول باسم $who');

  // ---------------------------------------------------------------- signup
  String get signupSeoTitle => _t('Create your account', 'अपना खाता बनाएँ', 'તમારું એકાઉન્ટ બનાવો', 'أنشئ حسابك');
  String get signupSeoDesc => _t('Join Go4Market for quick delivery, wallet rewards and referral credits.', 'क्विक डिलीवरी, वॉलेट रिवॉर्ड और रेफ़रल क्रेडिट के लिए Go4Market से जुड़ें।',
      'ક્વિક ડિલિવરી, વૉલેટ રિવોર્ડ અને રેફરલ ક્રેડિટ માટે Go4Market સાથે જોડાઓ.', 'انضم إلى Go4Market للتوصيل السريع ومكافآت المحفظة ورصيد الإحالة.');
  String get signupTitle => _t('Create your account', 'अपना खाता बनाएँ', 'તમારું એકાઉન્ટ બનાવો', 'أنشئ حسابك');
  String get signupSubtitle => _t('It takes less than a minute.', 'इसमें एक मिनट से भी कम लगता है।', 'આમાં એક મિનિટથી પણ ઓછો સમય લાગે છે.', 'لن يستغرق الأمر أكثر من دقيقة.');
  String get acceptTerms => _t('Please accept the terms to continue.', 'जारी रखने के लिए कृपया शर्तें स्वीकार करें।', 'આગળ વધવા માટે કૃપા કરી શરતો સ્વીકારો.', 'يُرجى قبول الشروط للمتابعة.');
  String welcome(String name) => _t('Welcome to Go4Market, $name!', 'Go4Market में आपका स्वागत है, $name!', 'Go4Market માં આપનું સ્વાગત છે, $name!', 'مرحبًا بك في Go4Market يا $name!');
  String get iAgree => _t('I agree to the ', 'मैं ', 'હું ', 'أوافق على ');
  String get termsWord => _t('terms', 'शर्तों', 'શરતો', 'الشروط');
  String get and => _t(' and ', ' और ', ' અને ', ' و');
  String get privacyWord => _t('privacy policy', 'गोपनीयता नीति', 'ગોપનીયતા નીતિ', 'سياسة الخصوصية');
  String get agreeSuffix => _t('', ' से सहमत हूँ', ' સાથે સંમત છું', '');
  String get creatingAccount => _t('Creating account…', 'खाता बन रहा है…', 'એકાઉન્ટ બની રહ્યું છે…', 'جارٍ إنشاء الحساب…');
  String get haveAccount => _t('Already have an account?', 'पहले से खाता है?', 'પહેલેથી એકાઉન્ટ છે?', 'لديك حساب بالفعل؟');

  // ---------------------------------------------------------------- forgot
  String get resetSeoTitle => _t('Reset your password', 'अपना पासवर्ड रीसेट करें', 'તમારો પાસવર્ડ રીસેટ કરો', 'إعادة تعيين كلمة المرور');
  String get resetSeoDesc => _t('Forgot your Go4Market password? Get a reset link by email.', 'Go4Market पासवर्ड भूल गए? ईमेल पर रीसेट लिंक पाएँ।',
      'Go4Market પાસવર્ડ ભૂલી ગયા? ઇમેઇલ પર રીસેટ લિંક મેળવો.', 'نسيت كلمة مرور Go4Market؟ احصل على رابط إعادة التعيين عبر البريد.');
  String get checkInbox => _t('Check your inbox', 'अपना इनबॉक्स देखें', 'તમારું ઇનબૉક્સ તપાસો', 'تحقّق من بريدك الوارد');
  String sentResetTo(String email) => _t('We sent a reset link to $email.', 'हमने $email पर रीसेट लिंक भेजा है।', 'અમે $email પર રીસેટ લિંક મોકલી છે.', 'أرسلنا رابط إعادة التعيين إلى $email.');
  String get resetSubtitle => _t('Enter your email and we will send you a reset link.', 'अपना ईमेल डालें, हम आपको रीसेट लिंक भेजेंगे।', 'તમારો ઇમેઇલ દાખલ કરો, અમે તમને રીસેટ લિંક મોકલીશું.', 'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين.');
  String get backToSignIn => _t('Back to sign in', 'साइन इन पर वापस जाएँ', 'સાઇન ઇન પર પાછા જાઓ', 'العودة إلى تسجيل الدخول');
  String get sending => _t('Sending…', 'भेजा जा रहा है…', 'મોકલાઈ રહ્યું છે…', 'جارٍ الإرسال…');
  String get sendResetLink => _t('Send reset link', 'रीसेट लिंक भेजें', 'રીસેટ લિંક મોકલો', 'إرسال رابط إعادة التعيين');
}

extension AuthStringsL on L {
  AuthStrings get auth => AuthStrings(this);
}
