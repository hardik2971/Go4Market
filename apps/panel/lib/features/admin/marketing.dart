import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'marketing_widgets.dart';
import 'package:panel/l10n/overrides.dart';

// ───────────────────────── Helpers ─────────────────────────

/// live / scheduled / expired from startAt–endAt.
String scheduleState(Doc d) {
  final now = DateTime.now();
  final s = d.dt('startAt'), e = d.dt('endAt');
  if (e != null && e.isBefore(now)) return 'expired';
  if (s != null && s.isAfter(now)) return 'scheduled';
  return 'live';
}

Widget scheduleTag(Doc d) {
  final st = scheduleState(d);
  return Tag(Fmt.titleCase(st),
      color: switch (st) { 'live' => G4MColors.success, 'scheduled' => G4MColors.info, _ => G4MColors.danger },
      icon: switch (st) { 'live' => Icons.circle, 'scheduled' => Icons.schedule_rounded, _ => Icons.history_rounded });
}

String? _endAfterStart(dynamic v, Map<String, dynamic> vals) {
  final s = toDate(vals['startAt']), e = toDate(v);
  if (s != null && e != null && !e.isAfter(s)) return 'End must be after start';
  return null;
}

const _scheduleFilter = {'live': 'Live', 'scheduled': 'Scheduled', 'expired': 'Expired'};
final _moduleFilter = TableFilter<Doc>('module', 'Module', moduleOptions, test: (d, v) => d.s('moduleId').isEmpty || d.s('moduleId') == v);

String _moduleLabel(Doc d) => d.s('moduleId').isEmpty ? 'All modules' : (moduleOptions[d.s('moduleId')] ?? d.s('moduleId'));

// ───────────────────────── Sliders ─────────────────────────

class SlidersPage extends StatelessWidget {
  const SlidersPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'sliders',
        title: 'Home sliders',
        subtitle: 'Hero banners on the website and app home. Drag to reorder.',
        singular: 'Slider',
        collection: Fs.sliders,
        orderField: 'order',
        labelOf: (d) => d.s('title', d.id),
        search: (d) => '${d.s('title')} ${d.s('subtitle')} ${d.s('link')}',
        filters: [_moduleFilter],
        fields: const [
          F('image', 'Banner image', FT.image, required: true, folder: 'banners/sliders', aspect: 16 / 6, help: 'Recommended 1600×600 · JPG, PNG or WebP'),
          F('title', 'Title', FT.text, required: true),
          F('subtitle', 'Subtitle', FT.text),
          F('ctaText', 'Button text', FT.text, hint: 'Shop now'),
          F('link', 'Link', FT.text, hint: '/category/fruits or https://…'),
          F('moduleId', 'Module', FT.select, options: moduleOptions, help: 'Empty = all modules'),
          F('bgColor', 'Background colour', FT.color),
        ],
        leading: (c, d) => RowThumb(d.s('image')),
        columns: [
          Col<Doc>('Slider', flex: 4, text: (d) => d.s('title'), cell: (c, d) => TwoLine(d.s('title'), d.s('subtitle'))),
          Col<Doc>('Module', flex: 2, text: _moduleLabel),
          Col<Doc>('Link', flex: 3, text: (d) => d.s('link')),
          Col<Doc>('#', flex: 1, numeric: true, text: (d) => '${d.i('order') + 1}', sort: (d) => d.n('order')),
        ],
        card: (c, d) => BannerPreview(
          image: d.s('image'),
          title: d.s('title'),
          subtitle: d.s('subtitle'),
          cta: d.s('ctaText', 'Shop now'),
          bg: d.s('bgColor'),
          footer: [Tag(_moduleLabel(d)), Tag('#${d.i('order') + 1}'), if (!d.b('active', true)) Tag('Hidden', color: G4MColors.danger)],
        ),
      ));
}

