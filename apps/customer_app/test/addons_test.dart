import 'package:customer_app/core/addons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g4m_core/g4m_core.dart';

/// Mirrors the seeded `margherita-pizza` plus a grouped variant.
Product pizza({List<Map<String, dynamic>>? addons, List<Map<String, dynamic>>? variants}) => Product('margherita-pizza', {
      'name': 'Margherita Pizza',
      'moduleId': 'food',
      'price': 249,
      'mrp': 299,
      'stock': 50,
      'sellerId': 's1',
      'variants': variants ?? [],
      'addons': addons ??
          [
            {'id': 'extra-cheese', 'name': 'Extra cheese', 'price': 59, 'active': true},
            {'id': 'jalapenos', 'name': 'Jalapeños', 'price': 39, 'active': true},
            {'id': 'olives', 'name': 'Black olives', 'price': 39, 'active': true},
            {'id': 'garlic-dip', 'name': 'Garlic dip', 'price': 25, 'active': true},
            {'id': 'old', 'name': 'Retired', 'price': 99, 'active': false},
          ],
    });

void main() {
  group('parsing', () {
    test('drops inactive add-ons and keeps catalogue order', () {
      final a = addonsOf(pizza());
      expect(a.map((e) => e.id), ['extra-cheese', 'jalapenos', 'olives', 'garlic-dip']);
      expect(a.first.price, 59);
    });

    test('reads group / maxSelect, tolerating strings', () {
      final a = addonsFromData([
        {'id': 'a', 'name': 'A', 'price': '10', 'group': 'Crust', 'maxSelect': '1'},
        {'id': 'b', 'name': 'B', 'price': 20, 'group': 'Crust', 'maxSelect': 1},
        {'id': 'c', 'name': 'C', 'price': 5},
      ]);
      expect(a[0].price, 10);
      expect(a[0].maxSelect, 1);
      final g = groupAddons(a);
      expect(g.map((e) => e.name), ['Crust', '']);
      expect(g.first.single, isTrue);
      expect(g.last.maxSelect, isNull);
    });

    test('a product without add-ons has none', () {
      expect(addonsOf(Product('x', {'price': 10})), isEmpty);
    });
  });

  group('selection rules', () {
    final groups = groupAddons(addonsFromData([
      {'id': 'thin', 'name': 'Thin crust', 'price': 0, 'group': 'Crust', 'maxSelect': 1},
      {'id': 'pan', 'name': 'Pan crust', 'price': 49, 'group': 'Crust', 'maxSelect': 1},
      {'id': 'cheese', 'name': 'Cheese', 'price': 59, 'group': 'Toppings', 'maxSelect': 2},
      {'id': 'olives', 'name': 'Olives', 'price': 39, 'group': 'Toppings', 'maxSelect': 2},
      {'id': 'corn', 'name': 'Corn', 'price': 29, 'group': 'Toppings', 'maxSelect': 2},
      {'id': 'dip', 'name': 'Dip', 'price': 25},
    ]));

    test('single-choice groups swap like radio buttons', () {
      var s = toggleAddon(groups, {}, 'thin').selection;
      s = toggleAddon(groups, s, 'pan').selection;
      expect(s, {'pan'});
    });

    test('maxSelect refuses one too many and reports the group', () {
      var s = toggleAddon(groups, {}, 'cheese').selection;
      s = toggleAddon(groups, s, 'olives').selection;
      final r = toggleAddon(groups, s, 'corn');
      expect(r.limitHit?.name, 'Toppings');
      expect(r.selection, {'cheese', 'olives'});
      // Ungrouped add-ons are not limited by other groups.
      expect(toggleAddon(groups, s, 'dip').selection, {'cheese', 'olives', 'dip'});
    });

    test('tapping a selected add-on deselects it', () {
      expect(toggleAddon(groups, {'cheese', 'dip'}, 'cheese').selection, {'dip'});
    });
  });

  group('price maths (matches functions/src/orders/engine.ts)', () {
    test('unit price = base + selected add-ons', () {
      final p = pizza();
      expect(addonTotal(addonsOf(p), ['extra-cheese', 'olives']), 98);
      expect(unitPriceWithAddons(p, 'default', ['extra-cheese', 'olives']), 347);
      expect(unitPriceWithAddons(p, 'default', const []), 249);
    });

    test('uses the variant price and ignores unknown / inactive ids', () {
      final p = pizza(variants: [
        {'id': 'reg', 'name': 'Regular', 'price': 199, 'mrp': 249, 'stock': 5},
        {'id': 'med', 'name': 'Medium', 'price': 349.5, 'mrp': 399, 'stock': 5},
      ]);
      expect(unitPriceWithAddons(p, 'med', ['garlic-dip', 'old', 'nope']), 374.5);
    });

    test('paise are rounded to 2 dp', () {
      final a = addonsFromData([
        {'id': 'x', 'name': 'x', 'price': 0.1},
        {'id': 'y', 'name': 'y', 'price': 0.2},
      ]);
      expect(addonTotal(a, ['x', 'y']), 0.3);
    });
  });

  group('cart line ids (same shape as the website)', () {
    test('plain line keeps the legacy id', () {
      expect(cartLineId('p1', 'default'), 'p1_default');
    });

    test('add-on ids are sorted and joined with +', () {
      expect(cartLineId('p1', 'default', ['olives', 'extra-cheese']), 'p1_default_extra-cheese+olives');
      expect(cartLineId('p1', 'default', ['extra-cheese', 'olives', 'olives']), cartLineId('p1', 'default', ['olives', 'extra-cheese']));
    });

    test('different add-on sets are different lines', () {
      expect(cartLineId('p1', 'med', ['olives']), isNot(cartLineId('p1', 'med', ['olives', 'garlic-dip'])));
    });

    test('CartItem.addonIds reads the stored array', () {
      final c = CartItem('p1_default_a+b', {'productId': 'p1', 'qty': 1, 'addonIds': ['b', 'a']});
      expect(c.addonIds, ['a', 'b']);
      expect(CartItem('p1_default', {'productId': 'p1'}).addonIds, isEmpty);
    });

    test('OrderItem.addons reads engine output', () {
      final it = OrderItem({
        'productId': 'p1',
        'price': 347,
        'basePrice': 249,
        'addons': [
          {'id': 'extra-cheese', 'name': 'Extra cheese', 'price': 59},
          {'id': 'olives', 'name': 'Black olives', 'price': 39},
        ],
      });
      expect(it.addons.map((a) => a.name), ['Extra cheese', 'Black olives']);
    });
  });
}
