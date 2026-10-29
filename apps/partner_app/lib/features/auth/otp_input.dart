import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/partner_theme.dart';

/// Keeps only digits, capped at [length]. A paste (several characters inserted at
/// once) that carries a full code replaces the field, so pasting "Your code is
/// 123 456" into a half-filled field still yields 123456.
class OtpFormatter extends TextInputFormatter {
  OtpFormatter(this.length);
  final int length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits(String s) => s.replaceAll(RegExp(r'\D'), '');
    var next = digits(newValue.text);
    final inserted = newValue.text.length - oldValue.text.length;
    if (inserted > 1) {
      // Work out the inserted chunk and prefer it when it is a whole code.
      final start = oldValue.selection.isValid ? oldValue.selection.start.clamp(0, oldValue.text.length) : oldValue.text.length;
      final end = (start + inserted + (oldValue.selection.isValid ? oldValue.selection.end - oldValue.selection.start : 0))
          .clamp(start, newValue.text.length);
      final code = extractCode(newValue.text.substring(start, end));
      if (code != null) next = code;
    }
    if (next.length > length) next = next.substring(0, length);
    return TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
  }

  /// Finds a [length]-digit code in pasted text such as "123456 is your Go4Market
  /// code" or "Code: 123 456". Digits inside words (the 4 in Go4Market) are ignored.
  String? extractCode(String text) {
    final exact = RegExp('(?<![0-9])[0-9]{$length}(?![0-9])');
    final m = exact.firstMatch(text);
    if (m != null) return m.group(0);
    // Codes split by spaces or dashes: "123 456", "123-456".
    final grouped = RegExp(r'(?<![0-9A-Za-z])[0-9][0-9 \-]*[0-9](?![0-9A-Za-z])');
    for (final g in grouped.allMatches(text)) {
      final d = g.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (d.length == length) return d;
    }
    final all = text.replaceAll(RegExp(r'\D'), '');
    return all.length == length ? all : null;
  }
}

/// Six boxes backed by one hidden text field: supports typing (the highlight
/// auto-advances), backspace, paste and Android SMS autofill (`oneTimeCode`).
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.color,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final Color? color;
  final bool hasError;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.removeListener(_rebuild);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _changed(String v) {
    widget.onChanged?.call(v);
    if (v.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(v);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final tint = widget.color ?? rc.brand;
    final text = widget.controller.text;
    final focused = _focus.hasFocus;
    return Semantics(
      label: 'One-time code, ${widget.length} digits',
      textField: true,
      child: SizedBox(
        height: 58,
        child: Stack(children: [
          Row(children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _box(context, i, text, focused, tint)),
            ],
          ]),
          // The real input sits on top, invisible, so taps focus it and long-press offers Paste.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey('otp-field'),
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [OtpFormatter(widget.length)],
                showCursor: false,
                enableSuggestions: false,
                autocorrect: false,
                style: const TextStyle(fontSize: 1, color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _changed,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _box(BuildContext context, int i, String text, bool focused, Color tint) {
    final rc = context.rc;
    final filled = i < text.length;
    final active = focused && widget.enabled && (i == text.length || (text.length == widget.length && i == widget.length - 1));
    final border = widget.hasError
        ? G4MColors.danger
        : active
            ? tint
            : filled
                ? tint.withValues(alpha: .45)
                : rc.line;
    return AnimatedContainer(
      key: ValueKey('otp-box-$i'),
      duration: G4MMotion.standard,
      curve: G4MMotion.curve,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? tint.withValues(alpha: .06) : rc.cardAlt,
        borderRadius: BorderRadius.circular(G4MRadius.sm),
        border: Border.all(color: border, width: active ? 2 : 1.2),
        boxShadow: active ? [BoxShadow(color: tint.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      // Enter-only pop (a keyed tween), so fast typing or a paste never leaves an outgoing digit behind.
      child: filled
          ? TweenAnimationBuilder<double>(
              key: ValueKey('d$i${text[i]}'),
              tween: Tween(begin: 0, end: 1),
              duration: G4MMotion.standard,
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .6 + .4 * v, child: child)),
              child: Text(text[i], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: rc.ink)),
            )
          : active
              ? _Caret(color: tint, key: const ValueKey('caret'))
              : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({super.key, required this.color});
  final Color color;
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(width: 2, height: 22, color: widget.color),
      );
}