// ───────────────────────── Offers ─────────────────────────

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});
  static const positions = {'home_top': 'Home · top', 'home_mid': 'Home · middle', 'category': 'Category pages'};
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'offers',
        title: 'Offer banners',
        subtitle: 'Promotional banners placed across the storefront, optionally scheduled',
        singular: 'Offer',
        collection: Fs.offers,
        orderField: 'order',
        labelOf: (d) => d.s('title', d.id),
        search: (d) => '${d.s('title')} ${d.s('link')} ${d.s('position')}',
        filters: [
          TableFilter<Doc>('position', 'Position', positions, test: (d, v) => d.s('position') == v),
          TableFilter<Doc>('when', 'Schedule', _scheduleFilter, test: (d, v) => scheduleState(d) == v),
          _moduleFilter,
        ],
        fields: [
          const F('image', 'Banner image', FT.image, required: true, folder: 'banners/offers', aspect: 2, help: 'Recommended 1200×600'),
          const F('title', 'Title', FT.text, required: true),
          const F('link', 'Link', FT.text, hint: '/offers/diwali'),
          const F('position', 'Position', FT.select, required: true, options: positions, initial: 'home_top'),
          const F('moduleId', 'Module', FT.select, options: moduleOptions),
          const F('startAt', 'Starts', FT.datetime),
          F('endAt', 'Ends', FT.datetime, validator: _endAfterStart),
        ],
        leading: (c, d) => RowThumb(d.s('image')),
        columns: [
          Col<Doc>('Offer', flex: 4, text: (d) => d.s('title'), cell: (c, d) => TwoLine(d.s('title'), d.s('link'))),
          Col<Doc>('Position', flex: 2, text: (d) => positions[d.s('position')] ?? d.s('position')),
          Col<Doc>('Module', flex: 2, text: _moduleLabel),
          Col<Doc>('Window', flex: 3, text: (d) => '${Fmt.date(d.dt('startAt'))} → ${Fmt.date(d.dt('endAt'))}'),
          Col<Doc>('Schedule', flex: 2, text: scheduleState, cell: (c, d) => scheduleTag(d)),
        ],
        card: (c, d) => BannerPreview(
          image: d.s('image'),
          title: d.s('title'),
          aspect: 2,
          footer: [scheduleTag(d), Tag(positions[d.s('position')] ?? d.s('position')), Tag(_moduleLabel(d))],
        ),
      ));
}

// ───────────────────────── Popups ─────────────────────────

class PopupsPage extends StatelessWidget {
  const PopupsPage({super.key});
  static const showOn = {'web': 'Website', 'app': 'Apps', 'both': 'Website & apps'};
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'popups',
        title: 'Popups',
        subtitle: 'Promotional popups shown once per session on the website and apps',
        singular: 'Popup',
        collection: Fs.popups,
        labelOf: (d) => d.s('title', d.id),
        search: (d) => '${d.s('title')} ${d.s('link')}',
        filters: [
          TableFilter<Doc>('showOn', 'Shown on', showOn, test: (d, v) => d.s('showOn', 'both') == v),
          TableFilter<Doc>('when', 'Schedule', _scheduleFilter, test: (d, v) => scheduleState(d) == v),
        ],
        fields: [
          const F('image', 'Popup image', FT.image, required: true, folder: 'banners/popups', aspect: 4 / 5),
          const F('title', 'Title', FT.text, required: true),
          const F('link', 'Link', FT.text),
          const F('showOn', 'Show on', FT.select, required: true, options: showOn, initial: 'both'),
          const F('startAt', 'Starts', FT.datetime),
          F('endAt', 'Ends', FT.datetime, validator: _endAfterStart),
        ],
        leading: (c, d) => RowThumb(d.s('image')),
        columns: [
          Col<Doc>('Popup', flex: 4, text: (d) => d.s('title'), cell: (c, d) => TwoLine(d.s('title'), d.s('link'))),
          Col<Doc>('Shown on', flex: 2, text: (d) => showOn[d.s('showOn', 'both')] ?? d.s('showOn')),
          Col<Doc>('Window', flex: 3, text: (d) => '${Fmt.date(d.dt('startAt'))} → ${Fmt.date(d.dt('endAt'))}'),
          Col<Doc>('Schedule', flex: 2, text: scheduleState, cell: (c, d) => scheduleTag(d)),
        ],
        card: (c, d) => BannerPreview(
          image: d.s('image'),
          title: d.s('title'),
          aspect: 4 / 3,
          footer: [scheduleTag(d), Tag(showOn[d.s('showOn', 'both')] ?? '')],
        ),
      ));
}

// ───────────────────────── Featured sections ─────────────────────────

