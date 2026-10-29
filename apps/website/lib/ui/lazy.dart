import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'markdown.dart' deferred as md;

/// Builds [builder] once a deferred library has loaded; shows a quiet loader meanwhile.
class Deferred extends StatefulWidget {
  const Deferred({super.key, required this.load, required this.builder, this.placeholder});
  final Future<void> Function() load;
  final WidgetBuilder builder;
  final Widget? placeholder;
  @override
  State<Deferred> createState() => _DeferredState();
}

class _DeferredState extends State<Deferred> {
  late final Future<void> _f = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.done && !s.hasError) return widget.builder(context);
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.l.content.pageLoadFailed),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() {}), child: Text(context.l.content.retry)),
                ]),
              ),
            );
          }
          return widget.placeholder ?? const Center(child: Padding(padding: EdgeInsets.all(80), child: CircularProgressIndicator()));
        },
      );
}

/// Markdown that loads its renderer on demand; shows the raw text until then.
class LazyMd extends StatelessWidget {
  const LazyMd(this.data, {super.key});
  final String data;
  @override
  Widget build(BuildContext context) => Deferred(
        load: md.loadLibrary,
        placeholder: Text(data.replaceAll(RegExp(r'[#*_>`]'), ''), style: const TextStyle(height: 1.75, fontSize: 16.5)),
        builder: (_) => md.Md(data),
      );
}
