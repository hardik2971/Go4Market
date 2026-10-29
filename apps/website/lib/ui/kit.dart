import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../core/web_bridge.dart';
import '../l10n/l10n.dart';

// ---------------------------------------------------------------- tokens

/// Orange tuned for text on white (WCAG AA 4.5:1). The brand orange is kept for fills.
const kAccentInk = Color(0xFFB4530A);
const kDiscountInk = Color(0xFF0A7A45);
const kMaxContent = 1320.0;

extension Bp on BuildContext {
  double get w => MediaQuery.sizeOf(this).width;
  bool get isPhone => w < 720;
  bool get isTablet => w >= 720 && w < 1100;
  bool get isDesktop => w >= 1100;
  double get gutter => w < 720 ? 16 : (w < 1100 ? 24 : 32);
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
  TextTheme get tt => Theme.of(this).textTheme;
}

/// Centres content at the site max width with responsive side gutters.
class Contained extends StatelessWidget {
  const Contained({super.key, required this.child, this.vertical = 0, this.maxWidth = kMaxContent});
  final Widget child;
  final double vertical;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth + context.gutter * 2),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: context.gutter, vertical: vertical), child: child),
        ),
      );
}

// ---------------------------------------------------------------- SEO

/// Sets document title / meta description / canonical for the page that renders it.
class SeoMeta extends StatefulWidget {
  const SeoMeta({super.key, this.title, this.description, this.image, required this.child});
  final String? title;
  final String? description;
  final String? image;
  final Widget child;
  @override
  State<SeoMeta> createState() => _SeoMetaState();
}

class _SeoMetaState extends State<SeoMeta> {
  String? _lang;
  void _apply() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        WebBridge.setMeta(title: widget.title, description: widget.description, image: widget.image, l: context.l);
      });
  @override
  void initState() {
    super.initState();
    _apply();
  }

  // Re-apply when the language changes even if this page's own title did not (e.g. the translated default).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = context.l.code;
    if (_lang != null && _lang != code) _apply();
    _lang = code;
  }

  @override
  void didUpdateWidget(SeoMeta old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title || old.description != widget.description) _apply();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Semantic page heading (h1/h2...) so screen readers and crawlers see structure.
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.level = 1, this.style, this.maxLines, this.textAlign});
  final String text;
  final int level;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) {
    final base = switch (level) {
      1 => context.tt.headlineLarge,
      2 => context.tt.headlineSmall,
      _ => context.tt.titleLarge,
    };
    return Semantics(
      header: true,
      headingLevel: level,
      child: Text(text,
          maxLines: maxLines,
          textAlign: textAlign,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: base?.copyWith(color: G4MColors.ink).merge(style)),
    );
  }
}

// ---------------------------------------------------------------- links

/// Resolves admin-entered links (`/c/fruits`, `category:fruits`, `product:x`, full URLs).
String resolveLink(String link) {
  final l = link.trim();
  if (l.isEmpty) return '/';
  if (l.startsWith('http') || l.startsWith('/')) return l;
  final i = l.indexOf(':');
  if (i > 0) {
    final kind = l.substring(0, i), v = l.substring(i + 1);
    return switch (kind) {
      'category' || 'c' => '/c/$v',
      'product' || 'p' => '/p/$v',
      'store' || 'seller' => '/store/$v',
      'module' || 'm' => '/m/$v',
      'search' => '/search?q=${Uri.encodeQueryComponent(v)}',
      'page' => '/page/$v',
      'blog' => '/blog/$v',
      _ => '/$l',
    };
  }
  return '/$l';
}

void openLink(BuildContext context, String link) {
  final to = resolveLink(link);
  if (to.startsWith('http')) {
    final own = to.startsWith(kSiteUrl);
    if (own) {
      context.go(to.substring(kSiteUrl.length).isEmpty ? '/' : to.substring(kSiteUrl.length));
    } else {
      launchUrl(Uri.parse(to), webOnlyWindowName: '_blank');
    }
  } else {
    context.go(to);
  }
}

/// A tappable region exposed to assistive tech (and the semantics DOM) as a real link with href.
class AppLink extends StatelessWidget {
  const AppLink({super.key, required this.to, required this.child, this.label, this.scale = .98});
  final String to;
  final Widget child;
  final String? label;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final href = resolveLink(to);
    return Semantics(
      link: true,
      linkUrl: Uri.parse(href),
      label: label,
      button: false,
      child: Pressable(scale: scale, haptic: false, onTap: () => openLink(context, href), child: child),
    );
  }
}

/// Text link with an underline on hover.
class TextLink extends StatefulWidget {
  const TextLink(this.text, {super.key, required this.to, this.style, this.hoverColor});
  final String text;
  final String to;
  final TextStyle? style;
  final Color? hoverColor;
  @override
  State<TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<TextLink> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = (widget.style ?? context.tt.bodyMedium)!;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AppLink(
        to: widget.to,
        scale: 1,
        child: AnimatedDefaultTextStyle(
          duration: G4MMotion.fast,
          style: s.copyWith(
            color: _h ? (widget.hoverColor ?? G4MColors.primary) : s.color,
            decoration: _h ? TextDecoration.underline : TextDecoration.none,
            decorationColor: widget.hoverColor ?? G4MColors.primary,
          ),
          child: Text(widget.text),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- motion

/// Fades and slides a child in the first time it scrolls into view. [index] staggers siblings.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 24, this.delayStep = 70});
  final Widget child;
  final int index;
  final double offset;
  final int delayStep;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: G4MMotion.slow);
  late final _a = CurvedAnimation(parent: _c, curve: G4MMotion.curve);
  final _key = UniqueKey();
  bool _started = false;

  void _start() {
    if (_started) return;
    _started = true;
    Future.delayed(Duration(milliseconds: (widget.index.clamp(0, 8)) * widget.delayStep), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: (i) {
        if (i.visibleFraction > 0.02) _start();
      },
      child: AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.offset), child: child),
        ),
      ),
    );
  }
}

