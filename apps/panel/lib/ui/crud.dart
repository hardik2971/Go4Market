import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../core/doc.dart';
import '../core/live.dart';
import 'data_view.dart';
import 'form_kit.dart';
import 'kit.dart';
import 'package:panel/l10n/overrides.dart';

/// Configuration for a generic Firestore collection manager page.
class Crud {
  const Crud({
    required this.id,
    required this.title,
    required this.singular,
    required this.collection,
    required this.columns,
    required this.fields,
    this.subtitle,
    this.query,
    this.search,
    this.card,
    this.leading,
    this.filters = const [],
    this.extraActions = const [],
    this.headerActions = const [],
    this.bulkActions = const [],
    this.idFrom,
    this.activeField = 'active',
    this.orderField,
    this.defaults = const {},
    this.beforeSave,
    this.afterSave,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.top,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyMessage,
    this.editorWidth = 620,
    this.labelOf,
    this.onTap,
    this.sortField = 'createdAt',
    this.sortDesc = true,
  });

  final String id;
  final String title;
  final String singular;
  final String? subtitle;
  final CollectionReference<Json> collection;

  /// Custom query; default is the whole collection ordered by [orderField] or createdAt.
  final Query<Json> Function()? query;
  final List<Col<Doc>> columns;
  final List<F> fields;
  final String Function(Doc d)? search;
  final Widget Function(BuildContext context, Doc d)? card;
  final Widget Function(BuildContext context, Doc d)? leading;
  final List<TableFilter<Doc>> filters;
  final List<RowAction<Doc>> extraActions;
  final List<Widget> headerActions;
  final List<BulkAction<Doc>> bulkActions;

  /// Derive the doc id from the form values (coupons → CODE, languages → code, pages → slug).
  final String Function(Map<String, dynamic> values)? idFrom;
  final String? activeField;
  final String? orderField;
  final Map<String, dynamic> defaults;
  final FutureOr<Map<String, dynamic>> Function(Map<String, dynamic> values, Doc? existing)? beforeSave;
  final FutureOr<void> Function(String id, Map<String, dynamic> values, Doc? existing)? afterSave;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final Widget? top;
  final IconData emptyIcon;
  final String? emptyMessage;
  final double editorWidth;
  final String Function(Doc d)? labelOf;
  final void Function(BuildContext context, Doc d)? onTap;
  final String sortField;
  final bool sortDesc;
}

class CrudPage extends StatelessWidget {
  const CrudPage(this.c, {super.key});
  final Crud c;

  Query<Json> _query() {
    if (c.query != null) return c.query!();
    if (c.orderField != null) return c.collection.orderBy(c.orderField!);
    return c.collection;
  }

  Future<void> edit(BuildContext context, [Doc? d]) => openCrudEditor(context, c, d);

