import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/session.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';
import '../shell/main_shell.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Wishlist'), actions: const [CartAction()]),
        body: ValueListenableBuilder<Set<String>>(
          valueListenable: Session.instance.wishlist,
          builder: (context, ids, _) {
            if (ids.isEmpty) {
              return EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Nothing saved yet',
                message: 'Tap the heart on any product to save it here.',
                action: FilledButton(onPressed: () => goHomeTab(context), child: const Text('Explore products')),
              );
            }
            return FutureBuilder<Map<String, Product>>(
              future: Session.instance.ensureProducts(ids),
              builder: (context, snap) {
                final m = snap.data;
                if (m == null) return const SingleChildScrollView(child: ProductGridSkeleton(count: 4));
                final list = [for (final id in ids) if (m[id] != null) m[id]!];
                return CustomScrollView(slivers: [SliverProductGrid(products: list, scope: 'wish')]);
              },
            );
          },
        ),
      );
}
