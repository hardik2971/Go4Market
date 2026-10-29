import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/location_service.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import '../common/notifications_screen.dart';
import 'active_delivery_screen.dart';
import 'delivery_data.dart';
import 'delivery_earnings.dart';
import 'delivery_shell.dart';
import 'delivery_widgets.dart';

class DeliveryHomeTab extends StatefulWidget {
  const DeliveryHomeTab({super.key});
  @override
  State<DeliveryHomeTab> createState() => _DeliveryHomeTabState();
}

class _DeliveryHomeTabState extends State<DeliveryHomeTab> {
  late final Stream<DeliveryPartner?> _me = DeliveryData.me();
  late final Stream<List<ShopOrder>> _orders = DeliveryData.myOrders();
  bool _busy = false;

  Future<void> _toggle(bool online, List<ShopOrder> active) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    if (online) {
      if (active.isNotEmpty) {
        final ok = await confirmDialog(context,
            title: context.tr('Go offline?', 'ऑफ़लाइन जाएं?'),
            message: context.tr('You still have an active delivery. Customers will stop seeing your live location.',
                'आपकी एक डिलीवरी अभी सक्रिय है। ग्राहक आपकी लाइव लोकेशन नहीं देख पाएंगे।'),
            confirmText: context.s.offline);
        if (!ok) return;
      }
      setState(() => _busy = true);
      await LocationService.instance.stop();
    } else {
      final ok = await LocationService.instance.ensurePermission(context);
      if (!ok || !mounted) return;
      setState(() => _busy = true);
      try {
        await LocationService.instance.start(myUid);
        HapticFeedback.heavyImpact();
      } catch (e) {
        if (mounted) toast(context, describeError(e), error: true);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeliveryPartner?>(
      stream: _me,
      builder: (context, meSnap) {
        final me = meSnap.data;
        return StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, oSnap) {
            final orders = oSnap.data ?? const <ShopOrder>[];
            final active = orders.where((o) => activeDeliveryStatuses.contains(o.status)).toList();
            final deliveredToday = orders.where((o) => o.status == OrderStatus.delivered && isToday(deliveredAt(o))).toList();
            final earnedToday = deliveredToday.fold<double>(0, (a, o) => a + orderEarning(o, me));
            return ListenableBuilder(
              listenable: LocationService.instance,
              builder: (context, _) {
                final loc = LocationService.instance;
                final online = loc.running || (me?.online ?? false);
                return CustomScrollView(slivers: [
                  SliverAppBar(
                    pinned: true,
                    titleSpacing: 16,
                    title: Row(children: [
                      Avatar(name: me?.name ?? '', url: me?.photoUrl ?? '', size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_greeting(context), style: context.tt.bodySmall),
                          Text(me?.name.isNotEmpty == true ? me!.name : context.s.deliveryPartner,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium),
                        ]),
                      ),
                    ]),
                    actions: const [NotificationBell(), SizedBox(width: 6)],
                  ),
                  SliverPadding(
                    padding: pagePad,
                    sliver: SliverList.list(children: [
                      OnlineToggle(online: online, busy: _busy, onTap: () => _toggle(online, active)),
                      const SizedBox(height: 10),
                      Center(
                        child: AnimatedSwitcher(
                          duration: G4MMotion.standard,
                          child: Text(
                            key: ValueKey('$online${me?.locationUpdatedAt}'),
                            online
                                ? '${context.tr('Location shared', 'लोकेशन साझा')} · ${me?.locationUpdatedAt == null ? context.tr('waiting for GPS', 'GPS की प्रतीक्षा') : Fmt.ago(me!.locationUpdatedAt)}'
                                : context.tr('Go online to receive delivery requests', 'डिलीवरी अनुरोध पाने के लिए ऑनलाइन जाएं'),
                            style: context.tt.bodySmall,
                          ),
                        ),
                      ),
                      if (loc.error != null && online)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(describeError(loc.error!), textAlign: TextAlign.center, style: context.tt.bodySmall?.copyWith(color: G4MColors.danger)),
                        ),
                      const SizedBox(height: 22),
                      if (active.isNotEmpty) ...[
                        SectionTitle(context.tr('Active delivery', 'सक्रिय डिलीवरी')),
                        for (var i = 0; i < active.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DeliveryOrderCard(
                              order: active[i],
                              highlight: true,
                              onTap: () => Go.push(context, ActiveDeliveryScreen(orderId: active[i].id)),
                            ).stagger(i),
                          ),
                        const SizedBox(height: 10),
                      ],
                      SectionTitle(context.s.today),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          StatTile(icon: Icons.currency_rupee_rounded, label: context.tr('Earned today', 'आज की कमाई'), value: earnedToday, money: true, color: G4MColors.accent)
                              .stagger(0),
                          StatTile(icon: Icons.task_alt_rounded, label: context.tr('Delivered today', 'आज डिलीवर'), value: deliveredToday.length, color: G4MColors.success)
                              .stagger(1),
                          StatTile(
                            icon: Icons.payments_rounded,
                            label: context.s.cashInHand,
                            value: me?.cashInHand ?? 0,
                            money: true,
                            color: G4MColors.primaryDeep,
                            onTap: () => Go.push(context, const CashCollectionScreen()),
                          ).stagger(2),
                          RatingTile(
                            rating: me?.rating ?? 0,
                            label: '${context.tr('Rating', 'रेटिंग')} · ${me?.completedCount ?? 0} ${context.tr('trips', 'ट्रिप')}',
                          ).stagger(3),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (active.isEmpty)
                        AppCard(
                          onTap: () => DeliveryShell.goTab(context, 1),
                          child: Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(color: context.rc.brandSoft, borderRadius: BorderRadius.circular(14)),
                              child: Icon(Icons.local_shipping_rounded, color: context.rc.brand),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(context.tr('Find orders near you', 'अपने पास ऑर्डर खोजें'), style: context.tt.titleSmall),
                                Text(
                                  online
                                      ? context.tr('Browse packed orders ready for pickup', 'पिकअप के लिए तैयार ऑर्डर देखें')
                                      : context.tr('Go online first to accept orders', 'ऑर्डर स्वीकार करने के लिए पहले ऑनलाइन जाएं'),
                                  style: context.tt.bodySmall,
                                ),
                              ]),
                            ),
                            Icon(Icons.arrow_forward_rounded, color: context.rc.brand),
                          ]),
                        ).stagger(4),
                    ]),
                  ),
                ]);
              },
            );
          },
        );
      },
    );
  }

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.tr('Good morning', 'सुप्रभात');
    if (h < 17) return context.tr('Good afternoon', 'नमस्कार');
    return context.tr('Good evening', 'शुभ संध्या');
  }
}

