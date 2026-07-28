/// Declarative schema of the SDK's working Config keys — single source for the
/// Settings screen UI and for reset-to-defaults. Documented no-op keys
/// (foregroundService, backgroundPermissionRationale) are excluded.
/// `defaultValue` is the effective engine/app default shown when no override is
/// set.
library;

enum FieldType { boolean, number, enumeration, string }

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
    ConfigField(
        key: 'stationaryRadius',
        label: 'Stationary radius',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 25.0),
    ConfigField(
        key: 'stationaryDistanceFilter',
        label: 'Stationary distance filter',
        type: FieldType.number,
        unit: 'm',
        defaultValue: 75.0),
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
    ConfigField(
        key: 'minimumActivityRecognitionConfidence',
        label: 'Min AR confidence',
        type: FieldType.number,
        unit: '%',
        defaultValue: 75),
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
    ConfigField(
        key: 'maxBatchSize', label: 'Max batch size', type: FieldType.number, defaultValue: 50),
    ConfigField(
        key: 'httpTimeoutMs',
        label: 'HTTP timeout',
        type: FieldType.number,
        unit: 'ms',
        defaultValue: 60000),
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
    ConfigField(
        key: 'diagnosticExtras',
        label: 'Diagnostic extras',
        type: FieldType.boolean,
        defaultValue: false),
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

/// Default value per key (`baseConfig` wins over schema defaults).
Object? defaultFor(String key) {
  if (baseConfig.containsKey(key)) return baseConfig[key];
  for (final section in configSections) {
    for (final field in section.fields) {
      if (field.key == key) return field.defaultValue;
    }
  }
  return null;
}