class FeaturedSectionsPage extends StatelessWidget {
  const FeaturedSectionsPage({super.key});
  static const types = {
    'manual': 'Hand-picked products',
    'category': 'From a category',
    'bestsellers': 'Bestsellers',
    'newest': 'Newest arrivals',
    'top_rated': 'Top rated',
    'deals': 'Best deals',
  };
  static const styles = {'carousel': 'Carousel', 'grid': 'Grid', 'banner_left': 'Banner + products'};

  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'featuredSections',
        title: 'Featured sections',
        subtitle: 'Product rows that make up the dynamic homepage. Drag to reorder.',
        singular: 'Section',
        collection: Fs.featuredSections,
        orderField: 'order',
        editorWidth: 720,
        labelOf: (d) => d.s('title', d.id),
        search: (d) => '${d.s('title')} ${d.s('subtitle')} ${d.s('type')}',
        filters: [
          TableFilter<Doc>('type', 'Type', types, test: (d, v) => d.s('type', 'manual') == v),
          _moduleFilter,
        ],
        fields: [
          const F('title', 'Title', FT.text, required: true, hint: 'Fresh picks for you'),
          const F('subtitle', 'Subtitle', FT.text),
          const F('moduleId', 'Module', FT.select, options: moduleOptions, help: 'Empty = all modules'),
          const F('type', 'Products from', FT.select, required: true, options: types, initial: 'manual'),
          F('productIds', 'Products', FT.custom,
              wide: true,
              visibleIf: (v) => (v['type'] ?? 'manual') == 'manual',
              validator: (v, vals) => (vals['type'] ?? 'manual') == 'manual' && (v is! List || v.isEmpty) ? 'Pick at least one product' : null,
              builder: (c, v, on, vals) => ProductPickerField(ids: v is List ? v.map((e) => '$e').toList() : const [], onChanged: on)),
          F('categoryId', 'Category', FT.select,
              visibleIf: (v) => v['type'] == 'category',
              validator: (v, vals) => vals['type'] == 'category' && (v == null || '$v'.isEmpty) ? 'Choose a category' : null,
              optionsStream: () => optionsOf(Fs.categories, 'name', label: (d) => '${'— ' * d.i('depth')}${d.s('name')}')),
          const F('style', 'Layout style', FT.select, required: true, options: styles, initial: 'carousel'),
          F('bannerImage', 'Side banner', FT.image, folder: 'banners/sections', aspect: 3 / 4, visibleIf: (v) => v['style'] == 'banner_left'),
          const F('bgColor', 'Background colour', FT.color),
        ],
        columns: [
          Col<Doc>('Section', flex: 4, text: (d) => d.s('title'), cell: (c, d) => TwoLine(d.s('title'), d.s('subtitle'))),
          Col<Doc>('Source', flex: 3, text: (d) => types[d.s('type', 'manual')] ?? d.s('type'),
              cell: (c, d) => Tag(d.s('type', 'manual') == 'manual' ? '${d.list('productIds').length} products' : types[d.s('type')] ?? d.s('type'), icon: Icons.auto_awesome_rounded)),
          Col<Doc>('Style', flex: 2, text: (d) => styles[d.s('style', 'carousel')] ?? d.s('style')),
          Col<Doc>('Module', flex: 2, text: _moduleLabel),
          Col<Doc>('#', flex: 1, numeric: true, text: (d) => '${d.i('order') + 1}', sort: (d) => d.n('order')),
        ],
        card: (c, d) => SectionStylePreview(d: d, typeLabel: types[d.s('type', 'manual')] ?? d.s('type')),
      ));
}

// ───────────────────────── Coupons ─────────────────────────

class CouponsPage extends StatelessWidget {
  const CouponsPage({super.key});

  bool get _seller => session.panel == PanelRole.seller;

  String _validity(Doc d) {
    if (!d.b('active', true)) return 'inactive';
    final lim = d.i('usageLimit');
    if (lim > 0 && d.i('usedCount') >= lim) return 'used_up';
    return scheduleState(d);
  }

