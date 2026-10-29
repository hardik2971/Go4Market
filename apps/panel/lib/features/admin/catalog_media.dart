import 'package:desktop_drop/desktop_drop.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide EmptyState;

import '../../ui/image_upload.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

class _Item {
  _Item(this.ref);
  final Reference ref;
  String? url;
  FullMetadata? meta;
}

/// Firebase Storage browser: folders, previews, copy URL, delete, drag-drop upload.
class MediaPage extends StatefulWidget {
  const MediaPage({super.key});
  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  static const _roots = ['uploads', 'products', 'categories', 'brands', 'banners', 'content', 'blogs', 'sellers'];
  String _path = 'uploads';
  List<Reference> _folders = [];
  List<_Item> _items = [];
  String? _pageToken;
  bool _loading = false;
  Object? _error;
  final _selected = <String>{};
  bool _drag = false;
  int _uploading = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items = [];
        _folders = [];
        _pageToken = null;
        _selected.clear();
      }
    });
    try {
      final r = await FirebaseStorage.instance.ref(_path).list(ListOptions(maxResults: 60, pageToken: more ? _pageToken : null));
      final items = r.items.map(_Item.new).toList();
      setState(() {
        if (!more) _folders = r.prefixes;
        _items.addAll(items);
        _pageToken = r.nextPageToken;
      });
      await Future.wait(items.map((i) async {
        try {
          final res = await Future.wait([i.ref.getDownloadURL(), i.ref.getMetadata()]);
          i.url = res[0] as String;
          i.meta = res[1] as FullMetadata;
        } catch (_) {}
      }));
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String p) {
    _path = p;
    _load();
  }

  Future<void> _upload(List<(String, Uint8List)> files) async {
    if (files.isEmpty) return;
    setState(() => _uploading += files.length);
    var ok = 0;
    for (final f in files) {
      try {
        await uploadBytes(_path, f.$1, f.$2);
        ok++;
      } catch (e) {
        toastError(e);
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
    if (ok > 0) toast('Uploaded $ok file(s)');
    await _load();
  }

  Future<void> _deleteSelected() async {
    final targets = _items.where((i) => _selected.contains(i.ref.fullPath)).toList();
    if (targets.isEmpty) return;
    if (!await confirm(context, 'Delete ${targets.length} file(s)?', message: 'Pages still using these URLs will show a broken image.', danger: true, confirmLabel: 'Delete')) return;
    await runToast(() async {
      await Future.wait(targets.map((t) => t.ref.delete()));
    }, success: 'Deleted ${targets.length} file(s)');
    await _load();
  }

  String _size(int? b) {
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final segs = _path.split('/');
    return PanelPage(
      title: 'Media library',
      subtitle: 'Images stored in Firebase Storage · WebP, PNG, JPG, SVG',
      actions: [
        if (_selected.isNotEmpty)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger),
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text('Delete ${_selected.length}'),
          ),
        OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Refresh'))),
        FilledButton.icon(
          onPressed: () async => _upload(await pickFiles(multiple: true)),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(tr('Upload')),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final r in _roots)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(label: Text(r), selected: segs.first == r, onSelected: (_) => _open(r)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.folder_open_rounded, size: 18, color: context.pal.muted),
          for (var i = 0; i < segs.length; i++) ...[
            TextButton(onPressed: i == segs.length - 1 ? null : () => _open(segs.sublist(0, i + 1).join('/')), child: Text(segs[i])),
            if (i < segs.length - 1) Icon(Icons.chevron_right_rounded, size: 16, color: context.pal.faint),
          ],
        ]),
        const SizedBox(height: 8),
        DropTarget(
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _drag ? context.pal.accent.withValues(alpha: .06) : context.pal.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _drag ? context.pal.accent : context.pal.line, width: _drag ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.cloud_upload_outlined, color: context.pal.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_uploading > 0 ? 'Uploading $_uploading file(s)…' : 'Drop images anywhere here to upload into /$_path',
                      style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w600)),
                ),
                if (_uploading > 0) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 16),
              if (_error != null)
                ErrorBox(_error!, onRetry: _load)
              else if (_loading && _items.isEmpty && _folders.isEmpty)
                const LoadingBlock(rows: 4)
              else if (_items.isEmpty && _folders.isEmpty)
                const EmptyState(icon: Icons.perm_media_outlined, title: 'This folder is empty', message: 'Upload images or drag them in.')
              else
                ResponsiveGrid(minItemWidth: 170, spacing: 12, children: [
                  for (final f in _folders) _folderTile(context, f),
                  for (var i = 0; i < _items.length; i++) _fileTile(context, _items[i]).animate(delay: (i < 24 ? i * 15 : 0).ms).fadeIn(duration: 200.ms),
                ]),
              if (_pageToken != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(child: TextButton.icon(onPressed: () => _load(more: true), icon: const Icon(Icons.expand_more_rounded), label: Text(tr('Load more')))),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _folderTile(BuildContext context, Reference f) => Pressable(
        onTap: () => _open(f.fullPath),
        child: Container(
          height: 170,
          decoration: BoxDecoration(color: context.pal.surfaceAlt.withValues(alpha: .6), borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.line)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.folder_rounded, size: 52, color: context.pal.accent),
            const SizedBox(height: 8),
            Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _fileTile(BuildContext context, _Item it) {
    final sel = _selected.contains(it.ref.fullPath);
    final isImg = (it.meta?.contentType ?? 'image/').startsWith('image/');
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? context.pal.accent : context.pal.line, width: sel ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: Container(
              color: context.pal.surfaceAlt,
              child: it.url == null
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : isImg
                      ? NetImage(it.url!, fit: BoxFit.contain)
                      : Icon(Icons.insert_drive_file_outlined, size: 40, color: context.pal.faint),
            ),
          ),
          Positioned(
            left: 4,
            top: 4,
            child: Checkbox(value: sel, onChanged: (v) => setState(() => v! ? _selected.add(it.ref.fullPath) : _selected.remove(it.ref.fullPath))),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.ref.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text([_size(it.meta?.size), it.meta?.contentType?.split('/').last.toUpperCase() ?? ''].where((e) => e.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 11, color: context.pal.muted)),
              ]),
            ),
            IconButton(
              tooltip: 'Copy URL',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.link_rounded, size: 18),
              onPressed: it.url == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: it.url!));
                      toast('URL copied');
                    },
            ),
          ]),
        ),
      ]),
    );
  }
}
