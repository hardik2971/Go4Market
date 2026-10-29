import '../../core/app_state.dart';

/// Where a freshly signed-in partner goes. Pure, so it is unit tested
/// (test/auth_routing_test.dart). The `role` claim is the only source of truth.
enum PostLoginRoute { sellerHome, deliveryHome, admin, roleChooser, customerMismatch }

class PostLoginDecision {
  const PostLoginDecision(this.route, {this.completeProfile = false, this.registeredAs});

  final PostLoginRoute route;

  /// First sign-in through phone / Google: call `completeProfile` before routing.
  final bool completeProfile;

  /// Set when the account already holds the *other* partner role than the one
  /// picked on the login toggle (shows the existing "registered as" message).
  final PartnerRole? registeredAs;

  @override
  String toString() => 'PostLoginDecision($route, completeProfile: $completeProfile, registeredAs: $registeredAs)';
}

/// Decides the post-login route from the `role` claim.
///
/// - `seller` / `delivery` claim: that role's home (plus a mismatch notice when it
///   differs from [selected]).
/// - `admin`: the admin notice.
/// - no partner claim and [isNewUser]: role chooser, then the registration wizard.
/// - an existing `customer` account: the role-mismatch message.
PostLoginDecision decidePostLogin({required String claim, required bool isNewUser, required PartnerRole selected}) {
  final role = PartnerRoleX.fromClaim(claim);
  if (role != null) {
    return PostLoginDecision(
      role == PartnerRole.seller ? PostLoginRoute.sellerHome : PostLoginRoute.deliveryHome,
      registeredAs: role == selected ? null : role,
    );
  }
  if (claim == 'admin') return const PostLoginDecision(PostLoginRoute.admin);
  if (isNewUser) return const PostLoginDecision(PostLoginRoute.roleChooser, completeProfile: true);
  return const PostLoginDecision(PostLoginRoute.customerMismatch);
}

/// Builds an E.164 number from what the user typed. A missing country code
/// falls back to [countryCode] (+91). Returns null when it cannot be a phone number.
String? toE164(String input, {String countryCode = '+91'}) {
  final raw = input.trim();
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (raw.startsWith('+')) {
    return digits.length >= 8 && digits.length <= 15 ? '+$digits' : null;
  }
  final cc = countryCode.replaceAll(RegExp(r'\D'), '');
  if (cc == '91') {
    // Accept 0-prefixed (09876543210) and 91-prefixed (919876543210) Indian numbers.
    if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
    if (digits.length != 10 || !RegExp(r'^[6-9]').hasMatch(digits)) return null;
    return '+91$digits';
  }
  final all = '$cc$digits';
  return all.length >= 8 && all.length <= 15 ? '+$all' : null;
}

/// `+919876543210` -> `9876543210` (for fields that already show a +91 prefix).
String nationalPhone(String? e164) {
  if (e164 == null) return '';
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (e164.trim().startsWith('+91') && d.length == 12) return d.substring(2);
  return e164.trim();
}

/// Masks a number for the "code sent to" line: `+91 98•••••210`.
String maskPhone(String e164) {
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.length < 6) return e164;
  final cc = d.length > 10 ? d.substring(0, d.length - 10) : '';
  final n = d.substring(d.length - 10 < 0 ? 0 : d.length - 10);
  final masked = '${n.substring(0, 2)}${'•' * (n.length - 5)}${n.substring(n.length - 3)}';
  return cc.isEmpty ? masked : '+$cc $masked';
}

/// Extracts the Firebase error code (`operation-not-allowed`, `invalid-verification-code`, ...)
/// from any auth / functions exception, or from its string form.
String authErrorCode(Object e) {
  try {
    final code = (e as dynamic).code;
    if (code is String && code.isNotEmpty) return code;
  } catch (_) {}
  final m = RegExp(r'\[[\w-]+/([\w-]+)\]').firstMatch(e.toString());
  return m?.group(1) ?? 'unknown';
}