  @override
  Widget build(BuildContext context) {
    final seller = _seller;
    return CrudPage(Crud(
      id: seller ? 'seller_coupons' : 'coupons',
      title: seller ? 'My coupons' : 'Coupons & promo codes',
      subtitle: seller ? 'Discount codes that apply to your products' : 'Platform and seller discount codes with limits and expiry',
      singular: 'Coupon',
      collection: Fs.coupons,
      query: seller ? () => Fs.coupons.where('sellerId', isEqualTo: session.uid) : null,
      idFrom: (v) => '${v['code'] ?? ''}'.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ''),
      labelOf: (d) => d.id,
      search: (d) => '${d.id} ${d.s('message')}',
      filters: [
        TableFilter<Doc>('validity', 'Validity', const {'live': 'Live', 'scheduled': 'Scheduled', 'expired': 'Expired', 'used_up': 'Used up', 'inactive': 'Inactive'},
            test: (d, v) => _validity(d) == v),
        TableFilter<Doc>('type', 'Type', const {'percent': 'Percent', 'flat': 'Flat'}, test: (d, v) => d.s('discountType', 'percent') == v),
        if (!seller)
          TableFilter<Doc>('owner', 'Owner', const {'platform': 'Platform', 'seller': 'Seller coupons'},
              test: (d, v) => v == 'platform' ? d.s('sellerId').isEmpty : d.s('sellerId').isNotEmpty),
      ],
      defaults: const {'discountType': 'percent', 'perUserLimit': 1},
      fields: [
        F('code', 'Code', FT.text,
            required: true,
            uppercase: true,
            hint: 'SAVE20',
            visibleIf: (v) => v['createdAt'] == null,
            validator: (v, _) => RegExp(r'^[A-Z0-9_-]{3,20}$').hasMatch('${v ?? ''}'.toUpperCase()) ? null : '3–20 letters, digits, - or _'),
        const F('message', 'Description shown to customers', FT.text, required: true, wide: true, hint: '20% off on your first order'),
        const F('discountType', 'Discount type', FT.select, required: true, options: {'percent': 'Percentage', 'flat': 'Flat amount'}),
        F('value', 'Discount value', FT.number, required: true, min: 0,
            validator: (v, vals) => vals['discountType'] == 'percent' && v is num && v > 100 ? 'Max 100%' : null),
        F('maxDiscount', 'Max discount', FT.money, visibleIf: (v) => v['discountType'] != 'flat', help: 'Cap for percentage coupons'),
        const F('minOrder', 'Minimum order', FT.money, min: 0),
        const F('startAt', 'Starts', FT.datetime),
        F('endAt', 'Expires', FT.datetime, validator: _endAfterStart),
        const F('usageLimit', 'Total uses', FT.integer, min: 0, help: '0 or empty = unlimited'),
        const F('perUserLimit', 'Uses per customer', FT.integer, min: 0),
        if (!seller)
          F('sellerId', 'Seller', FT.select,
              help: 'Empty = platform-wide coupon', optionsStream: () => optionsOf(Fs.sellers.where('status', isEqualTo: 'approved'), 'storeName')),
        const F('image', 'Coupon image', FT.image, folder: 'coupons', aspect: 2),
      ],
      beforeSave: (v, existing) {
        if (seller) v['sellerId'] = session.uid;
        if ('${v['sellerId'] ?? ''}'.isEmpty) v['sellerId'] = null;
        if (existing == null) {
          v['usedCount'] = 0;
          v['code'] = '${v['code']}'.trim().toUpperCase();
        }
        return v;
      },
      columns: [
        Col<Doc>('Code', flex: 4, text: (d) => d.id, cell: (c, d) => Row(children: [
              CouponCodeChip(d.id),
              const SizedBox(width: 10),
              Expanded(child: Text(d.s('message'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.pal.muted, fontSize: 12.5))),
            ])),
        Col<Doc>('Discount', flex: 2, text: (d) => Coupon(d.id, d.data).label,
            cell: (c, d) => TwoLine(Coupon(d.id, d.data).label, d.n('maxDiscount') > 0 ? 'up to ${Fmt.money(d.n('maxDiscount'))}' : null)),
        Col<Doc>('Min order', flex: 2, numeric: true, text: (d) => d.n('minOrder') > 0 ? Fmt.money(d.n('minOrder')) : '—', sort: (d) => d.n('minOrder')),
        Col<Doc>('Usage', flex: 2, text: (d) => '${d.i('usedCount')}/${d.i('usageLimit') == 0 ? '∞' : d.i('usageLimit')}',
            sort: (d) => d.n('usedCount'), cell: (c, d) => UsageBar(used: d.i('usedCount'), limit: d.i('usageLimit'))),
        Col<Doc>('Validity', flex: 2, text: _validity, cell: (c, d) {
          final v = _validity(d);
          return Tooltip(
            message: '${Fmt.dateTime(d.dt('startAt'))} → ${Fmt.dateTime(d.dt('endAt'))}',
            child: Tag(Fmt.titleCase(v), color: switch (v) { 'live' => G4MColors.success, 'scheduled' => G4MColors.info, 'used_up' => G4MColors.warning, _ => G4MColors.danger }),
          );
        }),
        if (!seller)
          Col<Doc>('Owner', flex: 2, text: (d) => d.s('sellerId').isEmpty ? 'Platform' : d.s('sellerId'),
              cell: (c, d) => d.s('sellerId').isEmpty ? Tag('Platform', color: G4MColors.primary) : LookupText(Fs.sellers.doc(d.s('sellerId')), 'storeName')),
      ],
      card: (c, d) => CouponCard(d: d, label: Coupon(d.id, d.data).label, validity: _validity(d)),
    ));
  }
}

// ───────────────────────── Campaigns ─────────────────────────

