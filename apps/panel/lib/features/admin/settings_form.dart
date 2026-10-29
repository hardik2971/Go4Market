import 'dart:async';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:web/web.dart' as web;

import '../../core/doc.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

/// One card on a settings page.
class SettingsSection {
  const SettingsSection(this.title, this.icon, this.fields, {this.subtitle, this.preview, this.extra});
  final String title;
  final IconData icon;
  final List<F> fields;
  final String? subtitle;

  /// Live preview rendered next to (wide) or below (narrow) the fields.
  final Widget Function(BuildContext context, Map<String, dynamic> values)? preview;

  /// Arbitrary widget rendered under the fields (not part of the doc form).
  final Widget? extra;
}

/// Edits a single settings document live with section cards and a sticky save bar.
class SettingsDocPage extends StatefulWidget {
  const SettingsDocPage({
    super.key,
    required this.ref,
    required this.title,
    required this.sections,
    this.subtitle,
    this.banner,
    this.maxWidth = 1100,
  });
  final DocumentReference<Json> ref;
  final String title;
  final String? subtitle;
  final List<SettingsSection> sections;
  final Widget? banner;
  final double maxWidth;
  @override
  State<SettingsDocPage> createState() => _SettingsDocPageState();
}

class _SettingsDocPageState extends State<SettingsDocPage> {
  Map<String, dynamic> _values = {};
  Map<String, dynamic> _remote = {};
  late final List<GlobalKey<EntityFormState>> _keys = [for (final _ in widget.sections) GlobalKey<EntityFormState>()];
  StreamSubscription? _sub;
  bool _loaded = false, _dirty = false, _saving = false;
  Object? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _sub = widget.ref.snapshots().listen((d) {
      _remote = d.data() ?? {};
      _updatedAt = toDate(_remote['updatedAt']);
      if (!_dirty) _values = deepCopy(_remote);
      setState(() => _loaded = true);
    }, onError: (Object e) => setState(() => _error = e));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _discard() => setState(() {
        _values = deepCopy(_remote);
        _dirty = false;
      });

  Future<void> _save() async {
    var ok = true;
    for (final k in _keys) {
      if (!(k.currentState?.validate() ?? true)) ok = false;
    }
    if (!ok) {
      toast('Please fix the highlighted fields', kind: ToastKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final v = cleanValues(_values)
        ..remove('createdAt')
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await widget.ref.set(v, SetOptions(merge: true));
      setState(() => _dirty = false);
      toast('${widget.title} saved');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1200;
    Widget body;
    if (_error != null) {
      body = ErrorBox(_error!);
    } else if (!_loaded) {
      body = const SectionCard(child: LoadingBlock());
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.banner != null) ...[widget.banner!, const SizedBox(height: 16)],
        for (var i = 0; i < widget.sections.length; i++) ...[
          _section(context, i, wide),
          const SizedBox(height: 16),
        ],
      ]);
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: Column(children: [
        Expanded(
          child: PanelPage(
            title: widget.title,
            subtitle: widget.subtitle ?? (_updatedAt == null ? null : 'Last saved ${Fmt.ago(_updatedAt)}'),
            maxWidth: widget.maxWidth,
            child: body,
          ),
        ),
        AnimatedContainer(
          duration: G4MMotion.standard,
          curve: G4MMotion.curve,
          height: _dirty ? 64 : 0,
          child: ClipRect(
            child: OverflowBox(
              maxHeight: 64,
              alignment: Alignment.topCenter,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: context.pal.surface,
                  border: Border(top: BorderSide(color: context.pal.line)),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
                ),
                child: Row(children: [
                  const Icon(Icons.edit_note_rounded, color: G4MColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('You have unsaved changes', style: TextStyle(fontWeight: FontWeight.w700))),
                  OutlinedButton(onPressed: _saving ? null : _discard, child: Text(tr('Discard'))),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(tr('Save changes')),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _section(BuildContext context, int i, bool wide) {
    final s = widget.sections[i];
    final form = s.fields.isEmpty
        ? const SizedBox()
        : EntityForm(
            key: _keys[i],
            fields: s.fields,
            values: _values,
            onChanged: () => setState(() => _dirty = true),
          );
    final preview = s.preview?.call(context, _values);
    return SectionCard(
      title: s.title,
      subtitle: s.subtitle,
      icon: s.icon,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (preview != null && wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: form),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: preview),
          ])
        else ...[
          form,
          if (preview != null) ...[const SizedBox(height: 16), preview],
        ],
        if (s.extra != null) ...[const SizedBox(height: 12), s.extra!],
      ]),
    );
  }
}

/// Editor for a list of `{from, to}` time slots (HH:mm).
class SlotsEditor extends StatefulWidget {
  const SlotsEditor({super.key, required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  @override
  State<SlotsEditor> createState() => _SlotsEditorState();
}

class _SlotsEditorState extends State<SlotsEditor> {
  late final List<Map<String, dynamic>> _slots = [
    if (widget.value is List)
      for (final s in widget.value as List)
        if (s is Map) Map<String, dynamic>.from(s),
  ];

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  TimeOfDay _parse(dynamic s) {
    final p = '${s ?? '09:00'}'.split(':');
    return TimeOfDay(hour: int.tryParse(p.first) ?? 9, minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  void _emit() {
    _slots.sort((a, b) => '${a['from']}'.compareTo('${b['from']}'));
    widget.onChanged([for (final s in _slots) Map<String, dynamic>.from(s)]);
    setState(() {});
  }

  Future<void> _pick(int i, String key) async {
    final t = await showTimePicker(context: context, initialTime: _parse(_slots[i][key]));
    if (t == null) return;
    _slots[i][key] = _fmt(t);
    _emit();
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: const InputDecoration(labelText: 'Delivery time slots', helperText: 'Shown to customers choosing scheduled delivery'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_slots.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('No slots yet', style: TextStyle(color: context.pal.muted))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _slots.length; i++)
              Container(
                padding: const EdgeInsetsDirectional.only(start: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.pal.line)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () => _pick(i, 'from'), child: Text('${_slots[i]['from'] ?? '--:--'}')),
                  Text(tr('–')),
                  TextButton(onPressed: () => _pick(i, 'to'), child: Text('${_slots[i]['to'] ?? '--:--'}')),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _slots.removeAt(i);
                      _emit();
                    },
                  ),
                ]),
              ),
            OutlinedButton.icon(
              onPressed: () {
                final last = _slots.isEmpty ? null : _parse(_slots.last['to']);
                final from = last ?? const TimeOfDay(hour: 9, minute: 0);
                final to = TimeOfDay(hour: (from.hour + 2) % 24, minute: from.minute);
                _slots.add({'from': _fmt(from), 'to': _fmt(to)});
                _emit();
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('Add slot')),
            ),
          ]),
        ]),
      );
}

/// Opens an HTML string in a new browser tab (preview).
void openHtmlPreview(String html) {
  final blob = web.Blob(<JSAny>[html.toJS].toJS, web.BlobPropertyBag(type: 'text/html'));
  web.window.open(web.URL.createObjectURL(blob), '_blank');
}

/// Small info banner.
class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.color = G4MColors.info, this.icon = Icons.info_outline_rounded});
  final String text;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: context.pal.ink, height: 1.45, fontSize: 13.5))),
        ]),
      );
}
