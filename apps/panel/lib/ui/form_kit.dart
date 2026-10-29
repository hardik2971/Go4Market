import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../core/doc.dart';
import 'image_upload.dart';
import 'kit.dart';
import 'package:panel/l10n/overrides.dart';

enum FT {
  text,
  multiline,
  email,
  password,
  number,
  integer,
  money,
  percent,
  toggle,
  select,
  multiselect,
  image,
  images,
  date,
  datetime,
  color,
  tags,
  markdown,
  keyValue,
  section,
  custom,
}

/// Declarative form field. [key] may be a dotted path (`seo.title`).
class F {
  const F(
    this.key,
    this.label,
    this.type, {
    this.required = false,
    this.hint,
    this.help,
    this.options,
    this.optionsStream,
    this.initial,
    this.wide = false,
    this.folder = 'uploads',
    this.validator,
    this.visibleIf,
    this.readOnly = false,
    this.min,
    this.max,
    this.builder,
    this.aspect = 1,
    this.uppercase = false,
  });

  const F.section(String title, {String? help})
      : this('', title, FT.section, help: help, wide: true);

  final String key;
  final String label;
  final FT type;
  final bool required;
  final String? hint;
  final String? help;
  final Map<String, String>? options;
  final Stream<Map<String, String>> Function()? optionsStream;
  final dynamic initial;
  final bool wide;
  final String folder;
  final String? Function(dynamic value, Map<String, dynamic> values)? validator;
  final bool Function(Map<String, dynamic> values)? visibleIf;
  final bool readOnly;
  final num? min;
  final num? max;
  final double aspect;
  final bool uppercase;

  /// For [FT.custom]: (context, value, onChanged, values).
  final Widget Function(BuildContext context, dynamic value, ValueChanged<dynamic> onChanged, Map<String, dynamic> values)? builder;
}

/// Controller-free, map-backed form. Values are read/written by dotted keys.
class EntityForm extends StatefulWidget {
  const EntityForm({super.key, required this.fields, required this.values, this.columns = 2, this.onChanged});
  final List<F> fields;
  final Map<String, dynamic> values;
  final int columns;
  final VoidCallback? onChanged;
  @override
  State<EntityForm> createState() => EntityFormState();
}

class EntityFormState extends State<EntityForm> {
  final _key = GlobalKey<FormState>();

  bool validate() => _key.currentState?.validate() ?? true;

