import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'settings_form.dart' show openHtmlPreview, InfoBanner;
import 'package:panel/l10n/overrides.dart';

// ───────────────────────── Blogs ─────────────────────────

class BlogsPage extends StatelessWidget {
  const BlogsPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'blogs',
        title: 'Blogs',
        subtitle: 'Articles for the website blog (Markdown)',
        singular: 'Post',
        collection: Fs.blogs,
        activeField: null,
        editorWidth: 920,
        labelOf: (d) => d.s('title'),
        search: (d) => '${d.s('title')} ${d.s('excerpt')} ${d.list('tags').join(' ')} ${d.s('author')}',
        filters: [
          TableFilter<Doc>('published', 'Status', const {'1': 'Published', '0': 'Draft'}, test: (d, v) => d.b('published') == (v == '1')),
        ],
        defaults: const {'author': 'Go4Market', 'published': false},
        fields: [
          const F('title', 'Title', FT.text, required: true, wide: true),
          const F('slug', 'URL slug', FT.text, help: 'Leave empty to generate from the title'),
          F('categoryId', 'Category', FT.select, optionsStream: () => optionsOf(Fs.blogCategories, 'name')),
          const F('author', 'Author', FT.text),
          const F('published', 'Published', FT.toggle, help: 'Visible on the website'),
          const F('excerpt', 'Excerpt', FT.multiline, help: 'Shown on blog cards and as meta description'),
          const F('cover', 'Cover image', FT.image, folder: 'blogs', aspect: 16 / 9),
          const F('tags', 'Tags', FT.tags),
          const F('content', 'Content', FT.markdown, required: true),
        ],
        beforeSave: (v, existing) {
          if ('${v['slug'] ?? ''}'.trim().isEmpty) v['slug'] = Fmt.slugify('${v['title']}');
          v['slug'] = Fmt.slugify('${v['slug']}');
          if (v['published'] == true && (existing == null || existing['publishedAt'] == null)) v['publishedAt'] = FieldValue.serverTimestamp();
          return v;
        },
        extraActions: [
          RowAction('Publish', Icons.public_rounded,
              (d) => runToast(() => d.ref!.update({'published': true, 'publishedAt': d['publishedAt'] ?? FieldValue.serverTimestamp()}), success: 'Published'),
              visible: (d) => !d.b('published')),
          RowAction('Unpublish', Icons.public_off_rounded, (d) => runToast(() => d.ref!.update({'published': false}), success: 'Moved to drafts'),
              visible: (d) => d.b('published')),
        ],
        leading: (c, d) => RowThumb(d.s('cover'), icon: Icons.article_outlined),
        columns: [
          Col<Doc>('Post', flex: 5, text: (d) => d.s('title'), cell: (c, d) => TwoLine(d.s('title'), '/${d.s('slug')}')),
          Col<Doc>('Category', flex: 2, text: (d) => d.s('categoryId'),
              cell: (c, d) => d.s('categoryId').isEmpty ? Text(tr('—')) : _DocField(Fs.blogCategories.doc(d.s('categoryId')), 'name')),
          Col<Doc>('Status', flex: 2, text: (d) => d.b('published') ? 'Published' : 'Draft',
              cell: (c, d) => Tag(d.b('published') ? 'Published' : 'Draft', color: d.b('published') ? G4MColors.success : G4MColors.warning)),
          Col<Doc>('Published', flex: 2, text: (d) => Fmt.date(d.dt('publishedAt')), sort: (d) => d.dt('publishedAt')?.millisecondsSinceEpoch ?? 0),
          textCol('Author', 'author'),
        ],
        card: (c, d) => _BlogCard(d),
      ));
}

class _BlogCard extends StatelessWidget {
  const _BlogCard(this.d);
  final Doc d;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(aspectRatio: 16 / 9, child: NetImage(d.s('cover'))),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Tag(d.b('published') ? 'Published' : 'Draft', color: d.b('published') ? G4MColors.success : G4MColors.warning),
              const Spacer(),
              Text(Fmt.date(d.dt('publishedAt') ?? d.createdAt), style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
            ]),
            const SizedBox(height: 8),
            Text(d.s('title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text(d.s('excerpt'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 4, runSpacing: 4, children: [for (final t in d.list('tags').take(4)) Tag('#$t')]),
          ]),
        ),
      ]);
}

