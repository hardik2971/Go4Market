import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/shop.dart';
import '../l10n/l10n.dart';

/// Shows [builder] only to signed-in (non-guest) shoppers; otherwise a friendly sign-in prompt.
class SignedInGate extends StatelessWidget {
  const SignedInGate({super.key, required this.next, required this.title, required this.message, required this.builder, this.icon = Icons.lock_outline_rounded});
  final String next;
  final String title;
  final String message;
  final IconData icon;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          if (!shop.authResolved) return const Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator()));
          if (!shop.signedIn) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: icon,
                title: title,
                message: message,
                action: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  FilledButton(onPressed: () => context.go('/login?next=${Uri.encodeQueryComponent(next)}'), child: Text(context.l.common.signIn)),
                  OutlinedButton(onPressed: () => context.go('/signup?next=${Uri.encodeQueryComponent(next)}'), child: Text(context.l.common.createAccount)),
                ]),
              ),
            );
          }
          return builder(context);
        },
      );
}
