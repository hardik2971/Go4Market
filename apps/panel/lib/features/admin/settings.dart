import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/image_upload.dart';
import '../../ui/kit.dart';
import 'settings_form.dart';
import 'package:panel/l10n/overrides.dart';

// ───────────────────────── Hub ─────────────────────────

class _HubLink {
  const _HubLink(this.title, this.desc, this.icon, this.path);
  final String title, desc, path;
  final IconData icon;
}

class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  static const groups = <(String, Color, List<_HubLink>)>[
    ('General', G4MColors.primary, [
      _HubLink('Platform', 'Store details, currency, fees, tax, COD, wallet & referral', Icons.tune_rounded, '/settings/platform'),
      _HubLink('Modules', 'Enable eCommerce, Grocery, Pharmacy, Food and order them', Icons.widgets_rounded, '/settings/modules'),
      _HubLink('Theme', 'Brand colours and per-module theme colours', Icons.palette_rounded, '/settings/theme'),
      _HubLink('Languages', 'Supported languages, RTL and translation files', Icons.translate_rounded, '/settings/languages'),
    ]),
    ('Delivery & locations', G4MColors.accent, [
      _HubLink('Delivery settings', 'Time slots, quick delivery, seller riders, auto-assign', Icons.schedule_rounded, '/delivery/settings'),
      _HubLink('Cities & zones', 'Serviceable cities with radius on the map', Icons.location_city_rounded, '/settings/cities'),
      _HubLink('Countries', 'Countries, dial codes and flags', Icons.public_rounded, '/settings/countries'),
    ]),
    ('Payments', G4MColors.info, [
      _HubLink('Payment gateways', 'Razorpay, Stripe, PayPal public keys and COD', Icons.payment_rounded, '/settings/payments'),
    ]),
    ('Communication', Color(0xFF7C3AED), [
      _HubLink('Communication', 'Email sender, SMS gateway, push and per-status alerts', Icons.sms_rounded, '/settings/communication'),
      _HubLink('Email templates', 'Order, welcome, OTP and withdrawal emails', Icons.mark_email_read_rounded, '/content/email-templates'),
      _HubLink('Push campaigns', 'Broadcast notifications to customers and partners', Icons.campaign_rounded, '/marketing/campaigns'),
    ]),
    ('Integrations & SEO', Color(0xFF0891B2), [
      _HubLink('SEO', 'Meta title, description, keywords and share image', Icons.travel_explore_rounded, '/settings/seo'),
      _HubLink('Social links', 'Facebook, Instagram, X, YouTube, LinkedIn', Icons.share_rounded, '/settings/social'),
      _HubLink('App versions', 'Latest / minimum versions and force update', Icons.system_update_rounded, '/settings/app-versions'),
    ]),
    ('Content & policies', Color(0xFFDB2777), [
      _HubLink('Pages & policies', 'About, terms, privacy, refund and customer policies', Icons.description_rounded, '/content/pages'),
      _HubLink('Seller policies', 'Terms sellers accept during onboarding', Icons.policy_rounded, '/sellers/policies'),
      _HubLink('Partner policies', 'Terms for delivery partners', Icons.gavel_rounded, '/delivery/policies'),
      _HubLink('FAQs', 'Questions shown on the website and apps', Icons.quiz_rounded, '/content/faqs'),
    ]),
    ('System', Color(0xFF475569), [
      _HubLink('Demo & maintenance', 'Demo mode, demo logins and maintenance mode', Icons.construction_rounded, '/settings/system-mode'),
      _HubLink('Staff & roles', 'Admin users and permissions', Icons.admin_panel_settings_rounded, '/staff'),
      _HubLink('System health', 'Function ping, counts and missing indexes', Icons.monitor_heart_rounded, '/system'),
    ]),
  ];

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Settings',
        subtitle: 'Everything that configures the Go4Market platform',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var g = 0; g < groups.length; g++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(children: [
                Container(width: 4, height: 18, decoration: BoxDecoration(color: groups[g].$2, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(groups[g].$1, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
            ResponsiveGrid(minItemWidth: 280, children: [
              for (var i = 0; i < groups[g].$3.length; i++)
                _HubCard(link: groups[g].$3[i], color: groups[g].$2)
                    .animate(delay: (40 * g + 20 * i).ms)
                    .fadeIn(duration: 240.ms)
                    .slideY(begin: .05, curve: Curves.easeOutCubic),
            ]),
            const SizedBox(height: 20),
          ],
        ]),
      );
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.link, required this.color});
  final _HubLink link;
  final Color color;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => context.go(link.path),
        scale: .98,
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.pal.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.pal.line),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
              child: Icon(link.icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(link.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(link.desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 12.5, height: 1.35)),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: context.pal.faint),
          ]),
        ),
      );
}

// ───────────────────────── Platform ─────────────────────────

