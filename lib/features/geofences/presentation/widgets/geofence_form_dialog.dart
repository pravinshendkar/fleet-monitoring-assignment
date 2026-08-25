import 'package:flutter/material.dart';
import '../../domain/entities/geofence.dart';

class GeofenceFormDialog extends StatefulWidget {
  final Geofence? geofence; // null for Create, non-null for Edit

  const GeofenceFormDialog({
    super.key,
    this.geofence,
  });

  @override
  State<GeofenceFormDialog> createState() => _GeofenceFormDialogState();
}

class _GeofenceFormDialogState extends State<GeofenceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    final g = widget.geofence;
    _nameController = TextEditingController(text: g?.name ?? '');
    _latController = TextEditingController(text: g != null ? g.centerLat.toString() : '12.9716');
    _lngController = TextEditingController(text: g != null ? g.centerLng.toString() : '77.5946');
    _radiusController = TextEditingController(text: g != null ? g.radiusMeters.toStringAsFixed(0) : '500');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.geofence != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Geofence' : 'Create Geofence'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Geofence Name',
                  hintText: 'e.g. Bangalore Depot',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid geofence name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Center Latitude',
                  hintText: 'e.g. 12.9716',
                ),
                validator: (val) {
                  final numVal = double.tryParse(val ?? '');
                  if (numVal == null || numVal < -90.0 || numVal > 90.0) {
                    return 'Latitude must be between -90 and 90';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Center Longitude',
                  hintText: 'e.g. 77.5946',
                ),
                validator: (val) {
                  final numVal = double.tryParse(val ?? '');
                  if (numVal == null || numVal < -180.0 || numVal > 180.0) {
                    return 'Longitude must be between -180 and 180';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radiusController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  hintText: 'e.g. 500',
                ),
                validator: (val) {
                  final numVal = double.tryParse(val ?? '');
                  if (numVal == null || numVal <= 0.0) {
                    return 'Radius must be greater than 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save Changes' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final radius = double.parse(_radiusController.text.trim());

      if (widget.geofence != null) {
        final updated = widget.geofence!.copyWith(
          name: name,
          centerLat: lat,
          centerLng: lng,
          radiusMeters: radius,
        );
        Navigator.of(context).pop(updated);
      } else {
        Navigator.of(context).pop({
          'name': name,
          'lat': lat,
          'lng': lng,
          'radius': radius,
        });
      }
    }
  }
}
