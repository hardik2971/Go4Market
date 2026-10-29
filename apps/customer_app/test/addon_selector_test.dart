import 'package:customer_app/core/addons.dart';
import 'package:customer_app/widgets/addon_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g4m_core/g4m_core.dart';

/// Product page in miniature: selector + live price, the same wiring as ProductDetailScreen.
class _Harness extends StatefulWidget {
  const _Harness({required this.addons, required this.base, this.onLimit});
  final List<ProductAddon> addons;
  final double base;
  final ValueChanged<AddonGroup>? onLimit;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Set<String> sel = {};
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              Text('price ${Fmt.money(widget.base + addonTotal(widget.addons, sel))}', key: const ValueKey('price')),
              AddonSelector(addons: widget.addons, selected: sel, onChanged: (s) => setState(() => sel = s), onLimit: widget.onLimit),
            ]),
          ),
        ),
      );
}

String priceText(WidgetTester t) => t.widget<Text>(find.byKey(const ValueKey('price'))).data!;

void main() {
  final pizzaAddons = addonsFromData([
    {'id': 'extra-cheese', 'name': 'Extra cheese', 'price': 59, 'active': true},
    {'id': 'jalapenos', 'name': 'Jalapeños', 'price': 39, 'active': true},
    {'id': 'garlic-dip', 'name': 'Garlic dip', 'price': 25, 'active': true},
    {'id': 'gone', 'name': 'Retired topping', 'price': 10, 'active': false},
  ]);

  testWidgets('shows active add-ons and updates the price live', (t) async {
    await t.pumpWidget(_Harness(addons: pizzaAddons, base: 249));
    await t.pumpAndSettle();

    expect(find.text('Extra cheese'), findsOneWidget);
    expect(find.text('+₹59'), findsOneWidget);
    expect(find.text('Retired topping'), findsNothing);
    expect(priceText(t), 'price ₹249');
    expect(find.byKey(const ValueKey('addon-total')), findsNothing);

    await t.tap(find.byKey(const ValueKey('addon-extra-cheese')));
    await t.pumpAndSettle();
    expect(priceText(t), 'price ₹308');
    expect(find.text('Add-ons +₹59'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('addon-garlic-dip')));
    await t.pumpAndSettle();
    expect(priceText(t), 'price ₹333');
    expect(find.text('Add-ons +₹84'), findsOneWidget);

    // Deselect.
    await t.tap(find.byKey(const ValueKey('addon-extra-cheese')));
    await t.pumpAndSettle();
    expect(priceText(t), 'price ₹274');
    expect(find.text('Optional'), findsOneWidget);
  });

  testWidgets('respects group and maxSelect', (t) async {
    final grouped = addonsFromData([
      {'id': 'thin', 'name': 'Thin crust', 'price': 0, 'group': 'Crust', 'maxSelect': 1},
      {'id': 'pan', 'name': 'Pan crust', 'price': 49, 'group': 'Crust', 'maxSelect': 1},
      {'id': 'cheese', 'name': 'Cheese', 'price': 59, 'group': 'Toppings', 'maxSelect': 2},
      {'id': 'olives', 'name': 'Olives', 'price': 39, 'group': 'Toppings', 'maxSelect': 2},
      {'id': 'corn', 'name': 'Corn', 'price': 29, 'group': 'Toppings', 'maxSelect': 2},
    ]);
    AddonGroup? limited;
    await t.pumpWidget(_Harness(addons: grouped, base: 200, onLimit: (g) => limited = g));
    await t.pumpAndSettle();

    expect(find.text('Crust'), findsOneWidget);
    expect(find.text('Choose 1'), findsOneWidget);
    expect(find.text('Choose up to 2'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    // Radio behaviour inside "Crust".
    await t.tap(find.byKey(const ValueKey('addon-pan')));
    await t.pumpAndSettle();
    expect(priceText(t), 'price ₹249');
    await t.tap(find.byKey(const ValueKey('addon-thin')));
    await t.pumpAndSettle();
    expect(priceText(t), 'price ₹200');

    // Two toppings allowed, the third is refused.
    await t.tap(find.byKey(const ValueKey('addon-cheese')));
    await t.tap(find.byKey(const ValueKey('addon-olives')));
    await t.pumpAndSettle();
    expect(priceText(t), 'price ₹298');
    await t.tap(find.byKey(const ValueKey('addon-corn')));
    await t.pumpAndSettle();
    expect(limited?.name, 'Toppings');
    expect(priceText(t), 'price ₹298');
  });
}
