import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

enum RouteStyle { sharedX, sharedY, sharedZ, fadeThrough }

/// Premium page transitions from the `animations` package.
Route<T> appRoute<T>(Widget page, {RouteStyle style = RouteStyle.sharedX, bool fullscreenDialog = false}) {
  if (style == RouteStyle.fadeThrough) {
    return PageRouteBuilder<T>(
      transitionDuration: G4MMotion.emphasized,
      reverseTransitionDuration: const Duration(milliseconds: 320),
      fullscreenDialog: fullscreenDialog,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (ctx, a, s, child) => FadeThroughTransition(
        animation: a,
        secondaryAnimation: s,
        fillColor: Theme.of(ctx).scaffoldBackgroundColor,
        child: child,
      ),
    );
  }
  final type = switch (style) {
    RouteStyle.sharedY => SharedAxisTransitionType.vertical,
    RouteStyle.sharedZ => SharedAxisTransitionType.scaled,
    _ => SharedAxisTransitionType.horizontal,
  };
  return PageRouteBuilder<T>(
    transitionDuration: G4MMotion.emphasized,
    reverseTransitionDuration: const Duration(milliseconds: 340),
    fullscreenDialog: fullscreenDialog,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (ctx, a, s, child) => SharedAxisTransition(
      animation: a,
      secondaryAnimation: s,
      transitionType: type,
      fillColor: Theme.of(ctx).scaffoldBackgroundColor,
      child: child,
    ),
  );
}

extension NavX on BuildContext {
  Future<T?> push<T>(Widget page, {RouteStyle style = RouteStyle.sharedX}) =>
      Navigator.of(this).push<T>(appRoute<T>(page, style: style));

  Future<T?> replaceAll<T>(Widget page, {RouteStyle style = RouteStyle.fadeThrough}) =>
      Navigator.of(this).pushAndRemoveUntil<T>(appRoute<T>(page, style: style), (_) => false);

  void toast(String msg, {bool error = false}) {
    final m = ScaffoldMessenger.maybeOf(this) ?? messengerKey.currentState;
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? G4MColors.danger : null,
        duration: const Duration(milliseconds: 2600),
      ));
  }
}

void globalToast(String msg, {bool error = false}) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? G4MColors.danger : null));
}
