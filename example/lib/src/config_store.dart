/// Persisted user overrides for the SDK config (Settings screen). Overrides are
/// applied immediately via setConfig and merged over `baseConfig` at boot.
///
/// Overrides are stored flat, keyed by the schema's dot paths (e.g.
/// `notification.priority`). `config_builder.dart` turns a flat map into the
/// typed nested [Config] the plugin wants.
library;

import 'dart:convert';

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_builder.dart';
import 'config_schema.dart';

const _key = 'bgeo:configOverrides';

Future<Map<String, Object?>> loadOverrides() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return {};
  final decoded = jsonDecode(raw);
  return decoded is Map ? decoded.map((k, v) => MapEntry(k.toString(), v)) : {};
}

Future<void> _saveOverrides(Map<String, Object?> overrides) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, jsonEncode(overrides));
}

/// All schema keys starting with a dot prefix (e.g. `notification.`).
List<String> _keysWithPrefix(String prefix) => [
      for (final section in configSections)
        for (final field in section.fields)
          if (field.key.startsWith(prefix)) field.key,
    ];

/// Every schema field of a dot prefix, filled from [values] where overridden,
/// else from its default. Returned flat (still dot-keyed) — [configFrom] does
/// the nesting.
Map<String, Object?> _nestedPatchFor(String prefix, Map<String, Object?> values) {
  final patch = <String, Object?>{};
  for (final fullKey in _keysWithPrefix('$prefix.')) {
    patch[fullKey] = values.containsKey(fullKey) ? values[fullKey] : defaultFor(fullKey);
  }
  return patch;
}

/// The flat patch to send for one changed [key].
///
/// For `a.b` keys the engine replaces the whole nested object on setConfig, so
/// rebuild it from EVERY schema field of the prefix (override if present, else
/// its default) — never just the overridden subset.
Map<String, Object?> patchFor(String key, Map<String, Object?> values) {
  final dot = key.indexOf('.');
  if (dot < 0) return {key: values[key]};
  return _nestedPatchFor(key.substring(0, dot), values);
}

/// Apply one config key right away and remember it across restarts.
Future<void> applyOverride(String key, Object? value) async {
  final overrides = await loadOverrides();
  overrides[key] = value;
  await BackgroundGeolocation.setConfig(configFrom(patchFor(key, overrides)));
  await _saveOverrides(overrides);
}

/// Drop all overrides and re-apply the defaults for every overridden key.
Future<void> resetOverrides() async {
  final overrides = await loadOverrides();
  if (overrides.isNotEmpty) {
    final defaults = <String, Object?>{};
    final seenPrefixes = <String>{};
    for (final key in overrides.keys) {
      final dot = key.indexOf('.');
      if (dot < 0) {
        defaults[key] = defaultFor(key);
      } else if (seenPrefixes.add(key.substring(0, dot))) {
        defaults.addAll(_nestedPatchFor(key.substring(0, dot), const {}));
      }
    }
    await BackgroundGeolocation.setConfig(configFrom(defaults));
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
}

/// Boot-time shape: dot-path overrides made schema-complete per nested prefix
/// (same rule as [patchFor]), plain keys left flat.
Map<String, Object?> expandOverrides(Map<String, Object?> overrides) {
  final out = <String, Object?>{};
  final seenPrefixes = <String>{};
  for (final key in overrides.keys) {
    final dot = key.indexOf('.');
    if (dot < 0) {
      out[key] = overrides[key];
    } else if (seenPrefixes.add(key.substring(0, dot))) {
      out.addAll(_nestedPatchFor(key.substring(0, dot), overrides));
    }
  }
  return out;
}

/// `baseConfig` merged with the user's persisted overrides — what `ready()` gets.
Config bootConfig(Map<String, Object?> overrides) =>
    configFrom({...baseConfig, ...expandOverrides(overrides)});