class _DocField extends StatelessWidget {
  const _DocField(this.ref, this.field);
  final DocumentReference<Json> ref;
  final String field;
  static final _cache = <String, Future<String>>{};
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _cache.putIfAbsent('${ref.path}.$field', () => ref.get().then((d) => '${d.data()?[field] ?? ref.id}').catchError((_) => ref.id)),
        builder: (c, s) => Text(s.data ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

class _CountText extends StatelessWidget {
  const _CountText(this.q);
  final Query<Json> q;
  @override
  Widget build(BuildContext context) => FutureBuilder<AggregateQuerySnapshot>(
        future: q.count().get(),
        builder: (c, s) => Text(s.hasData ? '${s.data!.count ?? 0}' : '…', style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class BlogCategoriesPage extends StatelessWidget {
  const BlogCategoriesPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'blogCategories',
        title: 'Blog categories',
        singular: 'Category',
        collection: Fs.blogCategories,
        sortField: 'name',
        sortDesc: false,
        labelOf: (d) => d.s('name'),
        search: (d) => '${d.s('name')} ${d.s('slug')}',
        fields: const [
          F('name', 'Name', FT.text, required: true),
          F('slug', 'Slug', FT.text, help: 'Leave empty to generate'),
          F('description', 'Description', FT.multiline),
        ],
        beforeSave: (v, _) {
          v['slug'] = Fmt.slugify('${(v['slug'] ?? '').toString().isEmpty ? v['name'] : v['slug']}');
          return v;
        },
        columns: [
          Col<Doc>('Category', flex: 4, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), '/${d.s('slug')}')),
          Col<Doc>('Posts', flex: 1, numeric: true, cell: (c, d) => _CountText(Fs.blogs.where('categoryId', isEqualTo: d.id))),
          dateCol('Created'),
        ],
      ));
}

// ───────────────────────── FAQs ─────────────────────────

class FaqsPage extends StatelessWidget {
  const FaqsPage({super.key});
  static const cats = ['General', 'Orders', 'Delivery', 'Payments', 'Returns', 'Account', 'Membership', 'Sellers'];
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'faqs',
        title: 'FAQs',
        subtitle: 'Frequently asked questions on the website and apps. Drag to reorder.',
        singular: 'FAQ',
        collection: Fs.faqs,
        orderField: 'order',
        labelOf: (d) => d.s('question'),
        search: (d) => '${d.s('question')} ${d.s('answer')} ${d.s('category')}',
        filters: [
          TableFilter<Doc>('category', 'Category', {for (final c in cats) c: c}, test: (d, v) => d.s('category', 'General') == v),
        ],
        defaults: const {'category': 'General'},
        fields: [
          const F('question', 'Question', FT.text, required: true, wide: true),
          F('category', 'Category', FT.select, required: true, options: {for (final c in cats) c: c}),
          const F('answer', 'Answer', FT.markdown, required: true),
        ],
        columns: [
          Col<Doc>('Question', flex: 6, text: (d) => d.s('question'), cell: (c, d) => TwoLine(d.s('question'), d.s('answer').replaceAll('\n', ' '))),
          Col<Doc>('Category', flex: 2, text: (d) => d.s('category', 'General'), cell: (c, d) => Tag(d.s('category', 'General'))),
          Col<Doc>('#', flex: 1, numeric: true, text: (d) => '${d.i('order') + 1}', sort: (d) => d.n('order')),
        ],
      ));
}

// ───────────────────────── CMS pages & policies ─────────────────────────

const cmsSlugs = <String, String>{
  'about': 'About us',
  'terms': 'Terms & conditions',
  'privacy': 'Privacy policy',
  'refund': 'Refund policy',
  'shipping': 'Shipping policy',
  'cancellation': 'Cancellation policy',
  'customer-policy': 'Customer policy',
  'seller-policy': 'Seller policies',
  'delivery-policy': 'Delivery partner policies',
};

class CmsPagesPage extends StatefulWidget {
  const CmsPagesPage({super.key});
  @override
  State<CmsPagesPage> createState() => _CmsPagesPageState();
}

class _CmsPagesPageState extends State<CmsPagesPage> {
  String _slug = 'about';
  late final Stream<List<Doc>> _pages = liveDocs(Fs.pages, label: 'pages');

