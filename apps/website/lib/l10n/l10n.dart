// Website localisation: English (default), Hindi, Gujarati and Arabic (RTL).
//
// Strings live in typed, namespaced classes (one file per area, `s_*.dart`), each
// getter carrying all four translations inline, so a missing translation is a
// compile error rather than a silent English fallback. Use them as:
//
//   context.l.cart.title          (inside widgets; rebuilds on language change)
//   L.current.common.retry         (outside the widget tree)
//
// Admins can override keyed strings at runtime through `translations/{code}.strings`.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:web/web.dart' as web;

import '../core/web_bridge.dart';

export 's_account.dart';
export 's_auth.dart';
export 's_cart.dart';
export 's_catalog.dart';
export 's_common.dart';
export 's_content.dart';
export 's_home.dart';
export 's_orders.dart';
export 's_product.dart';

/// Language codes the website ships translations for, in display order.
const kSupportedLangs = ['en', 'hi', 'gu', 'ar'];
const kDefaultLang = 'en';
const kRtlLangs = {'ar'};

/// Static fallback names, used until `languages` loads (and as a safety net).
const kLangNative = {'en': 'English', 'hi': 'हिन्दी', 'gu': 'ગુજરાતી', 'ar': 'العربية'};
const kLangEnglish = {'en': 'English', 'hi': 'Hindi', 'gu': 'Gujarati', 'ar': 'Arabic'};

class Lang {
  const Lang(this.code, this.name, this.nativeName, {this.rtl = false, this.isDefault = false});
  final String code, name, nativeName;
  final bool rtl, isDefault;
}

/// The active language plus locale-aware formatting. Immutable per language.
class L {
  L._(this.code) : _tag = _intlTag(code);
  final String code;
  final String _tag;

  static final _cache = <String, L>{};
  factory L(String code) => _cache.putIfAbsent(code, () => L._(code));

  /// The language currently shown. The whole page tree remounts when it changes,
  /// so reading this during build is safe.
  static L get current => L(LangController.instance.code);
  static L of(BuildContext context) => Localizations.of<L>(context, L) ?? current;

  bool get rtl => kRtlLangs.contains(code);
  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => Locale(code);

  /// Picks the translation for the active language.
  String tr(String en, String hi, String gu, String ar) => switch (code) {
        'hi' => hi,
        'gu' => gu,
        'ar' => ar,
        _ => en,
      };

  /// Like [tr], but an admin override in `translations/{code}.strings[key]` wins.
  String k(String key, String en, String hi, String gu, String ar) {
    final o = LangController.instance.overrides[key];
    return (o != null && o.trim().isNotEmpty) ? o : tr(en, hi, gu, ar);
  }

  // ------------------------------------------------------------ formatting

  static String _intlTag(String code) => switch (code) {
        'en' => 'en_IN',
        'hi' => 'hi',
        'gu' => 'gu',
        'ar' => 'ar',
        _ => 'en_IN',
      };

  late final NumberFormat _money0 = _nf(() => NumberFormat.currency(locale: _tag, symbol: '₹', decimalDigits: 0));
  late final NumberFormat _money2 = _nf(() => NumberFormat.currency(locale: _tag, symbol: '₹', decimalDigits: 2));
  late final NumberFormat _compact = _nf(() => NumberFormat.compactCurrency(locale: _tag, symbol: '₹'));
  late final NumberFormat _number = _nf(() => NumberFormat.decimalPattern(_tag));

  NumberFormat _nf(NumberFormat Function() make) {
    try {
      return make();
    } catch (_) {
      return NumberFormat.decimalPattern('en_IN');
    }
  }

  DateFormat _df(String pattern) {
    try {
      return DateFormat(pattern, _tag);
    } catch (_) {
      return DateFormat(pattern, 'en_IN');
    }
  }

  /// ₹1,299 (whole rupees) or ₹1,299.50 with paise. Arabic puts the symbol after the amount.
  String money(num v) => v % 1 == 0 ? _money0.format(v) : _money2.format(v);
  String moneyCompact(num v) => _compact.format(v);
  String number(num v) => _number.format(v);

  /// "20% off"-style percentage number (no sign), localised digits/marks.
  String pct(num v) => '${number(v)}%';
  String date(DateTime? d) => d == null ? '—' : _df('d MMM yyyy').format(d);
  String dateShort(DateTime? d) => d == null ? '—' : _df('d MMM').format(d);
  String dateTime(DateTime? d) => d == null ? '—' : _df('d MMM yyyy, h:mm a').format(d);
  String time(DateTime? d) => d == null ? '—' : _df('h:mm a').format(d);
  String weekday(DateTime d) => _df('EEE').format(d);
  String weekdayDate(DateTime d) => _df('EEE, d MMM').format(d);

  String ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return tr('just now', 'अभी-अभी', 'હમણાં જ', 'الآن');
    if (diff.inMinutes < 60) {
      final n = diff.inMinutes;
      return tr('${n}m ago', '$n मिनट पहले', '$n મિનિટ પહેલાં', 'منذ $n د');
    }
    if (diff.inHours < 24) {
      final n = diff.inHours;
      return tr('${n}h ago', '$n घंटे पहले', '$n કલાક પહેલાં', 'منذ $n س');
    }
    if (diff.inDays < 7) {
      final n = diff.inDays;
      return tr('${n}d ago', '$n दिन पहले', '$n દિવસ પહેલાં', 'منذ $n ي');
    }
    return date(d);
  }
}

