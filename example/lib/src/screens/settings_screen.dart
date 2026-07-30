/// Settings — device link (registration code), every working SDK config key
/// (applied immediately via setConfig, persisted as overrides), engine state and
/// upload-queue tools.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' hide State;
import 'package:flutter/material.dart';

import '../app_store.dart';
import '../config_schema.dart';
import '../config_store.dart';
import '../device_link.dart';
import '../log_uploader.dart';
import '../theme.dart';
import '../widgets/touchable_opacity.dart';

const _stateFields = [
  'enabled',
  'trackingActive',
  'isMoving',
  'odometer',
  'geofenceCount',
  'authorization',
  'lastRawFixAge',
  'lastAcceptedFixAge',
  'watchdogRecoveryCount',
  'sessionEngineActive',
  'serviceSessionActive',
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, Object?> _overrides = {};

  @override
  void initState() {
    super.initState();
    loadOverrides().then((o) {
      if (mounted) setState(() => _overrides = o);
    });
  }

  Future<void> _setValue(String key, Object? value) async {
    setState(() => _overrides = {..._overrides, key: value});
    await applyOverride(key, value);
    logEvent('setConfig', '$key=$value', null, LogLevel.info);
  }

  Future<void> _onReset() async {
    await resetOverrides();
    if (!mounted) return;
    setState(() => _overrides = {});
    logEvent('setConfig', 'reset to defaults', null, LogLevel.info);
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('settingsList'),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
        children: [
          const _LinkSection(),
          const _AppearanceSection(),
          for (final section in configSections)
            if (section.fields.any((f) => f.appliesToCurrentPlatform))
              _Section(
                title: section.title,
                children: [
                  for (final field in section.fields)
                    if (field.appliesToCurrentPlatform)
                      _FieldRow(
                        field: field,
                        value: _overrides.containsKey(field.key)
                            ? _overrides[field.key]
                            : field.resolvedDefault,
                        overridden: _overrides.containsKey(field.key),
                        onChanged: (v) => _setValue(field.key, v),
                      ),
                ],
              ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: _Button(
              label: 'Reset config to defaults',
              background: c.surfaceRaised,
              foreground: c.text,
              border: c.border,
              onTap: _onReset,
            ),
          ),
          const _StateSection(),
        ],
      ),
    );
  }
}