class PlatformSettingsPage extends StatelessWidget {
  const PlatformSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'Platform settings',
        sections: [
          const SettingsSection('Store details', Icons.store_rounded, [
            F('appName', 'App name', FT.text, required: true),
            F('tagline', 'Tagline', FT.text),
            F('contactEmail', 'Contact email', FT.email),
            F('contactPhone', 'Contact phone', FT.text),
            F('address', 'Business address', FT.multiline),
          ]),
          SettingsSection('Currency & tax', Icons.currency_rupee_rounded, const [
            F('currency', 'Currency code', FT.text, hint: 'INR', uppercase: true),
            F('currencySymbol', 'Currency symbol', FT.text, hint: '₹'),
            F('taxPct', 'Tax', FT.percent, min: 0, max: 100, help: 'Applied on subtotal at checkout'),
            F('fx.usd', 'INR → USD rate', FT.number, help: 'Used when Stripe / PayPal charge in USD (e.g. 0.012)'),
          ], preview: (c, v) => _MoneyPreview(v)),
          const SettingsSection('Delivery charges', Icons.local_shipping_rounded, [
            F('deliveryFee', 'Standard delivery fee', FT.money, min: 0),
            F('freeDeliveryAbove', 'Free delivery above', FT.money, min: 0),
            F('quickDeliveryFee', 'Quick delivery fee (15/30 min)', FT.money, min: 0),
            F('perKmFee', 'Per-km fee', FT.money, min: 0),
            F('maxDeliveryKm', 'Max delivery distance (km)', FT.number, min: 0),
            F('minOrder', 'Minimum order value', FT.money, min: 0),
          ]),
          SettingsSection('Delivery options', Icons.bolt_rounded, [
            const F('pickupEnabled', 'Self pickup', FT.toggle, help: 'Customers can collect from the store'),
            const F('scheduledEnabled', 'Scheduled delivery', FT.toggle, help: 'Customers pick a date & slot'),
            const F('quick15Enabled', 'Quick delivery · 15 min', FT.toggle),
            const F('quick30Enabled', 'Quick delivery · 30 min', FT.toggle),
            F('slots', 'Slots', FT.custom, wide: true, builder: (c, v, on, vals) => SlotsEditor(value: v, onChanged: on)),
          ]),
          const SettingsSection('Cash on delivery', Icons.payments_rounded, [
            F('codEnabled', 'Accept cash on delivery', FT.toggle),
            F('codMax', 'Max COD order value', FT.money, min: 0, help: 'Leave empty for no limit'),
          ]),
          const SettingsSection('Wallet & referral', Icons.account_balance_wallet_rounded, [
            F('walletEnabled', 'Customer wallet', FT.toggle, help: 'Top-ups, refunds and partial wallet payment'),
            F('referralReward', 'Referrer reward', FT.money, min: 0, help: 'Credited to the customer who invited'),
            F('refereeReward', 'New user reward', FT.money, min: 0, help: 'Credited to the invited customer'),
          ]),
        ],
      );
}

class _MoneyPreview extends StatelessWidget {
  const _MoneyPreview(this.v);
  final Map<String, dynamic> v;
  @override
  Widget build(BuildContext context) {
    final sym = '${v['currencySymbol'] ?? '₹'}';
    final tax = toNum(v['taxPct']);
    const sub = 1000.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.pal.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Checkout preview', style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 8),
        InfoRow('Subtotal', '$sym${sub.toStringAsFixed(0)}'),
        InfoRow('Tax ($tax%)', '$sym${(sub * tax / 100).toStringAsFixed(2)}'),
        InfoRow('Total', '$sym${(sub * (1 + tax / 100)).toStringAsFixed(2)}', bold: true),
      ]),
    );
  }
}

// ───────────────────────── Delivery ─────────────────────────

class DeliverySettingsPage extends StatelessWidget {
  const DeliverySettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'Delivery settings',
        subtitle: 'Speeds, slots and how riders are assigned',
        sections: [
          const SettingsSection('Delivery speeds', Icons.bolt_rounded, [
            F('quick15Enabled', 'Quick delivery · 15 minutes', FT.toggle),
            F('quick30Enabled', 'Quick delivery · 30 minutes', FT.toggle),
            F('scheduledEnabled', 'Scheduled delivery', FT.toggle),
            F('pickupEnabled', 'Self pickup', FT.toggle),
            F('quickDeliveryFee', 'Quick delivery fee', FT.money, min: 0),
            F('deliveryEstimateDays', 'Standard estimate (days)', FT.integer, min: 0),
          ]),
          SettingsSection('Time slots', Icons.schedule_rounded, [
            F('slots', 'Slots', FT.custom, wide: true, builder: (c, v, on, vals) => SlotsEditor(value: v, onChanged: on)),
            const F('slotDaysAhead', 'Days customers can book ahead', FT.integer, min: 1, max: 30),
            const F('lastOrderMinutesBeforeSlot', 'Last order (minutes before slot)', FT.integer, min: 0),
          ]),
          const SettingsSection('Rider assignment', Icons.delivery_dining_rounded, [
            F('autoAssign', 'Auto-assign nearest online rider', FT.toggle, help: 'When an order is packed, assignDeliveryPartner picks the nearest online rider'),
            F('sellerRidersEnabled', "Allow sellers' own delivery partners", FT.toggle, help: 'Sellers can onboard and assign their own riders'),
            F('requireDeliveryOtp', 'Require OTP on delivery', FT.toggle),
            F('maxDeliveryKm', 'Max delivery distance (km)', FT.number, min: 0),
          ]),
          const SettingsSection('Rider pay defaults', Icons.badge_rounded, [
            F('riderPay.type', 'Default salary type', FT.select, options: {'per_order': 'Per order', 'monthly': 'Monthly'}),
            F('riderPay.amount', 'Default amount', FT.money, min: 0),
            F('riderPay.perKm', 'Per-km bonus', FT.money, min: 0),
            F('riderPay.bonusPct', 'Bonus % of delivery fee', FT.percent, min: 0, max: 100),
          ]),
        ],
      );
}

// ───────────────────────── Payments ─────────────────────────

