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
    expect(_fieldDefault('stationaryRadius'), 200.0);
  });

  test('httpTimeoutMs matches both engines (30000 ms)', () {
    expect(_fieldDefault('httpTimeoutMs'), 30000);
  });

  test('maxBatchSize matches both engines (-1, unbatched)', () {
    expect(_fieldDefault('maxBatchSize'), -1);
  });

  // iOS engine default is 50; Android engine default is 75 (deliberate
  // divergence — see BGGeoEngine.mm's comment on the coarse iOS confidence
  // scale). This schema has no per-platform default mechanism, so it uses
  // iOS's value here — see the parity report for the full discussion.
  test('minimumActivityRecognitionConfidence matches the iOS engine default (50)', () {
    expect(_fieldDefault('minimumActivityRecognitionConfidence'), 50);
  });
}
