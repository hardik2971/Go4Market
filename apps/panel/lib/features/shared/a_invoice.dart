import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../../core/doc.dart';
import '../../ui/data_view.dart';
import 'a_common.dart';
import 'package:panel/l10n/overrides.dart';

String _m(num v) => Fmt.money(v);

const _css = '''
*{box-sizing:border-box}body{font-family:"Plus Jakarta Sans",Segoe UI,Roboto,Arial,sans-serif;color:#0F1A14;margin:0;padding:32px;background:#fff}
.wrap{max-width:820px;margin:0 auto}.head{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:3px solid #0B8A4F;padding-bottom:18px}
.brand{font-size:30px;font-weight:800;letter-spacing:-1px;color:#0A4A33}.brand .f{color:#F7860F}.brand .m{color:#0B8A4F}
.muted{color:#5B6B62;font-size:12.5px;line-height:1.5}h1{font-size:22px;margin:0 0 4px;text-align:right}
.grid{display:flex;gap:24px;margin:22px 0}.grid>div{flex:1}.label{font-size:11px;letter-spacing:.8px;text-transform:uppercase;color:#94A39A;font-weight:700;margin-bottom:4px}
table{width:100%;border-collapse:collapse;margin-top:8px}th{background:#F0F5F2;text-align:left;font-size:11.5px;text-transform:uppercase;letter-spacing:.6px;padding:10px;color:#5B6B62}
td{padding:10px;border-bottom:1px solid #E3EBE6;font-size:13.5px;vertical-align:top}.r{text-align:right}.seller{background:#FAFCFB;font-weight:700;color:#0A4A33}
.tot{margin-left:auto;width:320px;margin-top:16px}.tot div{display:flex;justify-content:space-between;padding:5px 0;font-size:13.5px}
.tot .g{border-top:2px solid #0F1A14;margin-top:6px;padding-top:10px;font-size:17px;font-weight:800}
.foot{margin-top:40px;padding-top:14px;border-top:1px dashed #E3EBE6;text-align:center;font-size:12px;color:#5B6B62}
.badge{display:inline-block;padding:3px 10px;border-radius:99px;font-size:11.5px;font-weight:700;background:#E6F4EC;color:#0B8A4F}
@media print{body{padding:0}.noprint{display:none}}
''';

/// Full A4 tax invoice.
String invoiceHtml(ShopOrder o, Map<String, dynamic> settings) {
  final s = Doc('platform', settings);
  final groups = <String, List<OrderItem>>{};
  for (final i in o.items) {
    groups.putIfAbsent(i.sellerName.isEmpty ? 'Go4Market' : i.sellerName, () => []).add(i);
  }
  final a = Address('a', o.address);
  final taxPct = s.n('taxPct');
  final rows = StringBuffer();
  var n = 0;
  for (final g in groups.entries) {
    rows.write('<tr><td colspan="5" class="seller">Sold by ${htmlEsc(g.key)}</td></tr>');
    for (final i in g.value) {
      n++;
      rows.write('<tr><td>$n</td><td>${htmlEsc(i.name)}${i.variantName.isNotEmpty ? '<div class="muted">${htmlEsc(i.variantName)}</div>' : ''}</td>'
          '<td class="r">${i.qty}</td><td class="r">${_m(i.price)}</td><td class="r">${_m(i.lineTotal)}</td></tr>');
    }
  }
  final half = o.tax / 2;
  return '''<!doctype html><html><head><meta charset="utf-8"><title>Invoice ${htmlEsc(o.orderNo)}</title><style>$_css</style></head><body><div class="wrap">
<div class="head"><div><div class="brand">Go<span class="f">4</span><span class="m">Market</span></div>
<div class="muted">${htmlEsc(s.s('address'))}<br>${htmlEsc(s.s('contactEmail'))} ${htmlEsc(s.s('contactPhone'))}${s.s('gstin').isNotEmpty ? '<br>GSTIN: ${htmlEsc(s.s('gstin'))}' : ''}</div></div>
<div><h1>TAX INVOICE</h1><div class="muted" style="text-align:right">Invoice # ${htmlEsc(o.orderNo)}<br>Date: ${Fmt.dateTime(o.createdAt)}<br><span class="badge">${htmlEsc(Fmt.titleCase(o.paymentStatus))}</span></div></div></div>
<div class="grid"><div><div class="label">Billed to</div><b>${htmlEsc(o.customerName)}</b><div class="muted">${htmlEsc(o.customerPhone)}<br>${htmlEsc(o.customer['email'] ?? '')}</div></div>
<div><div class="label">${o.deliveryType == 'pickup' ? 'Fulfilment' : 'Ship to'}</div>${o.deliveryType == 'pickup' ? '<b>Self pickup</b>' : o.channel == 'pos' ? '<b>In-store purchase</b>' : '<b>${htmlEsc(a.name.isEmpty ? o.customerName : a.name)}</b><div class="muted">${htmlEsc(a.oneLine)}</div>'}</div>
<div><div class="label">Payment</div><b>${htmlEsc(Fmt.titleCase(o.paymentMethod))}</b><div class="muted">${htmlEsc(o.data['paymentRef'] ?? '')}<br>Channel: ${htmlEsc(Fmt.titleCase(o.channel))}</div></div></div>
<table><thead><tr><th style="width:36px">#</th><th>Item</th><th class="r">Qty</th><th class="r">Price</th><th class="r">Amount</th></tr></thead><tbody>$rows</tbody></table>
<div class="tot"><div><span>Subtotal</span><span>${_m(o.subtotal)}</span></div>
<div><span>Delivery</span><span>${_m(o.deliveryFee)}</span></div>
${o.discount > 0 ? '<div><span>Discount${o.couponCode.isNotEmpty ? ' (${htmlEsc(o.couponCode)})' : ''}</span><span>− ${_m(o.discount)}</span></div>' : ''}
${o.tax > 0 ? '<div><span>CGST${taxPct > 0 ? ' (${(taxPct / 2).toStringAsFixed(1)}%)' : ''}</span><span>${_m(half)}</span></div><div><span>SGST${taxPct > 0 ? ' (${(taxPct / 2).toStringAsFixed(1)}%)' : ''}</span><span>${_m(o.tax - half)}</span></div>' : '<div><span>Tax</span><span>Included</span></div>'}
<div class="g"><span>Total</span><span>${_m(o.total)}</span></div>
${o.walletUsed > 0 ? '<div><span>Paid from wallet</span><span>− ${_m(o.walletUsed)}</span></div>' : ''}
<div><span><b>Amount payable</b></span><span><b>${_m(o.payable)}</b></span></div></div>
<div class="foot">Thank you for shopping with Go4Market. This is a computer generated invoice and does not require a signature.</div>
</div></body></html>''';
}