class PaymentSettingsPage extends StatelessWidget {
  const PaymentSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.paymentSettings,
        title: 'Payment gateways',
        subtitle: 'Public keys and availability only',
        banner: const InfoBanner(
          'Only public identifiers are stored here (settings/payments is readable by every client). '
          'Secret keys, webhook secrets and PayPal client secrets live in the Cloud Functions configuration and are never entered in the panel.',
          color: G4MColors.warning,
          icon: Icons.shield_outlined,
        ),
        sections: [
          SettingsSection('Razorpay', Icons.flash_on_rounded, const [
            F('razorpay.enabled', 'Enable Razorpay', FT.toggle, help: 'UPI, cards, netbanking, wallets'),
            F('razorpay.keyId', 'Key ID', FT.text, hint: 'rzp_live_…'),
          ], preview: (c, v) => _GatewayBadge('Razorpay', getPath(v, 'razorpay.enabled') == true, '${getPath(v, 'razorpay.keyId') ?? ''}')),
          SettingsSection('Stripe', Icons.credit_card_rounded, const [
            F('stripe.enabled', 'Enable Stripe', FT.toggle, help: 'Hosted Stripe Checkout'),
            F('stripe.publishableKey', 'Publishable key', FT.text, hint: 'pk_live_…'),
          ], preview: (c, v) => _GatewayBadge('Stripe', getPath(v, 'stripe.enabled') == true, '${getPath(v, 'stripe.publishableKey') ?? ''}')),
          SettingsSection('PayPal', Icons.account_balance_rounded, const [
            F('paypal.enabled', 'Enable PayPal', FT.toggle),
            F('paypal.clientId', 'Client ID', FT.text),
            F('paypal.env', 'Environment', FT.select, options: {'sandbox': 'Sandbox', 'live': 'Live'}),
          ], preview: (c, v) => _GatewayBadge('PayPal', getPath(v, 'paypal.enabled') == true, '${getPath(v, 'paypal.clientId') ?? ''}')),
          const SettingsSection('Cash on delivery', Icons.payments_rounded, [
            F('cod.enabled', 'Enable cash on delivery', FT.toggle),
          ]),
        ],
      );
}

class _GatewayBadge extends StatelessWidget {
  const _GatewayBadge(this.name, this.enabled, this.publicKey);
  final String name;
  final bool enabled;
  final String publicKey;
  @override
  Widget build(BuildContext context) {
    final ok = enabled && publicKey.isNotEmpty;
    final c = ok ? G4MColors.success : enabled ? G4MColors.warning : context.pal.muted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : enabled ? Icons.warning_amber_rounded : Icons.pause_circle_outline_rounded, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ok ? '$name is live at checkout' : enabled ? '$name enabled but missing its public key' : '$name is disabled',
            style: TextStyle(fontWeight: FontWeight.w700, color: c),
          ),
        ),
      ]),
    );
  }
}

// ───────────────────────── Modules ─────────────────────────

class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'modules',
        title: 'Modules',
        subtitle: 'Business modules shown on the website and apps. Drag to reorder.',
        singular: 'Module',
        collection: Fs.modules,
        orderField: 'order',
        activeField: 'enabled',
        canDelete: false,
        idFrom: (v) => '${v['id'] ?? ''}'.trim().toLowerCase(),
        labelOf: (d) => d.s('name', d.id),
        search: (d) => '${d.id} ${d.s('name')} ${d.s('tagline')}',
        fields: [
          F('id', 'Module id', FT.select,
              required: true,
              options: const {'ecommerce': 'ecommerce', 'grocery': 'grocery', 'pharmacy': 'pharmacy', 'food': 'food'},
              visibleIf: (v) => v['createdAt'] == null),
          const F('name', 'Name', FT.text, required: true),
          const F('tagline', 'Tagline', FT.text),
          const F('themeColor', 'Theme colour', FT.color, required: true),
          const F('icon', 'Icon', FT.text, hint: 'Material icon name, emoji or image URL'),
          const F('enabled', 'Enabled', FT.toggle, help: 'Disabled modules are hidden from customers'),
        ],
        columns: [
          Col<Doc>('Module', flex: 4, text: (d) => d.s('name', d.id), cell: (c, d) => Row(children: [
                _Swatch(d.s('themeColor')),
                const SizedBox(width: 12),
                Expanded(child: TwoLine(d.s('name', d.id), d.s('tagline'))),
              ])),
          Col<Doc>('ID', flex: 2, text: (d) => d.id),
          Col<Doc>('Colour', flex: 2, text: (d) => d.s('themeColor')),
          Col<Doc>('Order', flex: 1, numeric: true, text: (d) => '${d.i('order')}', sort: (d) => d.n('order')),
        ],
        card: (c, d) => _ModuleCard(d),
      ));
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.hex, {this.size = 40});
  final String hex;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = G4MColors.fromHex(hex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, .25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(Icons.storefront_rounded, color: Colors.white, size: size * .5),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard(this.d);
  final Doc d;
  @override
  Widget build(BuildContext context) {
    final c = G4MColors.fromHex(d.s('themeColor'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 96,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, .3)!])),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(d.s('name', d.id), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.s('tagline', '—'), style: TextStyle(color: context.pal.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Tag(d.b('enabled', true) ? 'Enabled' : 'Disabled', color: d.b('enabled', true) ? G4MColors.success : G4MColors.danger),
            const SizedBox(width: 6),
            Tag('#${d.i('order') + 1}'),
            const Spacer(),
            Text(d.s('themeColor'), style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ]),
      ),
    ]);
  }
}

