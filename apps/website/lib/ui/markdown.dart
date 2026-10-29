import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:g4m_core/g4m_core.dart';

import 'kit.dart';

/// Markdown renderer for blogs and CMS pages, styled to the brand.
class Md extends StatelessWidget {
  const Md(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final body = tt.bodyLarge?.copyWith(height: 1.75, color: const Color(0xFF26352D), fontSize: 16.5);
    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (_, href, _) {
        if (href != null) openLink(context, href);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        listBullet: body,
        h1: tt.headlineMedium?.copyWith(color: G4MColors.primaryDeep),
        h2: tt.headlineSmall?.copyWith(color: G4MColors.primaryDeep, height: 2),
        h3: tt.titleLarge?.copyWith(color: G4MColors.primaryDeep, height: 1.8),
        a: const TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
        blockquote: body?.copyWith(fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          color: G4MColors.primarySoft,
          borderRadius: BorderRadius.circular(G4MRadius.sm),
          border: const BorderDirectional(start: BorderSide(color: G4MColors.primary, width: 4)),
        ),
        code: const TextStyle(fontFamily: 'monospace', backgroundColor: G4MColors.surfaceAlt),
        blockSpacing: 16,
      ),
    );
  }
}
