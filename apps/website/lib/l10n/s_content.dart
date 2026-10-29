import 'l10n.dart';

/// Strings for content pages (blog, FAQ, CMS pages, 404), markdown, voice search and lazy loading.
/// Each getter returns the active language: tr(en, hi, gu, ar).
class ContentStrings {
  const ContentStrings(this._l);
  final L _l;
  String _t(String en, String hi, String gu, String ar) => _l.tr(en, hi, gu, ar);

  // ---------------------------------------------------------------- blog
  String get blogSeoTitle => _t('Blog: tips, recipes and guides', 'ब्लॉग: टिप्स, रेसिपी और गाइड', 'બ્લૉગ: ટિપ્સ, રેસિપી અને ગાઇડ', 'المدونة: نصائح ووصفات وأدلة');
  String get blogSeoDescription => _t('Recipes, healthy living tips, smart shopping guides and Go4Market news.',
      'रेसिपी, सेहतमंद जीवन के टिप्स, समझदारी से खरीदारी की गाइड और Go4Market की ख़बरें।', 'રેસિપી, સ્વસ્થ જીવનની ટિપ્સ, સમજદારીથી ખરીદીની ગાઇડ અને Go4Market સમાચાર.',
      'وصفات ونصائح للحياة الصحية وأدلة للتسوق الذكي وأخبار Go4Market.');
  String get blogHeading => _t('The Go4Market journal', 'Go4Market जर्नल', 'Go4Market જર્નલ', 'مجلة Go4Market');
  String get blogIntro => _t('Recipes, wellness tips and smarter ways to shop.', 'रेसिपी, सेहत के टिप्स और समझदारी से खरीदारी के तरीके।',
      'રેસિપી, આરોગ્યની ટિપ્સ અને સમજદારીથી ખરીદી કરવાની રીતો.', 'وصفات ونصائح للعافية وطرق أذكى للتسوق.');
  String get noArticles => _t('No articles yet', 'अभी कोई लेख नहीं', 'હજી કોઈ લેખ નથી', 'لا توجد مقالات بعد');
  String get noArticlesMsg => _t('Our first stories are on their way.', 'हमारी पहली कहानियाँ जल्द आ रही हैं।', 'અમારી પહેલી વાર્તાઓ ટૂંક સમયમાં આવી રહી છે.',
      'قصصنا الأولى في الطريق.');
  String get articleNotFound => _t('Article not found', 'लेख नहीं मिला', 'લેખ મળ્યો નથી', 'المقال غير موجود');
  String get articleUnavailable => _t('This article is not available', 'यह लेख उपलब्ध नहीं है', 'આ લેખ ઉપલબ્ધ નથી', 'هذا المقال غير متاح');
  String get allArticles => _t('All articles', 'सभी लेख', 'બધા લેખ', 'كل المقالات');
  String get shareArticle => _t('Share article', 'लेख शेयर करें', 'લેખ શેર કરો', 'مشاركة المقال');
  String get linkCopied => _t('Link copied', 'लिंक कॉपी हो गया', 'લિંક કૉપિ થઈ', 'تم نسخ الرابط');

  // ---------------------------------------------------------------- FAQ
  String get faqTitle => _t('Help & FAQs', 'मदद और FAQ', 'મદદ અને FAQ', 'المساعدة والأسئلة الشائعة');
  String get faqSeoDescription => _t('Answers about orders, quick delivery, payments, wallet, returns and refunds on Go4Market.',
      'Go4Market पर ऑर्डर, क्विक डिलीवरी, भुगतान, वॉलेट, रिटर्न और रिफ़ंड से जुड़े सवालों के जवाब।',
      'Go4Market પર ઓર્ડર, ક્વિક ડિલિવરી, ચુકવણી, વૉલેટ, રિટર્ન અને રિફંડ વિશેના પ્રશ્નોના જવાબ.',
      'إجابات حول الطلبات والتوصيل السريع والمدفوعات والمحفظة والمرتجعات والاسترداد على Go4Market.');
  String get faqHeading => _t('How can we help?', 'हम आपकी क्या मदद करें?', 'અમે તમારી શું મદદ કરી શકીએ?', 'كيف يمكننا مساعدتك؟');
  String get faqIntro => _t('Quick answers to common questions.', 'आम सवालों के झटपट जवाब।', 'સામાન્ય પ્રશ્નોના ઝડપી જવાબ.', 'إجابات سريعة عن الأسئلة الشائعة.');
  String get faqsBeingWritten => _t('FAQs are being written', 'FAQ लिखे जा रहे हैं', 'FAQ લખાઈ રહ્યા છે', 'جارٍ كتابة الأسئلة الشائعة');
  String get stillNeedHelp => _t('Still need help? Our support team replies quickly.', 'अब भी मदद चाहिए? हमारी सपोर्ट टीम जल्दी जवाब देती है।',
      'હજી મદદ જોઈએ છે? અમારી સપોર્ટ ટીમ ઝડપથી જવાબ આપે છે.', 'هل ما زلت بحاجة إلى مساعدة؟ فريق الدعم لدينا يرد بسرعة.');
  String get contactUs => _t('Contact us', 'संपर्क करें', 'સંપર્ક કરો', 'اتصل بنا');

