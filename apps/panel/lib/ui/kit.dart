import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState, StatusChip;

import '../core/router.dart';
import '../core/theme.dart';
import 'package:panel/l10n/overrides.dart';

export '../core/theme.dart';

// ───────────────────────── Toasts ─────────────────────────

enum ToastKind { success, error, info }

final _toasts = <OverlayEntry>[];

void toast(String message, {ToastKind kind = ToastKind.success}) {
  final overlay = rootNavKey.currentState?.overlay;
  if (overlay == null) return;
  late OverlayEntry e;
  final index = _toasts.length;
  e = OverlayEntry(builder: (ctx) => _Toast(message: message, kind: kind, index: index, onDone: () {
        e.remove();
        _toasts.remove(e);
      }));
  _toasts.add(e);
  overlay.insert(e);
}

void toastError(Object e) => toast(friendlyError(e), kind: ToastKind.error);

/// Runs [action], toasting [success] or the error. Returns true on success.
Future<bool> runToast(Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null) toast(success);
    return true;
  } catch (e) {
    toastError(e);
    return false;
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.kind, required this.index, required this.onDone});
  final String message;
  final ToastKind kind;
  final int index;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  bool _visible = true;
  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: widget.kind == ToastKind.error ? 5200 : 3200), () {
      if (mounted) setState(() => _visible = false);
      Timer(const Duration(milliseconds: 300), widget.onDone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (widget.kind) {
      ToastKind.success => (G4MColors.success, Icons.check_circle_rounded),
      ToastKind.error => (G4MColors.danger, Icons.error_rounded),
      ToastKind.info => (G4MColors.info, Icons.info_rounded),
    };
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return PositionedDirectional(
      end: 24,
      bottom: 24.0 + widget.index * 68,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420, minWidth: 260),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 18, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A14),
              borderRadius: BorderRadius.circular(14),
              border: BorderDirectional(start: BorderSide(color: color, width: 4)),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(tr(widget.message),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ]),
          ),
        ),
      ).animate().slideX(begin: rtl ? -.3 : .3, duration: 260.ms, curve: Curves.easeOutCubic).fadeIn(duration: 200.ms),
    );
  }
}

// ───────────────────────── Dialogs ─────────────────────────

Future<bool> confirm(BuildContext context, String title,
    {String? message, String confirmLabel = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
          color: danger ? G4MColors.danger : c.pal.accent, size: 32),
      title: Text(tr(title), textAlign: TextAlign.center),
      content: message == null ? null : Text(tr(message), textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(S.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: G4MColors.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr(confirmLabel)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Prompts for a single text value (e.g. a reason / note / amount).
Future<String?> promptText(BuildContext context, String title,
    {String label = 'Note', String initial = '', bool required = false, bool number = false, int maxLines = 1, String confirmLabel = 'Save'}) {
  final c = TextEditingController(text: initial);
  final key = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(title)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: key,
          child: TextFormField(
            controller: c,
            autofocus: true,
            maxLines: maxLines,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
            decoration: InputDecoration(labelText: tr(label)),
            validator: (v) {
              if (required && (v == null || v.trim().isEmpty)) return S.required;
              if (number && v != null && v.isNotEmpty && double.tryParse(v) == null) return S.enterNumber;
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.cancel)),
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(ctx, c.text.trim());
          },
          child: Text(tr(confirmLabel)),
        ),
      ],
    ),
  );
}

/// Slide-in side drawer from the right (used for forms / quick views).
Future<T?> showSideSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder, double width = 560}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .35),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) {
      final w = MediaQuery.sizeOf(ctx).width;
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Material(
          color: ctx.pal.surface,
          elevation: 16,
          child: SizedBox(width: w < width + 40 ? w : width, height: double.infinity, child: builder(ctx)),
        ),
      );
    },
    transitionBuilder: (ctx, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final rtl = Directionality.maybeOf(ctx) == TextDirection.rtl;
      return SlideTransition(position: Tween(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero).animate(c), child: child);
    },
  );
}

// ───────────────────────── Layout ─────────────────────────

/// Standard page: header (title, subtitle, actions) + scrollable body.
class PanelPage extends StatelessWidget {
  const PanelPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.scroll = true,
    this.maxWidth,
    this.padding = const EdgeInsets.fromLTRB(28, 8, 28, 40),
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scroll;
  final double? maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final pad = narrow ? const EdgeInsets.fromLTRB(16, 4, 16, 32) : padding;
    final header = Padding(
      padding: EdgeInsets.only(bottom: 20, top: narrow ? 8 : 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 16,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(tr(title), style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: L10n.instance.code == 'en' ? -.5 : 0)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(tr(subtitle!), style: context.tt.bodyMedium?.copyWith(color: context.pal.muted)),
            ],
          ]),
          if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
    Widget body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, scroll ? child : Expanded(child: child)]);
    if (maxWidth != null) body = Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: body));
    return scroll ? SingleChildScrollView(padding: pad, child: body) : Padding(padding: pad, child: body);
  }
}