  void _set(String k, dynamic v) {
    setState(() => setPath(widget.values, k, v));
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vals = widget.values;
    return Form(
      key: _key,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth < 520 ? 1 : widget.columns;
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final f in widget.fields)
            if (f.visibleIf?.call(vals) ?? true)
              SizedBox(
                width: f.wide || f.type == FT.section || _isWide(f.type) ? c.maxWidth : w,
                child: _field(context, f),
              ),
        ]);
      }),
    );
  }

  String? _h(F f) => f.help == null ? null : tr(f.help!);

  bool _isWide(FT t) => const {FT.multiline, FT.images, FT.markdown, FT.keyValue, FT.tags, FT.multiselect}.contains(t);

  String? _req(F f, dynamic v) {
    if (f.required && (v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty))) {
      return trf('{field} is required', {'field': tr(f.label)});
    }
    return f.validator?.call(v, widget.values);
  }

  Widget _field(BuildContext context, F f) {
    final v = getPath(widget.values, f.key);
    final label = f.required ? '${tr(f.label)} *' : tr(f.label);
    switch (f.type) {
      case FT.section:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(f.label), style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: context.pal.accent)),
            if (f.help != null) Text(_h(f)!, style: TextStyle(fontSize: 12, color: context.pal.muted)),
            const SizedBox(height: 6),
            Divider(color: context.pal.line),
          ]),
        );
      case FT.text:
      case FT.email:
      case FT.password:
      case FT.multiline:
        return TextFormField(
          key: ValueKey('${f.key}_${identityHashCode(widget.values)}'),
          initialValue: v == null ? '' : '$v',
          readOnly: f.readOnly,
          obscureText: f.type == FT.password,
          minLines: f.type == FT.multiline ? 3 : 1,
          maxLines: f.type == FT.multiline ? 8 : 1,
          inputFormatters: f.uppercase ? [_UpperCase()] : null,
          keyboardType: f.type == FT.email ? TextInputType.emailAddress : null,
          decoration: InputDecoration(labelText: label, hintText: f.hint, helperText: _h(f), helperMaxLines: 3),
          validator: (x) {
            final r = _req(f, x);
            if (r != null) return r;
            if (f.type == FT.email && x != null && x.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(x)) {
              return 'Enter a valid email';
            }
            return null;
          },
          onChanged: (x) => _set(f.key, f.uppercase ? x.toUpperCase() : x),
        );
      case FT.number:
      case FT.integer:
      case FT.money:
      case FT.percent:
        return TextFormField(
          key: ValueKey('${f.key}_${identityHashCode(widget.values)}'),
          initialValue: v == null ? '' : _numStr(v),
          readOnly: f.readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(f.type == FT.integer ? r'[0-9-]' : r'[0-9.-]'))],
          decoration: InputDecoration(
            labelText: label,
            hintText: f.hint,
            helperText: _h(f),
            prefixText: f.type == FT.money ? '₹ ' : null,
            suffixText: f.type == FT.percent ? '%' : null,
          ),
          validator: (x) {
            if ((x == null || x.isEmpty)) return _req(f, null);
            final n = num.tryParse(x);
            if (n == null) return 'Enter a number';
            if (f.min != null && n < f.min!) return 'Min ${f.min}';
            if (f.max != null && n > f.max!) return 'Max ${f.max}';
            return f.validator?.call(n, widget.values);
          },
          onChanged: (x) => _set(f.key, x.isEmpty ? null : (f.type == FT.integer ? int.tryParse(x) : num.tryParse(x))),
        );
      case FT.toggle:
        return _box(
          context,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            dense: true,
            title: Text(tr(f.label), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: f.help == null ? null : Text(_h(f)!, style: TextStyle(fontSize: 12, color: context.pal.muted)),
            value: v == true,
            onChanged: f.readOnly ? null : (x) => _set(f.key, x),
          ),
        );
      case FT.select:
        return _withOptions(f, (opts) {
          final value = v == null ? null : '$v';
          final items = {...opts};
          if (value != null && value.isNotEmpty && !items.containsKey(value)) items[value] = value;
          return DropdownButtonFormField<String>(
            key: ValueKey('${f.key}_${items.length}_${identityHashCode(widget.values)}'),
            initialValue: value == null || value.isEmpty ? null : value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, helperText: _h(f)),
            items: [
              if (!f.required) DropdownMenuItem<String>(value: '', child: Text(tr('— None —'))),
              for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(tr(e.value), overflow: TextOverflow.ellipsis)),
            ],
            validator: (x) => _req(f, x),
            onChanged: f.readOnly ? null : (x) => _set(f.key, x == '' ? null : x),
          );
        });
      case FT.multiselect:
        return _withOptions(f, (opts) {
          final sel = v is List ? v.map((e) => '$e').toSet() : <String>{};
          return FormField<List<String>>(
            initialValue: sel.toList(),
            validator: (_) => _req(f, getPath(widget.values, f.key)),
            builder: (st) => InputDecorator(
              decoration: InputDecoration(labelText: label, helperText: _h(f), errorText: st.errorText),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in opts.entries)
                  FilterChip(
                    label: Text(tr(e.value)),
                    selected: sel.contains(e.key),
                    onSelected: (on) {
                      final n = {...sel};
                      on ? n.add(e.key) : n.remove(e.key);
                      _set(f.key, n.toList());
                    },
                  ),
                if (opts.isEmpty) Text(tr('No options'), style: TextStyle(color: context.pal.muted)),
              ]),
            ),
          );
        });
      case FT.image:
      case FT.images:
        final urls = f.type == FT.images
            ? (v is List ? v.map((e) => '$e').toList() : <String>[])
            : (v == null || '$v'.isEmpty ? <String>[] : ['$v']);
        return FormField<int>(
          validator: (_) => _req(f, getPath(widget.values, f.key)),
          builder: (st) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ImageField(
              label: label,
              urls: urls,
              folder: f.folder,
              multiple: f.type == FT.images,
              aspect: f.aspect,
              help: _h(f),
              onChanged: (l) => _set(f.key, f.type == FT.images ? l : (l.isEmpty ? '' : l.first)),
            ),
            if (st.hasError) Padding(padding: const EdgeInsets.only(top: 4), child: Text(st.errorText!, style: const TextStyle(color: G4MColors.danger, fontSize: 12))),
          ]),
        );
      case FT.date:
      case FT.datetime:
        final d = toDate(v);
        return FormField<DateTime>(
          validator: (_) => _req(f, getPath(widget.values, f.key)),
          builder: (st) => InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: f.readOnly
                ? null
                : () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: d ?? now,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 10),
                    );
                    if (picked == null || !context.mounted) return;
                    var out = picked;
                    if (f.type == FT.datetime) {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(d ?? now));
                      if (t != null) out = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
                    }
                    _set(f.key, Timestamp.fromDate(out));
                  },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                helperText: _h(f),
                errorText: st.errorText,
                suffixIcon: d == null
                    ? const Icon(Icons.event_rounded, size: 18)
                    : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => _set(f.key, null)),
              ),
              child: Text(d == null ? 'Not set' : (f.type == FT.datetime ? Fmt.dateTime(d) : Fmt.date(d)),
                  style: TextStyle(color: d == null ? context.pal.muted : null)),
            ),
          ),
        );
      case FT.color:
        return ColorField(label: label, value: v == null ? '' : '$v', onChanged: (x) => _set(f.key, x));
      case FT.tags:
        return TagsField(
          label: label,
          help: _h(f),
          values: v is List ? v.map((e) => '$e').toList() : const [],
          onChanged: (l) => _set(f.key, l),
        );
      case FT.markdown:
        return MarkdownField(label: label, value: v == null ? '' : '$v', onChanged: (x) => _set(f.key, x), help: f.help);
      case FT.keyValue:
        return KeyValueField(
          label: label,
          help: _h(f),
          value: v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
          onChanged: (m) => _set(f.key, m),
        );
      case FT.custom:
        return f.builder!(context, v, (x) => _set(f.key, x), widget.values);
    }
  }

  Widget _box(BuildContext context, {required Widget child}) => Container(
        decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(10)),
        child: child,
      );

  Widget _withOptions(F f, Widget Function(Map<String, String>) build) {
    if (f.optionsStream == null) return build(f.options ?? const {});
    return _OptionsLoader(stream: f.optionsStream!, builder: build);
  }

  String _numStr(dynamic v) {
    if (v is num) return v % 1 == 0 ? v.toInt().toString() : v.toString();
    return '$v';
  }
}