// --- shared bits -----------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TouchableOpacity(
      onPressed: onTap,
      // RN SettingsScreen's `styles.disabled`.
      disabledOpacity: 0.5,
      child: Container(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Text(
          label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return TouchableOpacity(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(color: c.accentText, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(ThemeColors c, {String? hintText}) => InputDecoration(
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
    );

// --- appearance ------------------------------------------------------------

const _themeModes = [
  (ThemeMode.system, 'System'),
  (ThemeMode.light, 'Light'),
  (ThemeMode.dark, 'Dark'),
];

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => _Section(
        title: 'Appearance',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: TextStyle(color: c.text2, fontSize: 13)),
                      Text(
                        'same palette as the web console · now: '
                        '${isDark(context) ? 'dark' : 'light'}',
                        style: TextStyle(color: c.placeholder, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _EnumRow(
                  options: [for (final (mode, label) in _themeModes) EnumOption(label, mode.name)],
                  value: themeController.mode.name,
                  onChanged: (v) => themeController.setMode(
                    ThemeMode.values.firstWhere((m) => m.name == v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- device link -----------------------------------------------------------

class _LinkSection extends StatefulWidget {
  const _LinkSection();

  @override
  State<_LinkSection> createState() => _LinkSectionState();
}

class _LinkSectionState extends State<_LinkSection> {
  late final TextEditingController _serverUrl =
      TextEditingController(text: appStore.link.serverUrl);
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serverUrl.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _onLink() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await linkDevice(
        _serverUrl.text.replaceAll(RegExp(r'/+$'), ''),
        _code.text,
      );
      logEvent('link', 'linked to console as ${result.deviceId}', null, LogLevel.info);
      _code.clear();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onUnlink() async {
    setState(() => _busy = true);
    try {
      await unlinkDevice();
      logEvent('link', 'unlinked from console', null, LogLevel.info);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final link = appStore.link;
        final codeReady = _code.text.replaceAll('-', '').length >= 8;
        return _Section(
          title: 'Debug console',
          children: [
            Text(
              'Create a registration code in the BGeo web console (Dashboard → '
              'Registration codes) and enter it here. Locations and SDK events then '
              'stream live to your console.',
              style: TextStyle(color: c.textDim, fontSize: 13, height: 1.4),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text('Server', style: TextStyle(color: c.textDim, fontSize: 12)),
            ),
            TextField(
              controller: _serverUrl,
              enabled: !link.linked,
              autocorrect: false,
              style: TextStyle(color: c.text2, fontFamily: mono, fontSize: 14),
              decoration: _fieldDecoration(c),
            ),
            if (!link.linked) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text('Registration code',
                    style: TextStyle(color: c.textDim, fontSize: 12)),
              ),
              TextField(
                controller: _code,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: c.text2, fontFamily: mono, fontSize: 14),
                decoration: _fieldDecoration(c, hintText: 'XXXX-XXXX'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _Button(
                  label: _busy ? 'Linking…' : 'Link device',
                  background: c.accent,
                  foreground: c.onAccent,
                  onTap: _busy || !codeReady ? null : _onLink,
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '🟢 Linked — device ${link.deviceId != null && link.deviceId!.length > 8 ? link.deviceId!.substring(0, 8) : link.deviceId}',
                  style: TextStyle(color: c.successText, fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _Button(
                  label: 'Unlink',
                  background: c.danger,
                  foreground: c.onAccent,
                  onTap: _busy ? null : _onUnlink,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: c.dangerText, fontSize: 13)),
              ),
          ],
        );
      },
    );
  }
}

// --- config field controls -------------------------------------------------

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.value,
    required this.overridden,
    required this.onChanged,
  });

  final ConfigField field;
  final Object? value;
  final bool overridden;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${field.label}${field.unit != null ? ' (${field.unit})' : ''}',
                  style: TextStyle(
                    color: overridden ? c.accentText : c.text2,
                    fontSize: 13,
                  ),
                ),
                if (field.hint != null)
                  Text(field.hint!, style: TextStyle(color: c.placeholder, fontSize: 11)),
              ],
            ),
          ),
          const Spacer(),
          switch (field.type) {
            FieldType.boolean => Switch(
                value: value == true,
                onChanged: onChanged,
              ),
            FieldType.number => _TextValueInput(
                value: value?.toString() ?? '',
                numeric: true,
                onCommit: (text) {
                  final parsed = num.tryParse(text);
                  if (parsed == null) return;
                  // Keep the schema default's numeric kind — the plugin's Config
                  // is typed int vs double per key.
                  onChanged(field.resolvedDefault is double ? parsed.toDouble() : parsed.toInt());
                },
              ),
            FieldType.string => _TextValueInput(
                value: value?.toString() ?? '',
                onCommit: onChanged,
              ),
            FieldType.enumeration => _EnumRow(
                options: field.options ?? const [],
                value: value,
                onChanged: onChanged,
              ),
          },
        ],
      ),
    );
  }
}

class _EnumRow extends StatelessWidget {
  const _EnumRow({required this.options, required this.value, required this.onChanged});

