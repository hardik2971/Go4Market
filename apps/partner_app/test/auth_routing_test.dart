import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/app_state.dart';
import 'package:partner_app/features/auth/auth_routing.dart';

void main() {
  group('decidePostLogin', () {
    test('existing seller goes to seller home', () {
      final d = decidePostLogin(claim: 'seller', isNewUser: false, selected: PartnerRole.seller);
      expect(d.route, PostLoginRoute.sellerHome);
      expect(d.registeredAs, isNull);
      expect(d.completeProfile, isFalse);
    });

    test('existing delivery partner goes to delivery home', () {
      final d = decidePostLogin(claim: 'delivery', isNewUser: false, selected: PartnerRole.delivery);
      expect(d.route, PostLoginRoute.deliveryHome);
      expect(d.registeredAs, isNull);
    });

    test('claim wins over the login toggle and flags the mismatch', () {
      final d = decidePostLogin(claim: 'delivery', isNewUser: false, selected: PartnerRole.seller);
      expect(d.route, PostLoginRoute.deliveryHome);
      expect(d.registeredAs, PartnerRole.delivery);

      final s = decidePostLogin(claim: 'seller', isNewUser: false, selected: PartnerRole.delivery);
      expect(s.route, PostLoginRoute.sellerHome);
      expect(s.registeredAs, PartnerRole.seller);
    });

    test('new phone / Google user goes to the role chooser and completes the profile', () {
      for (final claim in ['customer', '', 'guest']) {
        for (final role in PartnerRole.values) {
          final d = decidePostLogin(claim: claim, isNewUser: true, selected: role);
          expect(d.route, PostLoginRoute.roleChooser, reason: 'claim "$claim"');
          expect(d.completeProfile, isTrue);
          expect(d.registeredAs, isNull);
        }
      }
    });

    test('existing customer account sees the role-mismatch message', () {
      final d = decidePostLogin(claim: 'customer', isNewUser: false, selected: PartnerRole.seller);
      expect(d.route, PostLoginRoute.customerMismatch);
      expect(d.completeProfile, isFalse);
    });

    test('admin gets the admin notice', () {
      expect(decidePostLogin(claim: 'admin', isNewUser: false, selected: PartnerRole.seller).route, PostLoginRoute.admin);
    });

    test('a partner claim is never treated as new, even on a fresh credential', () {
      final d = decidePostLogin(claim: 'seller', isNewUser: true, selected: PartnerRole.seller);
      expect(d.route, PostLoginRoute.sellerHome);
      expect(d.completeProfile, isFalse);
    });
  });

  group('phone helpers', () {
    test('toE164 defaults to +91 and validates Indian mobiles', () {
      expect(toE164('98765 43210'), '+919876543210');
      expect(toE164('09876543210'), '+919876543210');
      expect(toE164('919876543210'), '+919876543210');
      expect(toE164('+91 98765-43210'), '+919876543210');
      expect(toE164('12345'), isNull);
      expect(toE164('1234567890'), isNull); // Indian mobiles start 6-9
      expect(toE164(''), isNull);
    });

    test('toE164 honours another country code', () {
      expect(toE164('7911 123456', countryCode: '+44'), '+447911123456');
      expect(toE164('+14155550123', countryCode: '+91'), '+14155550123');
    });

    test('nationalPhone strips +91 only', () {
      expect(nationalPhone('+919876543210'), '9876543210');
      expect(nationalPhone('+447911123456'), '+447911123456');
      expect(nationalPhone(null), '');
    });

    test('maskPhone hides the middle digits', () {
      expect(maskPhone('+919876543210'), '+91 98•••••210');
    });

    test('authErrorCode reads codes from exceptions and strings', () {
      expect(authErrorCode(_CodeError('operation-not-allowed')), 'operation-not-allowed');
      expect(authErrorCode(Exception('[firebase_auth/invalid-verification-code] bad code')), 'invalid-verification-code');
      expect(authErrorCode(Exception('boom')), 'unknown');
    });
  });
}

class _CodeError implements Exception {
  _CodeError(this.code);
  final String code;
}
