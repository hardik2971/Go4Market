import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'category_picker.dart';
import 'seller_store.dart';

class _VariantRow {
  _VariantRow({String? id, String name = '', String price = '', String mrp = '', String stock = '', String sku = ''})
      : id = id ?? 'v${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        mrp = TextEditingController(text: mrp),
        stock = TextEditingController(text: stock),
        sku = TextEditingController(text: sku);
  final String id;
  final TextEditingController name, price, mrp, stock, sku;
  void dispose() {
    for (final c in [name, price, mrp, stock, sku]) {
      c.dispose();
    }
  }
}

class _FieldRow {
  _FieldRow([String k = '', String v = ''])
      : key = TextEditingController(text: k),
        value = TextEditingController(text: v);
  final TextEditingController key, value;
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

String _num(num v) => v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

/// Add / edit a product. Saves straight to `products/{id}` with status `pending`
/// (admin approval), as allowed for sellers by the security rules.
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final Product? p = widget.product;
  late final _name = TextEditingController(text: p?.name);
  late final _short = TextEditingController(text: p?.shortDescription);
  late final _desc = TextEditingController(text: p?.description);
  late final _price = TextEditingController(text: _num(p?.price ?? 0));
  late final _mrp = TextEditingController(text: _num(p?.mrp ?? 0));
  late final _stock = TextEditingController(text: p == null ? '' : '${p!.stock}');
  late final _lowAt = TextEditingController(text: '${p?.lowStockAt ?? 5}');
  late final _unit = TextEditingController(text: p?.unit);
  late final _minutes = TextEditingController(text: '${p?.deliveryMinutes ?? 30}');
  late final _barcode = TextEditingController(text: p?.barcode);
  late final _brand = TextEditingController(text: p?.brandName);
  late final _tags = TextEditingController(text: p?.tags.join(', '));
  late String _module = p?.moduleId ?? 'ecommerce';
  late String _categoryId = p?.categoryId ?? '';
  late List<String> _categoryPath = p?.categoryPath ?? const [];
  String _categoryLabel = '';
  late String _brandId = p?.brandId ?? '';
  late bool? _isVeg = p?.isVeg;
  late final List<String> _images = [...?p?.images];
  late final List<_VariantRow> _variants = [
    for (final v in p?.variants ?? const <Variant>[])
      _VariantRow(id: v.id, name: v.name, price: _num(v.price), mrp: _num(v.mrp), stock: '${v.stock}', sku: v.sku),
  ];
  late final List<_FieldRow> _fields = [for (final e in (p?.customFields ?? const <String, dynamic>{}).entries) _FieldRow(e.key, '${e.value}')];
  List<Json> _brands = [];
  List<Json> _attributes = [];
  bool _aiBusy = false;
  Timer? _typer;

  @override
  void initState() {
    super.initState();
    if (_categoryPath.isNotEmpty || _categoryId.isNotEmpty) {
      categoryBreadcrumb(_categoryPath.isEmpty ? [_categoryId] : _categoryPath).then((s) {
        if (mounted) setState(() => _categoryLabel = s);
      });
    }
    resilientGet<Json>([() => Fs.brands.where('active', isEqualTo: true).limit(300), () => Fs.brands.limit(300)], (d) => {...?d.data(), 'id': d.id})
        .then((b) => mounted ? setState(() => _brands = b) : null)
        .catchError((_) => null);
    Future.wait([
      resilientGet<Json>([() => Fs.attributes.where('sellerId', isEqualTo: myUid)], (d) => {...?d.data(), 'id': d.id}).catchError((_) => <Json>[]),
      resilientGet<Json>([() => Fs.attributes.where('sellerId', isNull: true)], (d) => {...?d.data(), 'id': d.id}).catchError((_) => <Json>[]),
    ]).then((r) {
      if (mounted) setState(() => _attributes = [...r[0], ...r[1]]);
    });
  }