class _OptionsLoader extends StatefulWidget {
  const _OptionsLoader({required this.stream, required this.builder});
  final Stream<Map<String, String>> Function() stream;
  final Widget Function(Map<String, String>) builder;
  @override
  State<_OptionsLoader> createState() => _OptionsLoaderState();
}

class _OptionsLoaderState extends State<_OptionsLoader> {
  late final Stream<Map<String, String>> _s = widget.stream();
  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, String>>(
        stream: _s,
        builder: (context, snap) => widget.builder(snap.data ?? const {}),
      );
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) => n.copyWith(text: n.text.toUpperCase());
}

/// Hex colour input with presets and live swatch.
class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  static const presets = ['#0B8A4F', '#0A4A33', '#F7860F', '#2563EB', '#7C3AED', '#DB2777', '#DC2626', '#0891B2', '#65A30D', '#111827', '#FFF3E3', '#E8F6EE'];
  @override
  Widget build(BuildContext context) {
    final c = G4MColors.fromHex(value, Colors.transparent);
    return TextFormField(
      key: ValueKey('color_$label$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: '#0B8A4F',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.pal.line)),
          ),
        ),
        suffixIcon: PopupMenuButton<String>(
          tooltip: 'Presets',
          icon: const Icon(Icons.palette_outlined, size: 18),
          onSelected: onChanged,
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in presets)
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(p);
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: G4MColors.fromHex(p),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
      validator: (x) => x == null || x.isEmpty || RegExp(r'^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(x) ? null : 'Use #RRGGBB',
      onChanged: (x) {
        if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(x)) onChanged(x.startsWith('#') ? x.toUpperCase() : '#${x.toUpperCase()}');
        if (x.isEmpty) onChanged('');
      },
    );
  }
}