/// 80 mm thermal-style POS receipt.
String receiptHtml({
  required String orderNo,
  required List<(String name, String variant, int qty, double price)> lines,
  required double subtotal,
  required double discount,
  required double total,
  required String method,
  double? tendered,
  String customer = '',
  String storeName = 'Go4Market',
}) {
  final rows = lines
      .map((l) => '<tr><td>${htmlEsc(l.$1)}${l.$2.isNotEmpty ? '<br><small>${htmlEsc(l.$2)}</small>' : ''}<br><small>${l.$3} × ${_m(l.$4)}</small></td><td class="r">${_m(l.$3 * l.$4)}</td></tr>')
      .join();
  return '''<!doctype html><html><head><meta charset="utf-8"><title>Receipt $orderNo</title><style>
body{font-family:ui-monospace,Consolas,monospace;width:300px;margin:0 auto;padding:12px;color:#000;font-size:12.5px}
h2{text-align:center;margin:4px 0}.c{text-align:center}table{width:100%;border-collapse:collapse}td{padding:4px 0;vertical-align:top}.r{text-align:right}
hr{border:none;border-top:1px dashed #000;margin:8px 0}.t td{font-weight:bold;font-size:14px}@page{size:80mm auto;margin:4mm}
</style></head><body><h2>${htmlEsc(storeName)}</h2><div class="c">Go4Market POS<br>${Fmt.dateTime(DateTime.now())}<br>Receipt # ${htmlEsc(orderNo)}${customer.isNotEmpty ? '<br>Customer: ${htmlEsc(customer)}' : ''}</div><hr>
<table>$rows</table><hr><table><tr><td>Subtotal</td><td class="r">${_m(subtotal)}</td></tr>
${discount > 0 ? '<tr><td>Discount</td><td class="r">− ${_m(discount)}</td></tr>' : ''}
<tr class="t"><td>TOTAL</td><td class="r">${_m(total)}</td></tr><tr><td>Paid by</td><td class="r">${htmlEsc(method.toUpperCase())}</td></tr>
${tendered != null && tendered > 0 ? '<tr><td>Tendered</td><td class="r">${_m(tendered)}</td></tr><tr><td>Change</td><td class="r">${_m((tendered - total).clamp(0, double.infinity))}</td></tr>' : ''}
</table><hr><div class="c">Thank you! Visit again.<br>go4market.web.app</div></body></html>''';
}