class CampaignsPage extends StatelessWidget {
  const CampaignsPage({super.key});
  static const audiences = {'all': 'Everyone', 'customers': 'Customers', 'sellers': 'Sellers', 'delivery': 'Delivery partners'};

  Future<void> _send(BuildContext context, Doc d) async {
    final resend = d.s('status') == 'sent';
    if (!await confirm(context, resend ? 'Send again?' : 'Send this campaign now?',
        message: '"${d.s('title')}" will be pushed to ${audiences[d.s('audience', 'all')]?.toLowerCase()} via FCM.', confirmLabel: 'Send now')) {
      return;
    }
    try {
      final r = await G4MApi.instance.sendCampaign(d.id);
      toast(r['sent'] != null ? 'Sent to ${r['sent']} devices' : 'Campaign sent');
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'campaigns',
        title: 'Push campaigns',
        subtitle: 'Broadcast push notifications to customers, sellers or delivery partners',
        singular: 'Campaign',
        collection: Fs.campaigns,
        activeField: null,
        labelOf: (d) => d.s('title', d.id),
        search: (d) => '${d.s('title')} ${d.s('body')}',
        defaults: const {'audience': 'all', 'status': 'draft'},
        filters: [
          TableFilter<Doc>('audience', 'Audience', audiences, test: (d, v) => d.s('audience', 'all') == v),
          TableFilter<Doc>('status', 'Status', const {'draft': 'Draft', 'sent': 'Sent', 'failed': 'Failed'}, test: (d, v) => d.s('status', 'draft') == v),
        ],
        fields: const [
          F('title', 'Title', FT.text, required: true, max: 65, hint: 'Weekend mega sale is live!'),
          F('body', 'Message', FT.multiline, required: true, hint: 'Up to 50% off on fruits & veggies. Today only.'),
          F('audience', 'Audience', FT.select, required: true, options: audiences),
          F('link', 'Open link (optional)', FT.text, hint: '/offers/weekend'),
          F('image', 'Image (optional)', FT.image, folder: 'campaigns', aspect: 2),
        ],
        beforeSave: (v, existing) {
          if (existing == null) v['status'] = 'draft';
          return v;
        },
        extraActions: [
          RowAction('Send now', Icons.send_rounded, (d) => _send(context, d)),
        ],
        columns: [
          Col<Doc>('Campaign', flex: 5, text: (d) => d.s('title'), cell: (c, d) => TwoLine(d.s('title'), d.s('body'))),
          Col<Doc>('Audience', flex: 2, text: (d) => audiences[d.s('audience', 'all')] ?? d.s('audience'), cell: (c, d) => Tag(audiences[d.s('audience', 'all')] ?? '', icon: Icons.people_alt_rounded)),
          Col<Doc>('Status', flex: 2, text: (d) => d.s('status', 'draft'), cell: (c, d) => statusPill(d.s('status', 'draft') == 'sent' ? 'paid' : d.s('status', 'draft'), label: Fmt.titleCase(d.s('status', 'draft')))),
          Col<Doc>('Sent', flex: 2, text: (d) => Fmt.dateTime(d.dt('sentAt')), sort: (d) => d.dt('sentAt')?.millisecondsSinceEpoch ?? 0),
          Col<Doc>('', flex: 2, cell: (c, d) => TextButton.icon(onPressed: () => _send(c, d), icon: const Icon(Icons.send_rounded, size: 16), label: Text(d.s('status') == 'sent' ? 'Resend' : 'Send'))),
        ],
        card: (c, d) => PushPreview(
          title: d.s('title'),
          body: d.s('body'),
          image: d.s('image'),
          footer: [Tag(audiences[d.s('audience', 'all')] ?? ''), statusPill(d.s('status', 'draft') == 'sent' ? 'paid' : d.s('status', 'draft'), label: Fmt.titleCase(d.s('status', 'draft')))],
        ),
      ));
}

// ───────────────────────── Membership ─────────────────────────

