import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/shell.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.l.content;
    return SeoMeta(
      title: t.notFoundTitle,
      child: PageScroll(children: [
        Contained(
          vertical: 48,
          child: Column(children: [
            const Text('404', style: TextStyle(fontSize: 96, fontWeight: FontWeight.w800, color: G4MColors.primarySoft, letterSpacing: -4)),
            Heading(t.notFoundHeading, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(t.notFoundBody, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 16)),
            const SizedBox(height: 24),
            Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
              FilledButton(onPressed: () => context.go('/'), child: Text(t.goHome)),
              OutlinedButton(onPressed: () => context.go('/categories'), child: Text(t.browseCategories)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
