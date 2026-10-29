import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../link_router.dart';

/// Inbox from `users/{uid}/notifications` (written by onOrderWritten / campaigns).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) => switch (type) {
        'order' || 'order_status' => Icons.local_shipping_outlined,
        'offer' || 'promo' || 'campaign' => Icons.local_offer_outlined,
        'wallet' || 'refund' || 'referral' => Icons.account_balance_wallet_outlined,
        _ => Icons.notifications_none_rounded,
      };

  Future<void> _markAll(List<AppNotification> list) async {
    final uid = Session.instance.uid;
    if (uid == null) return;
    final b = Fs.db.batch();
    for (final n in list.where((n) => !n.read)) {
      b.update(Fs.inbox(uid).doc(n.id), {'read': true});
    }
    await b.commit();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppNotification>>(
        stream: Session.instance.signedIn ? MyData.inbox() : Stream.value(const <AppNotification>[]),
        builder: (context, snap) {
          final list = snap.data;
          final unread = list?.where((n) => !n.read).length ?? 0;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Notifications'),
              actions: [
                if (unread > 0) TextButton(onPressed: () => _markAll(list!), child: const Text('Mark all read')),
              ],
            ),
            body: snap.hasError
                ? ErrorView(error: snap.error!)
                : list == null
                    ? const ListSkeleton(count: 6, height: 72)
                    : list.isEmpty
                        ? const EmptyState(icon: Icons.notifications_off_outlined, title: 'All caught up', message: 'Order updates and offers will show up here.')
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final n = list[i];
                              return AppCard(
                                color: n.read ? null : context.softPrimary,
                                onTap: () {
                                  final uid = Session.instance.uid;
                                  if (!n.read && uid != null) Fs.inbox(uid).doc(n.id).update({'read': true}).catchError((_) {});
                                  openNotificationData(context, n.payload);
                                },
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  CircleAvatar(
                                    backgroundColor: context.card,
                                    child: Icon(_icon(n.type), color: G4MColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(child: Text(n.title, style: context.text.titleSmall)),
                                        if (!n.read)
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: G4MColors.accent, shape: BoxShape.circle)),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(n.body, style: context.text.bodyMedium),
                                      const SizedBox(height: 4),
                                      Text(Fmt.ago(n.createdAt), style: context.text.bodySmall),
                                    ]),
                                  ),
                                ]),
                              ).stagger(i);
                            },
                          ),
          );
        },
      );
}
