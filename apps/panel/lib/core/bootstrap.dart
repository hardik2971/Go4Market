import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:web/web.dart' as web;

import '../l10n/l10n.dart';
import '../l10n/lang_sync.dart';
import '../shell/push.dart';
import 'panel.dart';
import 'router.dart';
import 'session.dart';
import 'theme.dart';

String? prefGet(String k) {
  try {
    return web.window.localStorage.getItem('g4m.$k');
  } catch (_) {
    return null;
  }
}

void prefSet(String k, String v) {
  try {
    web.window.localStorage.setItem('g4m.$k', v);
  } catch (_) {}
}

Future<void> runPanel(PanelRole role, PanelSpec Function() buildSpec) async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initG4MFirebase(role.client);
  await initializeDateFormatting();
  final s = Session.instance = Session(role);
  s.themeMode = prefGet('theme') == 'dark' ? ThemeMode.dark : ThemeMode.light;
  s.addListener(() => prefSet('theme', s.themeMode == ThemeMode.dark ? 'dark' : 'light'));
  LangSync.start(s);
  s.start();
  PushService.start(s);
  await s.firstReady.timeout(const Duration(seconds: 10), onTimeout: () {});
  runApp(PanelApp(spec: buildSpec()));
}

class PanelApp extends StatefulWidget {
  const PanelApp({super.key, required this.spec});
  final PanelSpec spec;
  @override
  State<PanelApp> createState() => _PanelAppState();
}

class _PanelAppState extends State<PanelApp> {
  late final GoRouter router = buildRouter(widget.spec);
  final _l10n = L10n.instance;
  late String _lang = _l10n.code;

  @override
  void initState() {
    super.initState();
    _l10n.addListener(_onLang);
  }

  @override
  void dispose() {
    _l10n.removeListener(_onLang);
    super.dispose();
  }

  /// UI strings are resolved with tr() at build time, so a language switch has to rebuild every
  /// element, including const subtrees and cached route pages. Widget state is kept.
  void _onLang() {
    if (_lang == _l10n.code) return;
    _lang = _l10n.code;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      (context as Element).visitChildren(mark);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) {
          final s = Session.instance;
          return MaterialApp.router(
            title: 'Go4Market ${s.panel.title}',
            debugShowCheckedModeBanner: false,
            theme: panelTheme(Brightness.light, s.accent),
            darkTheme: panelTheme(Brightness.dark, s.accent),
            themeMode: s.themeMode,
            themeAnimationDuration: G4MMotion.emphasized,
            themeAnimationCurve: G4MMotion.curve,
            locale: _l10n.locale,
            supportedLocales: supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            routerConfig: router,
          );
        },
      );
}
