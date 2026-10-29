import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'l10n.dart';
import 'lang_sync.dart';

/// Language picker (top bar and login screen). Lists English plus every language that is
/// `active` in Firestore `languages`, in its native name.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.compact = false, this.light = false});

  /// Icon + code only (narrow top bars).
  final bool compact;

  /// White foreground (dark hero backgrounds).
  final bool light;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: L10n.instance,
        builder: (context, _) {
          final l = L10n.instance;
          final fg = light ? Colors.white : context.pal.ink;
          return PopupMenuButton<String>(
            key: const ValueKey('lang-picker'),
            tooltip: S.language,
            position: PopupMenuPosition.under,
            onSelected: LangSync.choose,
            itemBuilder: (_) => [
              for (final a in l.available)
                PopupMenuItem(
                  value: a.code,
                  child: Row(children: [
                    SizedBox(width: 30, child: Text(a.code.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.pal.muted))),
                    Expanded(child: Text(a.nativeName, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (a.code != 'en') Text('  ${a.name}', style: TextStyle(fontSize: 12, color: context.pal.muted)),
                    if (a.code == l.code) ...[const SizedBox(width: 8), Icon(Icons.check_rounded, size: 18, color: context.pal.accent)],
                  ]),
                ),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: light ? Colors.white.withValues(alpha: .3) : context.pal.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.translate_rounded, size: 17, color: fg),
                const SizedBox(width: 6),
                Text(compact ? l.code.toUpperCase() : l.lang.nativeName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: fg)),
                Icon(Icons.expand_more_rounded, size: 17, color: fg),
              ]),
            ),
          );
        },
      );
}
