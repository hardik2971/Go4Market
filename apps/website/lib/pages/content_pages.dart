import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/markdown.dart';
import '../ui/shell.dart';
import 'catalog_pages.dart' show Breadcrumbs;
import 'home_page.dart' show BlogCard;

// ------------------------------------------------------------------ blog

class BlogListPage extends StatelessWidget {
  const BlogListPage({super.key});
  @override
  Widget build(BuildContext context) => SeoMeta(
        title: context.l.content.blogSeoTitle,
        description: context.l.content.blogSeoDescription,
        child: PageScroll(children: [
          Contained(
            vertical: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Breadcrumbs(items: [(context.l.common.navHome, '/'), (context.l.common.blog, null)]),
              const SizedBox(height: 14),
              Heading(context.l.content.blogHeading),
              const SizedBox(height: 6),
              Text(context.l.content.blogIntro, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 16)),
              const SizedBox(height: 28),
              StreamBuilder<List<Blog>>(
                stream: live('blogs50', () => Data.blogs(limit: 50)),
                builder: (context, s) => asyncView(s, (l) {
                  if (l.isEmpty) return EmptyState(icon: Icons.article_outlined, title: context.l.content.noArticles, message: context.l.content.noArticlesMsg);
                  return LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 620 ? 2 : 1);
                    final w = (c.maxWidth - 20 * (cols - 1)) / cols;
                    return Wrap(spacing: 20, runSpacing: 20, children: [
                      for (var i = 0; i < l.length; i++) SizedBox(width: w, child: Reveal(index: i % cols, child: BlogCard(blog: l[i]))),
                    ]);
                  });
                }),
              ),
            ]),
          ),
        ]),
      );
}

class BlogPostPage extends StatefulWidget {
  const BlogPostPage({super.key, required this.slug});
  final String slug;
  @override
  State<BlogPostPage> createState() => _BlogPostPageState();
}

class _BlogPostPageState extends State<BlogPostPage> {
  late final _f = Data.blogBySlug(widget.slug);

  @override
  void dispose() {
    WebBridge.setJsonLd('article', null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Blog?>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return const PageScroll(children: [Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator()))]);
          final b = s.data;
          if (b == null || !b.published) {
            return PageScroll(children: [
              SeoMeta(title: context.l.content.articleNotFound, child: EmptyState(icon: Icons.article_outlined, title: context.l.content.articleUnavailable)),
            ]);
          }
          WebBridge.setJsonLd('article', {
            '@context': 'https://schema.org',
            '@type': 'BlogPosting',
            'headline': b.title,
            'image': b.cover,
            'datePublished': b.publishedAt?.toIso8601String(),
            'author': {'@type': 'Organization', 'name': b.author},
            'publisher': {'@type': 'Organization', 'name': 'Go4Market', 'logo': {'@type': 'ImageObject', 'url': '$kSiteUrl/icons/Icon-512.png'}},
            'mainEntityOfPage': '$kSiteUrl/blog/${b.slug}',
          });
          return SeoMeta(
            title: b.title,
            description: b.excerpt,
            image: b.cover,
            child: PageScroll(children: [
              Contained(
                vertical: 24,
                maxWidth: 860,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Breadcrumbs(items: [(context.l.common.navHome, '/'), (context.l.common.blog, '/blog'), (b.title, null)]),
                  const SizedBox(height: 18),
                  Heading(b.title, style: TextStyle(fontSize: context.isPhone ? 28 : 40, height: 1.15)),
                  const SizedBox(height: 10),
                  Text('${context.l.date(b.publishedAt)} · ${b.author}', style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                  if (b.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [for (final t in b.tags) Pill('#$t', bg: G4MColors.primarySoft, fg: G4MColors.primaryDeep)]),
                  ],
                  const SizedBox(height: 22),
                  if (b.cover.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(24), child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(b.cover, semanticLabel: b.title))),
                  const SizedBox(height: 28),
                  Md(b.content),
                  const SizedBox(height: 32),
                  Row(children: [
                    OutlinedButton.icon(onPressed: () => context.go('/blog'), icon: const Icon(Icons.arrow_back_rounded), label: Text(context.l.content.allArticles)),
                    const Spacer(),
                    IconButton.outlined(
                      tooltip: context.l.content.shareArticle,
                      onPressed: () async {
                        final url = '$kSiteUrl/blog/${b.slug}';
                        if (!await WebBridge.share(title: b.title, text: b.excerpt, url: url) && context.mounted) copyText(context, url, context.l.content.linkCopied);
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ]),
                ]),
              ),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ FAQ

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});
  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  String? _cat;

