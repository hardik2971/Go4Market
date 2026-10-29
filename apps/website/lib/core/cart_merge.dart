/// Pure helpers for merging a guest (anonymous) cart into a signed-in account.
/// Kept free of Firebase/web imports so they can be unit-tested on the VM.
library;

/// Cart doc id: `${productId}_${variantId}`, or `${productId}_${variantId}_${sortedAddonIds.join('+')}`
/// for customised lines. Matches the customer app.
String cartLineId(String productId, String variantId, [List<String> addonIds = const []]) {
  final ids = [...addonIds]..sort();
  return ids.isEmpty ? '${productId}_$variantId' : '${productId}_${variantId}_${ids.join('+')}';
}

/// The doc to write for one guest line. [guest] is the guest doc data plus its `id`.
/// The id and `addonIds` are kept exactly as stored; qty is the larger of guest and existing.
/// Returns the target doc id and the fields to merge (without the server timestamp).
({String id, Map<String, dynamic> data}) mergedCartLine(Map<String, dynamic> guest, int? existingQty) {
  final id = guest['id'] as String;
  final q = (guest['qty'] as num?)?.toInt() ?? 1;
  final addons = guest['addonIds'];
  return (
    id: id,
    data: {
      'productId': guest['productId'],
      'variantId': guest['variantId'] ?? 'default',
      'sellerId': guest['sellerId'],
      if (addons is List && addons.isNotEmpty) 'addonIds': List<String>.from(addons.map((e) => '$e')),
      'qty': q > (existingQty ?? 0) ? q : existingQty,
    },
  );
}
