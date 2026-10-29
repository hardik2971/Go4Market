import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/push.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/ui.dart';

Stream<List<AppNotification>> _inbox() => resilientQuery<AppNotification>(
      [
        () => Fs.inbox(myUid).orderBy('createdAt', descending: true).limit(80),
        () => Fs.inbox(myUid).limit(80),
      ],
      AppNotification.fromDoc,
      sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
    );

/// App-bar bell with an animated unread badge.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.color});
  final Color? color;
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final Stream<List<AppNotification>> _stream = _inbox();
  Color? get color => widget.color;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snap) {
          final unread = (snap.data ?? const []).where((n) => !n.read).length;
          return IconButton(
            tooltip: context.s.notifications,
            onPressed: () => Go.push(context, const NotificationsScreen()),
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: G4MColors.accent,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: Icon(Icons.notifications_none_rounded, color: color)
                  .animate(target: unread > 0 ? 1 : 0)
                  .shake(hz: 3, rotation: .08, duration: 600.ms),
            ),
          );
        },
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<AppNotification>> _stream = _inbox();

  IconData _icon(String type) => switch (type) {
        'order' || 'order_status' || 'new_order' => Icons.receipt_long_rounded,
        'delivery' || 'assignment' => Icons.delivery_dining_rounded,
        'withdrawal' || 'payout' => Icons.account_balance_wallet_rounded,
        'product' || 'low_stock' => Icons.inventory_2_rounded,
        'campaign' || 'promo' => Icons.campaign_rounded,
        _ => Icons.notifications_rounded,
      };

  Future<void> _markAll(List<AppNotification> list) async {
    final b = Fs.db.batch();
    for (final n in list.where((n) => !n.read)) {
      b.update(Fs.inbox(myUid).doc(n.id), {'read': true});
    }
    await b.commit();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        final list = snap.data ?? const <AppNotification>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(context.s.notifications),
            actions: [
              if (list.any((n) => !n.read))
                TextButton(
                  onPressed: () => _markAll(list).catchError((_) {}),
                  child: Text(context.tr('Mark all read', 'सभी पढ़ा हुआ')),
                ),
            ],
          ),
          body: snap.hasError
              ? ErrorView(snap.error!)
              : !snap.hasData
                  ? const SkeletonList(itemHeight: 76)
                  : list.isEmpty
                      ? AppEmpty(
                          icon: Icons.notifications_off_outlined,
                          title: context.tr('All caught up', 'सब देख लिया'),
                          message: context.tr('Order and payout updates will appear here.', 'ऑर्डर और भुगतान अपडेट यहां दिखेंगे।'),
                        )
                      : ListView.separated(
                          padding: pagePad,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final n = list[i];
                            final orderId = n.payload['orderId'];
                            return Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(color: G4MColors.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(G4MRadius.md)),
                                child: const Icon(Icons.delete_outline_rounded, color: G4MColors.danger),
                              ),
                              onDismissed: (_) => Fs.inbox(myUid).doc(n.id).delete().catchError((_) {}),
                              child: AppCard(
                                color: n.read ? null : context.rc.highlightSoft,
                                onTap: () {
                                  if (!n.read) Fs.inbox(myUid).doc(n.id).update({'read': true}).catchError((_) {});
                                  final role = Session.instance.role;
                                  if (orderId is String && orderId.isNotEmpty && role != null) {
                                    PushService.instance.onOpenOrder?.call(role, orderId);
                                  }
                                },
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(color: context.rc.brand.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(_icon(n.type), color: context.rc.brand),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(child: Text(n.title, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                                        if (!n.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: G4MColors.accent, shape: BoxShape.circle)),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(n.body, style: context.tt.bodyMedium?.copyWith(color: context.rc.muted)),
                                      const SizedBox(height: 6),
                                      Text(Fmt.ago(n.createdAt), style: context.tt.bodySmall?.copyWith(color: context.rc.faint)),
                                    ]),
                                  ),
                                ]),
                              ),
                            ).stagger(i);
                          },
                        ),
        );
      },
    );
  }
}

/// Helper so other files can mark a notification doc without importing cloud_firestore.
Future<void> markNotificationRead(String id) => Fs.inbox(myUid).doc(id).set({'read': true}, SetOptions(merge: true));