  final List<EnumOption> options;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        for (final option in options)
          TouchableOpacity(
            onPressed: () => onChanged(option.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: value == option.value ? c.accent : c.surfaceRaised,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  color: value == option.value ? c.onAccent : c.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Commits on blur / submit (never per keystroke — the SDK call is a round trip).
class _TextValueInput extends StatefulWidget {
  const _TextValueInput({
    required this.value,
    required this.onCommit,
    this.numeric = false,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final bool numeric;

  @override
  State<_TextValueInput> createState() => _TextValueInputState();
}

class _TextValueInputState extends State<_TextValueInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_TextValueInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text == widget.value) return;
    widget.onCommit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return SizedBox(
      width: 110,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        autocorrect: false,
        textAlign: TextAlign.right,
        keyboardType: widget.numeric
            ? const TextInputType.numberWithOptions(signed: true, decimal: true)
            : TextInputType.text,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        style: TextStyle(color: c.text2, fontFamily: mono, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.field,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: c.accent),
          ),
        ),
      ),
    );
  }
}

// --- engine state + queue --------------------------------------------------

class _StateSection extends StatefulWidget {
  const _StateSection();

  @override
  State<_StateSection> createState() => _StateSectionState();
}

class _StateSectionState extends State<_StateSection> {
  Map<String, dynamic>? _engineState;
  int? _count;
  int? _logCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        BackgroundGeolocation.getState(),
        BackgroundGeolocation.getCount(),
        BackgroundGeolocation.getLog(limit: 5000),
      ]);
      if (!mounted) return;
      setState(() {
        _engineState = (results[0] as dynamic).raw as Map<String, dynamic>;
        _count = results[1] as int;
        _logCount = (results[2] as List).length;
      });
    } catch (_) {
      // No native side (tests / hot restart) — leave the placeholders.
    }
  }

  Future<void> _run(String event, Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      logEvent(event, await action(), null, LogLevel.info);
    } catch (e) {
      logEvent(event, e.toString(), null, LogLevel.error);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    final keyStyle = TextStyle(color: c.textDim, fontSize: 12, fontFamily: mono);
    final valueStyle = TextStyle(color: c.text2, fontSize: 12, fontFamily: mono);

    Widget stateRow(String key, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(key, style: keyStyle),
              Flexible(
                child: Text(value, style: valueStyle, textAlign: TextAlign.right, maxLines: 2),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Engine state',
              style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            _ChipButton(label: 'Refresh', onTap: _refresh),
          ],
        ),
        const SizedBox(height: 8),
        if (_engineState != null)
          for (final key in _stateFields)
            if (_engineState!.containsKey(key)) stateRow(key, '${_engineState![key]}'),
        stateRow('upload queue', '${_count ?? '—'} records'),
        stateRow(
          'log history',
          '${_logCount == null ? '—' : (_logCount == 5000 ? '5000+' : _logCount)} rows',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Expanded(
                child: _Button(
                  label: 'Sync now',
                  background: c.accent,
                  foreground: c.onAccent,
                  onTap: _busy
                      ? null
                      : () => _run('sync', () async {
                            final records = await BackgroundGeolocation.sync();
                            return '${records.length} records';
                          }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Button(
                  label: 'Destroy queue',
                  background: c.danger,
                  foreground: c.onAccent,
                  onTap: _busy
                      ? null
                      : () => _run('destroyLocations', () async {
                            final n = await BackgroundGeolocation.destroyLocations();
                            return '$n records';
                          }),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _Button(
            label: 'Upload logs',
            background: c.accent,
            foreground: c.onAccent,
            onTap: _busy
                ? null
                : () => _run('uploadLog', () async {
                      final n = await BackgroundGeolocation.uploadLog();
                      return '$n rows handed to the flusher';
                    }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _Button(
            label: 'Reset odometer',
            background: c.accent,
            foreground: c.onAccent,
            onTap: _busy
                ? null
                : () => _run('resetOdometer', () async {
                      await BackgroundGeolocation.resetOdometer();
                      return 'odometer=0';
                    }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: ListenableBuilder(
            listenable: appStore,
            builder: (context, _) => Row(
              children: [
                Text(
                  'Track buffer: ${appStore.points.length} pts · ',
                  style: TextStyle(color: c.textDim, fontSize: 13),
                ),
                TouchableOpacity(
                  onPressed: appStore.clearTrack,
                  child: Text(
                    'clear track',
                    style: TextStyle(color: c.dangerText, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
