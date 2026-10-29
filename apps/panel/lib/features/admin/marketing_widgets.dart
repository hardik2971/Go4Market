import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../../core/doc.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

/// Resolves a single field of another document (cached per path+field).
class LookupText extends StatelessWidget {
  const LookupText(this.ref, this.field, {super.key, this.sub, this.suffix = ''});
  final DocumentReference<Json> ref;
  final String field;
  final String? sub;
  final String suffix;

  static final _cache = <String, Future<Doc?>>{};

  static Future<Doc?> fetch(DocumentReference<Json> ref) => _cache.putIfAbsent(ref.path, () async {
        try {
          final d = await ref.get();
          return d.exists ? Doc.fromSnap(d) : null;
        } catch (_) {
          return null;
        }
      });

  @override
  Widget build(BuildContext context) {
    if (ref.id.isEmpty) return Text(tr('—'));
    return FutureBuilder<Doc?>(
      future: fetch(ref),
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) return const Shimmer(width: 110, height: 12);
        final d = s.data;
        final title = d == null ? ref.id : d.s(field, ref.id);
        return TwoLine('$title$suffix', sub == null ? null : d?.s(sub!));
      },
    );
  }
}

/// Banner / slider visual preview card.
class BannerPreview extends StatelessWidget {
  const BannerPreview({super.key, required this.image, required this.title, this.subtitle = '', this.cta, this.bg = '', this.aspect = 16 / 6, this.footer = const []});
  final String image, title, subtitle, bg;
  final String? cta;
  final double aspect;
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: aspect,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: G4MColors.fromHex(bg, context.pal.surfaceAlt)),
            NetImage(image),
            if (cta != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.black.withValues(alpha: .55), Colors.transparent], begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: G4MColors.accent, borderRadius: BorderRadius.circular(8)),
                      child: Text(cta!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (cta == null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            Wrap(spacing: 6, runSpacing: 6, children: footer),
          ]),
        ),
      ]);
}

/// Featured section card showing the layout style.
class SectionStylePreview extends StatelessWidget {
  const SectionStylePreview({super.key, required this.d, required this.typeLabel});
  final Doc d;
  final String typeLabel;
  @override
  Widget build(BuildContext context) {
    final style = d.s('style', 'carousel');
    final bg = G4MColors.fromHex(d.s('bgColor'), context.pal.surfaceAlt);
    Widget tile() => Container(decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.pal.line)));
    final body = switch (style) {
      'grid' => GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < 8; i++) tile()],
        ),
      'banner_left' => Row(children: [
          Expanded(
            flex: 2,
            child: ClipRRect(borderRadius: BorderRadius.circular(6), child: d.s('bannerImage').isEmpty ? Container(color: G4MColors.accent.withValues(alpha: .3)) : NetImage(d.s('bannerImage'))),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < 3; i++) ...[Expanded(child: tile()), if (i < 2) const SizedBox(width: 6)],
        ]),
      _ => Row(children: [for (var i = 0; i < 5; i++) ...[Expanded(child: tile()), if (i < 4) const SizedBox(width: 6)]]),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 120,
        color: bg,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.s('title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Expanded(child: body),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          Tag(typeLabel, icon: Icons.auto_awesome_rounded, color: context.pal.accent),
          Tag(Fmt.titleCase(style)),
          Tag('#${d.i('order') + 1}'),
          if (!d.b('active', true)) Tag('Hidden', color: G4MColors.danger),
        ]),
      ),
    ]);
  }
}

/// Selected-product list with reorder/remove + picker dialog (manual featured sections).
class ProductPickerField extends StatefulWidget {
  const ProductPickerField({super.key, required this.ids, required this.onChanged});
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  @override
  State<ProductPickerField> createState() => _ProductPickerFieldState();
}