  @override
  Widget build(BuildContext context) {
    final actions = <RowAction<Doc>>[
      if (c.canEdit) RowAction('Edit', Icons.edit_outlined, (d) => edit(context, d)),
      if (c.activeField != null)
        RowAction('Toggle ${Fmt.titleCase(c.activeField!)}', Icons.toggle_on_outlined,
            (d) => runToast(() => d.ref!.update({c.activeField!: !d.b(c.activeField!, true), 'updatedAt': FieldValue.serverTimestamp()}),
                success: 'Updated')),
      RowAction('Duplicate', Icons.copy_all_outlined, (d) async {
        if (c.idFrom != null) {
          await openCrudEditor(context, c, null, initial: d.data);
        } else {
          await runToast(() => c.collection.add({...d.data, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}),
              success: 'Duplicated');
        }
      }, visible: (_) => c.canCreate),
      ...c.extraActions,
      if (c.canDelete)
        RowAction('Delete', Icons.delete_outline_rounded, (d) async {
          if (await confirm(context, 'Delete "${c.labelOf?.call(d) ?? d.id}"?', message: tr('This cannot be undone.'), danger: true, confirmLabel: 'Delete')) {
            await runToast(() => d.ref!.delete(), success: trf('{x} deleted', {'x': tr(c.singular)}));
          }
        }, danger: true),
    ];
    final cols = [
      ...c.columns,
      if (c.activeField != null)
        Col<Doc>('Status',
            flex: 1,
            text: (d) => d.b(c.activeField!, true) ? 'Active' : 'Inactive',
            cell: (ctx, d) => _ActiveSwitch(doc: d, field: c.activeField!)),
    ];
    return PanelPage(
      title: c.title,
      subtitle: c.subtitle,
      actions: [
        ...c.headerActions,
        if (c.orderField != null)
          OutlinedButton.icon(
            onPressed: () => showReorderDialog(context, query: _query(), orderField: c.orderField!, labelOf: c.labelOf ?? (d) => d.s('name', d.s('title', d.id))),
            icon: const Icon(Icons.drag_indicator_rounded, size: 18),
            label: Text(tr('Reorder')),
          ),
        if (c.canCreate)
          FilledButton.icon(onPressed: () => edit(context), icon: const Icon(Icons.add_rounded, size: 18), label: Text(trf('Add {x}', {'x': lowerUi(tr(c.singular))}))),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (c.top != null) ...[c.top!, const SizedBox(height: 16)],
        DataView<Doc>(
          id: c.id,
          source: (q) => liveDocs(_query().limit(q.limit),
              fallback: c.collection.limit(q.limit), sortField: c.orderField ?? c.sortField, desc: c.orderField == null && c.sortDesc, label: c.id),
          columns: cols,
          rowId: (d) => d.id,
          searchText: c.search ?? (d) => d.data.values.whereType<String>().join(' '),
          filters: c.filters,
          actions: actions,
          bulkActions: [
            ...c.bulkActions,
            if (c.activeField != null) ...[
              BulkAction('Activate', Icons.visibility_outlined, (rows) => _batch(rows, (b, d) => b.update(d.ref!, {c.activeField!: true}))),
              BulkAction('Deactivate', Icons.visibility_off_outlined, (rows) => _batch(rows, (b, d) => b.update(d.ref!, {c.activeField!: false}))),
            ],
            if (c.canDelete) BulkAction('Delete', Icons.delete_outline_rounded, (rows) => _batch(rows, (b, d) => b.delete(d.ref!)), danger: true),
          ],
          card: c.card,
          leading: c.leading,
          onTap: c.onTap != null ? (d) => c.onTap!(context, d) : c.canEdit ? (d) => edit(context, d) : null,
          emptyIcon: c.emptyIcon,
          emptyTitle: trf('No {x} yet', {'x': lowerUi(tr(c.title))}),
          emptyMessage: c.emptyMessage,
          emptyAction: c.canCreate ? FilledButton.icon(onPressed: () => edit(context), icon: const Icon(Icons.add_rounded), label: Text(trf('Add {x}', {'x': lowerUi(tr(c.singular))}))) : null,
          csvName: c.id,
        ),
      ]),
    );
  }
}

Future<void> _batch(List<Doc> rows, void Function(WriteBatch b, Doc d) op) async {
  for (var i = 0; i < rows.length; i += 400) {
    final b = Fs.db.batch();
    for (final d in rows.skip(i).take(400)) {
      op(b, d);
    }
    await b.commit();
  }
}

Future<void> openCrudEditor(BuildContext context, Crud c, Doc? d, {Map<String, dynamic>? initial}) async {
  final init = d?.data ?? initial ?? {...c.defaults};
  if (d == null && initial == null && c.activeField != null && !init.containsKey(c.activeField)) init[c.activeField!] = true;
  await openEditor(
    context,
    title: d == null ? trf('New {x}', {'x': lowerUi(tr(c.singular))}) : trf('Edit {x}', {'x': lowerUi(tr(c.singular))}),
    subtitle: d == null ? null : 'ID · ${d.id}',
    fields: c.fields,
    initial: init,
    width: c.editorWidth,
    onSave: (values) async {
      var v = cleanValues(values)..remove('id');
      if (c.beforeSave != null) v = await c.beforeSave!(v, d);
      v['updatedAt'] = FieldValue.serverTimestamp();
      if (d != null) {
        await d.ref!.set(v, SetOptions(merge: true));
        await c.afterSave?.call(d.id, v, d);
      } else {
        v['createdAt'] = FieldValue.serverTimestamp();
        if (c.orderField != null && v[c.orderField] == null) {
          final last = await c.collection.orderBy(c.orderField!, descending: true).limit(1).get().catchError((_) => c.collection.limit(0).get());
          v[c.orderField!] = last.docs.isEmpty ? 0 : toNum(last.docs.first.data()[c.orderField]).toInt() + 1;
        }
        if (c.idFrom != null) {
          final id = c.idFrom!(v);
          if (id.isEmpty) throw 'ID cannot be empty';
          final ref = c.collection.doc(id);
          if ((await ref.get()).exists) throw '${c.singular} "$id" already exists';
          await ref.set(v);
          await c.afterSave?.call(id, v, null);
        } else {
          final ref = await c.collection.add(v);
          await c.afterSave?.call(ref.id, v, null);
        }
      }
    },
  );
}

