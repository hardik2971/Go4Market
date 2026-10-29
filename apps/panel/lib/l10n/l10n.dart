import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat, Intl;

import 'dict.dart';

/// A UI language the panels ship strings for. Mirrors Firestore `languages/{code}`.
class AppLang {
  const AppLang(this.code, this.name, this.nativeName, {this.rtl = false});
  final String code;
  final String name;
  final String nativeName;
  final bool rtl;
}

const appLangs = <AppLang>[
  AppLang('en', 'English', 'English'),
  AppLang('hi', 'Hindi', 'हिन्दी'),
  AppLang('gu', 'Gujarati', 'ગુજરાતી'),
  AppLang('ar', 'Arabic', 'العربية', rtl: true),
];

const supportedLocales = <Locale>[Locale('en'), Locale('hi'), Locale('gu'), Locale('ar')];

/// Current UI language. English is the default and the fallback for any missing string.
class L10n extends ChangeNotifier {
  L10n._();
  static final instance = L10n._();

  String _code = 'en';
  String get code => _code;

  /// Codes whose Firestore `languages/{code}.active` is true. Null until loaded (= all offered).
  Set<String>? active;

  Locale get locale => Locale(_code);
  bool get rtl => _code == 'ar';
  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;
  AppLang get lang => appLangs.firstWhere((l) => l.code == _code);

  /// intl locale for numbers and dates. `ar` keeps Latin digits (matches charts and order numbers).
  String get intlLocale => switch (_code) {
        'hi' => 'hi',
        'gu' => 'gu',
        'ar' => 'ar',
        _ => 'en_IN',
      };

  /// Languages offered in the pickers: English always, others only when active in Firestore.
  List<AppLang> get available => [for (final l in appLangs) if (l.code == 'en' || active == null || active!.contains(l.code)) l];

  bool isOffered(String c) => available.any((l) => l.code == c);

  int get _index => switch (_code) {
        'hi' => 0,
        'gu' => 1,
        'ar' => 2,
        _ => -1,
      };

  /// Switches language; returns false when [c] is unknown or inactive.
  bool set(String c) {
    if (!appLangs.any((l) => l.code == c) || !isOffered(c)) return false;
    if (c == _code) return true;
    _code = c;
    Intl.defaultLocale = intlLocale;
    // flutter_localizations installs Arabic-Indic digits for 'ar' dates; keep Latin digits so dates,
    // amounts, order numbers and chart axes all read the same way.
    DateFormat.useNativeDigitsByDefaultFor('ar', false);
    notifyListeners();
    return true;
  }

  void setActive(Set<String> codes) {
    active = codes;
    if (!isOffered(_code)) {
      set('en');
    } else {
      notifyListeners();
    }
  }
}

/// Translates an English UI string; unknown strings pass through unchanged.
String tr(String en) {
  final i = L10n.instance._index;
  if (i < 0 || en.isEmpty) return en;
  final v = kDict[en];
  if (v != null) return v[i];
  // "Label *" (required form field) and "Label:" variants.
  if (en.endsWith(' *')) return '${tr(en.substring(0, en.length - 2))} *';
  return en;
}

