import 'package:customer_app/widgets/otp_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

List<OtpCell> _cells(WidgetTester t) => t.widgetList<OtpCell>(find.byType(OtpCell)).toList();
String _digits(WidgetTester t) => _cells(t).map((c) => c.digit).join();
int _activeIndex(WidgetTester t) => _cells(t).indexWhere((c) => c.active);

void main() {
  test('extractOtp prefers a standalone 6-digit run', () {
    expect(extractOtp('Your Go4Market code is 654321'), '654321');
    expect(extractOtp('123456 is your verification code for go4market.firebaseapp.com'), '123456');
    expect(extractOtp('OTP 987-654 valid 10 min'), '987654');
    expect(extractOtp('12'), '12');
    expect(extractOtp('1 2 3 4 5 6 7'), '123456');
  });

  testWidgets('renders six boxes and auto-advances as digits arrive', (t) async {
    final done = <String>[];
    await t.pumpWidget(_app(OtpInput(onCompleted: done.add)));
    await t.pumpAndSettle();

    expect(find.byType(OtpCell), findsNWidgets(6));
    expect(_activeIndex(t), 0);

    await t.enterText(find.byKey(const ValueKey('otp-field')), '12');
    await t.pumpAndSettle();
    expect(_digits(t), '12');
    expect(_activeIndex(t), 2);
    expect(done, isEmpty);

    await t.enterText(find.byKey(const ValueKey('otp-field')), '123456');
    await t.pumpAndSettle();
    expect(_digits(t), '123456');
    expect(_activeIndex(t), -1, reason: 'nothing is highlighted once complete');
    expect(done, ['123456']);
  });

  testWidgets('backspace walks back', (t) async {
    final c = TextEditingController();
    await t.pumpWidget(_app(OtpInput(controller: c)));
    await t.enterText(find.byKey(const ValueKey('otp-field')), '1234');
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('otp-field')), '123');
    await t.pumpAndSettle();
    expect(_digits(t), '123');
    expect(_activeIndex(t), 3);
  });

  testWidgets('paste keeps only digits and caps at six', (t) async {
    final done = <String>[];
    await t.pumpWidget(_app(OtpInput(onCompleted: done.add)));
    await t.enterText(find.byKey(const ValueKey('otp-field')), 'Your Go4Market code is 654-321. Do not share 99');
    await t.pumpAndSettle();
    expect(_digits(t), '654321');
    expect(done, ['654321']);
  });

  testWidgets('clipboard paste through the system menu', (t) async {
    final done = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'OTP: 987 654'};
      if (call.method == 'Clipboard.hasStrings') return {'value': true};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await t.pumpWidget(_app(OtpInput(onCompleted: done.add)));
    await t.pumpAndSettle();
    final state = t.state<EditableTextState>(find.byType(EditableText));
    state.pasteText(SelectionChangedCause.toolbar);
    await t.pumpAndSettle();
    expect(_digits(t), '987654');
    expect(done, ['987654']);
  });

  testWidgets('programmatic fill (SMS auto-retrieval) completes', (t) async {
    final c = TextEditingController();
    final done = <String>[];
    await t.pumpWidget(_app(OtpInput(controller: c, onCompleted: done.add)));
    c.text = '246810';
    await t.pumpAndSettle();
    expect(_digits(t), '246810');
    expect(done, ['246810']);
  });

  testWidgets('error state marks every box', (t) async {
    await t.pumpWidget(_app(const OtpInput()));
    await t.pumpWidget(_app(const OtpInput(hasError: true)));
    await t.pumpAndSettle();
    expect(_cells(t).every((c) => c.error), isTrue);
  });
}
