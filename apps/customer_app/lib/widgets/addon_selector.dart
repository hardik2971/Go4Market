import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/addons.dart';
import '../core/theme.dart';

/// Animated add-on picker for food items. Respects `group` / `maxSelect`:
/// single-choice groups behave like radio buttons, fuller groups refuse with a shake.
class AddonSelector extends StatefulWidget {
  const AddonSelector({super.key, required this.addons, required this.selected, required this.onChanged, this.onLimit});
  final List<ProductAddon> addons;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Called when a tap is refused because the group is already full.
  final ValueChanged<AddonGroup>? onLimit;

  @override
  State<AddonSelector> createState() => _AddonSelectorState();
}

class _AddonSelectorState extends State<AddonSelector> {
  late List<AddonGroup> _groups = groupAddons(widget.addons);

  // Latest selection, updated on tap so quick successive taps never act on a stale parent value.
  late Set<String> _sel = widget.selected;
  final _shake = <String, int>{};

  @override
  void didUpdateWidget(covariant AddonSelector old) {
    super.didUpdateWidget(old);
    if (old.addons != widget.addons) _groups = groupAddons(widget.addons);
    _sel = widget.selected;
  }

  void _tap(ProductAddon a) {
    final r = toggleAddon(_groups, _sel, a.id);
    if (r.limitHit != null) {
      HapticFeedback.heavyImpact();
      setState(() => _shake[r.limitHit!.name] = (_shake[r.limitHit!.name] ?? 0) + 1);
      widget.onLimit?.call(r.limitHit!);
      return;
    }
    HapticFeedback.selectionClick();
    _sel = r.selection;
    widget.onChanged(r.selection);
  }

  String _hint(AddonGroup g) {
    final max = g.maxSelect;
    if (max == null) return 'Optional';
    if (max == 1) return 'Choose 1';
    return 'Choose up to $max';
  }

  @override
  Widget build(BuildContext context) {
    final total = addonTotal(widget.addons, _sel);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.restaurant_menu_rounded, size: 18, color: G4MColors.accent),
        const SizedBox(width: 8),
        Expanded(child: Text('Make it yours', style: context.text.titleSmall)),
        AnimatedSwitcher(
          duration: G4MMotion.standard,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(a), child: c),
          ),
          child: total > 0
              ? Container(
                  key: ValueKey(total),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(G4MRadius.pill)),
                  child: Text('Add-ons +${Fmt.money(total)}',
                      key: const ValueKey('addon-total'),
                      style: const TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        ),
      ]),
      for (final g in _groups) ...[
        const SizedBox(height: 12),
        _ShakeX(
          trigger: _shake[g.name] ?? 0,
          child: Row(children: [
            if (g.name.isNotEmpty) ...[
              Text(g.name, style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: context.cardAlt, borderRadius: BorderRadius.circular(G4MRadius.pill)),
              child: Text(_hint(g), style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        for (final (i, a) in g.addons.indexed)
          _AddonTile(
            key: ValueKey('addon-${a.id}'),
            addon: a,
            radio: g.single,
            selected: _sel.contains(a.id),
            onTap: () => _tap(a),
            index: i,
          ),
      ],
    ]);
  }
}

class _AddonTile extends StatelessWidget {
  const _AddonTile({super.key, required this.addon, required this.selected, required this.onTap, required this.radio, required this.index});
  final ProductAddon addon;
  final bool selected, radio;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${addon.name}, plus ${Fmt.money(addon.price)}',
        child: Pressable(
          onTap: onTap,
          haptic: false,
          child: AnimatedContainer(
            duration: G4MMotion.standard,
            curve: G4MMotion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? context.softPrimary : context.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? G4MColors.primary : context.line, width: selected ? 1.6 : 1),
              boxShadow: selected ? const [BoxShadow(color: Color(0x1F0B8A4F), blurRadius: 14, offset: Offset(0, 4))] : null,
            ),
            child: Row(children: [
              _Check(on: selected, radio: radio),
              const SizedBox(width: 12),
              Expanded(
                child: Text(addon.name,
                    style: context.text.bodyMedium?.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ),
              AnimatedDefaultTextStyle(
                duration: G4MMotion.standard,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? G4MColors.primary : context.muted,
                ),
                child: Text(addon.price > 0 ? '+${Fmt.money(addon.price)}' : 'Free'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Checkbox / radio that pops when toggled.
class _Check extends StatelessWidget {
  const _Check({required this.on, required this.radio});
  final bool on, radio;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: G4MMotion.standard,
      curve: G4MMotion.curve,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on && !radio ? G4MColors.primary : Colors.transparent,
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : BorderRadius.circular(7),
        border: Border.all(color: on ? G4MColors.primary : context.line, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: on ? Curves.elasticOut : Curves.easeIn,
        child: radio
            ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: G4MColors.primary, shape: BoxShape.circle))
            : const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
    );
  }
}

/// Horizontal shake each time [trigger] changes.
class _ShakeX extends StatelessWidget {
  const _ShakeX({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (trigger == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, t, c) => Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * 8 * (1 - t), 0), child: c),
      child: child,
    );
  }
}