// ───────────────────────── Theme ─────────────────────────

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'Theme',
        subtitle: 'Brand colours for the website and apps',
        sections: [
          SettingsSection('Brand colours', Icons.palette_rounded, const [
            F('theme.primary', 'Primary colour', FT.color, help: 'Buttons, links, highlights'),
            F('theme.accent', 'Accent colour', FT.color, help: 'Offers, badges, hot CTAs'),
            F('theme.useModuleColors', 'Use module colours', FT.toggle, help: 'Each module re-themes the storefront with its own colour'),
          ], preview: (c, v) => _ThemePreview(
                primary: G4MColors.fromHex('${getPath(v, 'theme.primary') ?? ''}', G4MColors.primary),
                accent: G4MColors.fromHex('${getPath(v, 'theme.accent') ?? ''}', G4MColors.accent),
              )),
          const SettingsSection('Module colours', Icons.widgets_rounded, [],
              subtitle: 'Saved instantly to each module', extra: _ModuleColours()),
        ],
      );
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.primary, required this.accent});
  final Color primary, accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.pal.surfaceAlt, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Go', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color.lerp(primary, Colors.black, .4))),
            Text('4', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: accent)),
            Text('Market', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: primary)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(12)),
            child: const Text('Fresh groceries in 15 minutes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: primary), onPressed: () {}, child: Text(tr('Add to cart')))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
              child: const Text('20% OFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      );
}

class _ModuleColours extends StatelessWidget {
  const _ModuleColours();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Doc>>(
        stream: liveDocs(Fs.modules.orderBy('order'), fallback: Fs.modules, sortField: 'order', desc: false, label: 'modules'),
        builder: (context, s) {
          final mods = s.data;
          if (mods == null) return const LoadingBlock(rows: 2);
          if (mods.isEmpty) return Text('No modules yet', style: TextStyle(color: context.pal.muted));
          return ResponsiveGrid(minItemWidth: 260, children: [
            for (final m in mods)
              Row(children: [
                _Swatch(m.s('themeColor'), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: ColorField(
                    label: m.s('name', m.id),
                    value: m.s('themeColor'),
                    onChanged: (hex) {
                      if (hex.isEmpty) return;
                      runToast(() => m.ref!.update({'themeColor': hex, 'updatedAt': FieldValue.serverTimestamp()}), success: '${m.s('name')} colour saved');
                    },
                  ),
                ),
              ]),
          ]);
        },
      );
}

// ───────────────────────── SEO / Social / App versions ─────────────────────────

class SeoSettingsPage extends StatelessWidget {
  const SeoSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'SEO',
        subtitle: 'Default meta tags for the customer website (the sitemap is generated automatically)',
        sections: [
          SettingsSection('Search engines', Icons.travel_explore_rounded, [
            F('seo.title', 'Meta title', FT.text, required: true, help: 'Ideal: 50–60 characters', validator: (v, _) => '${v ?? ''}'.length > 70 ? 'Keep it under 70 characters' : null),
            F('seo.description', 'Meta description', FT.multiline, help: 'Ideal: 120–160 characters', validator: (v, _) => '${v ?? ''}'.length > 200 ? 'Keep it under 200 characters' : null),
            const F('seo.keywords', 'Keywords', FT.text, wide: true, help: 'Comma separated'),
          ], preview: (c, v) => _GooglePreview(v)),
          SettingsSection('Social sharing', Icons.share_rounded, const [
            F('seo.ogImage', 'Share image (1200×630)', FT.image, folder: 'seo', aspect: 1200 / 630),
          ], preview: (c, v) => _SocialCardPreview(v)),
        ],
      );
}

class _GooglePreview extends StatelessWidget {
  const _GooglePreview(this.v);
  final Map<String, dynamic> v;
  @override
  Widget build(BuildContext context) {
    final t = '${getPath(v, 'seo.title') ?? ''}';
    final d = '${getPath(v, 'seo.description') ?? ''}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Google preview', style: TextStyle(color: context.pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text('go4market.web.app', style: TextStyle(fontSize: 12.5, color: context.pal.muted)),
        Text(t.isEmpty ? 'Go4Market — Everything you need, delivered fast' : t,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1A0DAB), fontSize: 18)),
        const SizedBox(height: 2),
        Text(d.isEmpty ? 'Add a meta description to control this snippet.' : d,
            maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.pal.muted, height: 1.4)),
        const SizedBox(height: 8),
        Text('${t.length}/60 title · ${d.length}/160 description', style: TextStyle(fontSize: 11, color: context.pal.faint)),
      ]),
    );
  }
}

class _SocialCardPreview extends StatelessWidget {
  const _SocialCardPreview(this.v);
  final Map<String, dynamic> v;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.line), color: context.pal.surface),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 1200 / 630, child: NetImage('${getPath(v, 'seo.ogImage') ?? ''}')),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GO4MARKET.WEB.APP', style: TextStyle(fontSize: 11, color: context.pal.muted)),
              Text('${getPath(v, 'seo.title') ?? 'Go4Market'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
}

class SocialSettingsPage extends StatelessWidget {
  const SocialSettingsPage({super.key});
  static const nets = [
    ('facebook', 'Facebook', Icons.facebook_rounded, Color(0xFF1877F2)),
    ('instagram', 'Instagram', Icons.camera_alt_rounded, Color(0xFFE1306C)),
    ('x', 'X (Twitter)', Icons.alternate_email_rounded, Color(0xFF111111)),
    ('youtube', 'YouTube', Icons.smart_display_rounded, Color(0xFFFF0000)),
    ('linkedin', 'LinkedIn', Icons.work_rounded, Color(0xFF0A66C2)),
    ('whatsapp', 'WhatsApp', Icons.chat_rounded, Color(0xFF25D366)),
  ];
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'Social links',
        subtitle: 'Icons shown in the website footer and app profile',
        sections: [
          SettingsSection(
            'Profiles',
            Icons.share_rounded,
            [for (final n in nets) F('social.${n.$1}', n.$2, FT.text, hint: 'https://…', validator: (v, _) => _url(v))],
            preview: (c, v) => Wrap(spacing: 10, runSpacing: 10, children: [
              for (final n in nets)
                Opacity(
                  opacity: '${getPath(v, 'social.${n.$1}') ?? ''}'.isEmpty ? .25 : 1,
                  child: Tooltip(
                    message: n.$2,
                    child: CircleAvatar(radius: 22, backgroundColor: n.$4, child: Icon(n.$3, color: Colors.white, size: 20)),
                  ),
                ),
            ]),
          ),
        ],
      );
}

