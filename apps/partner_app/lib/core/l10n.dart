import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Lightweight EN/HI localisation.
///
/// Material's own widgets stay in English: `flutter_localizations` pins
/// `intl 0.20.2`, while g4m_core requires `intl ^0.20.3`, so it cannot be added.
/// App strings are translated here instead.
///
/// Usage: `context.tr('Orders', 'ऑर्डर')` for one-off strings, or `S.of(context).orders` for core strings.
extension TrX on BuildContext {
  String tr(String en, String hi) => AppState.instance.lang == 'hi' ? hi : en;
  S get s => S._(AppState.instance.lang == 'hi');
}

/// Core strings shared by both roles.
class S {
  const S._(this.hi);
  final bool hi;
  static S of(BuildContext _) => S._(AppState.instance.lang == 'hi');
  String _t(String en, String h) => hi ? h : en;

  String get appName => 'Go4Market Partner';
  String get login => _t('Log in', 'लॉग इन करें');
  String get logout => _t('Log out', 'लॉग आउट');
  String get email => _t('Email', 'ईमेल');
  String get password => _t('Password', 'पासवर्ड');
  String get forgotPassword => _t('Forgot password?', 'पासवर्ड भूल गए?');
  String get createAccount => _t('Create account', 'खाता बनाएं');
  String get fullName => _t('Full name', 'पूरा नाम');
  String get phone => _t('Phone', 'फ़ोन');
  String get continueBtn => _t('Continue', 'जारी रखें');
  String get next => _t('Next', 'आगे');
  String get back => _t('Back', 'पीछे');
  String get skip => _t('Skip', 'छोड़ें');
  String get submit => _t('Submit', 'जमा करें');
  String get save => _t('Save', 'सहेजें');
  String get cancel => _t('Cancel', 'रद्द करें');
  String get confirm => _t('Confirm', 'पुष्टि करें');
  String get retry => _t('Retry', 'फिर से कोशिश करें');
  String get search => _t('Search', 'खोजें');
  String get home => _t('Home', 'होम');
  String get dashboard => _t('Dashboard', 'डैशबोर्ड');
  String get orders => _t('Orders', 'ऑर्डर');
  String get products => _t('Products', 'उत्पाद');
  String get more => _t('More', 'और');
  String get profile => _t('Profile', 'प्रोफ़ाइल');
  String get notifications => _t('Notifications', 'सूचनाएं');
  String get earnings => _t('Earnings', 'कमाई');
  String get withdrawals => _t('Withdrawals', 'निकासी');
  String get history => _t('History', 'इतिहास');
  String get settings => _t('Settings', 'सेटिंग्स');
  String get language => _t('Language', 'भाषा');
  String get darkMode => _t('Dark mode', 'डार्क मोड');
  String get helpFaq => _t('Help & FAQ', 'सहायता और FAQ');
  String get today => _t('Today', 'आज');
  String get revenue => _t('Revenue', 'आय');
  String get balance => _t('Balance', 'बैलेंस');
  String get online => _t('Online', 'ऑनलाइन');
  String get offline => _t('Offline', 'ऑफ़लाइन');
  String get noData => _t('Nothing here yet', 'अभी यहां कुछ नहीं है');
  String get somethingWrong => _t('Something went wrong', 'कुछ गलत हो गया');
  String get pendingApproval => _t('Pending approval', 'स्वीकृति लंबित');
  String get sellOn => _t('Sell on Go4Market', 'Go4Market पर बेचें');
  String get deliverWith => _t('Deliver with Go4Market', 'Go4Market के साथ डिलीवरी करें');
  String get seller => _t('Seller', 'विक्रेता');
  String get deliveryPartner => _t('Delivery Partner', 'डिलीवरी पार्टनर');
  String get updateRequired => _t('Update required', 'अपडेट आवश्यक है');
  String get updateNow => _t('Update now', 'अभी अपडेट करें');
  String get call => _t('Call', 'कॉल करें');
  String get navigate => _t('Navigate', 'नेविगेट करें');
  String get cashInHand => _t('Cash in hand', 'हाथ में नकद');
  String get completed => _t('Completed', 'पूर्ण');
  String get amount => _t('Amount', 'राशि');
  String get status => _t('Status', 'स्थिति');
}