/// Bordered surface card with optional title row.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.subtitle, this.trailing, required this.child, this.padding = const EdgeInsets.all(20), this.icon});
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.pal.line),
          boxShadow: context.pal.dark ? null : const [BoxShadow(color: Color(0x080A4A33), blurRadius: 18, offset: Offset(0, 6))],
        ),
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (title != null) ...[
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 20, color: context.pal.accent), const SizedBox(width: 10)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(title!), style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  if (subtitle != null) Text(tr(subtitle!), style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                ]),
              ),
              ?trailing,
            ]),
            const SizedBox(height: 16),
          ],
          child,
        ]),
      );
}

/// Responsive grid of equally sized children.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 240, this.spacing = 16});
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 6);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// KPI tile with icon, value, label and optional trend chip.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, required this.icon, this.color, this.trend, this.onTap, this.caption});
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final double? trend; // percent
  final String? caption;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.accent;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.pal.line),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.withValues(alpha: context.pal.dark ? .14 : .07), context.pal.surface],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: c, size: 21),
            ),
            const Spacer(),
            if (trend != null) TrendChip(trend!),
          ]),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.6)),
          ),
          const SizedBox(height: 2),
          Text(tr(label), style: context.tt.bodySmall?.copyWith(color: context.pal.muted, fontWeight: FontWeight.w600)),
          if (caption != null) Text(tr(caption!), style: context.tt.labelSmall?.copyWith(color: context.pal.faint)),
        ]),
      ),
    );
  }
}

class TrendChip extends StatelessWidget {
  const TrendChip(this.pct, {super.key});
  final double pct;
  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final c = up ? G4MColors.success : G4MColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: c),
        const SizedBox(width: 3),
        Text('${pct.abs().toStringAsFixed(pct.abs() < 10 ? 1 : 0)}%', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11.5)),
      ]),
    );
  }
}

/// Dark-mode aware shimmer.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.pal.surfaceAlt, borderRadius: BorderRadius.circular(radius)),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1300.ms, color: context.pal.dark ? const Color(0x22FFFFFF) : const Color(0xCCFFFFFF));
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.rows = 6});
  final int rows;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Shimmer(width: 40, height: 40, radius: 10),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Shimmer(width: 120.0 + (i % 3) * 60, height: 12),
                const SizedBox(height: 8),
                const Shimmer(width: 90, height: 10),
              ])),
              const Shimmer(width: 70, height: 22, radius: 99),
            ]),
          ),
      ]);
}

/// Error panel, aware of missing-index errors.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final s = error.toString();
    final index = s.contains('failed-precondition') || s.contains('requires an index');
    final perm = s.contains('permission-denied');
    return EmptyState(
      icon: index ? Icons.hourglass_top_rounded : perm ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
      title: index ? S.indexBuilding : perm ? S.noAccess : S.couldNotLoad,
      message: index
          ? S.indexBuildingMsg
          : perm
              ? S.noPermissionMsg
              : friendlyError(error),
      action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(S.retry)),
    );
  }
}

/// Small key → value line.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.valueWidget});
  final String label;
  final String value;
  final bool bold;
  final Widget? valueWidget;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(tr(label), style: TextStyle(color: context.pal.muted, fontSize: 13))),
          Expanded(
            child: valueWidget ??
                SelectableText(value.isEmpty ? '—' : value,
                    style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5)),
          ),
        ]),
      );
}

/// Round avatar with image or initials.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url = '', required this.name, this.size = 36, this.color});
  final String url;
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.accent;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: .14), shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url.isNotEmpty
          ? NetImage(url, width: size, height: size)
          : Text(initials, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: size * .38)),
    );
  }
}

/// Filled button that shows a spinner while [onPressed] runs.
class AsyncButton extends StatefulWidget {
  const AsyncButton({super.key, required this.onPressed, required this.label, this.icon, this.outlined = false, this.color});
  final Future<void> Function()? onPressed;
  final String label;
  final IconData? icon;
  final bool outlined;
  final Color? color;
  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;
  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onP = widget.onPressed == null || _busy ? null : _run;
    final icon = _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : widget.icon == null
            ? null
            : Icon(widget.icon, size: 18);
    final label = Text(tr(widget.label));
    if (widget.outlined) {
      return icon == null
          ? OutlinedButton(onPressed: onP, child: label)
          : OutlinedButton.icon(onPressed: onP, icon: icon, label: label);
    }
    final style = widget.color == null ? null : FilledButton.styleFrom(backgroundColor: widget.color);
    return icon == null
        ? FilledButton(style: style, onPressed: onP, child: label)
        : FilledButton.icon(style: style, onPressed: onP, icon: icon, label: label);
  }
}

/// Segmented pill selector.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: context.pal.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final e in options.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: G4MMotion.standard,
                  curve: G4MMotion.curve,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: e.key == value ? context.pal.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: e.key == value ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))] : null,
                  ),
                  child: Text(tr(e.value),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: e.key == value ? context.pal.ink : context.pal.muted,
                      )),
                ),
              ),
            ),
        ]),
      );
}

/// Coloured tag.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Text(tr(label), style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Status pill that accepts any status string (wraps core StatusChip with dark-mode safe text).
Widget statusPill(String status, {String? label}) => StatusChip(status, label: label ?? OrderStatus.label(status).replaceAll('_', ' ').let(Fmt.titleCase));

extension LetX<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
