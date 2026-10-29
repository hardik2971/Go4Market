import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/product_widgets.dart';
import '../ui/shell.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});
  @override
  Widget build(BuildContext context) => SeoMeta(
        title: context.l.common.wishlist,
        child: PageScroll(children: [
          Contained(
            vertical: 24,
            child: ListenableBuilder(
              listenable: Shop.instance,
              builder: (context, _) {
                final ids = Shop.instance.wishlist.toList()..sort();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Heading(context.l.catalog.yourWishlist)),
                    if (ids.isNotEmpty) Text(context.l.catalog.savedCount(ids.length), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 18),
                  if (ids.isEmpty)
                    EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: context.l.catalog.nothingSaved,
                      message: context.l.catalog.tapHeart,
                      action: FilledButton(onPressed: () => context.go('/'), child: Text(context.l.catalog.exploreProducts)),
                    )
                  else
                    ProductsFuture(
                      key: ValueKey(ids.join()),
                      load: () => CatalogRepo.instance.productsByIds(ids),
                      hideWhenEmpty: false,
                      skeleton: const ProductGrid(products: [], loading: true),
                      builder: (l) => ProductGrid(products: l),
                    ),
                ]);
              },
            ),
          ),
        ]),
      );
}