String? _url(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  return s.startsWith('http://') || s.startsWith('https://') ? null : 'Must start with https://';
}

String? _ver(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  return RegExp(r'^\d+(\.\d+){0,3}(\+\d+)?$').hasMatch(s) ? null : 'Use a version like 1.4.2';
}

class AppVersionsPage extends StatelessWidget {
  const AppVersionsPage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'App versions',
        subtitle: 'Apps below the minimum version are forced to update',
        sections: [
          SettingsSection('Customer app', Icons.phone_iphone_rounded, [
            F('appVersions.customer.latest', 'Latest version', FT.text, hint: '1.0.0', validator: (v, _) => _ver(v)),
            F('appVersions.customer.min', 'Minimum supported (force update)', FT.text, hint: '1.0.0', validator: (v, _) => _ver(v)),
            F('appVersions.customer.playStoreUrl', 'Play Store URL', FT.text, validator: (v, _) => _url(v)),
            F('appVersions.customer.appStoreUrl', 'App Store URL', FT.text, validator: (v, _) => _url(v)),
          ]),
          SettingsSection('Partner app (seller + delivery)', Icons.delivery_dining_rounded, [
            F('appVersions.partner.latest', 'Latest version', FT.text, hint: '1.0.0', validator: (v, _) => _ver(v)),
            F('appVersions.partner.min', 'Minimum supported (force update)', FT.text, hint: '1.0.0', validator: (v, _) => _ver(v)),
            F('appVersions.partner.playStoreUrl', 'Play Store URL', FT.text, validator: (v, _) => _url(v)),
            F('appVersions.partner.appStoreUrl', 'App Store URL', FT.text, validator: (v, _) => _url(v)),
          ]),
          const SettingsSection('Update prompt', Icons.system_update_rounded, [
            F('appVersions.message', 'Message shown on the update screen', FT.multiline, hint: 'A new version of Go4Market is available…'),
          ]),
        ],
      );
}

// ───────────────────────── Demo & maintenance ─────────────────────────

class SystemModePage extends StatelessWidget {
  const SystemModePage({super.key});
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.platformSettings,
        title: 'Demo & maintenance',
        banner: const InfoBanner(
          'Maintenance mode blocks checkout and shows a maintenance screen on the website and apps. '
          'Admin, seller and delivery panels keep working.',
          color: G4MColors.warning,
          icon: Icons.warning_amber_rounded,
        ),
        sections: [
          SettingsSection('Maintenance', Icons.construction_rounded, const [
            F('maintenance', 'Maintenance mode', FT.toggle, help: 'Customers see the maintenance message'),
            F('maintenanceMessage', 'Maintenance message', FT.multiline, hint: "We're upgrading Go4Market. Back shortly!"),
          ], preview: (c, v) => _ModeBadge(v['maintenance'] == true, 'Storefront is in maintenance', 'Storefront is live')),
          SettingsSection('Demo mode', Icons.science_rounded, const [
            F('demoMode', 'Demo mode', FT.toggle, help: 'Login screens show and prefill the demo accounts below'),
            F.section('Demo logins', help: 'Shown publicly on login screens while demo mode is on — use demo accounts only.'),
            F('demo.customer.email', 'Customer email', FT.email),
            F('demo.customer.password', 'Customer password', FT.text),
            F('demo.seller.email', 'Seller email', FT.email),
            F('demo.seller.password', 'Seller password', FT.text),
            F('demo.delivery.email', 'Delivery email', FT.email),
            F('demo.delivery.password', 'Delivery password', FT.text),
          ], preview: (c, v) => _ModeBadge(v['demoMode'] == true, 'Demo mode is ON', 'Demo mode is off')),
        ],
      );
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge(this.on, this.onText, this.offText);
  final bool on;
  final String onText, offText;
  @override
  Widget build(BuildContext context) {
    final c = on ? G4MColors.warning : G4MColors.success;
    return AnimatedContainer(
      duration: G4MMotion.standard,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: .4))),
      child: Row(children: [
        Icon(on ? Icons.toggle_on_rounded : Icons.check_circle_rounded, color: c, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Text(on ? onText : offText, style: TextStyle(fontWeight: FontWeight.w800, color: c))),
      ]),
    );
  }
}

// ───────────────────────── Communication ─────────────────────────