  Future<void> _newPage() async {
    final s = await promptText(context, 'New page', label: 'Slug (e.g. careers)', required: true, confirmLabel: 'Create');
    if (s == null || s.isEmpty) return;
    setState(() => _slug = Fmt.slugify(s));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1100;
    return PanelPage(
      title: 'Pages & policies',
      subtitle: 'Static pages and customer, seller and delivery policies (Markdown)',
      actions: [FilledButton.icon(onPressed: _newPage, icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('New page')))],
      child: StreamBuilder<List<Doc>>(
        stream: _pages,
        builder: (context, snap) {
          final docs = {for (final d in snap.data ?? const <Doc>[]) d.id: d};
          final slugs = {...cmsSlugs.keys, ...docs.keys, _slug}.toList();
          final list = SectionCard(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (final s in slugs)
                ListTile(
                  selected: s == _slug,
                  selectedTileColor: context.pal.accent.withValues(alpha: .08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Icon(s.contains('policy') || const {'terms', 'privacy', 'refund', 'shipping', 'cancellation'}.contains(s) ? Icons.policy_outlined : Icons.description_outlined),
                  title: Text(docs[s]?.s('title', cmsSlugs[s] ?? s) ?? cmsSlugs[s] ?? s, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(docs[s] == null ? 'Not written yet' : 'Updated ${Fmt.ago(docs[s]!.dt('updatedAt') ?? docs[s]!.createdAt)}',
                      style: TextStyle(fontSize: 11.5, color: docs[s] == null ? G4MColors.warning : context.pal.muted)),
                  onTap: () => setState(() => _slug = s),
                ),
            ]),
          );
          final editor = KeyedSubtree(key: ValueKey(_slug), child: CmsPageEditor(slug: _slug, defaultTitle: cmsSlugs[_slug] ?? Fmt.titleCase(_slug.replaceAll('-', ' '))));
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 300, child: list), const SizedBox(width: 16), Expanded(child: editor)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [list, const SizedBox(height: 16), editor]);
        },
      ),
    );
  }
}

/// Single CMS page editor (title + Markdown) for pages/{slug}.
class CmsPageEditor extends StatefulWidget {
  const CmsPageEditor({super.key, required this.slug, required this.defaultTitle});
  final String slug;
  final String defaultTitle;
  @override
  State<CmsPageEditor> createState() => _CmsPageEditorState();
}

class _CmsPageEditorState extends State<CmsPageEditor> {
  final _title = TextEditingController();
  String _content = '';
  bool _loaded = false, _dirty = false, _exists = false;
  DateTime? _updated;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Fs.pages.doc(widget.slug).get().then((d) {
      if (!mounted) return;
      final data = d.data() ?? {};
      setState(() {
        _exists = d.exists;
        _title.text = '${data['title'] ?? widget.defaultTitle}';
        _content = '${data['content'] ?? ''}';
        _updated = toDate(data['updatedAt']);
        _loaded = true;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast('Title is required', kind: ToastKind.error);
      return;
    }
    final ok = await runToast(
      () => Fs.pages.doc(widget.slug).set({
        'slug': widget.slug,
        'title': _title.text.trim(),
        'content': _content,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!_exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      success: '${_title.text.trim()} saved',
    );
    if (ok && mounted) {
      setState(() {
        _dirty = false;
        _exists = true;
        _updated = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return SectionCard(child: ErrorBox(_error!));
    if (!_loaded) return const SectionCard(child: LoadingBlock(rows: 4));
    final words = _content.trim().isEmpty ? 0 : _content.trim().split(RegExp(r'\s+')).length;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: SectionCard(
        title: _title.text.isEmpty ? widget.defaultTitle : _title.text,
        subtitle: 'pages/${widget.slug} · $words words${_updated == null ? '' : ' · saved ${Fmt.ago(_updated)}'}',
        icon: Icons.edit_document,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_dirty) const Padding(padding: EdgeInsetsDirectional.only(end: 10), child: Tag('Unsaved', color: G4MColors.warning)),
          AsyncButton(onPressed: _dirty || !_exists ? _save : null, icon: Icons.check_rounded, label: 'Save'),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Page title'),
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 16),
          MarkdownField(
            label: 'Content',
            value: _content,
            minHeight: 420,
            onChanged: (v) {
              _content = v;
              if (!_dirty) setState(() => _dirty = true);
            },
          ),
        ]),
      ),
    );
  }
}

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key, required this.slug, required this.title});
  final String slug;
  final String title;
  @override
  Widget build(BuildContext context) => PanelPage(
        title: title,
        subtitle: 'Shown during onboarding and in the apps · stored in pages/$slug',
        maxWidth: 1100,
        child: CmsPageEditor(slug: slug, defaultTitle: title),
      );
}

// ───────────────────────── Email templates ─────────────────────────