/// Chips input: type and press Enter / comma.
class TagsField extends StatefulWidget {
  const TagsField({super.key, required this.label, required this.values, required this.onChanged, this.help});
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String? help;
  @override
  State<TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends State<TagsField> {
  final _c = TextEditingController();
  void _add(String raw) {
    final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final l = [...widget.values];
    for (final p in parts) {
      if (!l.contains(p)) l.add(p);
    }
    widget.onChanged(l);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: widget.label, helperText: widget.help ?? 'Press Enter or comma to add'),
        child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final t in widget.values)
            InputChip(
              label: Text(t),
              onDeleted: () => widget.onChanged([...widget.values]..remove(t)),
              visualDensity: VisualDensity.compact,
            ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _c,
              decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, hintText: 'Add…'),
              onSubmitted: _add,
              onChanged: (v) {
                if (v.endsWith(',')) _add(v);
              },
            ),
          ),
        ]),
      );
}

/// Markdown editor with toolbar + live preview tabs.
class MarkdownField extends StatefulWidget {
  const MarkdownField({super.key, required this.label, required this.value, required this.onChanged, this.help, this.minHeight = 280});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? help;
  final double minHeight;
  @override
  State<MarkdownField> createState() => _MarkdownFieldState();
}

class _MarkdownFieldState extends State<MarkdownField> {
  late final _c = TextEditingController(text: widget.value);
  int _mode = 0; // 0 write, 1 split, 2 preview

  void _wrap(String l, [String? r]) {
    final s = _c.selection;
    final t = _c.text;
    final start = s.start < 0 ? t.length : s.start, end = s.end < 0 ? t.length : s.end;
    final sel = t.substring(start, end);
    final ins = '$l$sel${r ?? l}';
    _c.value = TextEditingValue(text: t.replaceRange(start, end, ins), selection: TextSelection.collapsed(offset: start + ins.length));
    widget.onChanged(_c.text);
    setState(() {});
  }

