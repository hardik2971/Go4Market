import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_data.dart';
import 'seller_store.dart';

/// The seller's own delivery team (`deliveryPartners` with sellerId == uid).
class SellerRidersScreen extends StatelessWidget {
  const SellerRidersScreen({super.key});

  void _invite(BuildContext context) {
    final store = SellerStore.instance.seller.value?.storeName ?? 'our store';
    SharePlus.instance.share(ShareParams(
      text: 'Join $store as a delivery partner on Go4Market! Download Go4Market Partner, choose "Deliver with Go4Market" and register: $playStoreUrl',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Delivery boys', 'डिलीवरी बॉय')),
        actions: [IconButton(tooltip: context.tr('Invite', 'आमंत्रित करें'), icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: () => _invite(context))],
      ),
      body: LiveList<List<DeliveryPartner>>(
        stream: SellerData.riders(),
        empty: AppEmpty(
          icon: Icons.delivery_dining_outlined,
          title: context.tr('No riders yet', 'अभी कोई राइडर नहीं'),
          message: context.tr(
            'Riders register in this app as delivery partners, then the Go4Market admin links them to your store. Until then, use auto-assign for deliveries.',
            'राइडर इस ऐप में डिलीवरी पार्टनर के रूप में पंजीकरण करते हैं, फिर एडमिन उन्हें आपके स्टोर से जोड़ता है। तब तक ऑटो-असाइन का उपयोग करें।',
          ),
          action: FilledButton.icon(icon: const Icon(Icons.share_rounded), label: Text(context.tr('Invite a rider', 'राइडर को आमंत्रित करें')), onPressed: () => _invite(context)),
        ),
        builder: (context, list) {
          final online = list.where((r) => r.online).length;
          final cash = list.fold<double>(0, (a, r) => a + r.cashInHand);
          return ListView(padding: pagePad, children: [
            Row(children: [
              Expanded(child: StatTile(icon: Icons.groups_rounded, label: context.tr('Riders', 'राइडर'), value: list.length)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(icon: Icons.wifi_tethering_rounded, label: context.s.online, value: online, color: G4MColors.success)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(icon: Icons.payments_rounded, label: context.s.cashInHand, value: cash, money: true, color: G4MColors.accent)),
            ]).stagger(0),
            const SizedBox(height: 16),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(children: [
                    Stack(children: [
                      Avatar(name: list[i].name, url: list[i].photoUrl, size: 50),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: list[i].online ? G4MColors.success : context.rc.faint,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.rc.card, width: 2),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(list[i].name, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                          const SizedBox(width: 6),
                          if (list[i].status != 'approved') StatusPill(list[i].status, label: Fmt.titleCase(list[i].status)),
                        ]),
                        Text('${Fmt.titleCase(list[i].vehicleType)} ${list[i].vehicleNo}'.trim(), style: context.tt.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          '${list[i].completedCount} ${context.tr('deliveries', 'डिलीवरी')} · ${context.s.cashInHand} ${Fmt.money(list[i].cashInHand)}',
                          style: context.tt.bodySmall?.copyWith(color: context.rc.muted),
                        ),
                      ]),
                    ),
                    IconButton.filledTonal(onPressed: () => callPhone(context, list[i].phone), icon: const Icon(Icons.call_rounded)),
                  ]),
                ).stagger(i + 1),
              ),
          ]);
        },
      ),
    );
  }
}
