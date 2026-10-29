import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../location/location_picker_screen.dart';
import '../../core/validators.dart';

/// Bottom sheet to choose (or add) a delivery address.
Future<Address?> pickAddress(BuildContext context, {String? selectedId}) => showAppSheet<Address>(
      context,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .7,
        child: StreamBuilder<List<Address>>(
          stream: ShopperRepo.instance.addresses(),
          builder: (ctx, snap) {
            final list = snap.data;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(children: [
                  Expanded(child: Text('Deliver to', style: ctx.text.titleLarge)),
                  TextButton.icon(
                    onPressed: () async {
                      final id = await ctx.push<String>(const AddressFormScreen());
                      if (id != null && ctx.mounted) {
                        final d = await Fs.addresses(Session.instance.uid!).doc(id).get();
                        if (ctx.mounted && d.exists) Navigator.of(ctx).pop(Address.fromDoc(d));
                      }
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add new'),
                  ),
                ]),
              ),
              Expanded(
                child: list == null
                    ? const ListSkeleton(count: 3)
                    : list.isEmpty
                        ? const EmptyState(icon: Icons.location_off_outlined, title: 'No saved addresses', message: 'Add one to get your order delivered.')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _AddressTile(
                              address: list[i],
                              selected: list[i].id == selectedId,
                              onTap: () => Navigator.of(ctx).pop(list[i]),
                            ).stagger(i),
                          ),
              ),
            ]);
          },
        ),
      ),
    );

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Saved addresses')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(const AddressFormScreen()),
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Add address'),
        ),
        body: StreamBuilder<List<Address>>(
          stream: ShopperRepo.instance.addresses(),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            final list = snap.data;
            if (list == null) return const ListSkeleton(count: 3, height: 96);
            if (list.isEmpty) {
              return const EmptyState(icon: Icons.location_off_outlined, title: 'No saved addresses', message: 'Add your home or work address for faster checkout.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AddressTile(
                address: list[i],
                onTap: () => context.push(AddressFormScreen(address: list[i])),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    final a = list[i];
                    if (v == 'edit') {
                      context.push(AddressFormScreen(address: a));
                    } else if (v == 'default') {
                      await setDefaultAddress(a.id, list);
                    } else if (v == 'delete') {
                      await ShopperRepo.instance.deleteAddress(a.id);
                      if (context.mounted) context.toast('Address deleted');
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (!list[i].isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: G4MColors.danger))),
                  ],
                ),
              ).stagger(i),
            );
          },
        ),
      );
}

Future<void> setDefaultAddress(String id, List<Address> all) async {
  final uid = Session.instance.uid;
  if (uid == null) return;
  final b = Fs.db.batch();
  for (final a in all) {
    b.set(Fs.addresses(uid).doc(a.id), {'isDefault': a.id == id}, SetOptions(merge: true));
  }
  b.set(Fs.user(uid), {'defaultAddressId': id}, SetOptions(merge: true));
  await b.commit();
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address, this.onTap, this.selected = false, this.trailing});
  final Address address;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final a = address;
    return AppCard(
      onTap: onTap,
      color: selected ? context.softPrimary : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          a.label == 'Work' ? Icons.work_outline_rounded : (a.label == 'Home' ? Icons.home_outlined : Icons.place_outlined),
          color: G4MColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(a.label, style: context.text.titleSmall),
              if (a.isDefault) ...[const SizedBox(width: 8), const Tag('DEFAULT', color: G4MColors.primary, filled: false)],
            ]),
            const SizedBox(height: 2),
            Text('${a.name}${a.phone.isNotEmpty ? ' · ${a.phone}' : ''}', style: context.text.bodyMedium),
            Text(a.oneLine, style: context.text.bodySmall),
          ]),
        ),
        if (selected) const Icon(Icons.check_circle_rounded, color: G4MColors.primary),
        ?trailing,
      ]),
    );
  }
}

