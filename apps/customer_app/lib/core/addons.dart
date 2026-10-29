import 'package:g4m_core/g4m_core.dart';

/// Food add-ons / modifiers (FEATURES.md #04).
///
/// Products may carry `addons: [{id, name, price, active, group?, maxSelect?}]`.
/// A cart line stores the chosen ids as a sorted `addonIds[]`, and the order engine
/// (functions/src/orders/engine.ts) prices each line as base price + sum(add-on prices).
/// Lines with different add-on sets are separate cart docs, keyed exactly like the website:
/// `${productId}_${variantId}` without add-ons, `${productId}_${variantId}_${ids.join('+')}` with them.

class ProductAddon {
  const ProductAddon({required this.id, required this.name, required this.price, this.active = true, this.group = '', this.maxSelect});

  factory ProductAddon.fromMap(Map m) {
    final raw = m['maxSelect'];
    final ms = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    return ProductAddon(
      id: '${m['id'] ?? ''}',
      name: '${m['name'] ?? ''}',
      price: m['price'] is num ? (m['price'] as num).toDouble() : double.tryParse('${m['price']}') ?? 0,
      active: m['active'] != false,
      group: m['group'] == null ? '' : '${m['group']}'.trim(),
      maxSelect: ms != null && ms > 0 ? ms : null,
    );
  }

  final String id;
  final String name;
  final double price;
  final bool active;

  /// Empty = ungrouped.
  final String group;
  final int? maxSelect;
}

/// A titled set of add-ons sharing one selection limit. `maxSelect == null` = unlimited.
class AddonGroup {
  const AddonGroup({required this.name, required this.addons, this.maxSelect});
  final String name;
  final List<ProductAddon> addons;
  final int? maxSelect;

  bool get single => maxSelect == 1;
}

/// Active add-ons of [p], in catalogue order.
List<ProductAddon> addonsOf(Product p) => addonsFromData(p.data['addons']);

List<ProductAddon> addonsFromData(dynamic raw) => (raw is List ? raw : const [])
    .whereType<Map>()
    .map(ProductAddon.fromMap)
    .where((a) => a.active && a.id.isNotEmpty)
    .toList();

/// Groups add-ons by `group`, preserving first-seen order. A group's limit is the smallest
/// positive `maxSelect` declared by any of its add-ons. Ungrouped add-ons form one unnamed group.
List<AddonGroup> groupAddons(List<ProductAddon> addons) {
  final order = <String>[];
  final byGroup = <String, List<ProductAddon>>{};
  for (final a in addons) {
    if (!byGroup.containsKey(a.group)) order.add(a.group);
    byGroup.putIfAbsent(a.group, () => []).add(a);
  }
  return [
    for (final g in order)
      AddonGroup(
        name: g,
        addons: byGroup[g]!,
        maxSelect: byGroup[g]!.map((a) => a.maxSelect).whereType<int>().fold<int?>(null, (m, v) => m == null || v < m ? v : m),
      ),
  ];
}

/// Result of a toggle: the new selection, or a reason it was refused.
class AddonToggle {
  const AddonToggle(this.selection, {this.limitHit});
  final Set<String> selection;

  /// Set when the toggle was refused because the group is full.
  final AddonGroup? limitHit;
}

/// Toggles [id] within [current], respecting its group's `maxSelect`.
/// Single-choice groups (`maxSelect: 1`) behave like radio buttons; fuller groups refuse.
AddonToggle toggleAddon(List<AddonGroup> groups, Set<String> current, String id) {
  final next = {...current};
  if (next.remove(id)) return AddonToggle(next);
  final g = groups.where((g) => g.addons.any((a) => a.id == id)).firstOrNull;
  if (g == null) return AddonToggle(current);
  final max = g.maxSelect;
  if (max != null) {
    final inGroup = g.addons.where((a) => next.contains(a.id)).map((a) => a.id).toList();
    if (inGroup.length >= max) {
      if (max == 1) {
        next.removeAll(inGroup);
      } else {
        return AddonToggle(current, limitHit: g);
      }
    }
  }
  next.add(id);
  return AddonToggle(next);
}

/// Sum of the prices of the selected add-ons (unknown / inactive ids count as 0).
double addonTotal(List<ProductAddon> addons, Iterable<String> ids) {
  final want = ids.toSet();
  return _round2(addons.where((a) => want.contains(a.id)).fold(0.0, (s, a) => s + a.price));
}

/// Unit price the engine charges: variant (or product) price + add-ons.
double unitPriceWithAddons(Product p, String variantId, Iterable<String> addonIds) {
  final v = p.variants.where((e) => e.id == variantId).firstOrNull;
  return _round2((v?.price ?? p.price) + addonTotal(addonsOf(p), addonIds));
}

/// Sorted, de-duplicated ids (the engine and the website both sort).
List<String> normalizeAddonIds(Iterable<String> ids) => ids.where((e) => e.isNotEmpty).toSet().toList()..sort();

/// Cart doc id, identical to the website's `Shop.addWithAddons`.
String cartLineId(String productId, String variantId, [Iterable<String> addonIds = const []]) {
  final ids = normalizeAddonIds(addonIds);
  return ids.isEmpty ? '${productId}_$variantId' : '${productId}_${variantId}_${ids.join('+')}';
}

/// The selected add-ons of [p] in catalogue order (drops ids that are no longer offered).
List<ProductAddon> selectedAddons(Product p, Iterable<String> ids) {
  final want = ids.toSet();
  return addonsOf(p).where((a) => want.contains(a.id)).toList();
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

extension CartItemAddons on CartItem {
  /// Add-on ids stored on the cart line (`addonIds[]`), sorted.
  List<String> get addonIds => normalizeAddonIds((data['addonIds'] is List ? data['addonIds'] as List : const []).map((e) => '$e'));
}

extension OrderItemAddons on OrderItem {
  /// `items[].addons[{id, name, price}]` written by the order engine.
  List<ProductAddon> get addons => (data['addons'] is List ? data['addons'] as List : const [])
      .whereType<Map>()
      .map(ProductAddon.fromMap)
      .where((a) => a.id.isNotEmpty || a.name.isNotEmpty)
      .toList();
}
