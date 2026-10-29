import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import '../common/help_screen.dart';
import '../common/notifications_screen.dart';
import '../common/preferences_section.dart';
import '../common/withdrawals_screen.dart';
import 'coupons_screen.dart';
import 'earnings_screen.dart';
import 'returns_screen.dart';
import 'reviews_screen.dart';
import 'riders_screen.dart';
import 'seller_data.dart';
import 'seller_store.dart';
import 'stock_screen.dart';
import 'store_settings_screen.dart';

class SellerMoreScreen extends StatelessWidget {
  const SellerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Seller?>(
          valueListenable: SellerStore.instance.seller,
          builder: (context, s, _) {
            final items = <(IconData, String, String?, Color, Widget)>[
              (Icons.inventory_rounded, context.tr('Stock', 'स्टॉक'), context.tr('Quick restock & alerts', 'त्वरित स्टॉक और अलर्ट'), G4MColors.primary, const StockScreen()),
              (Icons.local_offer_rounded, context.tr('Coupons', 'कूपन'), context.tr('Your store offers', 'आपके स्टोर ऑफ़र'), G4MColors.accent, const SellerCouponsScreen()),
              (Icons.delivery_dining_rounded, context.tr('Delivery boys', 'डिलीवरी बॉय'), context.tr('Your own riders', 'आपके अपने राइडर'), const Color(0xFF7C3AED), const SellerRidersScreen()),
              (Icons.star_rounded, context.tr('Reviews', 'समीक्षाएं'), context.tr('What customers say', 'ग्राहक क्या कहते हैं'), const Color(0xFFF5A524), const SellerReviewsScreen()),
              (Icons.assignment_return_rounded, context.tr('Returns', 'रिटर्न'), context.tr('Requests & refunds', 'अनुरोध और रिफंड'), G4MColors.danger, const SellerReturnsScreen()),
              (Icons.insights_rounded, context.s.earnings, context.tr('Sales & payouts', 'बिक्री और भुगतान'), G4MColors.success, const SellerEarningsScreen()),
              (
                Icons.account_balance_wallet_rounded,
                context.s.withdrawals,
                context.tr('Request payout', 'भुगतान का अनुरोध'),
                G4MColors.info,
                WithdrawalsScreen(role: PartnerRole.seller, balance: SellerData.balance()),
              ),
              (Icons.storefront_rounded, context.tr('Store settings', 'स्टोर सेटिंग्स'), context.tr('Profile, address, bank', 'प्रोफ़ाइल, पता, बैंक'), G4MColors.primaryDeep, const StoreSettingsScreen()),
              (Icons.notifications_rounded, context.s.notifications, null, G4MColors.accent, const NotificationsScreen()),
              (Icons.help_rounded, context.s.helpFaq, null, G4MColors.info, const HelpScreen()),
            ];
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Pressable(
                onTap: () => Go.push(context, const StoreSettingsScreen()),
                child: HeroPanel(
                  child: Row(children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 2)),
                      child: Avatar(name: s?.storeName ?? '', url: s?.logo ?? '', size: 58),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s?.storeName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: context.tt.titleLarge?.copyWith(color: Colors.white)),
                        Text(s?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC94D), size: 16),
                          const SizedBox(width: 4),
                          Text(s == null || s.rating == 0 ? '—' : s.rating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text('${s?.productCount ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ]),
                    ),
                    const Icon(Icons.edit_rounded, color: Colors.white70),
                  ]),
                ),
              ).popIn(),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  return AppCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Go.push(context, it.$5),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: it.$4.withValues(alpha: .13), borderRadius: BorderRadius.circular(11)),
                        child: Icon(it.$1, color: it.$4, size: 21),
                      ),
                      const Spacer(),
                      Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      if (it.$3 != null) Text(it.$3!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                    ]),
                  ).stagger(i + 1, stepMs: 35);
                },
              ),
              const SizedBox(height: 8),
              const PreferencesSection(),
            ]);
          },
        ),
      ),
    );
  }
}
