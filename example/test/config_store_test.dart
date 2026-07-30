/// Port of `react-native/example/__tests__/configStore.test.ts`.
///
/// Asserts the map that actually reaches the native side: the plugin's method
/// channel is mocked, so each case checks the `setConfig` payload — which covers
/// both `config_store.dart`'s patch logic and `config_builder.dart`'s typed
/// mapping.
library;

import 'dart:convert';

import 'package:bgeo_background_geolocation_example/src/config_schema.dart';
import 'package:bgeo_background_geolocation_example/src/config_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.bgeo/methods');

const _defaultNotification = {
  'title': 'Location',
  'text': 'Location tracking active',
  'channelId': 'bgeo_location_min',
  'channelName': 'Location',
  'smallIcon': '',
  'color': '',
  'priority': -2,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final setConfigCalls = <Map<Object?, Object?>>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setConfigCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'setConfig') {
        setConfigCalls.add(call.arguments as Map<Object?, Object?>);
      }
      return <Object?, Object?>{'enabled': false};
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('applyOverride applies via setConfig and persists across loads', () async {
    await applyOverride('distanceFilter', 25.0);
    expect(setConfigCalls.last, {'distanceFilter': 25.0});
    expect(await loadOverrides(), {'distanceFilter': 25.0});

    await applyOverride('debug', false);
    expect(await loadOverrides(), {'distanceFilter': 25.0, 'debug': false});
  });

  test('resetOverrides restores defaults for overridden keys and clears storage', () async {
    await applyOverride('distanceFilter', 99.0);
    await resetOverrides();
    expect(setConfigCalls.last, {'distanceFilter': baseConfig['distanceFilter']});
    expect(await loadOverrides(), isEmpty);
  });

  test('applyOverride on a dot-path key rebuilds the full nested object from the schema',
      () async {
    await applyOverride('notification.priority', 1);
    expect(setConfigCalls.last, {
      'notification': {..._defaultNotification, 'priority': 1},
    });
  });

  test('applyOverride on a sibling dot-path key preserves earlier dot-path overrides',
      () async {
    await applyOverride('notification.priority', 1);
    await applyOverride('notification.title', 'X');
    expect(setConfigCalls.last, {
      'notification': {..._defaultNotification, 'priority': 1, 'title': 'X'},
    });
  });

  test('resetOverrides on a dot-path key resets the full default nested object', () async {
    await applyOverride('notification.title', 'X');
    await resetOverrides();
    expect(setConfigCalls.last, {'notification': _defaultNotification});
    expect(await loadOverrides(), isEmpty);
  });

  // Regression guard: stationaryDistanceFilter is iOS-only (platform: 'ios'
  // in config_schema.dart). A value stuck in storage from before that tag
  // existed (or from a shared-backup edge case) must not be re-pushed to the
  // Android engine on reset — that would be a no-op push logged as noise.
  test(
      'resetOverrides on Android skips an iOS-only key even if one is stored, '
      'and still clears it', () async {
    await applyOverride('distanceFilter', 30.0);
    final overrides = await loadOverrides();
    overrides['stationaryDistanceFilter'] = 999.0; // simulate a stale/pre-existing override
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bgeo:configOverrides', jsonEncode(overrides));

    await resetOverrides(isIOS: false);

    expect(setConfigCalls.last, {'distanceFilter': baseConfig['distanceFilter']});
    expect(await loadOverrides(), isEmpty);
  });

  test('resetOverrides on iOS restores an iOS-only key', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bgeo:configOverrides', jsonEncode({'stationaryDistanceFilter': 999.0}));

    await resetOverrides(isIOS: true);

    expect(setConfigCalls.last, {'stationaryDistanceFilter': 75.0});
    expect(await loadOverrides(), isEmpty);
  });

  test('expandOverrides nests dot-path keys schema-complete and leaves plain keys flat', () {
    // expandOverrides keeps dot paths flat; configFrom does the nesting, so
    // assert through the Config the boot path actually builds.
    final config = bootConfig({
      'distanceFilter': 5.0,
      'notification.title': 'X',
      'notification.priority': 1,
    });
    final map = config.toMap();
    expect(map['distanceFilter'], 5.0);
    expect(map['notification'], {..._defaultNotification, 'title': 'X', 'priority': 1});
  });

  test('bootConfig sends baseConfig when there are no overrides', () {
    final map = bootConfig({}).toMap();
    for (final entry in baseConfig.entries) {
      expect(map[entry.key], entry.value, reason: entry.key);
    }
    // No notification keys overridden -> the nested object is not sent at all,
    // so the engine keeps its own defaults.
    expect(map.containsKey('notification'), isFalse);
  });

  test('every schema key survives the round trip through configFrom', () {
    // Guards the config_builder bridge: a key added to the schema but forgotten
    // in configFrom would silently never reach the engine.
    final overrides = <String, Object?>{};
    for (final section in configSections) {
      for (final field in section.fields) {
        overrides[field.key] = field.resolvedDefault;
      }
    }
    final map = bootConfig(overrides).toMap();
    for (final section in configSections) {
      for (final field in section.fields) {
        final dot = field.key.indexOf('.');
        if (dot < 0) {
          expect(map.containsKey(field.key), isTrue,
              reason: '${field.key} is missing from configFrom()');
        } else {
          final nested = map[field.key.substring(0, dot)] as Map<String, dynamic>?;
          expect(nested?.containsKey(field.key.substring(dot + 1)), isTrue,
              reason: '${field.key} is missing from configFrom()');
        }
      }
    }
  });
}
