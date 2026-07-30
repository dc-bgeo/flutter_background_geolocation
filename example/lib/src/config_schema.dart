/// Declarative schema of the SDK's working Config keys — single source for the
/// Settings screen UI and for reset-to-defaults. Documented no-op keys
/// (foregroundService, backgroundPermissionRationale) are excluded.
/// `defaultValue` is the effective engine/app default shown when no override is
/// set.
library;

import 'dart:io' show Platform;

enum FieldType { boolean, number, enumeration, string }

/// A default that differs between the iOS and Android engines — see
/// [resolveDefault]. Use only when the two engines' own literal fallbacks
/// genuinely disagree (rare: `minimumActivityRecognitionConfidence` below is
/// currently the one known case). Most fields keep a single [ConfigField.defaultValue].
class PlatformDefault {
  final Object ios;
  final Object android;

  const PlatformDefault({required this.ios, required this.android});
}

/// Resolves a field's `defaultValue` (single value, or a [PlatformDefault]
/// pair) for one platform. `isIOS` is an explicit parameter rather than
/// reading `Platform.isIOS` internally, so this stays a pure function —
/// unit-testable for both platforms from a single `flutter test` run, no
/// platform faking needed.
Object? resolveDefault(Object? value, {required bool isIOS}) =>
    value is PlatformDefault ? (isIOS ? value.ios : value.android) : value;

/// Whether [field] applies to the platform selected by [isIOS]. A field with
/// no `platform` tag applies to both — same "common case needs no tag" rule
/// [resolveDefault] uses for values. `isIOS` is a required parameter for the
/// same reason: pure, unit-testable for both platforms without a `dart:io
/// Platform` fake (which doesn't exist).
bool appliesToPlatform(ConfigField field, {required bool isIOS}) =>
    field.platform == null || field.platform == (isIOS ? 'ios' : 'android');

class EnumOption {
  final String label;
  final Object value; // int | String

  const EnumOption(this.label, this.value);
}

class ConfigField {
  final String key;
  final String label;
  final FieldType type;

  /// enum choices
  final List<EnumOption>? options;
  final Object? defaultValue;
  final String? unit;

  /// 'ios' | 'android' — omitted when the key works on both.
  final String? platform;
  final String? hint;

  const ConfigField({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.defaultValue,
    this.unit,
    this.platform,
    this.hint,
  });

  /// [defaultValue] resolved for the CURRENT platform (`dart:io`'s
  /// `Platform.isIOS`). Passes through unchanged unless `defaultValue` is a
  /// [PlatformDefault].
  Object? get resolvedDefault => resolveDefault(defaultValue, isIOS: Platform.isIOS);

  /// Whether this field applies to the CURRENT platform (`dart:io`'s
  /// `Platform.isIOS`) — what the Settings screen uses to decide whether to
  /// render a field.
  bool get appliesToCurrentPlatform => appliesToPlatform(this, isIOS: Platform.isIOS);
}

class ConfigSection {
  final String title;
  final List<ConfigField> fields;

  const ConfigSection(this.title, this.fields);
}

/// Base config the example app passes to ready() (before user overrides), as a
/// key/value map so it composes with the persisted overrides. `configFrom`
/// turns it into a typed [Config].
const Map<String, Object?> baseConfig = {
  'distanceFilter': 10.0,
  'stopTimeout': 5,
  'debug': true,
  'startOnBoot': false,
  'stopOnTerminate': true,
  // Native logger at INFO for the example app; upload starts once a device
  // link supplies logUrl (device_link.dart `_applySdkConfig`).
  'logLevel': 3,
};

const _accuracyOptions = [
  EnumOption('NAV', -2),
  EnumOption('HIGH', -1),
  EnumOption('MED', 10),
  EnumOption('LOW', 100),
  EnumOption('V.LOW', 1000),
];