  // ---------------------------------------------------------------- CMS pages
  String get aboutTitle => _t('About Go4Market', 'Go4Market के बारे में', 'Go4Market વિશે', 'عن Go4Market');
  String get pageBeingUpdated => _t('This page is being updated', 'यह पेज अपडेट किया जा रहा है', 'આ પેજ અપડેટ થઈ રહ્યું છે', 'يجري تحديث هذه الصفحة');
  String get checkBackShortly => _t('Please check back shortly.', 'कृपया थोड़ी देर बाद फिर देखें।', 'કૃપા કરી થોડી વાર પછી ફરી જુઓ.', 'يُرجى العودة بعد قليل.');

  // ---------------------------------------------------------------- 404
  String get notFoundTitle => _t('Page not found', 'पेज नहीं मिला', 'પેજ મળ્યું નથી', 'الصفحة غير موجودة');
  String get notFoundHeading => _t('We could not find that page', 'हमें वह पेज नहीं मिला', 'અમને તે પેજ મળ્યું નથી', 'لم نتمكن من العثور على هذه الصفحة');
  String get notFoundBody => _t('The link may be broken or the page may have moved.', 'हो सकता है लिंक टूटा हो या पेज कहीं और चला गया हो।',
      'કદાચ લિંક તૂટેલી હોય અથવા પેજ બીજે ખસેડાયું હોય.', 'ربما يكون الرابط معطلًا أو نُقلت الصفحة.');
  String get goHome => _t('Go home', 'होम पर जाएँ', 'હોમ પર જાઓ', 'الذهاب إلى الرئيسية');
  String get browseCategories => _t('Browse categories', 'श्रेणियाँ देखें', 'શ્રેણીઓ જુઓ', 'تصفّح الفئات');

  // ---------------------------------------------------------------- voice search
  String get voiceNotHeard => _t('We could not hear you. Please try again.', 'हम आपकी आवाज़ नहीं सुन सके। कृपया फिर से कोशिश करें।',
      'અમે તમારો અવાજ સાંભળી શક્યા નહીં. કૃપા કરી ફરી પ્રયાસ કરો.', 'لم نتمكن من سماعك. يُرجى المحاولة مرة أخرى.');
  String get voiceUnsupported => _t('Voice search is not supported in this browser. Try Chrome or Edge.', 'इस ब्राउज़र में वॉइस सर्च काम नहीं करता। Chrome या Edge आज़माएँ।',
      'આ બ્રાઉઝરમાં વૉઇસ સર્ચ ચાલતું નથી. Chrome અથવા Edge અજમાવો.', 'البحث الصوتي غير مدعوم في هذا المتصفح. جرّب Chrome أو Edge.');
  String get micPermission => _t('Microphone permission is needed for voice search.', 'वॉइस सर्च के लिए माइक्रोफ़ोन की अनुमति ज़रूरी है।',
      'વૉઇસ સર્ચ માટે માઇક્રોફોનની પરવાનગી જરૂરી છે.', 'يلزم إذن الميكروفون للبحث الصوتي.');
  String get listening => _t('Listening…', 'सुन रहे हैं…', 'સાંભળી રહ્યા છીએ…', 'جارٍ الاستماع…');
  String get voiceHint => _t('Say one product or several, e.g. "milk, bread and eggs"', 'एक या कई प्रोडक्ट बोलें, जैसे "दूध, ब्रेड और अंडे"',
      'એક અથવા વધુ પ્રોડક્ટ બોલો, જેમ કે "દૂધ, બ્રેડ અને ઈંડાં"', 'قل منتجًا واحدًا أو أكثر، مثل "حليب وخبز وبيض"');
  String get search => _t('Search', 'खोजें', 'શોધો', 'بحث');

  /// Speech-recognition locale for the active language.
  String get speechLocale => switch (_l.code) {
        'hi' => 'hi-IN',
        'gu' => 'gu-IN',
        'ar' => 'ar-SA',
        _ => 'en-IN',
      };

  // ---------------------------------------------------------------- lazy loading
  String get pageLoadFailed => _t('This page could not load. Check your connection.', 'यह पेज लोड नहीं हो सका। अपना कनेक्शन जाँचें।',
      'આ પેજ લોડ થઈ શક્યું નથી. તમારું કનેક્શન તપાસો.', 'تعذّر تحميل هذه الصفحة. تحقّق من اتصالك.');
  String get retry => _t('Retry', 'फिर से कोशिश करें', 'ફરી પ્રયાસ કરો', 'إعادة المحاولة');
}

extension ContentStringsL on L {
  ContentStrings get content => ContentStrings(this);
}