class _ProductPickerFieldState extends State<ProductPickerField> {
  final Map<String, Product> _known = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve(widget.ids);
  }

  Future<void> _resolve(List<String> ids) async {
    final missing = ids.where((i) => !_known.containsKey(i)).toList();
    if (missing.isEmpty) return;
    setState(() => _loading = true);
    try {
      for (final p in await CatalogRepo.instance.productsByIds(missing)) {
        _known[p.id] = p;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    final r = await showDialog<List<Product>>(context: context, builder: (_) => _ProductSearchDialog(selected: widget.ids, known: _known));
    if (r == null) return;
    for (final p in r) {
      _known[p.id] = p;
    }
    widget.onChanged(r.map((p) => p.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.ids;
    return InputDecorator(
      decoration: InputDecoration(labelText: 'Products (${ids.length})', helperText: 'Drag to set the display order'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (ids.isNotEmpty)
          SizedBox(
            height: (ids.length * 52.0).clamp(52, 312),
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: ids.length,
              onReorder: (a, b) {
                final l = List<String>.from(ids);
                if (b > a) b--;
                l.insert(b, l.removeAt(a));
                widget.onChanged(l);
              },
              itemBuilder: (_, i) {
                final p = _known[ids[i]];
                return ListTile(
                  key: ValueKey(ids[i]),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded)),
                  title: Row(children: [
                    RowThumb(p?.image ?? '', size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p?.name ?? ids[i], maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  subtitle: p == null ? null : Text('${Fmt.money(p.price)} · ${p.sellerName}', style: const TextStyle(fontSize: 11.5)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => widget.onChanged(List<String>.from(ids)..removeAt(i)),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.playlist_add_rounded, size: 18), label: Text(ids.isEmpty ? 'Pick products' : 'Add / remove products')),
        ),
      ]),
    );
  }
}

class _ProductSearchDialog extends StatefulWidget {
  const _ProductSearchDialog({required this.selected, required this.known});
  final List<String> selected;
  final Map<String, Product> known;
  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  late final List<String> _sel = List.of(widget.selected);
  final Map<String, Product> _all = {};
  List<Product> _results = const [];
  bool _busy = false;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _all.addAll(widget.known);
    _search('');
  }

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _busy = true);
    try {
      final tokens = q.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 1).take(10).toList();
      final Query<Json> query = tokens.isEmpty
          ? Fs.products.orderBy('createdAt', descending: true).limit(40)
          : Fs.products.where('keywords', arrayContainsAny: tokens).limit(40);
      List<Product> list;
      try {
        list = (await query.get()).docs.map(Product.fromDoc).toList();
      } catch (_) {
        list = (await Fs.products.limit(40).get()).docs.map(Product.fromDoc).toList();
      }
      if (tokens.isNotEmpty) {
        int score(Product p) => tokens.where((t) => p.name.toLowerCase().contains(t)).length;
        list.sort((a, b) => score(b).compareTo(score(a)));
      }
      for (final p in list) {
        _all[p.id] = p;
      }
      if (mounted) setState(() => _results = list);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text(tr('Pick products'))),
          Tag('${_sel.length} selected', color: context.pal.accent),
        ]),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
              onChanged: (v) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 300), () => _search(v));
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty && !_busy
                  ? Center(child: Text('No products found', style: TextStyle(color: context.pal.muted)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final p = _results[i];
                        final on = _sel.contains(p.id);
                        return CheckboxListTile(
                          value: on,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) => setState(() => v! ? _sel.add(p.id) : _sel.remove(p.id)),
                          secondary: RowThumb(p.image, size: 36),
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${Fmt.money(p.price)} · ${p.status} · ${p.sellerName}', maxLines: 1),
                        );
                      },
                    ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, [for (final id in _sel) _all[id] ?? Product(id, const {})]),
            child: Text(tr('Done')),
          ),
        ],
      );
}

/// Monospace coupon code chip with copy.
class CouponCodeChip extends StatelessWidget {
  const CouponCodeChip(this.code, {super.key});
  final String code;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          toast('Copied $code');
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: G4MColors.accent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: G4MColors.accent.withValues(alpha: .5)),
          ),
          child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: G4MColors.accent, letterSpacing: 1)),
        ),
      );
}

class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.used, required this.limit});
  final int used, limit;
  @override
  Widget build(BuildContext context) {
    final pct = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final c = pct >= 1 ? G4MColors.danger : pct > .8 ? G4MColors.warning : context.pal.accent;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('$used / ${limit <= 0 ? '∞' : limit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: limit <= 0 ? null : pct, minHeight: 5, color: c, backgroundColor: context.pal.surfaceAlt),
      ),
    ]);
  }
}

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.d, required this.label, required this.validity});
  final Doc d;
  final String label;
  final String validity;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(gradient: G4MColors.accentGradient),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(d.s('message'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .9))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CouponCodeChip(d.id),
              const Spacer(),
              Tag(Fmt.titleCase(validity), color: validity == 'live' ? G4MColors.success : G4MColors.warning),
            ]),
            const SizedBox(height: 10),
            UsageBar(used: d.i('usedCount'), limit: d.i('usageLimit')),
            const SizedBox(height: 8),
            Text('Min order ${d.n('minOrder') > 0 ? Fmt.money(d.n('minOrder')) : '—'} · expires ${Fmt.date(d.dt('endAt'))}',
                style: TextStyle(color: context.pal.muted, fontSize: 12)),
          ]),
        ),
      ]);
}

/// Phone-style push notification preview.
class PushPreview extends StatelessWidget {
  const PushPreview({super.key, required this.title, required this.body, this.image = '', this.footer = const []});
  final String title, body, image;
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1F2937), Color(0xFF0B1410)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                G4MLogo(size: 16),
                SizedBox(width: 6),
                Text('Go4Market · now', style: TextStyle(fontSize: 11, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text(title.isEmpty ? 'Notification title' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.ink)),
              Text(body.isEmpty ? 'Message' : body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: G4MColors.ink)),
              if (image.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 2, child: NetImage(image))),
              ],
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 6, runSpacing: 6, children: footer)),
      ]);
}

class PlanCard extends StatelessWidget {
  const PlanCard(this.d, {super.key});
  final Doc d;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            if (!d.b('active', true)) Tag('Inactive', color: G4MColors.danger),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.money(d.n('price')), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.8)),
            Text(' / ${d.i('durationDays')} days', style: TextStyle(color: context.pal.muted)),
            if (d.n('mrp') > d.n('price')) ...[
              const SizedBox(width: 8),
              Text(Fmt.money(d.n('mrp')), style: TextStyle(color: context.pal.muted, decoration: TextDecoration.lineThrough)),
            ],
          ]),
          const SizedBox(height: 12),
          for (final b in [
            if (d.b('freeDelivery')) 'Free delivery',
            if (d.n('discountPct') > 0) '${d.n('discountPct').toStringAsFixed(0)}% extra off',
            ...d.list('benefits'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: G4MColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
              ]),
            ),
        ]),
      );
}
