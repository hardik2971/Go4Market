import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/l10n.dart';
import 'kit.dart';

/// Listening dialog for voice search (loaded on demand).
class VoiceDialog extends StatefulWidget {
  const VoiceDialog({super.key});
  @override
  State<VoiceDialog> createState() => VoiceDialogState();
}

class VoiceDialogState extends State<VoiceDialog> with SingleTickerProviderStateMixin {
  static final _stt = SpeechToText();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  String _text = '';
  String? _error;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final ok = await _stt.initialize(
        onError: (e) => mounted ? setState(() => _error = L.current.content.voiceNotHeard) : null,
        onStatus: (s) {
          if (!mounted) return;
          setState(() => _listening = s == 'listening');
          if ((s == 'done' || s == 'notListening') && _text.isNotEmpty) Navigator.of(context).maybePop(_text);
        },
      );
      if (!ok) {
        setState(() => _error = L.current.content.voiceUnsupported);
        return;
      }
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          if (!mounted) return;
          setState(() => _text = r.recognizedWords);
          if (r.finalResult && _text.isNotEmpty) Navigator.of(context).maybePop(_text);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.search,
          cancelOnError: true,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          localeId: L.current.content.speechLocale,
        ),
      );
      if (mounted) setState(() => _listening = true);
    } catch (e) {
      if (mounted) setState(() => _error = L.current.content.micPermission);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => CustomPaint(
                    painter: _PulsePainter(_listening && !context.reduceMotion ? _pulse.value : 0),
                    child: Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(gradient: G4MColors.heroGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 34),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(_error ?? (_text.isEmpty ? context.l.content.listening : '"$_text"'),
                  textAlign: TextAlign.center, style: context.tt.titleLarge?.copyWith(color: _error != null ? G4MColors.danger : G4MColors.ink)),
              const SizedBox(height: 8),
              Text(context.l.content.voiceHint, textAlign: TextAlign.center, style: const TextStyle(color: G4MColors.inkMuted)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l.common.cancel)),
                if (_text.isNotEmpty) ...[const SizedBox(width: 8), FilledButton(onPressed: () => Navigator.pop(context, _text), child: Text(context.l.content.search))],
              ]),
            ]),
          ),
        ),
      );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(c, 36 + p * 34, Paint()..color = G4MColors.primary.withValues(alpha: (1 - p) * .22));
    }
  }

  @override
  bool shouldRepaint(_PulsePainter o) => o.t != t;
}