/// Large animated online/offline control: colour morph, rotating halo and glow
/// pulse when online, haptics on tap.
class OnlineToggle extends StatefulWidget {
  const OnlineToggle({super.key, required this.online, required this.onTap, this.busy = false});
  final bool online;
  final bool busy;
  final VoidCallback onTap;
  @override
  State<OnlineToggle> createState() => _OnlineToggleState();
}

class _OnlineToggleState extends State<OnlineToggle> with TickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  late final _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: widget.online ? 1 : 0);

  @override
  void didUpdateWidget(OnlineToggle old) {
    super.didUpdateWidget(old);
    if (old.online != widget.online) {
      widget.online ? _morph.forward() : _morph.reverse();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 196.0;
    final off = context.isDark ? const Color(0xFF2A3A31) : const Color(0xFFDDE6E0);
    return Center(
      child: Pressable(
        onTap: widget.busy ? null : widget.onTap,
        scale: .95,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _morph]),
          builder: (context, _) {
            final m = Curves.easeInOutCubic.transform(_morph.value);
            final c1 = Color.lerp(off, G4MColors.accent, m)!;
            final c2 = Color.lerp(off, G4MColors.primary, m)!;
            return SizedBox(
              width: size + 70,
              height: size + 70,
              child: Stack(alignment: Alignment.center, children: [
                // Expanding glow rings while online.
                for (var k = 0; k < 2; k++)
                  if (m > 0)
                    Builder(builder: (_) {
                      final t = (_pulse.value + k * .5) % 1;
                      return Container(
                        width: size + 60 * t,
                        height: size + 60 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: G4MColors.accent.withValues(alpha: (1 - t) * .18 * m),
                        ),
                      );
                    }),
                // Rotating gradient halo.
                Transform.rotate(
                  angle: _pulse.value * 2 * math.pi,
                  child: Container(
                    width: size + 10,
                    height: size + 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [c1, c2, c1]),
                      boxShadow: [BoxShadow(color: c1.withValues(alpha: .35 * m), blurRadius: 40, spreadRadius: 2)],
                    ),
                  ),
                ),
                Container(
                  width: size - 8,
                  height: size - 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.rc.card),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (widget.busy)
                      SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3, color: c1 == off ? context.rc.muted : c1))
                    else
                      AnimatedSwitcher(
                        duration: G4MMotion.emphasized,
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: RotationTransition(turns: Tween(begin: .75, end: 1.0).animate(a), child: c)),
                        child: Icon(
                          widget.online ? Icons.delivery_dining_rounded : Icons.power_settings_new_rounded,
                          key: ValueKey(widget.online),
                          size: 54,
                          color: widget.online ? G4MColors.accent : context.rc.muted,
                        ),
                      ),
                    const SizedBox(height: 10),
                    AnimatedDefaultTextStyle(
                      duration: G4MMotion.standard,
                      style: context.tt.titleLarge!.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: widget.online ? G4MColors.accent : context.rc.muted,
                      ),
                      child: Text(widget.online ? context.s.online.toUpperCase() : context.s.offline.toUpperCase()),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.online ? context.tr('Tap to go offline', 'ऑफ़लाइन जाने के लिए टैप करें') : context.tr('Tap to go online', 'ऑनलाइन जाने के लिए टैप करें'),
                      style: context.tt.bodySmall,
                    ),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(.9, .9), curve: Curves.easeOutBack, duration: 600.ms);
  }
}
