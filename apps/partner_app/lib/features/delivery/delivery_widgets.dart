import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'delivery_data.dart';

/// Compact pill with an icon (distance, ETA, payout, COD...).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.rc.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: context.isDark ? .2 : .1), borderRadius: BorderRadius.circular(G4MRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

/// Rating tile with one decimal (StatTile rounds to integers).
class RatingTile extends StatelessWidget {
  const RatingTile({super.key, required this.rating, required this.label});
  final double rating;
  final String label;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF5A524).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.star_rounded, color: Color(0xFFF5A524), size: 20),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(end: rating),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutExpo,
            builder: (_, v, _) => Text(rating <= 0 ? '—' : v.toStringAsFixed(1), style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall?.copyWith(color: context.rc.muted)),
        ]),
      );
}

/// Order summary card used in Home, Orders and History.
class DeliveryOrderCard extends StatelessWidget {
  const DeliveryOrderCard({super.key, required this.order, this.onTap, this.highlight = false, this.trailing, this.distanceKm, this.footer});
  final ShopOrder order;
  final VoidCallback? onTap;
  final bool highlight;
  final Widget? trailing;
  final double? distanceKm;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final quick = quickDeadline(o);
    final card = AppCard(
      onTap: onTap,
      borderColor: highlight ? context.rc.brand.withValues(alpha: .6) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: context.rc.brandSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_rounded, color: context.rc.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${o.orderNo}', style: context.tt.titleMedium),
              Text('${o.itemCount} ${context.tr('items', 'आइटम')} · ${o.customerName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
            ]),
          ),
          trailing ?? StatusPill(o.status),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.location_on_outlined, size: 16, color: context.rc.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(addressLine(o.address).isEmpty ? '—' : addressLine(o.address),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          InfoChip(icon: Icons.currency_rupee_rounded, label: Fmt.money(o.payable), color: context.rc.ink),
          if (isCodDue(o)) const InfoChip(icon: Icons.payments_rounded, label: 'COD', color: G4MColors.warning),
          if (distanceKm != null) InfoChip(icon: Icons.near_me_rounded, label: '${distanceKm!.toStringAsFixed(1)} km', color: G4MColors.info),
          if (distanceKm == null && o.distanceKm > 0) InfoChip(icon: Icons.route_rounded, label: '${o.distanceKm.toStringAsFixed(1)} km', color: G4MColors.info),
          if (quick != null) InfoChip(icon: Icons.bolt_rounded, label: speedLabel(context, o.speed), color: G4MColors.accent),
        ]),
        ?footer,
      ]),
    );
    if (!highlight) return card;
    return card
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 2400.ms, delay: 800.ms, color: context.rc.brand.withValues(alpha: .08));
  }
}

/// Horizontal stepper for the home-delivery flow from the rider's view.
class DeliveryStepper extends StatelessWidget {
  const DeliveryStepper({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (OrderStatus.assigned, context.tr('Assigned', 'असाइन'), Icons.assignment_turned_in_rounded),
      (OrderStatus.pickedUp, context.tr('Picked up', 'पिकअप'), Icons.shopping_bag_rounded),
      (OrderStatus.outForDelivery, context.tr('On the way', 'रास्ते में'), Icons.delivery_dining_rounded),
      (OrderStatus.delivered, context.tr('Delivered', 'डिलीवर'), Icons.home_rounded),
    ];
    final idx = steps.indexWhere((s) => s.$1 == status);
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: i == idx ? 40 : 32,
            height: i == idx ? 40 : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= idx ? context.rc.brand : context.rc.cardAlt,
              boxShadow: i == idx ? [BoxShadow(color: context.rc.brand.withValues(alpha: .4), blurRadius: 12)] : null,
            ),
            child: Icon(steps[i].$3, size: i == idx ? 20 : 16, color: i <= idx ? Colors.white : context.rc.faint),
          ),
          const SizedBox(height: 6),
          Text(steps[i].$2, style: context.tt.labelSmall?.copyWith(color: i <= idx ? context.rc.ink : context.rc.faint, fontWeight: FontWeight.w700)),
        ]),
        if (i < steps.length - 1)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(children: [
                  Container(height: 3, color: context.rc.line),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    widthFactor: i < idx ? 1 : 0,
                    child: Container(height: 3, color: context.rc.brand),
                  ),
                ]),
              ),
            ),
          ),
      ],
    ]);
  }
}
