import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/theme.dart';

/// Pulls an OTP out of pasted text. Prefers a standalone run of [length] digits (allowing one space
/// or dash between digits, e.g. "654-321"), so "Your Go4Market code is 654321" gives 654321, not 465432.
/// Otherwise keeps the first [length] digits.
String extractOtp(String text, {int length = 6}) {
  final run = RegExp(r'(?<!\d)\d(?:[ \-]?\d){' '${length - 1}' r'}(?!\d)').firstMatch(text);
  final src = run?.group(0) ?? text;
  final digits = src.replaceAll(RegExp(r'\D'), '');
  return digits.length > length ? digits.substring(0, length) : digits;
}

/// Typing: digits only. Paste / autofill (several characters at once): [extractOtp].
class _OtpFormatter extends TextInputFormatter {
  _OtpFormatter(this.length);
  final int length;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text;
    if (newValue.text.length - oldValue.text.length > 1) {
      // A full code pasted after partial typing replaces it; otherwise read the whole value.
      final inserted = newValue.text.startsWith(oldValue.text) ? newValue.text.substring(oldValue.text.length) : newValue.text;
      final fromInsert = extractOtp(inserted, length: length);
      text = fromInsert.length == length ? fromInsert : extractOtp(newValue.text, length: length);
    } else {
      text = newValue.text.replaceAll(RegExp(r'\D'), '');
    }
    final capped = text.length > length ? text.substring(0, length) : text;
    return TextEditingValue(text: capped, selection: TextSelection.collapsed(offset: capped.length));
  }
}

/// Six animated OTP boxes backed by one invisible text field.
///
/// One field (rather than six) keeps the behaviour robust on Android keyboards: typing auto-advances
/// the highlight, backspace walks back, SMS autofill (`oneTimeCode`) works, and pasting any text
/// ("Your code is 123456") keeps just the code. Long-press shows the system Paste menu.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });
  final int length;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  /// Turns the boxes red and shakes them once each time it flips to true.
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> with SingleTickerProviderStateMixin {
  TextEditingController? _own;
  TextEditingController get _c => widget.controller ?? (_own ??= TextEditingController());
  final _focus = FocusNode();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  String _last = '';

  @override
  void initState() {
    super.initState();
    _c.addListener(_onText);
    _focus.addListener(() => setState(() {}));
    _last = _c.text;
  }

  @override
  void didUpdateWidget(covariant OtpInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_onText);
      _c.addListener(_onText);
    }
    if (widget.hasError && !old.hasError) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  void _onText() {
    final t = _c.text;
    if (t == _last) return;
    _last = t;
    setState(() {});
    widget.onChanged?.call(t);
    if (t.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(t);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onText);
    _own?.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _c.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) {
        final t = _shake.value;
        return Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * 10 * (1 - t), 0), child: child);
      },
      child: SizedBox(
        height: 60,
        child: Stack(children: [
          // The real input. Transparent, but it receives taps, long-press (paste) and autofill.
          Positioned.fill(
            child: TextField(
              key: const ValueKey('otp-field'),
              controller: _c,
              focusNode: _focus,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [_OtpFormatter(widget.length)],
              showCursor: false,
              enableSuggestions: false,
              autocorrect: false,
              expands: true,
              maxLines: null,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                counterText: '',
              ),
            ),
          ),
          IgnorePointer(
            child: Row(children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) SizedBox(width: i == widget.length ~/ 2 ? 14 : 8),
                Expanded(
                  child: OtpCell(
                    digit: i < text.length ? text[i] : '',
                    // The highlight walks along as digits arrive; nothing is highlighted once complete.
                    active: _focus.hasFocus && widget.enabled && i == text.length,
                    error: widget.hasError,
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One OTP box. Public so tests can read its state.
class OtpCell extends StatelessWidget {
  const OtpCell({super.key, required this.digit, required this.active, required this.error});
  final String digit;
  final bool active, error;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    final border = error ? G4MColors.danger : (active ? G4MColors.primary : (filled ? G4MColors.primary.withValues(alpha: .45) : context.line));
    return AnimatedScale(
      scale: active ? 1.06 : 1,
      duration: G4MMotion.standard,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: G4MMotion.standard,
        curve: G4MMotion.curve,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: error ? G4MColors.danger.withValues(alpha: .06) : (filled ? context.softPrimary : context.card),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: active || error ? 2 : 1.2),
          boxShadow: active ? const [BoxShadow(color: Color(0x290B8A4F), blurRadius: 14, offset: Offset(0, 4))] : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: .4, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: filled
              ? Text(digit, key: ValueKey('d$digit'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.ink))
              : active
                  ? Container(key: const ValueKey('cursor'), width: 2, height: 24, color: G4MColors.primary)
                  : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}
