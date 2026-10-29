import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/app_state.dart';
import 'package:partner_app/core/partner_theme.dart';
import 'package:partner_app/features/auth/otp_input.dart';

TextEditingValue _v(String text, [int? caret]) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret ?? text.length));

/// Lets the digit cross-fade finish and the outgoing child be dropped.
Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

void main() {
  group('OtpFormatter', () {
    final f = OtpFormatter(6);

    test('keeps digits only, capped at 6', () {
      expect(f.formatEditUpdate(_v('12'), _v('12a')).text, '12');
      expect(f.formatEditUpdate(_v('12345'), _v('123456')).text, '123456');
      expect(f.formatEditUpdate(_v('123456'), _v('1234567')).text, '123456');
    });

    test('a pasted full code replaces a half-typed one', () {
      expect(f.formatEditUpdate(_v('12'), _v('12Your code is 654 321')).text, '654321');
      expect(f.formatEditUpdate(_v(''), _v('G-482913 is your code')).text, '482913');
    });

    test('digits inside words in the SMS are ignored', () {
      expect(f.formatEditUpdate(_v(''), _v('Your Go4Market code is 654321')).text, '654321');
      expect(f.formatEditUpdate(_v('9'), _v('9123456 is your verification code for go4market.firebaseapp.com')).text, '123456');
      expect(f.extractCode('Code: 123-456. Valid 5 min'), '123456');
      expect(f.extractCode('no code here'), isNull);
    });

    test('a short paste is appended', () {
      expect(f.formatEditUpdate(_v('12'), _v('1234')).text, '1234');
    });

    test('caret stays at the end', () {
      final r = f.formatEditUpdate(_v('1'), _v('12'));
      expect(r.selection, const TextSelection.collapsed(offset: 2));
    });
  });

  group('OtpInput widget', () {
    late TextEditingController ctrl;
    late List<String> completed;

    Future<void> pump(WidgetTester t) async {
      ctrl = TextEditingController();
      completed = [];
      final theme = ThemeData.light().copyWith(extensions: [RoleColors.of(PartnerRole.seller, Brightness.light)]);
      await t.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OtpInput(controller: ctrl, onCompleted: completed.add, autofocus: false),
          ),
        ),
      ));
      await t.pump();
    }

    String boxText(WidgetTester t, int i) {
      final texts = find.descendant(of: find.byKey(ValueKey('otp-box-$i')), matching: find.byType(Text));
      if (texts.evaluate().isEmpty) return '';
      return t.widget<Text>(texts.first).data ?? '';
    }

    testWidgets('renders six boxes', (t) async {
      await pump(t);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('otp-box-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('otp-box-6')), findsNothing);
    });

    testWidgets('typing fills the boxes one by one and completes once', (t) async {
      await pump(t);
      final field = find.byKey(const ValueKey('otp-field'));
      var typed = '';
      for (final d in '482913'.split('')) {
        typed += d;
        await t.enterText(field, typed);
        await settle(t);
        expect(boxText(t, typed.length - 1), d);
        if (typed.length < 6) expect(boxText(t, typed.length), '');
      }
      expect(ctrl.text, '482913');
      expect(completed, ['482913']);
    });

    testWidgets('paste of a whole SMS fills every box', (t) async {
      await pump(t);
      final field = find.byKey(const ValueKey('otp-field'));
      await t.enterText(field, '12');
      await t.pump();
      await t.enterText(field, '12Your Go4Market code is 654321');
      await settle(t);
      expect(ctrl.text, '654321');
      for (var i = 0; i < 6; i++) {
        expect(boxText(t, i), '654321'[i]);
      }
      expect(completed, ['654321']);
    });

    testWidgets('letters are ignored and backspace clears the last box', (t) async {
      await pump(t);
      final field = find.byKey(const ValueKey('otp-field'));
      await t.enterText(field, '1a2b3');
      await settle(t);
      expect(ctrl.text, '123');
      await t.enterText(field, '12');
      await settle(t);
      expect(boxText(t, 1), '2');
      expect(boxText(t, 2), '');
      expect(completed, isEmpty);
    });

    testWidgets('uses the numeric keyboard and SMS autofill hint', (t) async {
      await pump(t);
      final tf = t.widget<TextField>(find.byKey(const ValueKey('otp-field')));
      expect(tf.keyboardType, TextInputType.number);
      expect(tf.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(tf.inputFormatters!.whereType<OtpFormatter>(), isNotEmpty);
      expect(tf.inputFormatters!.first, isA<TextInputFormatter>());
    });
  });
}
