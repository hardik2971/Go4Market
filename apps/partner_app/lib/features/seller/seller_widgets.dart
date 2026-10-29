import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_data.dart';

/// Order summary card with a pulsing accent border for fresh `placed` orders.
class SellerOrderCard extends StatelessWidget {
  const SellerOrderCard({super.key, required this.order, this.onTap});
  final ShopOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final fresh = SellerTabs.isNew(o);
    final items = SellerData.myItems(o);
    final card = AppCard(
      onTap: onTap,
      borderColor: fresh ? G4MColors.accent : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${o.orderNo}', style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          if (fresh)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(gradient: G4MColors.accentGradient, borderRadius: BorderRadius.circular(G4MRadius.pill)),
              child: Text(context.tr('NEW', 'नया'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.08, duration: 700.ms),
          if (o.channel == 'pos') ...[
            const SizedBox(width: 6),
            _tag(context, 'POS', G4MColors.info),
          ],
          if (o.speed == 'quick15' || o.speed == 'quick30') ...[
            const SizedBox(width: 6),
            _tag(context, o.speed == 'quick15' ? '⚡ 15m' : '⚡ 30m', G4MColors.accent),
          ],
          if (o.deliveryType == 'pickup') ...[
            const SizedBox(width: 6),
            _tag(context, context.tr('Pickup', 'पिकअप'), G4MColors.info),
          ],
          const Spacer(),
          StatusPill(o.status),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.person_outline_rounded, size: 16, color: context.rc.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(o.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium)),
          Text(Fmt.ago(o.createdAt), style: context.tt.bodySmall),
        ]),
        const SizedBox(height: 6),
        Text(
          items.map((i) => '${i.qty}× ${i.name}').join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(color: context.rc.muted),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text(Fmt.money(SellerData.myRevenue(o)), style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text(o.paymentMethod.toUpperCase(), style: context.tt.labelSmall?.copyWith(color: context.rc.muted)),
          const Spacer(),
          Text('${items.fold<int>(0, (a, i) => a + i.qty)} ${context.tr('items', 'आइटम')}', style: context.tt.bodySmall),
        ]),
      ]),
    );
    if (!fresh) return card;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(G4MRadius.md)),
      child: card,
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .boxShadow(
          begin: BoxShadow(color: G4MColors.accent.withValues(alpha: 0), blurRadius: 0, spreadRadius: 0),
          end: BoxShadow(color: G4MColors.accent.withValues(alpha: .35), blurRadius: 18, spreadRadius: 1),
          borderRadius: BorderRadius.circular(G4MRadius.md),
          duration: 1100.ms,
        );
  }

  Widget _tag(BuildContext context, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

/// Rounded product image with fallback icon.
class ProductThumb extends StatelessWidget {
  const ProductThumb(this.url, {super.key, this.size = 56});
  final String url;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.rc.cardAlt, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty ? Icon(Icons.inventory_2_outlined, color: context.rc.faint, size: size * .45) : NetImage(url, width: size, height: size),
      );
}

/// Quantity stepper used by stock and POS.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 0});
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.rc.brandSoft,
          borderRadius: BorderRadius.circular(G4MRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(context, Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: SizedBox(
              key: ValueKey(value),
              width: 34,
              child: Text('$value', textAlign: TextAlign.center, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          _btn(context, Icons.add_rounded, () => onChanged(value + 1)),
        ]),
      );

  Widget _btn(BuildContext context, IconData i, VoidCallback? f) => InkResponse(
        onTap: f,
        radius: 20,
        child: Padding(padding: const EdgeInsets.all(7), child: Icon(i, size: 18, color: f == null ? context.rc.faint : context.rc.brand)),
      );
}
