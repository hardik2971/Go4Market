import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';

import '../core/shop.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import 'kit.dart';
import 'maps.dart';

/// Add / edit an address with a map pin (lat/lng are required by the delivery estimate).
/// Returns the saved address id (for new addresses) or null.
Future<bool?> showAddressForm(BuildContext context, {Address? existing}) => showDialog<bool>(
      context: context,
      builder: (_) => _AddressDialog(existing: existing),
    );

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.existing});
  final Address? existing;
  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _form = GlobalKey<FormState>();
  final _map = MapController();
  late final Address? a = widget.existing;
  late String _label = a?.label ?? 'Home';
  late final _name = TextEditingController(text: a?.name ?? Shop.instance.profile?.name ?? '');
  late final _phone = TextEditingController(text: a?.phone ?? Shop.instance.profile?.phone ?? '');
  late final _line1 = TextEditingController(text: a?.line1);
  late final _line2 = TextEditingController(text: a?.line2);
  late final _landmark = TextEditingController(text: a?.landmark);
  late final _city = TextEditingController(text: a?.city ?? Shop.instance.city.value ?? '');
  late final _state = TextEditingController(text: a?.state);
  late final _pin = TextEditingController(text: a?.pincode);
  late bool _default = a?.isDefault ?? false;
  late LatLng _pos = a?.lat != null && a?.lng != null ? LatLng(a!.lat!, a!.lng!) : kDefaultCenter;
  bool _moved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _moved = a?.lat != null;
    if (!_moved) _locate(silent: true);
  }

  Future<void> _locate({bool silent = false}) async {
    final p = await WebBridge.locate();
    if (!mounted) return;
    if (p == null) {
      if (!silent) toast(context, context.l.common.locationDenied, error: true);
      return;
    }
    setState(() {
      _pos = LatLng(p.lat, p.lng);
      _moved = true;
    });
    try {
      _map.move(_pos, 16);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_moved) {
      toast(context, context.l.cart.movePinToDoor, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = {
        'label': _label,
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'line1': _line1.text.trim(),
        'line2': _line2.text.trim(),
        'landmark': _landmark.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pin.text.trim(),
        'lat': double.parse(_pos.latitude.toStringAsFixed(6)),
        'lng': double.parse(_pos.longitude.toStringAsFixed(6)),
        'isDefault': _default,
      };
      final uid = Shop.instance.user!.uid;
      if (_default) {
        final all = await Fs.addresses(uid).get();
        for (final d in all.docs) {
          if (d.id != a?.id && d.data()['isDefault'] == true) await d.reference.update({'isDefault': false});
        }
      }
      String id;
      if (a == null) {
        final ref = await Fs.addresses(uid).add({...data, 'createdAt': Fs.now, 'updatedAt': Fs.now});
        id = ref.id;
      } else {
        await ShopperRepo.instance.saveAddress(data, a!.id);
        id = a!.id;
      }
      if (_default) await Fs.user(uid).set({'defaultAddressId': id}, SetOptions(merge: true));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _landmark, _city, _state, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? L.current.cart.requiredField : null;

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final t = context.l.cart;
    final fields = Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'Home', icon: const Icon(Icons.home_outlined), label: Text(t.addressLabel('Home'))),
            ButtonSegment(value: 'Work', icon: const Icon(Icons.work_outline), label: Text(t.addressLabel('Work'))),
            ButtonSegment(value: 'Other', icon: const Icon(Icons.place_outlined), label: Text(t.addressLabel('Other'))),
          ],
          selected: {_label},
          onSelectionChanged: (s) => setState(() => _label = s.first),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextFormField(controller: _name, validator: _req, decoration: InputDecoration(labelText: t.fullName))),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? t.invalidPhone : null,
              decoration: InputDecoration(labelText: t.phone),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _line1, validator: _req, decoration: InputDecoration(labelText: t.line1)),
        const SizedBox(height: 10),
        TextFormField(controller: _line2, decoration: InputDecoration(labelText: t.line2)),
        const SizedBox(height: 10),
        TextFormField(controller: _landmark, decoration: InputDecoration(labelText: t.landmark)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _city, validator: _req, decoration: InputDecoration(labelText: t.city))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _state, validator: _req, decoration: InputDecoration(labelText: t.state))),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : t.sixDigits,
              decoration: InputDecoration(labelText: t.pin),
            ),
          ),
        ]),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _default,
          onChanged: (v) => setState(() => _default = v ?? false),
          title: Text(t.makeDefault),
        ),
      ]),
    );
    final map = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: phone ? 220 : 360, child: LocationPicker(initial: _pos, controller: _map, onChanged: (p) {
        _pos = p;
        _moved = true;
      })),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _locate, icon: const Icon(Icons.my_location_rounded), label: Text(context.l.common.useMyLocation)),
    ]);
    return Dialog(
      insetPadding: EdgeInsets.all(phone ? 12 : 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 760),
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 12, 8),
            child: Row(children: [
              Expanded(child: Text(a == null ? t.addADeliveryAddress : t.editAddress, style: context.tt.titleLarge)),
              IconButton(tooltip: context.l.common.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: phone
                  ? Column(children: [map, const SizedBox(height: 16), fields])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: map), const SizedBox(width: 20), Expanded(child: fields)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l.common.cancel)),
              const SizedBox(width: 10),
              FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? t.saving : t.saveAddress)),
            ]),
          ),
        ]),
      ),
    );
  }
}

