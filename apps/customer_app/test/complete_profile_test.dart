import 'package:customer_app/core/validators.dart';
import 'package:customer_app/screens/auth/complete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)));

Future<void> _submit(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const ValueKey('profile-submit')));
  await t.tap(find.byKey(const ValueKey('profile-submit')));
  await t.pumpAndSettle();
}

void main() {
  group('Validators', () {
    test('name', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name(' A '), isNotNull);
      expect(Validators.name('R2D2'), isNotNull);
      expect(Validators.name('Asha Verma'), isNull);
    });

    test('email is optional unless required', () {
      expect(Validators.email(''), isNull);
      expect(Validators.email('', required: true), isNotNull);
      expect(Validators.email('asha@'), isNotNull);
      expect(Validators.email('asha@example.in'), isNull);
    });

    test('Indian mobile numbers', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('', required: true), isNotNull);
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('5876543210'), isNotNull, reason: 'Indian mobiles start with 6-9');
      expect(Validators.phone('98765 43210'), isNull);
      expect(Validators.phone('4155550100', dial: '+1'), isNull);
    });

    test('referral codes', () {
      expect(Validators.referral(''), isNull);
      expect(Validators.referral('ab'), isNotNull);
      expect(Validators.referral('g4m-123'), isNotNull);
      expect(Validators.referral('asha1234'), isNull);
    });

    test('E.164 normalisation', () {
      expect(Validators.toE164('+91', '98765 43210'), '+919876543210');
      expect(Validators.toE164('+91', '09876543210'), '+919876543210');
      expect(Validators.toE164('+91', '919876543210'), '+919876543210');
      expect(Validators.toE164('+1', '415 555 0100'), '+14155550100');
      expect(Validators.prettyPhone('+919876543210'), '+91 98765 43210');
    });
  });

  group('CompleteProfileForm', () {
    testWidgets('requires a name and validates the optional fields', (t) async {
      final submitted = <ProfileInput>[];
      await t.pumpWidget(_app(CompleteProfileForm(askEmail: true, askPhone: true, onSubmit: (p) async => submitted.add(p))));
      await t.pumpAndSettle();

      await _submit(t);
      expect(find.text('Enter your name'), findsOneWidget);
      expect(submitted, isEmpty);

      await t.enterText(find.byKey(const ValueKey('profile-name')), 'Asha Verma');
      await t.enterText(find.byKey(const ValueKey('profile-email')), 'asha@');
      await t.enterText(find.byKey(const ValueKey('profile-phone')), '12345');
      await _submit(t);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
      expect(submitted, isEmpty);

      // Referral field is revealed on demand and validated too.
      await t.tap(find.byKey(const ValueKey('profile-ref-toggle')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('profile-ref')), 'ab');
      await t.enterText(find.byKey(const ValueKey('profile-email')), 'asha@example.in');
      await t.enterText(find.byKey(const ValueKey('profile-phone')), '98765 43210');
      await _submit(t);
      expect(find.textContaining('Referral codes are'), findsOneWidget);
      expect(submitted, isEmpty);

      await t.enterText(find.byKey(const ValueKey('profile-ref')), 'asha1234');
      await _submit(t);
      expect(submitted, hasLength(1));
      final p = submitted.single;
      expect(p.name, 'Asha Verma');
      expect(p.email, 'asha@example.in');
      expect(p.phone, '+919876543210');
      expect(p.referralCode, 'ASHA1234');
    });

    testWidgets('only asks for what is missing; empty optional fields are omitted', (t) async {
      final submitted = <ProfileInput>[];
      var skipped = false;
      await t.pumpWidget(_app(CompleteProfileForm(
        initialName: 'Ravi Kumar',
        askPhone: true,
        onSubmit: (p) async => submitted.add(p),
        onSkip: () => skipped = true,
      )));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile-email')), findsNothing);
      expect(find.byKey(const ValueKey('profile-phone')), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);

      await _submit(t);
      expect(submitted.single.phone, isNull);
      expect(submitted.single.email, isNull);
      expect(submitted.single.referralCode, isNull);

      await t.tap(find.text('Skip for now'));
      expect(skipped, isTrue);
    });

    testWidgets('shows the error when saving fails', (t) async {
      await t.pumpWidget(_app(CompleteProfileForm(initialName: 'Asha', onSubmit: (_) async => throw Exception('Server busy'))));
      await t.pumpAndSettle();
      await _submit(t);
      expect(find.text('Server busy'), findsOneWidget);
    });
  });
}