/// Translates a template with `{name}` placeholders, e.g. `trf('Add {x}', {'x': 'coupon'})`.
String trf(String en, Map<String, Object?> args) {
  var s = tr(en);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Lower-cases Latin text only (Devanagari/Gujarati/Arabic have no case).
String lowerUi(String s) => L10n.instance._index < 0 ? s.toLowerCase() : s;

/// Typed strings for the shell, auth screens and shared chrome.
abstract final class S {
  // Shell / top bar
  static String get menu => tr('Menu');
  static String get searchHint => tr('Search pages, orders, products…');
  static String get searchShort => tr('Search (Ctrl+K)');
  static String get lightMode => tr('Light mode');
  static String get darkMode => tr('Dark mode');
  static String get notifications => tr('Notifications');
  static String get markAllRead => tr('Mark all read');
  static String get allCaughtUp => tr("You're all caught up");
  static String get account => tr('Account');
  static String get myAccount => tr('My account');
  static String get signOut => tr('Sign out');
  static String get signOutQ => tr('Sign out?');
  static String get switchModule => tr('Switch module');
  static String get allModules => tr('All modules');
  static String get disabled => tr('Disabled');
  static String get language => tr('Language');
  static String get enableNotifications => tr('Enable notifications');
  static String get notificationsOn => tr('Notifications on');
  static String get notificationsBlocked => tr('Notifications are blocked in this browser');
  static String get pageNotFound => tr('Page not found');
  static String get backToDashboard => tr('Back to dashboard');
  static String get dashboard => tr('Dashboard');
  // Command palette
  static String get jumpHint => tr('Jump to a page or action…');
  static String get paletteSearchHint => tr('Search pages, order no, products, customers…');
  static String get noResults => tr('No results');
  static String get toggleDark => tr('Toggle dark mode');
  static String get appearance => tr('Appearance');
  static String get pages => tr('Pages');
  static String get actions => tr('Actions');
  static String get records => tr('Records');
  static String get navigate => tr('navigate');
  static String get open => tr('open');
  static String get close => tr('close');
  // Common buttons
  static String get cancel => tr('Cancel');
  static String get confirm => tr('Confirm');
  static String get save => tr('Save');
  static String get retry => tr('Retry');
  static String get clear => tr('Clear');
  static String get back => tr('Back');
  static String get continue_ => tr('Continue');
  static String get refresh => tr('Refresh');
  static String get required => tr('Required');
  static String get enterNumber => tr('Enter a number');
  static String get note => tr('Note');
  // Table chrome
  static String get search => tr('Search…');
  static String get table => tr('Table');
  static String get cards => tr('Cards');
  static String get exportCsv => tr('Export CSV (current view)');
  static String get noMatches => tr('No matches');
  static String get tryDifferent => tr('Try a different search or clear the filters.');
  static String get clearFilters => tr('Clear filters');
  static String get nothingYet => tr('Nothing here yet');
  static String get loadMore => tr('Load more');
  static String get rows => tr('Rows');
  static String allOf(String label) => trf('All {x}', {'x': lowerUi(tr(label))});
  static String selected(int n) => trf('{n} selected', {'n': n});
  static String showing(int a, int b, int c) => trf('Showing {a}–{b} of {c}', {'a': a, 'b': b, 'c': c});
  static String exported(int n) => trf('Exported {n} rows', {'n': n});
  static String bulkDone(String label, int n) => trf('{action}: {n} item(s)', {'action': tr(label), 'n': n});
  static String bulkConfirm(String label, int n) => trf('{action} {n} item(s)?', {'action': tr(label), 'n': n});
  // Errors / empty
  static String get indexBuilding => tr('Index is building');
  static String get noAccess => tr('No access');
  static String get couldNotLoad => tr('Could not load data');
  static String get indexBuildingMsg => tr('Firestore is still building an index for this view. It usually takes a few minutes.');
  static String get noPermissionMsg => tr('Your account does not have permission to view this data.');
  // Auth
  static String get welcomeBack => tr('Welcome back');
  static String signInTo(String panel) => trf('Sign in to the Go4Market {panel} panel', {'panel': lowerUi(tr(panel))});
  static String get email => tr('Email');
  static String get password => tr('Password');
  static String get enterEmail => tr('Enter your email');
  static String get atLeast6 => tr('At least 6 characters');
  static String get forgotPassword => tr('Forgot password?');
  static String get resetPassword => tr('Reset password');
  static String get sendLink => tr('Send link');
  static String resetSent(String email) => trf('Password reset link sent to {email}', {'email': email});
  static String get signIn => tr('Sign in');
  static String get orContinueWith => tr('or continue with');
  static String get google => tr('Continue with Google');
  static String get phone => tr('Continue with phone');
  static String get mobileNumber => tr('Mobile number');
  static String get sendOtp => tr('Send OTP');
  static String get otp => tr('6-digit OTP');
  static String get verify => tr('Verify & sign in');
  static String otpSentTo(String p) => trf('OTP sent to {phone}', {'phone': p});
  static String get changeNumber => tr('Change number');
  static String get useEmail => tr('Use email instead');
  static String get phoneNotEnabled => tr('Phone sign-in is not enabled yet. Use Google or email.');
  static String get invalidPhone => tr('Enter a valid mobile number');
  static String get invalidOtp => tr('Incorrect OTP. Check the code and try again.');
  static String get popupClosed => tr('Sign-in window was closed.');
  static String get popupBlocked => tr('Allow pop-ups for this site to sign in with Google.');
  static String get newToG4m => tr('New to Go4Market? ');
  static String get wantToDeliver => tr('Want to deliver with us? ');
  static String get becomeSeller => tr('Become a seller');
  static String get joinPartner => tr('Join as a partner');
  static String get securedBy => tr('Secured by Firebase Authentication');
  static String get incorrectCreds => tr('Incorrect email or password.');
  static String get tooMany => tr('Too many attempts. Try again in a few minutes.');
  static String get accountDisabled => tr('This account has been disabled.');
  static String get noAccessPanel => tr('No access to this panel');
  static String wrongRole(String email, String role, String claim) =>
      trf('You are signed in as {email} ({role}). This panel is only for {claim} accounts.', {'email': email, 'role': role, 'claim': claim});
  static String get signOutSwitch => tr('Sign out and switch account');
  // Time ago
  static String get justNow => tr('just now');
  static String minAgo(int n) => trf('{n}m ago', {'n': n});
  static String hourAgo(int n) => trf('{n}h ago', {'n': n});
  static String dayAgo(int n) => trf('{n}d ago', {'n': n});
}
