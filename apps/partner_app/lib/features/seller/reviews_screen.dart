import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';

class _R {
  _R(this.review, this.product);
  final Review review;
  final Product product;
}

/// Reviews across the seller's rated products (products/{id}/reviews).
class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});
  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  late Future<List<_R>> _future = _load();
  int? _stars;

  Future<List<_R>> _load() async {
    var products = SellerStore.instance.products.value;
    if (products == null) {
      final s = await Fs.products.where('sellerId', isEqualTo: myUid).limit(500).get();
      products = s.docs.map(Product.fromDoc).toList();
    }
    final rated = products.where((p) => p.ratingCount > 0).toList()..sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
    final out = <_R>[];
    await Future.wait(rated.take(20).map((p) async {
      try {
        final list = await resilientGet<Review>([
          () => Fs.reviews(p.id).orderBy('createdAt', descending: true).limit(25),
          () => Fs.reviews(p.id).limit(25),
        ], Review.fromDoc);
        out.addAll(list.map((r) => _R(r, p)));
      } catch (_) {}
    }));
    out.sort((a, b) => newestFirst(a.review.createdAt, b.review.createdAt));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reviews', 'समीक्षाएं'))),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _load());
          await _future;
        },
        child: FutureBuilder<List<_R>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(snap.error!, onRetry: () => setState(() => _future = _load()));
            if (!snap.hasData) return const SkeletonList(itemHeight: 100);
            final all = snap.data!;
            if (all.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                AppEmpty(
                  icon: Icons.star_outline_rounded,
                  title: context.tr('No reviews yet', 'अभी कोई समीक्षा नहीं'),
                  message: context.tr('Reviews from customers who bought your products appear here.', 'आपके उत्पाद खरीदने वाले ग्राहकों की समीक्षाएं यहां दिखेंगी।'),
                ),
              ]);
            }
            final dist = List<int>.filled(5, 0);
            for (final r in all) {
              dist[(r.review.rating.clamp(1, 5)) - 1]++;
            }
            final avg = all.fold<int>(0, (a, r) => a + r.review.rating) / all.length;
            final list = _stars == null ? all : all.where((r) => r.review.rating == _stars).toList();
            return ListView(padding: pagePad, children: [
              AppCard(
                child: Row(children: [
                  Column(children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: avg),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(v.toStringAsFixed(1), style: context.tt.displaySmall),
                    ),
                    RatingStars(avg, size: 16),
                    const SizedBox(height: 4),
                    Text('${all.length} ${context.tr('reviews', 'समीक्षाएं')}', style: context.tt.bodySmall),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(children: [
                      for (var s = 5; s >= 1; s--)
                        InkWell(
                          onTap: () => setState(() => _stars = _stars == s ? null : s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Text('$s', style: context.tt.labelMedium?.copyWith(fontWeight: _stars == s ? FontWeight.w900 : null)),
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5A524)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: dist[s - 1] / all.length),
                                    duration: Duration(milliseconds: 500 + (5 - s) * 120),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, _) => LinearProgressIndicator(
                                      value: v,
                                      minHeight: 8,
                                      backgroundColor: context.rc.cardAlt,
                                      color: s >= 4 ? G4MColors.success : (s == 3 ? G4MColors.warning : G4MColors.danger),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 30, child: Text('${dist[s - 1]}', textAlign: TextAlign.right, style: context.tt.bodySmall)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ).popIn(),
              const SizedBox(height: 16),
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Avatar(name: list[i].review.userName, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(list[i].review.userName, style: context.tt.titleSmall),
                            RatingStars(list[i].review.rating.toDouble(), size: 13),
                          ]),
                        ),
                        Text(Fmt.ago(list[i].review.createdAt), style: context.tt.bodySmall),
                      ]),
                      if (list[i].review.comment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(list[i].review.comment, style: context.tt.bodyMedium),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        ProductThumb(list[i].product.image, size: 26),
                        const SizedBox(width: 8),
                        Expanded(child: Text(list[i].product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall)),
                      ]),
                    ]),
                  ).stagger(i + 1),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