class CommunicationSettingsPage extends StatelessWidget {
  const CommunicationSettingsPage({super.key});
  static const events = [
    ('placed', 'Order placed'),
    ('confirmed', 'Confirmed'),
    ('packed', 'Packed'),
    ('assigned', 'Rider assigned'),
    ('picked_up', 'Picked up'),
    ('out_for_delivery', 'Out for delivery'),
    ('ready_for_pickup', 'Ready for pickup'),
    ('delivered', 'Delivered'),
    ('cancelled', 'Cancelled'),
    ('returned', 'Returned'),
    ('refund', 'Refund issued'),
    ('withdrawal', 'Withdrawal processed'),
    ('welcome', 'Welcome / signup'),
  ];
  @override
  Widget build(BuildContext context) => SettingsDocPage(
        ref: Fs.db.doc('settings/communication'),
        title: 'Communication',
        subtitle: 'Email, SMS and push notifications sent by Cloud Functions',
        banner: const InfoBanner(
          'SMTP passwords and SMS API tokens are secrets and are configured in the Cloud Functions environment, not here. '
          'This page controls sender identity and which events trigger which channel.',
          icon: Icons.shield_outlined,
        ),
        sections: [
          const SettingsSection('Email', Icons.email_rounded, [
            F('email.enabled', 'Send transactional emails', FT.toggle),
            F('email.fromName', 'Sender name', FT.text, hint: 'Go4Market'),
            F('email.fromAddress', 'From address', FT.email, hint: 'no-reply@go4market.com'),
            F('email.replyTo', 'Reply-to', FT.email),
            F('email.adminCopy', 'Send admin a copy of new orders to', FT.email),
          ]),
          SettingsSection('SMS gateway', Icons.sms_rounded, [
            F('_smsStatus', 'Active provider', FT.custom, wide: true, builder: (c, v, on, vals) => const _SmsGatewayStatus()),
            const F('sms.enabled', 'Send SMS', FT.toggle, help: 'OTP and order updates'),
            const F('sms.provider', 'Fallback provider', FT.select,
                options: {'twilio': 'Twilio', 'msg91': 'MSG91', 'fast2sms': 'Fast2SMS', 'none': 'None'},
                help: 'Used only when SMS_PROVIDER in functions/.env is empty. The server setting wins.'),
            const F('sms.senderId', 'Sender ID / from number', FT.text),
            const F('sms.dltEntityId', 'DLT entity ID (India)', FT.text),
          ]),
          const SettingsSection('Push (FCM)', Icons.notifications_active_rounded, [
            F('push.enabled', 'Send push notifications', FT.toggle),
            F('push.riderOrderAlerts', 'Alert nearby riders about new orders', FT.toggle),
          ]),
          SettingsSection('Event matrix', Icons.grid_on_rounded, [
            F('events', 'Events', FT.custom, wide: true, builder: (c, v, on, vals) => _EventMatrix(value: v, onChanged: on)),
          ], subtitle: 'Choose which channels fire for every order status and account event'),
        ],
      );
}

class _EventMatrix extends StatelessWidget {
  const _EventMatrix({required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  static const channels = ['email', 'sms', 'push'];

  bool _get(String e, String ch) {
    final m = value is Map ? value as Map : const {};
    final row = m[e];
    if (row is Map && row[ch] is bool) return row[ch] as bool;
    // Unset defaults mirror the backend: SMS is on for the events the functions hook (unset = on).
    return ch == 'push' ||
        (ch == 'email' && const {'placed', 'delivered', 'cancelled', 'welcome', 'withdrawal'}.contains(e)) ||
        (ch == 'sms' && smsHooked.contains(e));
  }

  /// Events the backend queues SMS for (`settings/communication.events.{event}.sms`).
  static const smsHooked = {'placed', 'out_for_delivery', 'ready_for_pickup', 'delivered', 'cancelled', 'withdrawal'};

  void _set(String e, String ch, bool on) {
    final m = <String, dynamic>{};
    for (final ev in CommunicationSettingsPage.events) {
      m[ev.$1] = {for (final c in channels) c: _get(ev.$1, c)};
    }
    (m[e] as Map)[ch] = on;
    onChanged(m);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: context.pal.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Expanded(flex: 3, child: Text('EVENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6))),
              for (final c in channels)
                Expanded(child: Center(child: Text(c.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)))),
            ]),
          ),
          for (final e in CommunicationSettingsPage.events)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.line))),
              child: Row(children: [
                Expanded(flex: 3, child: Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w600))),
                for (final c in channels)
                  Expanded(child: Center(child: Checkbox(value: _get(e.$1, c), onChanged: (v) => _set(e.$1, c, v ?? false)))),
              ]),
            ),
        ]),
      );
}

/// Read-only view of the server-side SMS gateway (`getSystemStatus.integrations`) + test send.
class _SmsGatewayStatus extends StatefulWidget {
  const _SmsGatewayStatus();
  @override
  State<_SmsGatewayStatus> createState() => _SmsGatewayStatusState();
}

class _SmsGatewayStatusState extends State<_SmsGatewayStatus> {
  late Future<Map<String, dynamic>> _status = _load();

  Future<Map<String, dynamic>> _load() async {
    final r = await G4MApi.instance.call('getSystemStatus');
    final i = r['integrations'];
    return i is Map ? Map<String, dynamic>.from(i) : const {};
  }

  static const _names = {'twilio': 'Twilio', 'msg91': 'MSG91', 'fast2sms': 'Fast2SMS', 'none': 'None', '': 'Not configured'};

  Future<void> _sendTest() async {
    final to = await promptText(context, 'Send test SMS', label: 'Mobile number (+91 default)', required: true, confirmLabel: 'Send');
    if (to == null || !mounted) return;
    try {
      final ref = await Fs.db.collection('smsOutbox').add({
        'to': to,
        'text': 'Go4Market test SMS. If you received this, the SMS gateway works.',
        'event': 'test',
        'test': true,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
      toast(tr('Test SMS queued'), kind: ToastKind.info);
      // Watch the outbox doc until the onSmsQueued trigger settles it.
      final done = await ref
          .snapshots()
          .map((s) => s.data() ?? const {})
          .firstWhere((d) => '${d['status'] ?? 'queued'}' != 'queued' && '${d['status']}' != 'sending')
          .timeout(const Duration(seconds: 60));
      final st = '${done['status']}';
      final err = '${done['error'] ?? ''}';
      toast(st == 'sent' ? tr('Test SMS sent') : '${tr('Test SMS')}: $st${err.isEmpty ? '' : ' — $err'}', kind: st == 'sent' ? ToastKind.success : ToastKind.error);
    } on TimeoutException {
      toast(tr('Still queued after 60 s — check smsOutbox'), kind: ToastKind.error);
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _status,
        builder: (context, s) {
          final i = s.data ?? const {};
          final provider = '${i['smsProvider'] ?? ''}';
          final ready = i['sms'] == true;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.pal.surfaceAlt.withValues(alpha: .6), borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(tr('Active provider'), style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w600)),
                if (s.connectionState != ConnectionState.done)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                else if (s.hasError)
                  Tag(tr('Status unavailable'), color: G4MColors.warning)
                else ...[
                  Text(_names[provider] ?? provider, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Tag(ready ? 'Ready' : 'Not ready', color: ready ? G4MColors.success : G4MColors.danger, icon: ready ? Icons.check_rounded : Icons.close_rounded),
                ],
                IconButton(tooltip: S.refresh, onPressed: () => setState(() => _status = _load()), icon: const Icon(Icons.refresh_rounded, size: 18)),
                OutlinedButton.icon(onPressed: _sendTest, icon: const Icon(Icons.send_rounded, size: 16), label: Text(tr('Send test SMS'))),
              ]),
              const SizedBox(height: 6),
              Text(
                tr('Chosen server-side by SMS_PROVIDER in functions/.env. API keys live in Secret Manager, not in this page.'),
                style: TextStyle(fontSize: 12, color: context.pal.muted),
              ),
            ]),
          );
        },
      );
}