const configSections = <ConfigSection>[
  ConfigSection('Geolocation', [
    ConfigField(
        key: 'desiredAccuracy',
        label: 'Desired accuracy',
        type: FieldType.enumeration,
        options: _accuracyOptions,
        defaultValue: -1),
    ConfigField(
        key: 'distanceFilter',
        label: 'Distance filter',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 10.0),
    // CORRECTED — engine default 200 on both platforms (core/ios/Sources/BGGeoEngine.mm:809,
    // core/android/.../BGGeoEngine.kt:636), not 25.
    ConfigField(
        key: 'stationaryRadius',
        label: 'Stationary radius',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 200.0),
    // iOS-only: read by the session engine's stationary distance gate
    // (core/ios/Sources/BGGeoEngine.mm:1466, :1827). Zero occurrences under
    // core/android/engine — a no-op on Android (already doc-tagged
    // `@platform ios` on both SDKs' Config types).
    ConfigField(
        key: 'stationaryDistanceFilter',
        label: 'Stationary distance filter',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 75.0,
        platform: 'ios'),
    ConfigField(
        key: 'stationaryDesiredAccuracy',
        label: 'Stationary accuracy',
        type: FieldType.enumeration,
        options: [
          EnumOption('HIGH', 'HIGH'),
          EnumOption('BAL', 'BALANCED'),
          EnumOption('LOW', 'LOW'),
        ],
        defaultValue: 'BALANCED'),
    ConfigField(
        key: 'stationaryKeepAlive',
        label: 'Stationary keep-alive',
        type: FieldType.boolean,
        defaultValue: true),
    ConfigField(
        key: 'locationUpdateInterval',
        label: 'Moving interval',
        type: FieldType.number,
        unit: 'ms',
        defaultValue: 1000,
        platform: 'android'),
    ConfigField(
        key: 'showsBackgroundLocationIndicator',
        label: 'BG location indicator',
        type: FieldType.boolean,
        defaultValue: false,
        platform: 'ios'),
    ConfigField(
        key: 'disableLocationFilter',
        label: 'Disable Kalman filter',
        type: FieldType.boolean,
        defaultValue: false),
    ConfigField(
        key: 'locationFilterMaxAccuracy',
        label: 'Filter max accuracy',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 100.0),
    ConfigField(
        key: 'locationFilterMaxSpeed',
        label: 'Filter max speed',
        type: FieldType.number,
        unit: 'm/s',
        defaultValue: 60.0),
    ConfigField(
        key: 'locationFilterPolicy',
        label: 'Filter policy',
        type: FieldType.enumeration,
        options: [
          EnumOption('CONS', 'Conservative'),
          EnumOption('ADJ', 'Adjust'),
          EnumOption('PASS', 'PassThrough'),
        ],
        defaultValue: 'Conservative'),
    ConfigField(
        key: 'kalmanProfile',
        label: 'Kalman profile',
        type: FieldType.enumeration,
        options: [
          EnumOption('DEF', 'DEFAULT'),
          EnumOption('AGGR', 'AGGRESSIVE'),
          EnumOption('CONS', 'CONSERVATIVE'),
        ],
        defaultValue: 'DEFAULT'),
    ConfigField(
        key: 'odometerAccuracyThreshold',
        label: 'Odometer accuracy gate',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 0.0,
        hint: '0 = off'),
  ]),
  ConfigSection('Motion / Activity', [
    ConfigField(
        key: 'stopTimeout',
        label: 'Stop timeout',
        type: FieldType.number,
        unit: 'min',
        defaultValue: 5),
    ConfigField(
        key: 'motionTriggerDelay',
        label: 'Motion trigger delay',
        type: FieldType.number,
        unit: 'ms',
        defaultValue: 0),
    // DIVERGENT BY DESIGN — iOS engine default is 50 (core/ios/Sources/BGGeoEngine.mm:1576,
    // deliberate: iOS's confidence scale is coarse Low/Med/High=33/66/100, and 50 preserves
    // "anything above Low counts as moving"); Android engine default is 75
    // (core/android/.../BGGeoEngine.kt:870). Resolved per platform via [resolveDefault] so
    // each platform's Settings screen displays and resets to its OWN engine's real default.
    ConfigField(
        key: 'minimumActivityRecognitionConfidence',
        label: 'Min AR confidence',
        type: FieldType.number,
        unit: '%',
        defaultValue: PlatformDefault(ios: 50, android: 75)),
    ConfigField(
        key: 'disableMotionActivityUpdates',
        label: 'Disable motion updates',
        type: FieldType.boolean,
        defaultValue: false),
    ConfigField(
        key: 'preventSuspend',
        label: 'Prevent suspend',
        type: FieldType.boolean,
        defaultValue: false,
        platform: 'ios'),
  ]),
  ConfigSection('Power', [
    ConfigField(
        key: 'disableElasticity',
        label: 'Disable elasticity',
        type: FieldType.boolean,
        defaultValue: false),
    ConfigField(
        key: 'elasticityMultiplier',
        label: 'Elasticity multiplier',
        type: FieldType.number,
        defaultValue: 1.0),
  ]),
  ConfigSection('HTTP / Sync', [
    ConfigField(key: 'autoSync', label: 'Auto sync', type: FieldType.boolean, defaultValue: true),
    ConfigField(
        key: 'autoSyncThreshold',
        label: 'Auto-sync threshold',
        type: FieldType.number,
        defaultValue: 0),
    ConfigField(
        key: 'disableAutoSyncOnCellular',
        label: 'Wi-Fi-only auto sync',
        type: FieldType.boolean,
        defaultValue: false,
        hint: 'explicit Sync still uploads on cellular'),
    ConfigField(key: 'batchSync', label: 'Batch sync', type: FieldType.boolean, defaultValue: false),
    // CORRECTED — engine default -1/unbatched on both platforms (core/ios/Sources/
    // BGGeoHttpStore.mm:74,183, core/android/.../BGGeoHttpStore.kt:60,198), not 50;
    // DeviceLink sets 50 once linked, independently of this default.
    ConfigField(
        key: 'maxBatchSize', label: 'Max batch size', type: FieldType.number, defaultValue: -1),
    // CORRECTED — engine default 30000 on both platforms (core/ios/Sources/
    // BGGeoHttpStore.mm:185, core/android/.../BGGeoHttpStore.kt:199), not 60000.
    ConfigField(
        key: 'httpTimeoutMs',
        label: 'HTTP timeout',
        type: FieldType.number,
        unit: 'ms',
        defaultValue: 30000),
  ]),
  ConfigSection('Persistence', [
    ConfigField(
        key: 'maxRecordsToPersist',
        label: 'Max records',
        type: FieldType.number,
        defaultValue: -1,
        hint: '-1 = unlimited'),
    ConfigField(
        key: 'maxDaysToPersist',
        label: 'Max days',
        type: FieldType.number,
        unit: 'd',
        defaultValue: 0),
  ]),
  ConfigSection('Geofencing', [
    ConfigField(
        key: 'geofenceProximityRadius',
        label: 'Proximity radius',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 1000.0),
    ConfigField(
        key: 'maxMonitoredGeofences',
        label: 'Max monitored',
        type: FieldType.number,
        defaultValue: -1,
        hint: '-1 = platform budget'),
    ConfigField(
        key: 'geofenceInitialTriggerEntry',
        label: 'Initial ENTER trigger',
        type: FieldType.boolean,
        defaultValue: true),
  ]),
  ConfigSection('Application', [
    ConfigField(
        key: 'heartbeatInterval',
        label: 'Heartbeat interval',
        type: FieldType.number,
        unit: 's',
        defaultValue: 60),
    ConfigField(
        key: 'stopOnTerminate',
        label: 'Stop on terminate',
        type: FieldType.boolean,
        defaultValue: true),
    ConfigField(
        key: 'startOnBoot', label: 'Start on boot', type: FieldType.boolean, defaultValue: false),
    ConfigField(key: 'debug', label: 'Debug sounds', type: FieldType.boolean, defaultValue: true),
  ]),
  ConfigSection('Diagnostics / Engine', [
    ConfigField(
        key: 'logLevel',
        label: 'Log level',
        type: FieldType.enumeration,
        options: [
          EnumOption('OFF', 0),
          EnumOption('ERR', 1),
          EnumOption('WARN', 2),
          EnumOption('INFO', 3),
          EnumOption('DBG', 4),
          EnumOption('VERB', 5),
        ],
        defaultValue: 3,
        hint: 'native log persistence (mirror to logcat/os_log is always on)'),
    // iOS-only: gates the per-point diagnostic snapshot
    // (core/ios/Sources/BGGeoEngine.mm:848). Zero occurrences under
    // core/android/engine — a no-op on Android today (not doc-tagged
    // `@platform ios` on either SDK's Config, since Android support is on
    // the backlog; re-evaluate this tag if/when that ships).
    ConfigField(
        key: 'diagnosticExtras',
        label: 'Diagnostic extras',
        type: FieldType.boolean,
        defaultValue: false,
        platform: 'ios'),
    ConfigField(
        key: 'useSessionEngine',
        label: 'Session engine',
        type: FieldType.boolean,
        defaultValue: true,
        platform: 'ios',
        hint: 'OFF = legacy CLLocationManager (SLC-burst degraded in background)'),
  ]),
  ConfigSection('Notification', [
    ConfigField(
        key: 'notification.title',
        label: 'Title',
        type: FieldType.string,
        defaultValue: 'Location',
        platform: 'android'),
    ConfigField(
        key: 'notification.text',
        label: 'Text',
        type: FieldType.string,
        defaultValue: 'Location tracking active',
        platform: 'android'),
    ConfigField(
        key: 'notification.channelId',
        label: 'Channel ID',
        type: FieldType.string,
        defaultValue: 'bgeo_location_min',
        platform: 'android',
        hint: 'importance is frozen per channel — change the ID to change priority'),
    ConfigField(
        key: 'notification.channelName',
        label: 'Channel name',
        type: FieldType.string,
        defaultValue: 'Location',
        platform: 'android'),
    ConfigField(
        key: 'notification.smallIcon',
        label: 'Small icon',
        type: FieldType.string,
        defaultValue: '',
        platform: 'android',
        hint: 'drawable/name or mipmap/name; empty = app icon'),
    ConfigField(
        key: 'notification.color',
        label: 'Accent color',
        type: FieldType.string,
        defaultValue: '',
        platform: 'android',
        hint: '#RRGGBB; empty = none'),
    ConfigField(
        key: 'notification.priority',
        label: 'Priority',
        type: FieldType.enumeration,
        options: [
          EnumOption('MIN', -2),
          EnumOption('LOW', -1),
          EnumOption('DEF', 0),
          EnumOption('HIGH', 1),
          EnumOption('MAX', 2),
        ],
        defaultValue: -2,
        platform: 'android'),
  ]),
];

/// The schema field for [key], searching every section.
ConfigField? fieldFor(String key) {
  for (final section in configSections) {
    for (final field in section.fields) {
      if (field.key == key) return field;
    }
  }
  return null;
}

/// Every schema field (flattened across sections) that applies to the
/// platform selected by [isIOS] — what the Settings screen renders and what
/// `resetOverrides` is allowed to touch.
List<ConfigField> fieldsForPlatform({required bool isIOS}) => [
      for (final section in configSections)
        for (final field in section.fields)
          if (appliesToPlatform(field, isIOS: isIOS)) field,
    ];

/// Default value per key (`baseConfig` wins over the schema's, possibly
/// per-platform, default).
Object? defaultFor(String key) {
  if (baseConfig.containsKey(key)) return baseConfig[key];
  return fieldFor(key)?.resolvedDefault;
}
