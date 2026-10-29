import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/cart_fx.dart';
import '../cart/cart_screen.dart';
import '../categories/categories_screen.dart';
import '../home/home_screen.dart';
import '../link_router.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

/// Currently selected bottom tab; any screen can switch tabs (e.g. "Start shopping").
final shellTab = ValueNotifier<int>(0);

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _built = <int>{0};
  bool _updateShown = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    shellTab.value = 0;
    shellTab.addListener(_onTab);
    pendingDeepLink.addListener(_onDeepLink);
    AppConfig.platform.addListener(_checkVersion);
    PackageInfo.fromPlatform().then((i) {
      _version = i.version;
      _checkVersion();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onDeepLink();
      // Ask for notification permission once the user is inside the app, not during splash.
      PushService.init();
    });
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    pendingDeepLink.removeListener(_onDeepLink);
    AppConfig.platform.removeListener(_checkVersion);
    super.dispose();
  }

  void _onTab() => setState(() => _built.add(shellTab.value));

  void _onDeepLink() {
    final d = pendingDeepLink.value;
    if (d == null || !mounted) return;
    pendingDeepLink.value = null;
    openNotificationData(context, d);
  }

  // ----------------------------------------------------------- force update

  static int _cmp(String a, String b) {
    List<int> parts(String v) => v.split('+').first.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d.sign;
    }
    return 0;
  }

  void _checkVersion() {
    if (_updateShown || _version.isEmpty || !mounted) return;
    final cust = AppConfig.platform.value.appVersions['customer'];
    final min = cust is Map ? '${cust['min'] ?? ''}' : '';
    if (min.isEmpty || _cmp(_version, min) >= 0) return;
    _updateShown = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'update',
      transitionDuration: G4MMotion.emphasized,
      transitionBuilder: (_, a, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child),
      ),
      pageBuilder: (ctx, _, _) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.system_update_rounded, size: 44, color: G4MColors.primary),
          title: const Text('Update required'),
          content: Text(
            'A new version of Go4Market is available. Please update to continue.\n\nYour version: $_version · Required: $min',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton.icon(
              onPressed: () async {
                final market = Uri.parse('market://details?id=com.go4market.customer');
                final web = Uri.parse('https://play.google.com/store/apps/details?id=com.go4market.customer');
                if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
                  await launchUrl(web, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const CategoriesScreen(),
        2 => const CartScreen(),
        3 => const OrdersScreen(),
        _ => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final tab = shellTab.value;
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shellTab.value = 0;
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(children: [
          for (final i in _built)
            _FadeThroughTab(active: i == tab, child: _page(i)),
        ]),
        bottomNavigationBar: _BottomNav(index: tab, onTap: (i) {
          if (i == tab) return;
          HapticFeedback.selectionClick();
          shellTab.value = i;
        }),
      ),
    );
  }
}

/// Keeps each tab alive while animating a fade-through (fade + slight scale) between them.
class _FadeThroughTab extends StatelessWidget {
  const _FadeThroughTab({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !active,
        // Opacity/scale animate outside TickerMode so the outgoing tab can still fade out.
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: active ? const Duration(milliseconds: 300) : const Duration(milliseconds: 120),
          curve: active ? const Interval(.3, 1, curve: Curves.easeOut) : Curves.easeIn,
          child: AnimatedScale(
            scale: active ? 1 : .96,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: HeroMode(enabled: active, child: TickerMode(enabled: active, child: child)),
          ),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      (Icons.home_outlined, Icons.home_rounded, l.home),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, l.categories),
      (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, l.cart),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, l.orders),
      (Icons.person_outline_rounded, Icons.person_rounded, l.account),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 12),
      height: 68,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x1F0A4A33), blurRadius: 30, offset: Offset(0, 10))],
        border: context.isDark ? Border.all(color: context.line) : null,
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / items.length;
        return Stack(children: [
          // Sliding pill indicator.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            left: index * w + (w - 52) / 2,
            top: 8,
            child: Container(
              width: 52,
              height: 32,
              decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(16)),
            ),
          ),
          Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$3,
                  child: InkResponse(
                    onTap: () => onTap(i),
                    radius: 36,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(
                        height: 32,
                        child: Center(
                          child: AnimatedScale(
                            scale: i == index ? 1.12 : 1,
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutBack,
                            child: i == 2
                                ? CartBadgeIcon(
                                    icon: i == index ? items[i].$2 : items[i].$1,
                                    color: i == index ? G4MColors.primary : context.muted,
                                  )
                                : AnimatedSwitcher(
                                    duration: G4MMotion.standard,
                                    child: Icon(
                                      i == index ? items[i].$2 : items[i].$1,
                                      key: ValueKey(i == index),
                                      color: i == index ? G4MColors.primary : context.muted,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: G4MMotion.standard,
                        style: TextStyle(
                          fontFamily: context.text.labelSmall?.fontFamily,
                          fontSize: 11,
                          fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                          color: i == index ? G4MColors.primary : context.muted,
                        ),
                        child: Text(items[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Helper for "Start shopping" style CTAs.
void goHomeTab(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  shellTab.value = 0;
}

/// Bottom padding tab pages need because the floating nav bar overlaps content.
const kNavPad = 116.0;
