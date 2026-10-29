import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/location_service.dart';
import '../../core/push.dart';
import 'delivery_earnings.dart';
import 'delivery_history.dart';
import 'delivery_home.dart';
import 'delivery_orders.dart';
import 'delivery_profile.dart';

/// Bottom-nav shell for approved delivery partners. Tabs keep their state and
/// cross-fade/slide when switched.
class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key});

  /// Lets children switch tab (e.g. Home -> Orders).
  static void goTab(BuildContext context, int i) => context.findAncestorStateOfType<_DeliveryShellState>()?._select(i);

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  int _tab = 0;
  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => PushService.instance.flushPending());
    _restoreOnline();
  }

  /// After an app restart the doc may still say online while no stream runs.
  Future<void> _restoreOnline() async {
    try {
      final d = await Fs.deliveryPartners.doc(myUid).get();
      final online = d.data()?['online'] == true;
      if (!online || LocationService.instance.running) return;
      final p = await Geolocator.checkPermission();
      final granted = p == LocationPermission.always || p == LocationPermission.whileInUse;
      if (granted && await Geolocator.isLocationServiceEnabled()) {
        await LocationService.instance.start(myUid);
      } else {
        await LocationService.instance.stop();
      }
    } catch (_) {}
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = [DeliveryHomeTab(), DeliveryOrdersTab(), DeliveryHistoryTab(), DeliveryEarningsTab(), DeliveryProfileTab()];
    return Builder(

      builder: (context) {
        return Scaffold(
          body: Stack(children: [
            for (var i = 0; i < pages.length; i++)
              if (_visited.contains(i))
                IgnorePointer(
                  ignoring: i != _tab,
                  child: TickerMode(
                    enabled: i == _tab,
                    child: AnimatedOpacity(
                      opacity: i == _tab ? 1 : 0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSlide(
                        offset: i == _tab ? Offset.zero : const Offset(0, .015),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        child: pages[i],
                      ),
                    ),
                  ),
                ),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _select,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: context.s.home),
              NavigationDestination(
                icon: const Icon(Icons.delivery_dining_outlined),
                selectedIcon: const Icon(Icons.delivery_dining_rounded),
                label: context.s.orders,
              ),
              NavigationDestination(icon: const Icon(Icons.history_rounded), selectedIcon: const Icon(Icons.history_toggle_off_rounded), label: context.s.history),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
                label: context.s.earnings,
              ),
              NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: context.s.profile),
            ],
          ),
        );
      },
    );
  }
}