const _templates = <String, (String, List<String>)>{
  'order_placed': ('Order placed', ['name', 'orderNo', 'total', 'items', 'orderUrl']),
  'order_status': ('Order status update', ['name', 'orderNo', 'status', 'statusLabel', 'orderUrl']),
  'welcome': ('Welcome', ['name', 'referralCode', 'appName']),
  'otp': ('One-time password', ['name', 'otp', 'minutes']),
  'withdrawal': ('Withdrawal processed', ['name', 'amount', 'status', 'note']),
};

String _starterHtml(String id) => '''<!doctype html>
<html><body style="margin:0;background:#F7FAF8;font-family:Arial,Helvetica,sans-serif;color:#0F1A14">
  <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px">
    <table width="560" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;border:1px solid #E3EBE6">
      <tr><td style="background:linear-gradient(135deg,#0A4A33,#0B8A4F);padding:24px 28px;border-radius:16px 16px 0 0">
        <span style="color:#fff;font-size:22px;font-weight:800">Go<span style="color:#F7860F">4</span>Market</span>
      </td></tr>
      <tr><td style="padding:28px">
        <h2 style="margin:0 0 12px">Hi {{name}},</h2>
        ${switch (id) {
          'order_placed' => '<p>Thanks for your order <b>{{orderNo}}</b>! We\'ve received it and the store is preparing it.</p><p>Total: <b>{{total}}</b></p>',
          'order_status' => '<p>Your order <b>{{orderNo}}</b> is now <b>{{statusLabel}}</b>.</p>',
          'welcome' => '<p>Welcome to Go4Market — groceries, pharmacy, food and more, delivered fast.</p><p>Invite friends with code <b>{{referralCode}}</b> and earn wallet credit.</p>',
          'otp' => '<p>Your verification code is</p><p style="font-size:32px;font-weight:800;letter-spacing:6px">{{otp}}</p><p>It expires in {{minutes}} minutes.</p>',
          _ => '<p>Your withdrawal of <b>{{amount}}</b> is <b>{{status}}</b>.</p><p>{{note}}</p>',
        }}
        ${id.startsWith('order') ? '<p><a href="{{orderUrl}}" style="background:#0B8A4F;color:#fff;padding:12px 18px;border-radius:10px;text-decoration:none;font-weight:700">Track order</a></p>' : ''}
      </td></tr>
      <tr><td style="padding:16px 28px;color:#5B6B62;font-size:12px;border-top:1px solid #E3EBE6">© Go4Market · You receive this email because you have an account with us.</td></tr>
    </table>
  </td></tr></table>
</body></html>''';

class EmailTemplatesPage extends StatefulWidget {
  const EmailTemplatesPage({super.key});
  @override
  State<EmailTemplatesPage> createState() => _EmailTemplatesPageState();
}

