import 'package:flutter_test/flutter_test.dart';
import 'package:website/core/cart_merge.dart';

void main() {
  group('cartLineId', () {
    test('plain line', () => expect(cartLineId('p1', 'default'), 'p1_default'));
    test('add-ons are sorted and joined with +', () => expect(cartLineId('p1', 'v2', ['b', 'a']), 'p1_v2_a+b'));
  });

  group('mergedCartLine', () {
    test('keeps id and addonIds of a customised food line', () {
      final r = mergedCartLine({
        'id': 'biryani_full_extra-raita+no-onion',
        'productId': 'biryani',
        'variantId': 'full',
        'sellerId': 's1',
        'qty': 2,
        'addonIds': ['extra-raita', 'no-onion'],
      }, null);
      expect(r.id, 'biryani_full_extra-raita+no-onion');
      expect(r.data['addonIds'], ['extra-raita', 'no-onion']);
      expect(r.data['qty'], 2);
      expect(r.data['variantId'], 'full');
    });

    test('plain line has no addonIds and defaults the variant', () {
      final r = mergedCartLine({'id': 'milk_default', 'productId': 'milk', 'sellerId': 's1', 'qty': 1}, null);
      expect(r.id, 'milk_default');
      expect(r.data.containsKey('addonIds'), isFalse);
      expect(r.data['variantId'], 'default');
    });

    test('takes the larger of guest and account quantity', () {
      expect(mergedCartLine({'id': 'a_default', 'productId': 'a', 'qty': 1}, 3).data['qty'], 3);
      expect(mergedCartLine({'id': 'a_default', 'productId': 'a', 'qty': 4}, 3).data['qty'], 4);
    });
  });
}
