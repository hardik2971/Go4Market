import 'package:panel/l10n/overrides.dart';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import 'kit.dart';

const _imgExt = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'svg', 'avif'};

String mimeFor(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'svg' => 'image/svg+xml',
    'avif' => 'image/avif',
    'csv' => 'text/csv',
    'json' => 'application/json',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}

/// Picks files with the browser dialog. Returns (name, bytes) pairs.
Future<List<(String, Uint8List)>> pickFiles({bool multiple = false, List<String>? extensions}) async {
  final files = await FilePicker.pickFiles(
    type: extensions == null ? FileType.image : FileType.custom,
    allowedExtensions: extensions,
  );
  final out = <(String, Uint8List)>[];
  for (final f in multiple ? files : files.take(1)) {
    out.add((f.name, await f.xFile.readAsBytes()));
  }
  return out;
}

Future<String> uploadBytes(String folder, String name, Uint8List bytes) =>
    StorageRepo.instance.upload(folder, name, bytes, contentType: mimeFor(name));

/// Single or multiple image field with drag-drop, picker, URL paste, reorder and remove.
class ImageField extends StatefulWidget {
  const ImageField({
    super.key,
    required this.urls,
    required this.onChanged,
    required this.folder,
    this.multiple = false,
    this.label,
    this.aspect = 1,
    this.help,
  });
  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final String folder;
  final bool multiple;
  final String? label;
  final double aspect;
  final String? help;

  @override
  State<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<ImageField> {
  bool _drag = false;
  int _uploading = 0;

  Future<void> _upload(List<(String, Uint8List)> files) async {
    final valid = files.where((f) => _imgExt.contains(f.$1.split('.').last.toLowerCase())).toList();
    if (valid.isEmpty) {
      if (files.isNotEmpty) toast('Only image files (JPG, PNG, WebP, GIF, SVG)', kind: ToastKind.error);
      return;
    }
    setState(() => _uploading += valid.length);
    final urls = List<String>.from(widget.urls);
    for (final f in widget.multiple ? valid : valid.take(1)) {
      try {
        if (f.$2.lengthInBytes > 5 * 1024 * 1024) throw 'Max 5 MB per image (${f.$1})';
        final url = await uploadBytes(widget.folder, f.$1, f.$2);
        if (widget.multiple) {
          urls.add(url);
        } else {
          urls
            ..clear()
            ..add(url);
        }
        widget.onChanged(List.of(urls));
      } catch (e) {
        toastError(e);
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  Future<void> _pasteUrl() async {
    final u = await promptText(context, 'Image URL', label: 'https://…', required: true, confirmLabel: 'Add');
    if (u == null || u.isEmpty) return;
    widget.onChanged(widget.multiple ? [...widget.urls, u] : [u]);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final drop = DropTarget(
      onDragEntered: (_) => setState(() => _drag = true),
      onDragExited: (_) => setState(() => _drag = false),
      onDragDone: (d) async {
        setState(() => _drag = false);
        final files = <(String, Uint8List)>[];
        for (final f in d.files) {
          files.add((f.name, await f.readAsBytes()));
        }
        await _upload(files);
      },
      child: AnimatedContainer(
        duration: G4MMotion.fast,
        height: widget.multiple || urls.isEmpty ? 112 : 0,
        decoration: BoxDecoration(
          color: _drag ? context.pal.accent.withValues(alpha: .08) : context.pal.surfaceAlt.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _drag ? context.pal.accent : context.pal.line, width: _drag ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async => _upload(await pickFiles(multiple: widget.multiple)),
          child: Center(
            child: _uploading > 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text('Uploading $_uploading…'),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_upload_outlined, color: context.pal.accent, size: 28),
                    const SizedBox(height: 6),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'Click to upload', style: TextStyle(color: context.pal.accent, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' or drag & drop'),
                    ])),
                    Text(widget.help ?? 'JPG, PNG or WebP · max 5 MB', style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
                  ]),
          ),
        ),
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Text(widget.label!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            TextButton.icon(onPressed: _pasteUrl, icon: const Icon(Icons.link_rounded, size: 16), label: Text(tr('Paste URL'))),
          ]),
        ),
      if (urls.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: widget.multiple
              ? SizedBox(
                  height: 96,
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    onReorder: (a, b) {
                      final l = List<String>.from(urls);
                      if (b > a) b--;
                      l.insert(b, l.removeAt(a));
                      widget.onChanged(l);
                    },
                    children: [
                      for (var i = 0; i < urls.length; i++)
                        ReorderableDragStartListener(
                          key: ValueKey('${urls[i]}$i'),
                          index: i,
                          child: _thumb(context, urls[i], i, first: i == 0),
                        ),
                    ],
                  ),
                )
              : _single(context, urls.first),
        ),
      drop,
    ]);
  }

  Widget _single(BuildContext context, String url) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: widget.aspect,
            child: Container(color: context.pal.surfaceAlt, child: NetImage(url, fit: BoxFit.contain)),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Row(children: [
            _roundBtn(Icons.swap_horiz_rounded, 'Replace', () async => _upload(await pickFiles())),
            const SizedBox(width: 6),
            _roundBtn(Icons.delete_outline_rounded, 'Remove', () => widget.onChanged(const [])),
          ]),
        ),
      ]);

  Widget _thumb(BuildContext context, String url, int i, {bool first = false}) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Stack(children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: first ? context.pal.accent : context.pal.line, width: first ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: NetImage(url, width: 96, height: 96),
          ),
          if (first)
            Positioned(
              left: 4,
              bottom: 4,
              child: Tag('Cover', color: context.pal.accent),
            ),
          Positioned(
            right: 4,
            top: 4,
            child: _roundBtn(Icons.close_rounded, 'Remove', () {
              final l = List<String>.from(widget.urls)..removeAt(i);
              widget.onChanged(l);
            }, small: true),
          ),
        ]),
      );

  Widget _roundBtn(IconData icon, String tip, VoidCallback onTap, {bool small = false}) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.black.withValues(alpha: .55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: EdgeInsets.all(small ? 3 : 6), child: Icon(icon, size: small ? 14 : 18, color: Colors.white)),
          ),
        ),
      );
}
