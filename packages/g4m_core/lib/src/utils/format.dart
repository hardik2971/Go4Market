import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/brand.dart';

abstract final class Fmt {
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _money2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

  /// ₹1,299 (whole rupees) or ₹1,299.50 when there are paise.
  static String money(num v) => v % 1 == 0 ? _money.format(v) : _money2.format(v);
  static String moneyCompact(num v) => _compact.format(v);
  static String date(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy, h:mm a').format(d);
  static String time(DateTime? d) => d == null ? '—' : DateFormat('h:mm a').format(d);
  static String number(num v) => NumberFormat.decimalPattern('en_IN').format(v);

  static String ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  static String titleCase(String s) => s
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static String slugify(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
}

/// Colour for any status string used across orders, sellers, withdrawals, returns.
Color statusColor(String status) => switch (status) {
      OrderStatus.delivered || 'approved' || 'active' || 'paid' || 'settled' || 'refunded' || 'credit' => G4MColors.success,
      OrderStatus.cancelled || 'rejected' || 'failed' || 'blocked' || 'suspended' || 'debit' => G4MColors.danger,
      OrderStatus.pending || 'requested' || 'open' => G4MColors.warning,
      OrderStatus.outForDelivery || OrderStatus.pickedUp || OrderStatus.assigned => G4MColors.accent,
      OrderStatus.returned => const Color(0xFF7C3AED),
      _ => G4MColors.info,
    };