  void _line(String prefix) {
    final s = _c.selection;
    final t = _c.text;
    final pos = s.start < 0 ? t.length : s.start;
    final lineStart = t.lastIndexOf('\n', pos - 1) + 1;
    _c.value = TextEditingValue(text: t.replaceRange(lineStart, lineStart, prefix), selection: TextSelection.collapsed(offset: pos + prefix.length));
    widget.onChanged(_c.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final editor = TextField(
      controller: _c,
      maxLines: null,
      minLines: 12,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.5),
      decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, hintText: 'Write in Markdown…'),
      onChanged: (v) {
        widget.onChanged(v);
        if (_mode == 1) setState(() {});
      },
    );
    final preview = Container(
      color: context.pal.surfaceAlt.withValues(alpha: .4),
      padding: const EdgeInsets.all(14),
      child: MarkdownBody(data: _c.text.isEmpty ? '_Nothing to preview_' : _c.text, selectable: true),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const Spacer(),
        Segmented<int>(value: _mode, options: const {0: 'Write', 1: 'Split', 2: 'Preview'}, onChanged: (m) => setState(() => _mode = m)),
      ]),
      const SizedBox(height: 8),
      Container(
        constraints: BoxConstraints(minHeight: widget.minHeight),
        decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          if (_mode != 2)
            Container(
              color: context.pal.surfaceAlt.withValues(alpha: .6),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                _tb(Icons.format_bold_rounded, 'Bold', () => _wrap('**')),
                _tb(Icons.format_italic_rounded, 'Italic', () => _wrap('_')),
                _tb(Icons.title_rounded, 'Heading', () => _line('## ')),
                _tb(Icons.format_list_bulleted_rounded, 'List', () => _line('- ')),
                _tb(Icons.format_list_numbered_rounded, 'Numbered', () => _line('1. ')),
                _tb(Icons.format_quote_rounded, 'Quote', () => _line('> ')),
                _tb(Icons.link_rounded, 'Link', () => _wrap('[', '](https://)')),
                _tb(Icons.image_outlined, 'Image', () async {
                  final f = await pickFiles();
                  if (f.isEmpty) return;
                  try {
                    final url = await uploadBytes('content', f.first.$1, f.first.$2);
                    _wrap('![${f.first.$1}]($url)', '');
                  } catch (e) {
                    toastError(e);
                  }
                }),
                _tb(Icons.code_rounded, 'Code', () => _wrap('`')),
              ]),
            ),
          if (_mode == 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: editor),
          if (_mode == 2) SizedBox(width: double.infinity, child: preview),
          if (_mode == 1)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: editor)),
                VerticalDivider(width: 1, color: context.pal.line),
                Expanded(child: preview),
              ]),
            ),
        ]),
      ),
      if (widget.help != null) Padding(padding: const EdgeInsetsDirectional.only(top: 4, start: 4), child: Text(widget.help!, style: TextStyle(fontSize: 12, color: context.pal.muted))),
    ]);
  }

  Widget _tb(IconData i, String tip, VoidCallback onTap) =>
      IconButton(tooltip: tip, onPressed: onTap, icon: Icon(i, size: 18), visualDensity: VisualDensity.compact);
}

/// Editable key → value list (custom fields, specs…).
class KeyValueField extends StatefulWidget {
  const KeyValueField({super.key, required this.label, required this.value, required this.onChanged, this.help, this.suggestions = const []});
  final String label;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String? help;
  final List<String> suggestions;
  @override
  State<KeyValueField> createState() => _KeyValueFieldState();
}

class _KeyValueFieldState extends State<KeyValueField> {
  late List<(TextEditingController, TextEditingController)> rows = [
    for (final e in widget.value.entries) (TextEditingController(text: e.key), TextEditingController(text: '${e.value}')),
  ];

  void _emit() {
    final m = <String, dynamic>{};
    for (final r in rows) {
      if (r.$1.text.trim().isNotEmpty) m[r.$1.text.trim()] = r.$2.text.trim();
    }
    widget.onChanged(m);
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: widget.label, helperText: widget.help),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: TextField(controller: rows[i].$1, decoration: const InputDecoration(hintText: 'Field (e.g. Allergens)'), onChanged: (_) => _emit())),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextField(controller: rows[i].$2, decoration: const InputDecoration(hintText: 'Value'), onChanged: (_) => _emit())),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: G4MColors.danger),
                  onPressed: () {
                    setState(() => rows.removeAt(i));
                    _emit();
                  },
                ),
              ]),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => rows.add((TextEditingController(), TextEditingController()))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('Add field')),
            ),
            for (final s in widget.suggestions.where((s) => !rows.any((r) => r.$1.text == s)))
              ActionChip(
                label: Text('+ $s'),
                onPressed: () => setState(() => rows.add((TextEditingController(text: s), TextEditingController()))),
              ),
          ]),
        ]),
      );
}

