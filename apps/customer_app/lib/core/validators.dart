/// Pure form validators shared by the phone sign-in and "Complete your profile" screens.
/// Each returns null when valid, or a short message.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _referral = RegExp(r'^[A-Z0-9]{4,16}$');

  static String? name(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 2) return 'Enter your name';
    if (s.length > 60) return 'Keep it under 60 characters';
    if (RegExp(r'\d').hasMatch(s)) return 'Names can\'t contain numbers';
    return null;
  }

  static String? email(String? v, {bool required = false}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return required ? 'Enter your email' : null;
    return _email.hasMatch(s) ? null : 'Enter a valid email';
  }

  /// [v] is the national number; [dial] the country code (default +91).
  static String? phone(String? v, {String dial = '+91', bool required = false}) {
    final digits = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return required ? 'Enter your mobile number' : null;
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'Use digits only';
    if (dial == '+91') {
      return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? null : 'Enter a valid 10-digit mobile number';
    }
    return digits.length >= 6 && digits.length <= 14 ? null : 'Enter a valid mobile number';
  }

  static String? dialCode(String? v) => RegExp(r'^\+\d{1,4}$').hasMatch((v ?? '').trim()) ? null : 'Invalid code';

  static String? referral(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    if (s.isEmpty) return null;
    return _referral.hasMatch(s) ? null : 'Referral codes are 4–16 letters or digits';
  }

  /// "+91" + "98765 43210" -> "+919876543210". Strips a leading 0 from Indian numbers.
  static String toE164(String dial, String number) {
    var digits = number.replaceAll(RegExp(r'\D'), '');
    final cc = dial.replaceAll(RegExp(r'[^\d]'), '');
    if (cc == '91' && digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith(cc) && digits.length > 10 && cc == '91') digits = digits.substring(cc.length);
    return '+$cc$digits';
  }

  /// Any stored Indian phone ("+919876543210", "919876543210", "09876543210") -> "9876543210",
  /// for fields that already show a "+91 " prefix. Other numbers pass through unchanged.
  static String localIndian(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) return digits.substring(2);
    if (digits.length == 11 && digits.startsWith('0')) return digits.substring(1);
    return digits.length == 10 ? digits : (phone ?? '');
  }

  /// "+919876543210" -> "+91 98765 43210" for display.
  static String prettyPhone(String e164) {
    final m = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(e164);
    return m == null ? e164 : '+91 ${m[1]} ${m[2]}';
  }
}