class MembershipPlansPage extends StatelessWidget {
  const MembershipPlansPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'membershipPlans',
        title: 'Membership plans',
        subtitle: 'Paid plans with free delivery and extra discounts for loyal customers',
        singular: 'Plan',
        collection: Fs.membershipPlans,
        labelOf: (d) => d.s('name'),
        sortField: 'price',
        sortDesc: false,
        search: (d) => '${d.s('name')} ${d.list('benefits').join(' ')}',
        fields: const [
          F('name', 'Plan name', FT.text, required: true, hint: 'Go4Market Plus'),
          F('price', 'Price', FT.money, required: true, min: 0),
          F('mrp', 'Strike-through price', FT.money, min: 0),
          F('durationDays', 'Duration (days)', FT.integer, required: true, min: 1, initial: 30),
          F('discountPct', 'Extra discount', FT.percent, min: 0, max: 100),
          F('freeDeliveryAbove', 'Free delivery above', FT.money, help: 'Only if free delivery is on; 0 = always'),
          F('freeDelivery', 'Free delivery', FT.toggle),
          F('benefits', 'Benefits', FT.tags, help: 'Shown as bullet points'),
        ],
        columns: [
          Col<Doc>('Plan', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), '${d.i('durationDays')} days')),
          moneyCol('Price', 'price'),
          Col<Doc>('Discount', flex: 2, numeric: true, text: (d) => '${d.n('discountPct').toStringAsFixed(0)}%'),
          Col<Doc>('Free delivery', flex: 2, text: (d) => d.b('freeDelivery') ? 'Yes' : 'No',
              cell: (c, d) => Tag(d.b('freeDelivery') ? 'Free delivery' : 'Standard', color: d.b('freeDelivery') ? G4MColors.success : null)),
          Col<Doc>('Benefits', flex: 4, text: (d) => d.list('benefits').join(', ')),
        ],
        card: (c, d) => PlanCard(d),
      ));
}