/// Lifts a card on hover with a deeper shadow.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.radius = G4MRadius.lg, this.lift = 6, this.color, this.border = true});
  final Widget child;
  final double radius;
  final double lift;
  final Color? color;
  final bool border;
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: G4MMotion.standard,
        curve: G4MMotion.curve,
        transform: Matrix4.translationValues(0, _h && !rm ? -widget.lift : 0, 0),
        decoration: BoxDecoration(
          color: widget.color ?? G4MColors.surface,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border ? Border.all(color: _h ? const Color(0xFFCFE3D7) : G4MColors.line) : null,
          boxShadow: _h ? G4MShadows.lifted : const [BoxShadow(color: Color(0x080A4A33), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: widget.child),
      ),
    );
  }
}

// ---------------------------------------------------------------- building blocks

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.viewAll, this.trailing, this.eyebrow, this.accent});
  final String title;
  final String? subtitle;
  final String? viewAll;
  final Widget? trailing;
  final String? eyebrow;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (eyebrow != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(eyebrow!.toUpperCase(),
                    style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: accent ?? G4MColors.primary)),
              ),
            Heading(title, level: 2, style: TextStyle(fontSize: context.isPhone ? 21 : 26)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!, style: context.tt.bodyMedium?.copyWith(color: G4MColors.inkMuted)),
              ),
          ]),
        ),
        ?trailing,
        if (viewAll != null) ...[
          const SizedBox(width: 8),
          ViewAllButton(to: viewAll!, label: context.l.common.viewAllOf(title)),
        ],
      ]),
    );
  }
}

class ViewAllButton extends StatelessWidget {
  const ViewAllButton({super.key, required this.to, this.label});
  final String to;
  final String? label;
  @override
  Widget build(BuildContext context) => AppLink(
        to: to,
        label: label ?? context.l.common.viewAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: G4MColors.primarySoft, borderRadius: BorderRadius.circular(G4MRadius.pill)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(context.l.common.viewAll, style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.primaryDeep, fontSize: 13.5)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: G4MColors.primaryDeep),
          ]),
        ),
      );
}

/// Circular arrow button used for carousels.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, required this.tooltip, this.size = 40, this.filled = false});
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: G4MMotion.fast,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: filled ? G4MColors.primaryDeep : G4MColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: filled ? G4MColors.primaryDeep : G4MColors.line),
                boxShadow: G4MShadows.soft,
              ),
              child: Icon(icon, size: size * .48, color: onTap == null ? G4MColors.inkFaint : (filled ? Colors.white : G4MColors.ink)),
            ),
          ),
        ),
      );
}

/// Price with struck MRP and discount, using AA-contrast colours.
class Price extends StatelessWidget {
  const Price({super.key, required this.price, this.mrp, this.size = 16, this.showOff = true});
  final double price;
  final double? mrp;
  final double size;
  final bool showOff;
  @override
  Widget build(BuildContext context) {
    final off = mrp != null && mrp! > price && mrp! > 0 ? (((mrp! - price) / mrp!) * 100).round() : 0;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
      Text(context.l.money(price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: G4MColors.ink, letterSpacing: -.2)),
      if (off > 0)
        Text(context.l.money(mrp!),
            semanticsLabel: context.l.common.mrpLabel(context.l.money(mrp!)),
            style: TextStyle(fontSize: size * .8, color: G4MColors.inkMuted, decoration: TextDecoration.lineThrough, decorationColor: G4MColors.inkMuted)),
      if (off > 0 && showOff) Text(context.l.common.off(off), style: TextStyle(fontSize: size * .8, fontWeight: FontWeight.w800, color: kDiscountInk)),
    ]);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = G4MColors.accentSoft, this.fg = kAccentInk, this.icon, this.fontSize = 11.5});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(G4MRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: fontSize + 2, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: fg)),
        ]),
      );
}

/// Shows loading skeleton / error / content for a Future or Stream snapshot.
Widget asyncView<T>(AsyncSnapshot<T> s, Widget Function(T data) builder, {Widget? loading, String? errorTitle}) {
  if (s.hasError) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: errorTitle ?? L.current.common.loadErrorTitle,
      message: errorMessage(s.error!),
    );
  }
  if (!s.hasData) return loading ?? const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
  return builder(s.data as T);
}

String errorMessage(Object e) {
  final s = friendlyError(e);
  if (s.contains('failed-precondition') || s.contains('index')) return L.current.common.catalogWarming;
  if (s.contains('permission-denied') || s.contains('insufficient permissions')) return L.current.common.notAvailableYet;
  if (s.contains('network-request-failed') || s.contains('Failed to fetch')) return L.current.common.networkError;
  return s;
}

void toast(BuildContext context, String msg, {bool error = false, String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? G4MColors.danger : G4MColors.primaryDeep,
    width: context.isPhone ? null : 420,
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, textColor: const Color(0xFFBFF0D4), onPressed: onAction ?? () {}),
  ));
}

Future<void> copyText(BuildContext context, String text, [String? msg]) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, msg ?? context.l.common.copied);
}

/// Rounded white panel.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color = G4MColors.surface, this.radius = G4MRadius.lg});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: G4MColors.line),
          boxShadow: const [BoxShadow(color: Color(0x080A4A33), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

/// Picks readable text colour for an arbitrary background.
Color onColor(Color bg) => bg.computeLuminance() > .45 ? G4MColors.ink : Colors.white;