/// Side-sheet editor with sticky header + save bar. [onSave] receives the edited map.
Future<bool> openEditor(
  BuildContext context, {
  required String title,
  required List<F> fields,
  Map<String, dynamic>? initial,
  required Future<void> Function(Map<String, dynamic> values) onSave,
  String saveLabel = 'Save',
  double width = 620,
  String? subtitle,
  Widget? headerExtra,
}) async {
  final values = initial == null ? <String, dynamic>{} : deepCopy(initial);
  for (final f in fields) {
    if (f.initial != null && getPath(values, f.key) == null) setPath(values, f.key, f.initial);
  }
  final r = await showSideSheet<bool>(
    context,
    width: width,
    builder: (ctx) => _EditorSheet(title: title, subtitle: subtitle, fields: fields, values: values, onSave: onSave, saveLabel: saveLabel, headerExtra: headerExtra),
  );
  return r ?? false;
}

class _EditorSheet extends StatefulWidget {
  const _EditorSheet({required this.title, required this.fields, required this.values, required this.onSave, required this.saveLabel, this.subtitle, this.headerExtra});
  final String title;
  final String? subtitle;
  final List<F> fields;
  final Map<String, dynamic> values;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final String saveLabel;
  final Widget? headerExtra;
  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  final _form = GlobalKey<EntityFormState>();
  bool _saving = false;
  bool _dirty = false;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? true)) {
      toast('Please fix the highlighted fields', kind: ToastKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(widget.values);
      if (mounted) Navigator.pop(context, true);
      toast('Saved');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_dirty && !await confirm(context, 'Discard changes?', confirmLabel: 'Discard', danger: true)) return;
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.escape): _close,
        },
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(widget.title), style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (widget.subtitle != null) Text(widget.subtitle!, style: TextStyle(color: context.pal.muted, fontSize: 13)),
                ]),
              ),
              IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (widget.headerExtra != null) ...[widget.headerExtra!, const SizedBox(height: 16)],
                EntityForm(key: _form, fields: widget.fields, values: widget.values, onChanged: () {
                  if (!_dirty) setState(() => _dirty = true);
                }),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            decoration: BoxDecoration(
              color: context.pal.surface,
              border: Border(top: BorderSide(color: context.pal.line)),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -4))],
            ),
            child: Row(children: [
              if (_dirty) Text(tr('Unsaved changes'), style: TextStyle(color: G4MColors.warning, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const Spacer(),
              OutlinedButton(onPressed: _close, child: Text(S.cancel)),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(tr(widget.saveLabel)),
              ),
            ]),
          ),
        ]),
      );
}

/// Normalises values before writing: trims strings, drops nulls for new docs.
Map<String, dynamic> cleanValues(Map<String, dynamic> m) {
  final out = <String, dynamic>{};
  m.forEach((k, v) {
    if (v is String) {
      out[k] = v.trim();
    } else if (v is Map) {
      out[k] = cleanValues(Map<String, dynamic>.from(v));
    } else {
      out[k] = v;
    }
  });
  return out;
}

/// Firestore options streams used by many forms.
Stream<Map<String, String>> optionsOf(Query<Json> q, String labelField, {String Function(Doc d)? label}) =>
    q.snapshots().map((s) {
      final m = <String, String>{};
      final docs = s.docs.map(Doc.fromSnap).toList()
        ..sort((a, b) => (label?.call(a) ?? a.s(labelField)).toLowerCase().compareTo((label?.call(b) ?? b.s(labelField)).toLowerCase()));
      for (final d in docs) {
        m[d.id] = label?.call(d) ?? d.s(labelField, d.id);
      }
      return m;
    });

const moduleOptions = {'ecommerce': 'eCommerce', 'grocery': 'Grocery', 'pharmacy': 'Pharmacy', 'food': 'Food'};