/// On-screen invoice preview (paper look, always light).
class InvoicePreview extends StatelessWidget {
  const InvoicePreview({super.key, required this.order, required this.settings});
  final ShopOrder order;
  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final s = Doc('platform', settings);
    final a = Address('a', o.address);
    const ink = G4MColors.ink, muted = G4MColors.inkMuted;
    TextStyle t([double size = 13.5, FontWeight w = FontWeight.w500, Color c = ink]) => TextStyle(fontSize: size, fontWeight: w, color: c);
    Widget kv(String k, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Text(k, style: t(13.5, bold ? FontWeight.w800 : FontWeight.w500, bold ? ink : muted)), const Spacer(), Text(v, style: t(bold ? 16 : 13.5, bold ? FontWeight.w800 : FontWeight.w600))]),
        );
    return Theme(
      data: ThemeData.light(useMaterial3: true),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: G4MShadows.lifted),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const G4MWordmark(size: 36),
                const SizedBox(height: 8),
                Text([s.s('address'), s.s('contactEmail'), s.s('contactPhone')].where((e) => e.isNotEmpty).join('\n'), style: t(12.5, FontWeight.w500, muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('TAX INVOICE', style: t(22, FontWeight.w800)),
              Text('# ${o.orderNo}', style: t(13, FontWeight.w600, muted)),
              Text(Fmt.dateTime(o.createdAt), style: t(13, FontWeight.w500, muted)),
            ]),
          ]),
          const SizedBox(height: 16),
          Container(height: 3, color: G4MColors.primary),
          const SizedBox(height: 20),
          Wrap(spacing: 40, runSpacing: 16, children: [
            _block('BILLED TO', o.customerName, [o.customerPhone, '${o.customer['email'] ?? ''}']),
            _block(o.deliveryType == 'pickup' ? 'FULFILMENT' : 'SHIP TO', o.deliveryType == 'pickup' ? 'Self pickup' : (o.channel == 'pos' ? 'In-store' : (a.name.isEmpty ? o.customerName : a.name)),
                [if (o.deliveryType != 'pickup' && o.channel != 'pos') a.oneLine]),
            _block('PAYMENT', Fmt.titleCase(o.paymentMethod), [Fmt.titleCase(o.paymentStatus)]),
          ]),
          const SizedBox(height: 24),
          Container(
            color: G4MColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              Expanded(flex: 5, child: Text('ITEM', style: t(11, FontWeight.w800, muted))),
              Expanded(child: Text('QTY', textAlign: TextAlign.right, style: t(11, FontWeight.w800, muted))),
              Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.right, style: t(11, FontWeight.w800, muted))),
              Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: t(11, FontWeight.w800, muted))),
            ]),
          ),
          for (final i in o.items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: G4MColors.line))),
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: Row(children: [
                    RowThumb(i.image, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.name, style: t(13.5, FontWeight.w700)),
                      Text([i.variantName, if (i.sellerName.isNotEmpty) 'Sold by ${i.sellerName}'].where((e) => e.isNotEmpty).join(' · '), style: t(11.5, FontWeight.w500, muted)),
                    ])),
                  ]),
                ),
                Expanded(child: Text('${i.qty}', textAlign: TextAlign.right, style: t())),
                Expanded(flex: 2, child: Text(Fmt.money(i.price), textAlign: TextAlign.right, style: t())),
                Expanded(flex: 2, child: Text(Fmt.money(i.lineTotal), textAlign: TextAlign.right, style: t(13.5, FontWeight.w700))),
              ]),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 320,
              child: Column(children: [
                kv('Subtotal', Fmt.money(o.subtotal)),
                kv('Delivery', Fmt.money(o.deliveryFee)),
                if (o.discount > 0) kv('Discount${o.couponCode.isNotEmpty ? ' (${o.couponCode})' : ''}', '− ${Fmt.money(o.discount)}'),
                if (o.tax > 0) ...[kv('CGST', Fmt.money(o.tax / 2)), kv('SGST', Fmt.money(o.tax - o.tax / 2))],
                const Divider(color: ink, thickness: 1.5),
                kv('Total', Fmt.money(o.total), bold: true),
                if (o.walletUsed > 0) kv('Wallet', '− ${Fmt.money(o.walletUsed)}'),
                kv('Payable', Fmt.money(o.payable)),
              ]),
            ),
          ),
          const SizedBox(height: 32),
          Text('Thank you for shopping with Go4Market.', textAlign: TextAlign.center, style: t(12, FontWeight.w500, muted)),
        ]),
      ),
    );
  }

  Widget _block(String label, String title, List<String> lines) => SizedBox(
        width: 230,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, letterSpacing: .8, fontWeight: FontWeight.w800, color: G4MColors.inkFaint)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.ink)),
          for (final l in lines.where((e) => e.isNotEmpty)) Text(l, style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
        ]),
      );
}