class _EmailTemplatesPageState extends State<EmailTemplatesPage> {
  String _id = 'order_placed';
  late final Stream<List<Doc>> _docs = liveDocs(Fs.emailTemplates, label: 'emailTemplates');

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1100;
    return PanelPage(
      title: 'Email templates',
      subtitle: 'HTML emails sent by Cloud Functions. Use {{placeholders}} for dynamic values.',
      child: StreamBuilder<List<Doc>>(
        stream: _docs,
        builder: (context, snap) {
          final docs = {for (final d in snap.data ?? const <Doc>[]) d.id: d};
          final list = SectionCard(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (final e in _templates.entries)
                ListTile(
                  selected: e.key == _id,
                  selectedTileColor: context.pal.accent.withValues(alpha: .08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: Text(e.value.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(docs[e.key] == null ? 'Using default' : 'Updated ${Fmt.ago(docs[e.key]!.dt('updatedAt') ?? docs[e.key]!.createdAt)}',
                      style: TextStyle(fontSize: 11.5, color: docs[e.key] == null ? G4MColors.warning : context.pal.muted)),
                  onTap: () => setState(() => _id = e.key),
                ),
            ]),
          );
          final editor = KeyedSubtree(key: ValueKey(_id), child: _TemplateEditor(id: _id, existing: docs[_id], loaded: snap.hasData));
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 280, child: list), const SizedBox(width: 16), Expanded(child: editor)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [list, const SizedBox(height: 16), editor]);
        },
      ),
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.id, required this.existing, required this.loaded});
  final String id;
  final Doc? existing;
  final bool loaded;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _subject = TextEditingController(text: widget.existing?.s('subject') ?? _defaultSubject);
  late final _html = TextEditingController(text: widget.existing?.s('html') ?? _starterHtml(widget.id));
  bool _dirty = false;

  String get _defaultSubject => switch (widget.id) {
        'order_placed' => 'Order {{orderNo}} confirmed 🎉',
        'order_status' => 'Order {{orderNo}}: {{statusLabel}}',
        'welcome' => 'Welcome to Go4Market, {{name}}!',
        'otp' => 'Your Go4Market code: {{otp}}',
        _ => 'Withdrawal {{status}}',
      };

  void _insert(String token) {
    final sel = _html.selection;
    final t = _html.text;
    final pos = sel.start < 0 ? t.length : sel.start;
    final end = sel.end < 0 ? t.length : sel.end;
    _html.value = TextEditingValue(text: t.replaceRange(pos, end, token), selection: TextSelection.collapsed(offset: pos + token.length));
    setState(() => _dirty = true);
  }

  String _sample(String s) {
    const values = {
      'name': 'Aarav Sharma',
      'orderNo': 'G4M104233',
      'total': '₹1,249',
      'items': '3 items',
      'orderUrl': 'https://go4market.web.app/orders',
      'status': 'approved',
      'statusLabel': 'Out for delivery',
      'referralCode': 'AARAV50',
      'appName': 'Go4Market',
      'otp': '482913',
      'minutes': '10',
      'amount': '₹5,000',
      'note': 'Paid to HDFC ••4421',
    };
    return s.replaceAllMapped(RegExp(r'\{\{\s*(\w+)\s*\}\}'), (m) => values[m[1]] ?? m[0]!);
  }

  Future<void> _save() async {
    final ok = await runToast(
      () => Fs.emailTemplates.doc(widget.id).set({
        'subject': _subject.text.trim(),
        'html': _html.text,
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.existing == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      success: 'Template saved',
    );
    if (ok && mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = _templates[widget.id]!;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: SectionCard(
        title: t.$1,
        subtitle: 'emailTemplates/${widget.id}',
        icon: Icons.mark_email_read_outlined,
        trailing: Wrap(spacing: 8, children: [
          if (_dirty) const Tag('Unsaved', color: G4MColors.warning),
          OutlinedButton.icon(
            onPressed: () => openHtmlPreview(_sample(_html.text).replaceFirst('<body', '<body data-subject="${_sample(_subject.text)}"')),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(tr('Preview')),
          ),
          AsyncButton(onPressed: _dirty || widget.existing == null ? _save : null, icon: Icons.check_rounded, label: 'Save'),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject'), onChanged: (_) => setState(() => _dirty = true)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Insert:', style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
            for (final p in t.$2) ActionChip(label: Text('{{$p}}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)), onPressed: () => _insert('{{$p}}')),
            TextButton.icon(
              onPressed: () async {
                if (await confirm(context, 'Reset to the default template?', danger: true, confirmLabel: 'Reset')) {
                  setState(() {
                    _html.text = _starterHtml(widget.id);
                    _subject.text = _defaultSubject;
                    _dirty = true;
                  });
                }
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text(tr('Reset')),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(10), color: context.pal.surfaceAlt.withValues(alpha: .4)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _html,
              maxLines: null,
              minLines: 20,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.45),
              decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
              onChanged: (_) {
                if (!_dirty) setState(() => _dirty = true);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Send email / mail log ─────────────────────────

class EmailLogPage extends StatefulWidget {
  const EmailLogPage({super.key});
  @override
  State<EmailLogPage> createState() => _EmailLogPageState();
}

class _EmailLogPageState extends State<EmailLogPage> {
  final _to = TextEditingController();
  final _subject = TextEditingController();
  String _body = '';
  String _mode = 'single';
  String _audience = 'customers';
  int _formGen = 0;

  static const audiences = {'customers': 'All customers', 'sellers': 'All sellers', 'delivery': 'All delivery partners', 'all': 'Everyone'};

  String _toHtml(String md) {
    final esc = md.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    final paras = esc.split(RegExp(r'\n{2,}')).map((p) {
      final line = p
          .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<b>${m[1]}</b>')
          .replaceAllMapped(RegExp(r'_(.+?)_'), (m) => '<i>${m[1]}</i>')
          .replaceAllMapped(RegExp(r'\[(.+?)\]\((.+?)\)'), (m) => '<a href="${m[2]}">${m[1]}</a>')
          .replaceAll('\n', '<br>');
      return '<p>$line</p>';
    }).join();
    return '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#0F1A14">$paras</div>';
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final to = _to.text.trim();
    if (subject.isEmpty || _body.trim().isEmpty) {
      toast('Subject and message are required', kind: ToastKind.error);
      return;
    }
    if (_mode == 'single' && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(to)) {
      toast('Enter a valid email address', kind: ToastKind.error);
      return;
    }
    if (_mode == 'audience' && !await confirm(context, 'Email ${audiences[_audience]!.toLowerCase()}?', message: 'This queues a bulk email for every matching account.', confirmLabel: 'Queue email')) {
      return;
    }
    final ok = await runToast(
      () => Fs.col('mail').add({
        if (_mode == 'single') 'to': to else 'audience': _audience,
        'message': {'subject': subject, 'html': _toHtml(_body), 'text': _body},
        'source': 'admin_panel',
        'createdAt': FieldValue.serverTimestamp(),
      }),
      success: _mode == 'single' ? 'Email queued to $to' : 'Bulk email queued',
    );
    if (ok && mounted) {
      setState(() {
        _to.clear();
        _subject.clear();
        _body = '';
        _formGen++;
      });
    }
  }

  String _state(Doc d) => d.s('delivery.state', d.s('status', 'queued')).toLowerCase();

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Send email',
        subtitle: 'Compose one-off or bulk emails and review recent deliveries',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const InfoBanner(
            'Emails are written to the `mail` collection in the Firebase "Trigger Email" extension format. '
            'They are delivered only when that extension (or an equivalent Cloud Function) is installed; bulk "audience" emails need a backend fan-out.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Compose',
            icon: Icons.edit_outlined,
            child: KeyedSubtree(
              key: ValueKey(_formGen),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Segmented<String>(value: _mode, options: const {'single': 'One recipient', 'audience': 'Audience'}, onChanged: (m) => setState(() => _mode = m)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _mode == 'single'
                        ? TextField(controller: _to, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'To', prefixIcon: Icon(Icons.alternate_email_rounded)))
                        : DropdownButtonFormField<String>(
                            initialValue: _audience,
                            decoration: const InputDecoration(labelText: 'Audience'),
                            items: [for (final e in audiences.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                            onChanged: (v) => setState(() => _audience = v!),
                          ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 12),
                MarkdownField(label: 'Message', value: _body, minHeight: 200, onChanged: (v) => _body = v),
                const SizedBox(height: 12),
                Align(alignment: AlignmentDirectional.centerEnd, child: AsyncButton(onPressed: _send, icon: Icons.send_rounded, label: 'Send email')),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Text('Recent emails', style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DataView<Doc>(
            id: 'mail',
            source: (q) => liveDocs(Fs.col('mail').orderBy('createdAt', descending: true).limit(q.limit), fallback: Fs.col('mail').limit(q.limit), label: 'mail'),
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('to')} ${d.s('audience')} ${d.s('message.subject')}',
            filters: [
              TableFilter<Doc>('state', 'Delivery', const {'success': 'Delivered', 'error': 'Failed', 'pending': 'Pending', 'processing': 'Processing', 'queued': 'Queued'},
                  test: (d, v) => _state(d) == v),
            ],
            columns: [
              Col<Doc>('Recipient', flex: 3, text: (d) => d.s('to', audiences[d.s('audience')] ?? d.s('audience')),
                  cell: (c, d) => TwoLine(d['to'] is List ? d.list('to').join(', ') : d.s('to', audiences[d.s('audience')] ?? d.s('audience')), d.s('source'))),
              Col<Doc>('Subject', flex: 4, text: (d) => d.s('message.subject', d.s('template.name'))),
              Col<Doc>('Status', flex: 2, text: _state, cell: (c, d) {
                final s = _state(d);
                return Tooltip(
                  message: d.s('delivery.error'),
                  child: Tag(Fmt.titleCase(s), color: switch (s) { 'success' => G4MColors.success, 'error' => G4MColors.danger, _ => G4MColors.warning }),
                );
              }),
              Col<Doc>('Sent', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
            ],
            actions: [
              RowAction('Preview', Icons.visibility_outlined, (d) => openHtmlPreview(d.s('message.html', '<p>No HTML body</p>'))),
              RowAction('Delete', Icons.delete_outline_rounded, (d) async {
                if (await confirm(context, 'Delete this log entry?', danger: true, confirmLabel: 'Delete')) await runToast(() => d.ref!.delete());
              }, danger: true),
            ],
            emptyIcon: Icons.mark_email_unread_outlined,
            emptyTitle: 'No emails sent yet',
            csvName: 'emails',
          ),
        ]),
      );
}