// ───────────────────────── Subscriptions ─────────────────────────

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});
  static const freq = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
  static const statuses = {'active': 'Active', 'paused': 'Paused', 'cancelled': 'Cancelled'};

  Future<void> _set(Doc d, String status) =>
      runToast(() => d.ref!.update({'status': status, 'updatedAt': FieldValue.serverTimestamp()}), success: 'Subscription ${status == 'active' ? 'resumed' : status}');

  Future<void> _edit(BuildContext context, Doc d) => openEditor(
        context,
        title: 'Edit subscription',
        subtitle: d.id,
        initial: d.data,
        fields: const [
          F('qty', 'Quantity', FT.integer, required: true, min: 1),
          F('frequency', 'Frequency', FT.select, required: true, options: freq),
          F('nextRunAt', 'Next delivery', FT.datetime, required: true),
          F('status', 'Status', FT.select, required: true, options: statuses),
        ],
        onSave: (v) => d.ref!.update({
          'qty': v['qty'],
          'frequency': v['frequency'],
          'nextRunAt': v['nextRunAt'],
          'status': v['status'],
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Subscriptions',
        subtitle: 'Recurring product orders placed automatically by runSubscriptions',
        child: DataView<Doc>(
          id: 'subscriptions',
          source: (q) => liveDocs(Fs.subscriptions.orderBy('createdAt', descending: true).limit(q.limit),
              fallback: Fs.subscriptions.limit(q.limit), label: 'subscriptions'),
          rowId: (d) => d.id,
          searchText: (d) => '${d.id} ${d.s('userId')} ${d.s('productId')} ${d.s('frequency')}',
          filters: [
            TableFilter<Doc>('status', 'Status', statuses, test: (d, v) => d.s('status', 'active') == v),
            TableFilter<Doc>('frequency', 'Frequency', freq, test: (d, v) => d.s('frequency') == v),
          ],
          columns: [
            Col<Doc>('Customer', flex: 3, text: (d) => d.s('userId'), cell: (c, d) => LookupText(Fs.user(d.s('userId')), 'name', sub: 'email')),
            Col<Doc>('Product', flex: 4, text: (d) => d.s('productId'),
                cell: (c, d) => LookupText(Fs.products.doc(d.s('productId')), 'name', suffix: ' × ${d.i('qty', 1)}', sub: 'unit')),
            Col<Doc>('Frequency', flex: 2, text: (d) => freq[d.s('frequency')] ?? d.s('frequency'), cell: (c, d) => Tag(freq[d.s('frequency')] ?? d.s('frequency'), icon: Icons.autorenew_rounded)),
            Col<Doc>('Next run', flex: 2, text: (d) => Fmt.dateTime(d.dt('nextRunAt')), sort: (d) => d.dt('nextRunAt')?.millisecondsSinceEpoch ?? 0),
            Col<Doc>('Status', flex: 2, text: (d) => d.s('status', 'active'), cell: (c, d) => statusPill(d.s('status', 'active') == 'paused' ? 'pending' : d.s('status', 'active'), label: Fmt.titleCase(d.s('status', 'active')))),
            dateCol('Started'),
          ],
          actions: [
            RowAction('Edit', Icons.edit_outlined, (d) => _edit(context, d)),
            RowAction('Pause', Icons.pause_circle_outline_rounded, (d) => _set(d, 'paused'), visible: (d) => d.s('status', 'active') == 'active'),
            RowAction('Resume', Icons.play_circle_outline_rounded, (d) => _set(d, 'active'), visible: (d) => d.s('status', 'active') == 'paused'),
            RowAction('View customer', Icons.person_outline_rounded, (d) => context.go('/customers/${d.s('userId')}')),
            RowAction('Cancel', Icons.cancel_outlined, (d) async {
              if (await confirm(context, 'Cancel this subscription?', danger: true, confirmLabel: 'Cancel subscription')) await _set(d, 'cancelled');
            }, danger: true, visible: (d) => d.s('status', 'active') != 'cancelled'),
          ],
          bulkActions: [
            BulkAction('Pause', Icons.pause_rounded, (rows) => _batch(rows, 'paused')),
            BulkAction('Resume', Icons.play_arrow_rounded, (rows) => _batch(rows, 'active')),
          ],
          emptyIcon: Icons.autorenew_rounded,
          emptyTitle: 'No subscriptions yet',
          emptyMessage: 'Customers create subscriptions from product pages in the apps.',
          csvName: 'subscriptions',
        ),
      );

  Future<void> _batch(List<Doc> rows, String status) async {
    final b = Fs.db.batch();
    for (final d in rows) {
      b.update(d.ref!, {'status': status, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await b.commit();
  }
}

// ───────────────────────── Abandoned carts ─────────────────────────

class AbandonedCart {
  AbandonedCart(this.uid, this.items, this.products);
  final String uid;
  final List<Doc> items;
  final Map<String, Product> products;

  DateTime? get last => items.map((d) => d.dt('addedAt')).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  int get qty => items.fold(0, (a, d) => a + d.i('qty', 1));
  double priceOf(Doc d) {
    final p = products[d.s('productId')];
    if (p == null) return 0;
    final v = p.variants.where((x) => x.id == d.s('variantId')).firstOrNull;
    return v?.price ?? p.price;
  }

  double get value => items.fold(0, (a, d) => a + priceOf(d) * d.i('qty', 1));
  List<String> get names => items.map((d) => products[d.s('productId')]?.name ?? d.s('productId')).toList();
}

class AbandonedCartsPage extends StatefulWidget {
  const AbandonedCartsPage({super.key});
  @override
  State<AbandonedCartsPage> createState() => _AbandonedCartsPageState();
}

class _AbandonedCartsPageState extends State<AbandonedCartsPage> {
  List<AbandonedCart> _carts = const [];
  int _hours = 6;
  int _gen = 0;

  bool get _seller => session.panel == PanelRole.seller;

  Stream<List<AbandonedCart>> _source(SourceQuery q) {
    final cutoff = DateTime.now().subtract(Duration(hours: _hours));
    Query<Json> base = Fs.db.collectionGroup('cart');
    if (_seller) base = base.where('sellerId', isEqualTo: session.uid);
    final primary = base.where('addedAt', isLessThan: Timestamp.fromDate(cutoff)).orderBy('addedAt', descending: true).limit(q.limit);
    final cache = <String, Product>{};
    return liveDocs(primary, fallback: base.limit(q.limit * 2), sortField: 'addedAt', label: _seller ? 'cart(sellerId,addedAt) group' : 'cart(addedAt) group')
        .asyncMap((docs) async {
      final stale = docs.where((d) {
        final t = d.dt('addedAt');
        return t != null && t.isBefore(cutoff);
      }).toList();
      final missing = stale.map((d) => d.s('productId')).where((id) => id.isNotEmpty && !cache.containsKey(id)).toSet().toList();
      if (missing.isNotEmpty) {
        try {
          for (final p in await CatalogRepo.instance.productsByIds(missing)) {
            cache[p.id] = p;
          }
        } catch (_) {}
      }
      final byUser = <String, List<Doc>>{};
      for (final d in stale) {
        final uid = d.ref?.parent.parent?.id ?? '';
        byUser.putIfAbsent(uid, () => []).add(d);
      }
      final carts = [for (final e in byUser.entries) AbandonedCart(e.key, e.value, cache)]
        ..sort((a, b) => (b.last ?? DateTime(0)).compareTo(a.last ?? DateTime(0)));
      if (mounted) setState(() => _carts = carts);
      return carts;
    });
  }

  Future<void> _remind(List<AbandonedCart> carts) async {
    final b = Fs.db.batch();
    for (final c in carts) {
      b.set(Fs.inbox(c.uid).doc(), {
        'title': 'Still thinking it over? 🛒',
        'body': c.items.length == 1
            ? '${c.names.first} is waiting in your cart. Complete your order before it sells out!'
            : 'You left ${c.items.length} items in your cart. Complete your order before they sell out!',
        'type': 'cart_reminder',
        'data': {'screen': 'cart'},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await b.commit();
  }

  @override
  Widget build(BuildContext context) {
    final total = _carts.fold<double>(0, (a, c) => a + c.value);
    final items = _carts.fold<int>(0, (a, c) => a + c.qty);
    return PanelPage(
      title: 'Abandoned carts',
      subtitle: _seller ? 'Customers who left your products in their cart' : 'Carts left without checkout (collectionGroup cart)',
      actions: [
        Segmented<int>(
          value: _hours,
          options: const {6: 'Older than 6h', 24: '24h', 72: '3 days'},
          onChanged: (h) => setState(() {
            _hours = h;
            _gen++;
          }),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ResponsiveGrid(minItemWidth: 220, children: [
          KpiCard(label: 'Abandoned carts', value: Fmt.number(_carts.length), icon: Icons.remove_shopping_cart_rounded),
          KpiCard(label: 'Items left behind', value: Fmt.number(items), icon: Icons.shopping_basket_rounded, color: G4MColors.info),
          KpiCard(label: 'Recoverable value', value: Fmt.money(total), icon: Icons.currency_rupee_rounded, color: G4MColors.accent),
        ]),
        const SizedBox(height: 16),
        DataView<AbandonedCart>(
          key: ValueKey(_gen),
          id: 'abandoned_carts',
          source: _source,
          rowId: (c) => c.uid,
          searchText: (c) => '${c.uid} ${c.names.join(' ')}',
          columns: [
            Col<AbandonedCart>('Customer', flex: 3, text: (c) => c.uid, cell: (ctx, c) => LookupText(Fs.user(c.uid), 'name', sub: 'email')),
            Col<AbandonedCart>('Items', flex: 5, text: (c) => c.names.join(', '), cell: (ctx, c) => Row(children: [
                  for (final d in c.items.take(3))
                    Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: RowThumb(c.products[d.s('productId')]?.image ?? '', size: 34)),
                  Expanded(child: Text(c.names.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                ])),
            Col<AbandonedCart>('Qty', flex: 1, numeric: true, text: (c) => '${c.qty}', sort: (c) => c.qty),
            Col<AbandonedCart>('Value', flex: 2, numeric: true, text: (c) => Fmt.money(c.value), sort: (c) => c.value, csv: (c) => c.value.toStringAsFixed(2)),
            Col<AbandonedCart>('Last added', flex: 2, text: (c) => Fmt.dateTime(c.last), sort: (c) => c.last?.millisecondsSinceEpoch ?? 0,
                cell: (ctx, c) => Tooltip(message: Fmt.dateTime(c.last), child: Tag(Fmt.ago(c.last), icon: Icons.schedule_rounded))),
          ],
          actions: [
            if (!_seller) ...[
              RowAction('Send reminder', Icons.notifications_active_outlined, (c) => runToast(() => _remind([c]), success: 'Reminder sent')),
              RowAction('View customer', Icons.person_outline_rounded, (c) => context.go('/customers/${c.uid}')),
            ],
            RowAction('Show items', Icons.list_alt_rounded, (c) => _showItems(context, c)),
          ],
          bulkActions: [
            if (!_seller) BulkAction('Send reminders', Icons.notifications_active_outlined, _remind),
          ],
          onTap: (c) => _showItems(context, c),
          defaultSort: 4,
          emptyIcon: Icons.shopping_cart_checkout_rounded,
          emptyTitle: 'No abandoned carts',
          emptyMessage: 'Nice — nobody has left items behind in this window.',
          csvName: 'abandoned_carts',
        ),
      ]),
    );
  }

  void _showItems(BuildContext context, AbandonedCart c) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Cart items')),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final d in c.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: RowThumb(c.products[d.s('productId')]?.image ?? ''),
                  title: Text(c.products[d.s('productId')]?.name ?? d.s('productId')),
                  subtitle: Text('Qty ${d.i('qty', 1)} · added ${Fmt.ago(d.dt('addedAt'))}'),
                  trailing: Text(Fmt.money(c.priceOf(d) * d.i('qty', 1)), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              const Divider(),
              InfoRow('Total', Fmt.money(c.value), bold: true),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Close'))),
            if (!_seller)
              AsyncButton(
                icon: Icons.notifications_active_outlined,
                label: 'Send reminder',
                onPressed: () async {
                  if (await runToast(() => _remind([c]), success: 'Reminder sent') && ctx.mounted) Navigator.pop(ctx);
                },
              ),
          ],
        ),
      );
}