  @override
  void dispose() {
    _typer?.cancel();
    for (final c in [_name, _short, _desc, _price, _mrp, _stock, _lowAt, _unit, _minutes, _barcode, _brand, _tags]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _showVeg => _module == 'food' || _module == 'grocery';

  Future<void> _addImage() async {
    final url = await pickAndUploadImage(context, 'products/$myUid');
    if (url != null) setState(() => _images.add(url));
  }

  Future<void> _ai() async {
    if (_name.text.trim().isEmpty) {
      toast(context, context.tr('Enter the product name first', 'पहले उत्पाद का नाम दर्ज करें'), error: true);
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final r = await G4MApi.instance.generateDescription({
        'name': _name.text.trim(),
        'category': _categoryLabel.split(' › ').last,
        'keywords': [
          ..._tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
          if (_brand.text.trim().isNotEmpty) _brand.text.trim(),
        ],
      });
      final short = '${r['short'] ?? r['shortDescription'] ?? ''}';
      final long = '${r['long'] ?? r['description'] ?? ''}';
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _typewrite(short, long);
    } catch (e) {
      if (mounted) toast(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _typewrite(String short, String long) {
    _typer?.cancel();
    _short.text = short;
    _desc.text = '';
    var i = 0;
    _typer = Timer.periodic(const Duration(milliseconds: 12), (t) {
      i = (i + 4).clamp(0, long.length);
      _desc.text = long.substring(0, i);
      if (i >= long.length) t.cancel();
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }
    if (_categoryId.isEmpty) {
      toast(context, context.tr('Choose a category', 'श्रेणी चुनें'), error: true);
      return;
    }
    final variants = [
      for (final v in _variants)
        if (v.name.text.trim().isNotEmpty)
          {
            'id': v.id,
            'name': v.name.text.trim(),
            'price': double.tryParse(v.price.text) ?? double.tryParse(_price.text) ?? 0,
            'mrp': double.tryParse(v.mrp.text) ?? double.tryParse(v.price.text) ?? 0,
            'stock': int.tryParse(v.stock.text) ?? 0,
            'sku': v.sku.text.trim(),
          },
    ];
    final price = double.tryParse(_price.text) ?? 0;
    final mrp = double.tryParse(_mrp.text) ?? price;
    final stock = variants.isEmpty ? (int.tryParse(_stock.text) ?? 0) : variants.fold<int>(0, (a, v) => a + (v['stock'] as int));
    final name = _name.text.trim();
    final ref = p == null ? Fs.products.doc() : Fs.products.doc(p!.id);
    final seller = SellerStore.instance.seller.value ?? (await Fs.sellers.doc(myUid).get().then((d) => d.exists ? Seller.fromDoc(d) : null).catchError((_) => null));
    final brandName = _brand.text.trim();
    final matchedBrand = _brands.where((b) => '${b['name']}'.toLowerCase() == brandName.toLowerCase()).firstOrNull;
    final data = <String, dynamic>{
      'name': name,
      'slug': p?.slug.isNotEmpty == true && p!.slug != p!.id ? p!.slug : '${Fmt.slugify(name)}-${ref.id.substring(0, 5).toLowerCase()}',
      'shortDescription': _short.text.trim(),
      'description': _desc.text.trim(),
      'moduleId': _module,
      'categoryId': _categoryId,
      'categoryPath': _categoryPath,
      'brandId': matchedBrand?['id'] ?? (brandName.isEmpty ? '' : _brandId),
      'brandName': brandName,
      'sellerId': myUid,
      'sellerName': seller?.storeName ?? '',
      'images': _images,
      'price': price,
      'mrp': mrp < price ? price : mrp,
      'stock': stock,
      'lowStockAt': int.tryParse(_lowAt.text) ?? 5,
      'unit': _unit.text.trim(),
      'variants': variants,
      'tags': _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'isVeg': _showVeg ? _isVeg : null,
      'customFields': {
        for (final f in _fields)
          if (f.key.text.trim().isNotEmpty) f.key.text.trim(): f.value.text.trim(),
      },
      'status': 'pending',
      'barcode': _barcode.text.trim(),
      'deliveryMinutes': int.tryParse(_minutes.text) ?? 30,
      'updatedAt': Fs.now,
      if (p == null) ...{
        'createdAt': Fs.now,
        'rating': 0,
        'ratingCount': 0,
        'soldCount': 0,
        'viewCount': 0,
        'featured': false,
      },
    };
    if (!mounted) return;
    final ok = await runBusy(context, () async {
      if (p == null) {
        await ref.set(data);
      } else {
        await ref.update(data);
      }
      return true;
    });
    if (ok == true && mounted) {
      await showSuccess(context,
          title: p == null ? context.tr('Product submitted', 'उत्पाद जमा हुआ') : context.tr('Changes submitted', 'बदलाव जमा हुए'),
          subtitle: context.tr('It will go live once the admin approves it.', 'एडमिन की स्वीकृति के बाद यह लाइव होगा।'));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: context.tr('Delete product?', 'उत्पाद हटाएं?'), message: p!.name, confirmText: context.tr('Delete', 'हटाएं'), danger: true);
    if (!ok || !mounted) return;
    final r = await runBusy(context, () => Fs.products.doc(p!.id).delete().then((_) => true));
    if (r == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(p == null ? context.tr('Add product', 'उत्पाद जोड़ें') : context.tr('Edit product', 'उत्पाद संपादित करें')),
        actions: [
          if (p != null) IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
          if (p != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: G4MColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(G4MRadius.sm)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: G4MColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.tr('Saving changes sends the product for admin review again.', 'बदलाव सहेजने पर उत्पाद फिर से एडमिन समीक्षा में जाएगा।'),
                      style: context.tt.bodySmall?.copyWith(color: context.rc.ink)),
                ),
              ]),
            ).stagger(i++),
          _section(context, context.tr('Images', 'चित्र'), [
            SizedBox(
              height: 108,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: _images.length,
                onReorder: (a, b) => setState(() {
                  if (b > a) b--;
                  _images.insert(b, _images.removeAt(a));
                }),
                footer: Pressable(
                  onTap: _addImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: context.rc.brandSoft,
                      borderRadius: BorderRadius.circular(G4MRadius.md),
                      border: Border.all(color: context.rc.brand.withValues(alpha: .4)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_rounded, color: context.rc.brand),
                      const SizedBox(height: 4),
                      Text(context.tr('Add', 'जोड़ें'), style: context.tt.labelMedium?.copyWith(color: context.rc.brand)),
                    ]),
                  ),
                ),
                itemBuilder: (c, k) => ReorderableDelayedDragStartListener(
                  key: ValueKey(_images[k]),
                  index: k,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 10),
                    child: Stack(children: [
                      Positioned.fill(child: NetImage(_images[k], radius: G4MRadius.md)),
                      if (k == 0)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: Text(context.tr('Cover', 'कवर'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(k)),
                          child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ).animate().scale(begin: const Offset(.8, .8), duration: 300.ms, curve: Curves.easeOutBack),
                ),
              ),
            ),
            if (_images.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context.tr('Long-press and drag to reorder', 'क्रम बदलने के लिए दबाकर खींचें'), style: context.tt.bodySmall),
              ),
          ]).stagger(i++),
          _section(context, context.tr('Basics', 'मूल जानकारी'), [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.tr('Product name', 'उत्पाद का नाम')),
              validator: (v) => (v ?? '').trim().length < 2 ? context.tr('Required', 'आवश्यक') : null,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<MarketModule>>(
              stream: CatalogRepo.instance.modules(),
              builder: (context, s) {
                final ids = s.data?.map((m) => m.id).toList() ?? const ['ecommerce', 'grocery', 'pharmacy', 'food'];
                final names = {for (final m in s.data ?? const <MarketModule>[]) m.id: m.name};
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in {...ids, _module})
                    ChoiceChip(
                      label: Text(names[m]?.isNotEmpty == true ? names[m]! : Fmt.titleCase(m)),
                      selected: _module == m,
                      onSelected: (_) => setState(() {
                        if (_module != m) {
                          _module = m;
                          _categoryId = '';
                          _categoryPath = const [];
                          _categoryLabel = '';
                        }
                      }),
                    ),
                ]);
              },
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () async {
                final c = await pickCategory(context, _module);
                if (c != null) {
                  setState(() {
                    _categoryId = c.id;
                    _categoryPath = [...c.path, c.id];
                    _categoryLabel = c.name;
                  });
                  categoryBreadcrumb(_categoryPath).then((s) {
                    if (mounted && s.isNotEmpty) setState(() => _categoryLabel = s);
                  });
                }
              },
              child: Row(children: [
                Icon(Icons.account_tree_outlined, color: context.rc.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Category', 'श्रेणी'), style: context.tt.bodySmall),
                    Text(_categoryLabel.isEmpty ? (_categoryId.isEmpty ? context.tr('Choose category', 'श्रेणी चुनें') : _categoryId) : _categoryLabel,
                        style: context.tt.titleSmall),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _brand.text),
              optionsBuilder: (v) {
                final q = v.text.toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return _brands.map((b) => '${b['name'] ?? ''}').where((n) => n.toLowerCase().contains(q)).take(8);
              },
              onSelected: (s) {
                _brand.text = s;
                _brandId = '${_brands.firstWhere((b) => b['name'] == s, orElse: () => {})['id'] ?? ''}';
              },
              fieldViewBuilder: (c, ctrl, focus, onSubmit) => TextField(
                controller: ctrl,
                focusNode: focus,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  _brand.text = v;
                  _brandId = '';
                },
                decoration: InputDecoration(labelText: context.tr('Brand', 'ब्रांड'), prefixIcon: const Icon(Icons.sell_outlined)),
              ),
            ),
            if (_showVeg) ...[
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 1, icon: const VegMark(isVeg: true), label: Text(context.tr('Veg', 'शाकाहारी'))),
                  ButtonSegment(value: 0, icon: const VegMark(isVeg: false), label: Text(context.tr('Non-veg', 'मांसाहारी'))),
                  ButtonSegment(value: -1, label: Text(context.tr('N/A', 'लागू नहीं'))),
                ],
                selected: {_isVeg == null ? -1 : (_isVeg! ? 1 : 0)},
                onSelectionChanged: (s) => setState(() => _isVeg = s.first == -1 ? null : s.first == 1),
              ),
            ],
          ]).stagger(i++),
          _section(context, context.tr('Pricing & stock', 'मूल्य और स्टॉक'), [
            Row(children: [
              Expanded(child: _numField(_price, context.tr('Price', 'कीमत'), prefix: '₹ ', required: true)),
              const SizedBox(width: 12),
              Expanded(
                child: _numField(_mrp, 'MRP', prefix: '₹ ', validator: (v) {
                  final m = double.tryParse(v ?? '');
                  final pr = double.tryParse(_price.text) ?? 0;
                  if (m != null && m < pr) return context.tr('MRP < price', 'MRP कीमत से कम');
                  return null;
                }),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _variants.isEmpty
                    ? _numField(_stock, context.tr('Stock', 'स्टॉक'), integer: true, required: true)
                    : InputDecorator(
                        decoration: InputDecoration(labelText: context.tr('Stock', 'स्टॉक')),
                        child: Text(context.tr('From variants', 'वेरिएंट से')),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _numField(_lowAt, context.tr('Low-stock alert at', 'कम स्टॉक अलर्ट'), integer: true)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(controller: _unit, decoration: InputDecoration(labelText: context.tr('Unit (e.g. 500 g)', 'इकाई (जैसे 500 ग्राम)'))),
              ),
              const SizedBox(width: 12),
              Expanded(child: _numField(_minutes, context.tr('Delivery mins', 'डिलीवरी मिनट'), integer: true)),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: context.tr('Barcode', 'बारकोड'),
                prefixIcon: const Icon(Icons.qr_code_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () async {
                    final code = await scanBarcode(context);
                    if (code != null) setState(() => _barcode.text = code);
                  },
                ),
              ),
            ),
          ]).stagger(i++),
          _section(
            context,
            context.tr('Variants', 'वेरिएंट'),
            [
              for (var k = 0; k < _variants.length; k++) _variantCard(context, k),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(context.tr('Add variant (size, colour, pack)', 'वेरिएंट जोड़ें (साइज़, रंग, पैक)')),
                onPressed: () => setState(() => _variants.add(_VariantRow(price: _price.text, mrp: _mrp.text))),
              ),
            ],
          ).stagger(i++),
          _section(
            context,
            context.tr('Description', 'विवरण'),
            [
              Align(
                alignment: Alignment.centerLeft,
                child: _AiButton(busy: _aiBusy, onTap: _ai),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _short, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Short description', 'संक्षिप्त विवरण'))),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, minLines: 4, maxLines: 12, decoration: InputDecoration(labelText: context.tr('Full description', 'पूरा विवरण'), alignLabelWithHint: true)),
              const SizedBox(height: 12),
              TextFormField(controller: _tags, decoration: InputDecoration(labelText: context.tr('Tags (comma separated)', 'टैग (कॉमा से अलग)'))),
            ],
          ).stagger(i++),
          _section(
            context,
            context.tr('Specifications & custom fields', 'विशेषताएं और कस्टम फ़ील्ड'),
            [
              if (_attributes.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final a in _attributes.where((a) => !_fields.any((f) => f.key.text == a['name'])).take(12))
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text('${a['name']}'),
                      onPressed: () => setState(() => _fields.add(_FieldRow('${a['name']}'))),
                    ),
                ]),
              for (var k = 0; k < _fields.length; k++)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _fields[k].key, decoration: InputDecoration(hintText: context.tr('Field (e.g. Allergens)', 'फ़ील्ड'), isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: _valueField(k)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: G4MColors.danger),
                      onPressed: () => setState(() => _fields.removeAt(k).dispose()),
                    ),
                  ]),
                ).animate().fadeIn().slideX(begin: .05),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(context.tr('Add field', 'फ़ील्ड जोड़ें')),
                onPressed: () => setState(() => _fields.add(_FieldRow())),
              ),
            ],
          ).stagger(i++),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.cloud_upload_rounded),
            label: Text(context.tr('Submit for review', 'समीक्षा के लिए जमा करें')),
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  Widget _valueField(int k) {
    final attr = _attributes.where((a) => a['name'] == _fields[k].key.text).firstOrNull;
    final values = attr?['values'] is List ? (attr!['values'] as List).map((e) => '$e').toList() : const <String>[];
    return TextField(
      controller: _fields[k].value,
      decoration: InputDecoration(
        hintText: context.tr('Value', 'मान'),
        isDense: true,
        suffixIcon: values.isEmpty
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down_rounded),
                onSelected: (v) => setState(() => _fields[k].value.text = v),
                itemBuilder: (_) => [for (final v in values) PopupMenuItem(value: v, child: Text(v))],
              ),
      ),
    );
  }

  Widget _variantCard(BuildContext context, int k) {
    final v = _variants[k];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.rc.cardAlt, borderRadius: BorderRadius.circular(G4MRadius.sm)),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: v.name, decoration: InputDecoration(hintText: context.tr('Name (e.g. 1 kg, Red / L)', 'नाम'), isDense: true))),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: G4MColors.danger),
              onPressed: () => setState(() => _variants.removeAt(k).dispose()),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _numField(v.price, context.tr('Price', 'कीमत'), dense: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField(v.mrp, 'MRP', dense: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField(v.stock, context.tr('Stock', 'स्टॉक'), integer: true, dense: true)),
          ]),
          const SizedBox(height: 8),
          TextField(controller: v.sku, decoration: const InputDecoration(hintText: 'SKU', isDense: true)),
        ]),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: .1),
    );
  }

  Widget _numField(TextEditingController c, String label,
          {String? prefix, bool integer = false, bool required = false, bool dense = false, String? Function(String?)? validator}) =>
      TextFormField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, prefixText: prefix, isDense: dense),
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty || double.tryParse(v) == null) ? context.tr('Required', 'आवश्यक') : null
                : null),
      );

  Widget _section(BuildContext context, String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: context.tt.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );
}

class _AiButton extends StatelessWidget {
  const _AiButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final btn = Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF0B8A4F)]),
          borderRadius: BorderRadius.circular(G4MRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(busy ? context.tr('Writing…', 'लिख रहा है…') : context.tr('Write with AI', 'AI से लिखें'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
    return busy ? btn.animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms) : btn;
  }
}