// ───────────────────────── Languages ─────────────────────────

class LanguagesPage extends StatelessWidget {
  const LanguagesPage({super.key});

  Future<void> _uploadJson(Doc d) async {
    final files = await pickFiles(extensions: ['json']);
    if (files.isEmpty) return;
    final (name, bytes) = files.first;
    await runToast(() async {
      final url = await StorageRepo.instance.upload('i18n', '${d.id}.json', bytes, contentType: 'application/json');
      await d.ref!.update({'translationsUrl': url, 'translationsUpdatedAt': FieldValue.serverTimestamp(), 'translationsFile': name});
    }, success: 'Translations uploaded for ${d.s('name', d.id)}');
  }

  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'languages',
        title: 'Languages',
        subtitle: 'Languages offered on the website and apps, with translation files',
        singular: 'Language',
        collection: Fs.languages,
        idFrom: (v) => '${v['code'] ?? ''}'.trim().toLowerCase(),
        labelOf: (d) => d.s('name', d.id),
        search: (d) => '${d.id} ${d.s('name')} ${d.s('nativeName')}',
        sortField: 'name',
        sortDesc: false,
        fields: [
          F('code', 'Language code', FT.text,
              required: true, hint: 'en, hi, ar…', visibleIf: (v) => v['createdAt'] == null,
              validator: (v, _) => RegExp(r'^[a-zA-Z]{2,3}(-[a-zA-Z]{2})?$').hasMatch('${v ?? ''}') ? null : 'ISO code like en or en-IN'),
          const F('name', 'Name (English)', FT.text, required: true, hint: 'Hindi'),
          const F('nativeName', 'Native name', FT.text, hint: 'हिन्दी'),
          const F('rtl', 'Right-to-left (RTL)', FT.toggle, help: 'Arabic, Urdu, Hebrew…'),
          const F('isDefault', 'Default language', FT.toggle),
        ],
        afterSave: (id, v, _) async {
          if (v['isDefault'] == true) {
            final others = await Fs.languages.where('isDefault', isEqualTo: true).get();
            final b = Fs.db.batch();
            for (final o in others.docs.where((o) => o.id != id)) {
              b.update(o.reference, {'isDefault': false});
            }
            await b.commit();
          }
        },
        extraActions: [
          RowAction('Upload translations JSON', Icons.upload_file_rounded, _uploadJson),
          RowAction('Make default', Icons.star_rounded, (d) => runToast(() async {
                final b = Fs.db.batch();
                for (final o in (await Fs.languages.get()).docs) {
                  b.update(o.reference, {'isDefault': o.id == d.id});
                }
                await b.commit();
              }, success: '${d.s('name')} is now the default'), visible: (d) => !d.b('isDefault')),
        ],
        columns: [
          Col<Doc>('Language', flex: 4, text: (d) => d.s('name'), cell: (c, d) => Row(children: [
                CircleAvatar(radius: 18, child: Text(d.id.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(child: TwoLine(d.s('name', d.id), d.s('nativeName'))),
                if (d.b('isDefault')) Tag('Default', color: G4MColors.primary, icon: Icons.star_rounded),
              ])),
          Col<Doc>('Direction', flex: 2, text: (d) => d.b('rtl') ? 'RTL' : 'LTR', cell: (c, d) => Tag(d.b('rtl') ? 'RTL' : 'LTR', color: d.b('rtl') ? G4MColors.info : null)),
          Col<Doc>('Translations', flex: 3, text: (d) => d.s('translationsUrl').isEmpty ? 'Missing' : 'Uploaded',
              cell: (c, d) => d.s('translationsUrl').isEmpty
                  ? Tag('No file', color: G4MColors.warning)
                  : Tag('Updated ${Fmt.ago(d.dt('translationsUpdatedAt'))}', color: G4MColors.success, icon: Icons.check_rounded)),
        ],
      ));
}

// ───────────────────────── Cities ─────────────────────────