extension LContext on BuildContext {
  L get l => L.of(this);
}

/// Shorthand formatters for code that has no BuildContext.
String money(num v) => L.current.money(v);

class LDelegate extends LocalizationsDelegate<L> {
  const LDelegate();
  @override
  bool isSupported(Locale locale) => kSupportedLangs.contains(locale.languageCode);
  @override
  Future<L> load(Locale locale) => SynchronousFuture(L(locale.languageCode));
  @override
  bool shouldReload(LDelegate old) => false;
}

/// Owns the chosen language: `?lang=` > localStorage > the account's `users/{uid}.lang` > default.
/// Keeps `<html lang dir>` and `og:locale` in sync, and mirrors the choice to the user doc.
class LangController extends ChangeNotifier {
  LangController._();
  static final instance = LangController._();

  static const _storeKey = 'g4m_lang';

  String code = kDefaultLang;
  List<Lang> languages = const [Lang('en', 'English', 'English', isDefault: true)];
  Map<String, String> overrides = const {};
  bool _explicit = false;
  bool _loaded = false;
  StreamSubscription? _langSub, _trSub;

  Locale get locale => Locale(code);
  bool get rtl => kRtlLangs.contains(code);
  Iterable<Locale> get supportedLocales => kSupportedLangs.map(Locale.new);

  void init() {
    final fromUrl = Uri.base.queryParameters['lang'];
    final stored = WebBridge.local(_storeKey);
    if (fromUrl != null && kSupportedLangs.contains(fromUrl)) {
      code = fromUrl;
      _explicit = true;
      WebBridge.setLocal(_storeKey, fromUrl);
    } else if (stored != null && kSupportedLangs.contains(stored)) {
      code = stored;
      _explicit = true;
    }
    _applyDocument();
    _listenOverrides();
    _langSub = FirebaseFirestore.instance.collection('languages').snapshots().listen((s) {
      final out = <Lang>[];
      for (final d in s.docs) {
        final m = d.data();
        final c = (m['code'] as String?) ?? d.id;
        if (m['active'] != true || !kSupportedLangs.contains(c)) continue;
        out.add(Lang(
          c,
          (m['name'] as String?) ?? kLangEnglish[c]!,
          (m['nativeName'] as String?) ?? kLangNative[c]!,
          rtl: m['rtl'] == true || kRtlLangs.contains(c),
          isDefault: m['isDefault'] == true,
        ));
      }
      out.sort((a, b) => kSupportedLangs.indexOf(a.code).compareTo(kSupportedLangs.indexOf(b.code)));
      if (out.isEmpty) out.add(const Lang('en', 'English', 'English', isDefault: true));
      languages = out;
      _loaded = true;
      // The chosen language was switched off by an admin: fall back to the default one.
      if (!out.any((l) => l.code == code)) {
        final def = out.where((l) => l.isDefault).firstOrNull ?? out.first;
        _set(def.code, persist: false);
      } else {
        notifyListeners();
      }
    }, onError: (_) {});
  }

  bool isActive(String c) => !_loaded ? c == code || c == kDefaultLang : languages.any((l) => l.code == c);

  /// Called by the user's profile listener: adopt the saved language unless this browser chose one.
  void adoptFromProfile(String? saved) {
    if (saved == null || saved == code || !kSupportedLangs.contains(saved)) return;
    if (_explicit) {
      // This browser already has a choice; keep it and push it to the account instead.
      _saveToProfile(code);
      return;
    }
    if (_loaded && !languages.any((l) => l.code == saved)) return;
    _set(saved, persist: false);
  }

  /// User picked a language from the picker.
  Future<void> select(String c) async {
    if (!kSupportedLangs.contains(c)) return;
    _explicit = true;
    WebBridge.setLocal(_storeKey, c);
    _set(c);
    await _saveToProfile(c);
  }

  void _set(String c, {bool persist = true}) {
    if (c == code) return;
    code = c;
    if (persist) WebBridge.setLocal(_storeKey, c);
    _applyDocument();
    _listenOverrides();
    notifyListeners();
  }

  Future<void> _saveToProfile(String c) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) return;
    try {
      await Fs.user(u.uid).set({'lang': c}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _listenOverrides() {
    _trSub?.cancel();
    overrides = const {};
    _trSub = FirebaseFirestore.instance.doc('translations/$code').snapshots().listen((d) {
      final m = d.data()?['strings'];
      overrides = m is Map ? m.map((k, v) => MapEntry('$k', '$v')) : const {};
      notifyListeners();
    }, onError: (_) {});
  }

  void _applyDocument() {
    try {
      final html = web.document.documentElement;
      html?.setAttribute('lang', code);
      html?.setAttribute('dir', rtl ? 'rtl' : 'ltr');
      web.document.querySelector('meta[property="og:locale"]')?.setAttribute('content', switch (code) {
        'hi' => 'hi_IN',
        'gu' => 'gu_IN',
        'ar' => 'ar_AR',
        _ => 'en_IN',
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _langSub?.cancel();
    _trSub?.cancel();
    super.dispose();
  }
}
