// Locale-aware stand-ins for g4m_core's Fmt, EmptyState and StatusChip.
// g4m_core is shared by four apps and hard-codes en_IN / English, so panel files import
// `package:g4m_core/g4m_core.dart` with `hide Fmt, EmptyState, StatusChip` and use these.
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' as core;
import 'package:intl/intl.dart';

import 'l10n.dart';

export 'l10n.dart' show tr, trf, lowerUi, S, L10n;

abstract final class Fmt {
  static final _cache = <String, Object>{};
  static T _f<T extends Object>(String key, T Function(String locale) make) {
    final l = L10n.instance.intlLocale;
    return _cache.putIfAbsent('$key|$l', () => make(l)) as T;
  }

  static NumberFormat get _money => _f('m0', (l) => NumberFormat.currency(locale: l, symbol: '₹', decimalDigits: 0));
  static NumberFormat get _money2 => _f('m2', (l) => NumberFormat.currency(locale: l, symbol: '₹', decimalDigits: 2));
  static NumberFormat get _compact => _f('mc', (l) => NumberFormat.compactCurrency(locale: l, symbol: '₹'));
  static NumberFormat get _num => _f('n', NumberFormat.decimalPattern);

  /// ₹1,299 (whole rupees) or ₹1,299.50 when there are paise. Per-locale grouping, ₹ always.
  static String money(num v) => v % 1 == 0 ? _money.format(v) : _money2.format(v);
  static String moneyCompact(num v) => _compact.format(v);
  static String date(DateTime? d) => d == null ? '—' : _f('d', (l) => DateFormat('d MMM yyyy', l)).format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : _f('dt', (l) => DateFormat('d MMM yyyy, h:mm a', l)).format(d);
  static String time(DateTime? d) => d == null ? '—' : _f('t', (l) => DateFormat('h:mm a', l)).format(d);
  static String number(num v) => _num.format(v);

  static String ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return S.justNow;
    if (diff.inMinutes < 60) return S.minAgo(diff.inMinutes);
    if (diff.inHours < 24) return S.hourAgo(diff.inHours);
    if (diff.inDays < 7) return S.dayAgo(diff.inDays);
    return date(d);
  }

  static String titleCase(String s) => core.Fmt.titleCase(s);
  static String slugify(String s) => core.Fmt.slugify(s);
}

/// Empty / error placeholder with translated title and message.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) =>
      core.EmptyState(icon: icon, title: tr(title), message: message == null ? null : tr(message!), action: action);
}

/// Status pill with a translated label.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;
  @override
  Widget build(BuildContext context) => core.StatusChip(status, label: tr(label ?? core.Fmt.titleCase(status)));
}