class CitiesPage extends StatelessWidget {
  const CitiesPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'cities',
        title: 'Cities & zones',
        subtitle: 'Serviceable cities. Tap the map to set the centre; the circle shows the delivery radius.',
        singular: 'City',
        collection: Fs.cities,
        sortField: 'name',
        sortDesc: false,
        editorWidth: 760,
        labelOf: (d) => d.s('name'),
        search: (d) => '${d.s('name')} ${d.s('state')} ${d.s('zone')}',
        fields: [
          const F('name', 'City', FT.text, required: true),
          const F('state', 'State', FT.text, required: true),
          const F('zone', 'Zone / area label', FT.text),
          const F('radiusKm', 'Delivery radius (km)', FT.number, required: true, min: 0.5, max: 200, initial: 10),
          const F('deliveryFee', 'City delivery fee override', FT.money, help: 'Empty = platform default'),
          const F('minFreeDelivery', 'Free delivery above (override)', FT.money),
          const F('minutesPerKm', 'Minutes per km (ETA)', FT.number, initial: 3),
          F('lat', 'Location', FT.custom, wide: true, required: true, builder: (c, v, on, vals) => _CityMapPicker(values: vals, onPicked: on)),
        ],
        beforeSave: (v, _) {
          if (v['lat'] == null || v['lng'] == null) throw 'Tap the map to set the city location';
          v['lat'] = toNum(v['lat']);
          v['lng'] = toNum(v['lng']);
          return v;
        },
        columns: [
          Col<Doc>('City', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), [d.s('zone'), d.s('state')].where((e) => e.isNotEmpty).join(' · '))),
          Col<Doc>('Radius', flex: 1, numeric: true, text: (d) => '${d.n('radiusKm').toStringAsFixed(0)} km', sort: (d) => d.n('radiusKm')),
          Col<Doc>('Centre', flex: 2, text: (d) => d['lat'] == null ? '—' : '${d.n('lat').toStringAsFixed(4)}, ${d.n('lng').toStringAsFixed(4)}'),
          Col<Doc>('Fee', flex: 1, numeric: true, text: (d) => d['deliveryFee'] == null ? 'Default' : Fmt.money(d.n('deliveryFee'))),
        ],
        card: (c, d) => _CityCard(d),
      ));
}

class _CityMapPicker extends StatelessWidget {
  const _CityMapPicker({required this.values, required this.onPicked});
  final Map<String, dynamic> values;
  final ValueChanged<dynamic> onPicked;
  @override
  Widget build(BuildContext context) {
    final has = values['lat'] != null && values['lng'] != null;
    final center = has ? LatLng(toNum(values['lat']), toNum(values['lng'])) : const LatLng(19.0760, 72.8777);
    final r = toNum(values['radiusKm'], 10);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Location *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const Spacer(),
        Text(has ? '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}' : 'Tap the map to set the city centre',
            style: TextStyle(color: has ? context.pal.ink : G4MColors.warning, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 320,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: has ? 10.5 : 4.5,
              onTap: (_, p) {
                values['lng'] = double.parse(p.longitude.toStringAsFixed(6));
                onPicked(double.parse(p.latitude.toStringAsFixed(6)));
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
              if (has)
                CircleLayer(circles: [
                  CircleMarker(
                    point: center,
                    radius: r * 1000,
                    useRadiusInMeter: true,
                    color: context.pal.accent.withValues(alpha: .15),
                    borderColor: context.pal.accent,
                    borderStrokeWidth: 2,
                  ),
                ]),
              if (has)
                MarkerLayer(markers: [
                  Marker(point: center, width: 40, height: 40, child: Icon(Icons.location_on_rounded, color: context.pal.accent, size: 40)),
                ]),
              const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text('Tap anywhere on the map to move the centre. The circle shows the delivery radius.', style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
    ]);
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard(this.d);
  final Doc d;
  @override
  Widget build(BuildContext context) {
    final has = d['lat'] != null;
    final p = LatLng(d.n('lat'), d.n('lng'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 140,
        child: has
            ? IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: p, initialZoom: 9.5),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
                    CircleLayer(circles: [
                      CircleMarker(point: p, radius: d.n('radiusKm', 10) * 1000, useRadiusInMeter: true, color: context.pal.accent.withValues(alpha: .15), borderColor: context.pal.accent, borderStrokeWidth: 2),
                    ]),
                  ],
                ),
              )
            : Container(color: context.pal.surfaceAlt, child: Icon(Icons.map_outlined, color: context.pal.faint, size: 40)),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(child: TwoLine(d.s('name'), d.s('state'))),
          Tag('${d.n('radiusKm').toStringAsFixed(0)} km', icon: Icons.radar_rounded),
        ]),
      ),
    ]);
  }
}

// ───────────────────────── Countries ─────────────────────────

class CountriesPage extends StatelessWidget {
  const CountriesPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'countries',
        title: 'Countries',
        subtitle: 'Countries for phone numbers and addresses',
        singular: 'Country',
        collection: Fs.col('countries'),
        idFrom: (v) => '${v['code'] ?? ''}'.trim().toUpperCase(),
        sortField: 'name',
        sortDesc: false,
        labelOf: (d) => d.s('name'),
        search: (d) => '${d.s('name')} ${d.s('code')} ${d.s('dialCode')}',
        fields: [
          const F('name', 'Country', FT.text, required: true),
          F('code', 'ISO code', FT.text,
              required: true, uppercase: true, hint: 'IN', visibleIf: (v) => v['createdAt'] == null,
              validator: (v, _) => RegExp(r'^[A-Za-z]{2}$').hasMatch('${v ?? ''}') ? null : '2-letter ISO code'),
          F('dialCode', 'Dial code', FT.text, required: true, hint: '+91', validator: (v, _) => RegExp(r'^\+\d{1,4}$').hasMatch('${v ?? ''}') ? null : 'Like +91'),
          const F('currency', 'Currency', FT.text, uppercase: true, hint: 'INR'),
          const F('flag', 'Flag', FT.image, folder: 'countries', aspect: 3 / 2),
        ],
        leading: (c, d) => RowThumb(d.s('flag'), icon: Icons.flag_outlined),
        columns: [
          Col<Doc>('Country', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), d.id)),
          textCol('Dial code', 'dialCode'),
          textCol('Currency', 'currency'),
        ],
      ));
}