class _ActiveSwitch extends StatelessWidget {
  const _ActiveSwitch({required this.doc, required this.field});
  final Doc doc;
  final String field;
  @override
  Widget build(BuildContext context) => Transform.scale(
        scale: .8,
        alignment: AlignmentDirectional.centerStart,
        child: Switch(
          value: doc.b(field, true),
          onChanged: (v) => runToast(() => doc.ref!.update({field: v, 'updatedAt': FieldValue.serverTimestamp()})),
        ),
      );
}

/// Drag-to-reorder dialog writing sequential [orderField] values.
Future<void> showReorderDialog(BuildContext context,
    {required Query<Json> query, required String orderField, required String Function(Doc) labelOf, Widget Function(Doc)? leading}) async {
  List<Doc> docs;
  try {
    docs = await fetchDocs(query, fallback: query);
  } catch (e) {
    toastError(e);
    return;
  }
  docs.sort((a, b) => a.n(orderField).compareTo(b.n(orderField)));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return AlertDialog(
        title: Text(tr('Drag to reorder')),
        content: SizedBox(
          width: 460,
          height: 480,
          child: ReorderableListView.builder(
            itemCount: docs.length,
            onReorder: (a, b) => set(() {
              if (b > a) b--;
              docs.insert(b, docs.removeAt(a));
            }),
            itemBuilder: (_, i) => ListTile(
              key: ValueKey(docs[i].id),
              leading: leading?.call(docs[i]) ?? CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              title: Text(labelOf(docs[i])),
              trailing: const Icon(Icons.drag_indicator_rounded),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          AsyncButton(
            label: 'Save order',
            onPressed: () async {
              final ok = await runToast(() async {
                final b = Fs.db.batch();
                for (var i = 0; i < docs.length; i++) {
                  b.update(docs[i].ref!, {orderField: i});
                }
                await b.commit();
              }, success: 'Order saved');
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      );
    }),
  );
}

/// Common column helpers.
Col<Doc> imageTitleCol(String label, {String image = 'image', String title = 'name', String? sub, int flex = 4}) => Col<Doc>(
      label,
      flex: flex,
      text: (d) => d.s(title),
      cell: (ctx, d) => Row(children: [
        RowThumb(d[image] is List ? (d.list(image).isEmpty ? '' : d.list(image).first) : d.s(image)),
        const SizedBox(width: 12),
        Expanded(child: TwoLine(d.s(title), sub == null ? null : d.s(sub))),
      ]),
    );

Col<Doc> dateCol(String label, [String key = 'createdAt']) =>
    Col<Doc>(label, flex: 2, text: (d) => Fmt.date(d.dt(key)), sort: (d) => d.dt(key)?.millisecondsSinceEpoch ?? 0);

Col<Doc> moneyCol(String label, String key, {int flex = 2}) =>
    Col<Doc>(label, flex: flex, numeric: true, text: (d) => Fmt.money(d.n(key)), sort: (d) => d.n(key), csv: (d) => d.n(key).toStringAsFixed(2));

Col<Doc> statusCol(String label, String key, {String f = ''}) =>
    Col<Doc>(label, flex: 2, text: (d) => d.s(key, f), cell: (ctx, d) => statusPill(d.s(key, f)));

Col<Doc> textCol(String label, String key, {int flex = 2}) => Col<Doc>(label, flex: flex, text: (d) => d.s(key));
