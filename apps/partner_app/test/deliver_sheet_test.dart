import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:partner_app/core/app_state.dart';
import 'package:partner_app/core/partner_theme.dart';
import 'package:partner_app/features/delivery/active_delivery_screen.dart';

Future<void> pumpSheet(WidgetTester t) async {
  final order = ShopOrder('o1', {
    'orderNo': 'G4M100011',
    'deliveryOtp': '7998',
    'paymentMethod': 'cod',
    'paymentStatus': 'pending',
    'payable': 369,
    'status': 'out_for_delivery',
  });
  final theme = ThemeData.light().copyWith(extensions: [RoleColors.of(PartnerRole.delivery, Brightness.light)]);
  await t.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: SingleChildScrollView(child: DeliverSheet(order: order)))));
  await t.pumpAndSettle();
}

Future<void> typeDigits(WidgetTester t, String digits) async {
  // Mimics a keyboard: each key press inserts at the current caret position.
  final field = find.byType(TextField);
  for (final d in digits.split('')) {
    final ctrl = t.widget<TextField>(field).controller!;
    final v = ctrl.value;
    final at = v.selection.isValid ? v.selection.baseOffset : v.text.length;
    await t.enterText(field, v.text.substring(0, at) + d + v.text.substring(at));
    // enterText puts the caret at the end; restore the "real keyboard" caret right after the inserted digit.
    ctrl.selection = TextSelection.collapsed(offset: at + 1);
    await t.pump();
  }
}

/// Lets entrance-animation timers finish before the test tears down.
Future<void> drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('digits stay in typing order after tapping an OTP box mid-entry', (t) async {
    await pumpSheet(t);
    await typeDigits(t, '79');
    // Tapping a box used to leave the hidden field's caret mid-text, so later digits were inserted in front.
    final ctrl = t.widget<TextField>(find.byType(TextField)).controller!;
    ctrl.selection = const TextSelection.collapsed(offset: 0);
    await t.tap(find.text('7').first);
    await t.pump();
    await typeDigits(t, '98');
    expect(ctrl.text, '7998');
    await drain(t);
  });

  testWidgets('Mark delivered enables only after OTP and cash confirmation', (t) async {
    await pumpSheet(t);
    FilledButton button() => t.widget<FilledButton>(find.byWidgetPredicate((w) => w is FilledButton));
    expect(button().onPressed, isNull);
    await typeDigits(t, '7998');
    expect(button().onPressed, isNull, reason: 'COD cash not yet confirmed');
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    expect(button().onPressed, isNotNull);
    await drain(t);
  });
}