  @override
  void dispose() {
    WebBridge.setJsonLd('faq', null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SeoMeta(
        title: context.l.content.faqTitle,
        description: context.l.content.faqSeoDescription,
        child: PageScroll(children: [
          Contained(
            vertical: 24,
            maxWidth: 900,
            child: StreamBuilder<List<Faq>>(
              stream: live('faqs', CatalogRepo.instance.faqs),
              builder: (context, s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Breadcrumbs(items: [(context.l.common.navHome, '/'), (context.l.content.faqTitle, null)]),
                const SizedBox(height: 14),
                Heading(context.l.content.faqHeading),
                const SizedBox(height: 6),
                Text(context.l.content.faqIntro, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 16)),
                const SizedBox(height: 24),
                asyncView(s, (l) {
                  if (l.isNotEmpty) {
                    WebBridge.setJsonLd('faq', {
                      '@context': 'https://schema.org',
                      '@type': 'FAQPage',
                      'mainEntity': [
                        for (final f in l) {'@type': 'Question', 'name': f.question, 'acceptedAnswer': {'@type': 'Answer', 'text': f.answer}},
                      ],
                    });
                  }
                  if (l.isEmpty) return EmptyState(icon: Icons.help_outline_rounded, title: context.l.content.faqsBeingWritten);
                  final cats = l.map((f) => f.category).toSet().toList();
                  final shown = _cat == null ? l : l.where((f) => f.category == _cat).toList();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (cats.length > 1)
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ChoiceChip(label: Text(context.l.common.all), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                        for (final c in cats) ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                      ]),
                    const SizedBox(height: 18),
                    for (var i = 0; i < shown.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Reveal(
                          index: i % 6,
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: G4MColors.line)),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                shape: const RoundedRectangleBorder(),
                                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                childrenPadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 18),
                                title: Text(shown[i].question, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                children: [Md(shown[i].answer)],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]);
                }),
                const SizedBox(height: 28),
                Panel(
                  color: G4MColors.primarySoft,
                  child: Row(children: [
                    const Icon(Icons.support_agent_rounded, size: 36, color: G4MColors.primaryDeep),
                    const SizedBox(width: 14),
                    Expanded(child: Text(context.l.content.stillNeedHelp, style: const TextStyle(fontWeight: FontWeight.w700))),
                    FilledButton(onPressed: () => context.go('/page/about'), child: Text(context.l.content.contactUs)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ CMS pages

String? _pageTitle(L l, String slug) => switch (slug) {
      'about' => l.content.aboutTitle,
      'terms' => l.common.terms,
      'privacy' => l.common.privacy,
      'refund' => l.common.refundPolicy,
      'shipping' => l.common.shippingPolicy,
      'cancellation' => l.common.cancellationPolicy,
      _ => null,
    };

class CmsPageView extends StatefulWidget {
  const CmsPageView({super.key, required this.slug});
  final String slug;
  @override
  State<CmsPageView> createState() => _CmsPageViewState();
}

class _CmsPageViewState extends State<CmsPageView> {
  late final _f = CatalogRepo.instance.page(widget.slug);
  @override
  Widget build(BuildContext context) => FutureBuilder<CmsPage?>(
        future: _f,
        builder: (context, s) {
          final p = s.data;
          final title = (p?.title.isNotEmpty ?? false) ? p!.title : (_pageTitle(context.l, widget.slug) ?? Fmt.titleCase(widget.slug));
          return SeoMeta(
            title: title,
            description: p?.content,
            child: PageScroll(children: [
              Contained(
                vertical: 24,
                maxWidth: 860,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Breadcrumbs(items: [(context.l.common.navHome, '/'), (title, null)]),
                  const SizedBox(height: 14),
                  Heading(title, style: TextStyle(fontSize: context.isPhone ? 28 : 38)),
                  const SizedBox(height: 22),
                  if (s.connectionState != ConnectionState.done)
                    const Column(children: [Skeleton(height: 16), SizedBox(height: 10), Skeleton(height: 16), SizedBox(height: 10), Skeleton(width: 300, height: 16)])
                  else if (p == null || p.content.isEmpty)
                    EmptyState(icon: Icons.description_outlined, title: context.l.content.pageBeingUpdated, message: context.l.content.checkBackShortly)
                  else
                    Panel(padding: EdgeInsets.all(context.isPhone ? 20 : 36), child: Md(p.content)),
                ]),
              ),
            ]),
          );
        },
      );
}
