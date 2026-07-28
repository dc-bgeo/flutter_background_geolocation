/// Modal form for geofence CRUD. New fence: long-press on the map. Edit /
/// delete: tap a fence pin. Every change goes to the SDK, then the snapshot is
/// mirrored to the console via [syncGeofences].
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' hide State;
import 'package:flutter/material.dart';

import '../app_store.dart';
import '../geofences.dart';
import '../log_uploader.dart';
import '../theme.dart';
import '../widgets/touchable_opacity.dart';

class GeofenceFormScreen extends StatefulWidget {
  const GeofenceFormScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.identifier,
  });

  final double latitude;
  final double longitude;

  /// Set when editing an existing fence.
  final String? identifier;

  @override
  State<GeofenceFormScreen> createState() => _GeofenceFormScreenState();
}

class _GeofenceFormScreenState extends State<GeofenceFormScreen> {
  Geofence? _existing;
  late final TextEditingController _identifier;
  late final TextEditingController _radius;
  late final TextEditingController _loiteringDelay;
  late bool _notifyOnEntry;
  late bool _notifyOnExit;
  late bool _notifyOnDwell;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editId = widget.identifier;
    _existing = editId == null
        ? null
        : appStore.geofences.where((g) => g.identifier == editId).firstOrNull;
    _identifier = TextEditingController(text: _existing?.identifier ?? '');
    _radius = TextEditingController(text: (_existing?.radius ?? 200).toStringAsFixed(0));
    _loiteringDelay =
        TextEditingController(text: _existing?.loiteringDelay?.toString() ?? '');
    _notifyOnEntry = _existing?.notifyOnEntry ?? true;
    _notifyOnExit = _existing?.notifyOnExit ?? true;
    _notifyOnDwell = _existing?.notifyOnDwell ?? false;
  }

  @override
  void dispose() {
    _identifier.dispose();
    _radius.dispose();
    _loiteringDelay.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final identifier = _identifier.text.trim();
    final radius = double.tryParse(_radius.text);
    if (identifier.isEmpty || radius == null || radius <= 0) {
      setState(() => _error = 'identifier and a positive radius are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loitering = int.tryParse(_loiteringDelay.text.trim());
      await BackgroundGeolocation.addGeofence(Geofence(
        identifier: identifier,
        latitude: _existing?.latitude ?? widget.latitude,
        longitude: _existing?.longitude ?? widget.longitude,
        radius: radius,
        notifyOnEntry: _notifyOnEntry,
        notifyOnExit: _notifyOnExit,
        notifyOnDwell: _notifyOnDwell,
        loiteringDelay: loitering,
      ));
      logEvent('addGeofence', '$identifier r=${radius.toStringAsFixed(0)}m', null, LogLevel.info);
      await syncGeofences();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDelete() async {
    final existing = _existing;
    if (existing == null) return;
    setState(() => _busy = true);
    try {
      await BackgroundGeolocation.removeGeofence(existing.identifier);
      logEvent('removeGeofence', existing.identifier, null, LogLevel.info);
      await syncGeofences();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    final existing = _existing;
    final lat = existing?.latitude ?? widget.latitude;
    final lng = existing?.longitude ?? widget.longitude;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Geofence'),
        backgroundColor: c.surface,
        foregroundColor: c.text,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            existing != null ? 'Edit geofence' : 'New geofence',
            style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
              style: TextStyle(color: c.textDim, fontSize: 12, fontFamily: mono),
            ),
          ),
          _label(c, 'Identifier'),
          _input(
            c,
            controller: _identifier,
            enabled: existing == null,
            hintText: 'home',
          ),
          _label(c, 'Radius (m)'),
          _input(c, controller: _radius, numeric: true),
          _switchRow(c, 'Notify on ENTER', _notifyOnEntry, (v) => setState(() => _notifyOnEntry = v)),
          _switchRow(c, 'Notify on EXIT', _notifyOnExit, (v) => setState(() => _notifyOnExit = v)),
          _switchRow(c, 'Notify on DWELL', _notifyOnDwell, (v) => setState(() => _notifyOnDwell = v)),
          if (_notifyOnDwell) ...[
            _label(c, 'Loitering delay (ms)'),
            _input(c, controller: _loiteringDelay, numeric: true, hintText: '30000'),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: c.dangerText, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _button(
              c,
              label: _busy ? 'Saving…' : 'Save',
              background: c.accent,
              onTap: _busy ? null : _onSave,
            ),
          ),
          if (existing != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _button(
                c,
                label: 'Delete',
                background: c.danger,
                onTap: _busy ? null : _onDelete,
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(ThemeColors c, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text, style: TextStyle(color: c.textDim, fontSize: 12)),
      );

  Widget _input(
    ThemeColors c, {
    required TextEditingController controller,
    bool enabled = true,
    bool numeric = false,
    String? hintText,
  }) =>
      Opacity(
        opacity: enabled ? 1 : 0.5,
        child: TextField(
          controller: controller,
          enabled: enabled,
          autocorrect: false,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: c.text2, fontFamily: mono, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: TextStyle(color: c.placeholder, fontFamily: mono, fontSize: 14),
            filled: true,
            fillColor: c.field,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.accent),
            ),
          ),
        ),
      );

  Widget _switchRow(ThemeColors c, String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: c.text2, fontSize: 14)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _button(
    ThemeColors c, {
    required String label,
    required Color background,
    VoidCallback? onTap,
  }) =>
      TouchableOpacity(
        onPressed: onTap,
        // RN GeofenceFormScreen's `styles.disabled`.
        disabledOpacity: 0.5,
        child: Container(
          padding: const EdgeInsets.all(14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
