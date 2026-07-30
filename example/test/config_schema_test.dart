/// Guards against the schema's defaults drifting from what the native engines
/// actually use — the Settings screen displays these for un-overridden keys,
/// and "reset to defaults" pushes them into the engine.
library;

import 'package:bgeo_background_geolocation_example/src/config_schema.dart';
import 'package:flutter_test/flutter_test.dart';

Object? _fieldDefault(String key) {
  for (final section in configSections) {
    for (final field in section.fields) {
      if (field.key == key) return field.defaultValue;
    }
  }
  throw StateError('field $key not found in configSections');
}

void main() {
  test('stationaryRadius matches both engines (200 m)', () {
    expect(resolveDefault(_fieldDefault('stationaryRadius'), isIOS: true), 200.0);
    expect(resolveDefault(_fieldDefault('stationaryRadius'), isIOS: false), 200.0);
  });

  test('httpTimeoutMs matches both engines (30000 ms)', () {
    expect(resolveDefault(_fieldDefault('httpTimeoutMs'), isIOS: true), 30000);
    expect(resolveDefault(_fieldDefault('httpTimeoutMs'), isIOS: false), 30000);
  });

  test('maxBatchSize matches both engines (-1, unbatched)', () {
    expect(resolveDefault(_fieldDefault('maxBatchSize'), isIOS: true), -1);
    expect(resolveDefault(_fieldDefault('maxBatchSize'), isIOS: false), -1);
  });

  // iOS engine default is 50 (BGGeoEngine.mm:1576); Android engine default is
  // 75 (BGGeoEngine.kt:870) — deliberate divergence (iOS's confidence scale is
  // coarse). Each platform now resolves to its OWN engine's literal default.
  test('minimumActivityRecognitionConfidence resolves per platform', () {
    expect(resolveDefault(_fieldDefault('minimumActivityRecognitionConfidence'), isIOS: true), 50);
    expect(
        resolveDefault(_fieldDefault('minimumActivityRecognitionConfidence'), isIOS: false), 75);
  });

  group('resolveDefault', () {
    test('returns the iOS value on iOS and the Android value on Android for a divergent field',
        () {
      const divergent = PlatformDefault(ios: 50, android: 75);
      expect(resolveDefault(divergent, isIOS: true), 50);
      expect(resolveDefault(divergent, isIOS: false), 75);
    });

    test('a single-valued default resolves identically on both platforms', () {
      expect(resolveDefault(200.0, isIOS: true), 200.0);
      expect(resolveDefault(200.0, isIOS: false), 200.0);
      expect(resolveDefault('BALANCED', isIOS: true), 'BALANCED');
      expect(resolveDefault('BALANCED', isIOS: false), 'BALANCED');
      expect(resolveDefault(false, isIOS: true), false);
      expect(resolveDefault(false, isIOS: false), false);
      expect(resolveDefault(null, isIOS: true), null);
      expect(resolveDefault(null, isIOS: false), null);
    });
  });
}