/// Add/edit address. "Pin on map" fills lat/lng (used for distance & live tracking) and prefills fields.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.address});
  final Address? address;
  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final a = widget.address;
  late String _label = a?.label ?? 'Home';
  late final _name = TextEditingController(text: a?.name ?? Session.instance.profile.value?.name ?? '');
  late final _phone = TextEditingController(text: Validators.localIndian(a?.phone ?? Session.instance.profile.value?.phone));
  late final _line1 = TextEditingController(text: a?.line1);
  late final _line2 = TextEditingController(text: a?.line2);
  late final _landmark = TextEditingController(text: a?.landmark);
  late final _city = TextEditingController(text: a?.city ?? AppPrefs.instance.location?.city);
  late final _state = TextEditingController(text: a?.state);
  late final _pin = TextEditingController(text: a?.pincode ?? AppPrefs.instance.location?.pincode);
  late double? _lat = a?.lat ?? AppPrefs.instance.location?.lat;
  late double? _lng = a?.lng ?? AppPrefs.instance.location?.lng;
  late bool _default = a?.isDefault ?? false;
  bool _busy = false;

  Future<void> _pick() async {
    final r = await context.push<PickedPoint>(
      LocationPickerScreen(forAddress: true, initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null),
      style: RouteStyle.sharedY,
    );
    if (r == null) return;
    setState(() {
      _lat = r.point.latitude;
      _lng = r.point.longitude;
      final g = r.address;
      if (g != null) {
        if (_line1.text.isEmpty && g.line1.isNotEmpty) _line1.text = g.line1;
        if (g.area.isNotEmpty) _line2.text = g.area;
        if (g.city.isNotEmpty) _city.text = g.city;
        if (g.state.isNotEmpty) _state.text = g.state;
        if (g.pincode.isNotEmpty) _pin.text = g.pincode;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final uid = Session.instance.uid!;
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
        'lat': _lat,
        'lng': _lng,
        'isDefault': _default,
      };
      final ref = a == null ? Fs.addresses(uid).doc() : Fs.addresses(uid).doc(a!.id);
      await ref.set({...data, if (a == null) 'createdAt': Fs.now, 'updatedAt': Fs.now}, SetOptions(merge: true));
      final all = (await Fs.addresses(uid).get()).docs.map(Address.fromDoc).toList();
      if (_default || all.length == 1) await setDefaultAddress(ref.id, all);
      if (mounted) Navigator.of(context).pop(ref.id);
    } catch (e) {
      if (mounted) context.toast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _req(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(a == null ? 'Add address' : 'Edit address')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              onTap: _pick,
              color: context.softPrimary,
              child: Row(children: [
                const Icon(Icons.map_rounded, color: G4MColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_lat == null ? 'Pin your location on the map' : 'Location pinned', style: context.text.titleSmall),
                    Text(_lat == null ? 'Helps riders find you and enables live tracking' : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                        style: context.text.bodySmall),
                  ]),
                ),
                Icon(_lat == null ? Icons.chevron_right_rounded : Icons.check_circle_rounded, color: G4MColors.primary),
              ]),
            ).stagger(0),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              for (final l in ['Home', 'Work', 'Other'])
                ChoiceChip(label: Text(l), selected: _label == l, onSelected: (_) => setState(() => _label = l)),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Receiver name'), validator: _req),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone', prefixText: '+91 '),
              validator: (v) => RegExp(r'^\d{10}$').hasMatch((v ?? '').trim()) ? null : 'Enter a 10-digit number',
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _line1, decoration: const InputDecoration(labelText: 'House / flat, building, street'), validator: _req),
            const SizedBox(height: 12),
            TextFormField(controller: _line2, decoration: const InputDecoration(labelText: 'Area / locality')),
            const SizedBox(height: 12),
            TextFormField(controller: _landmark, decoration: const InputDecoration(labelText: 'Landmark (optional)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'), validator: _req)),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pincode'),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : '6 digits',
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State'), validator: _req),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make this my default address'),
              value: _default,
              onChanged: (v) => setState(() => _default = v),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save address')),
          ]),
        ),
      );
}
