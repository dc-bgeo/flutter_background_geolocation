/// The one place the Settings schema's string keys meet Dart's typed [Config].
///
/// RN hands `setConfig` an arbitrary `Record<string, unknown>`, so its
/// configStore can build patches from string keys freely. Dart's [Config] is a
/// const class with named parameters, so the mapping has to be written out once
/// — here.
///
/// This works as a PATCH mechanism because `Config.toMap()` omits null fields: a
/// [Config] built from a one-key map serialises to exactly `{key: value}`, which
/// is what `setConfig` expects. Keys absent from [values] stay null and are
/// therefore not sent.
///
/// Adding a config key to `config_schema.dart` means adding one line here too.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';

double? _d(Object? v) => v is num ? v.toDouble() : null;

int? _i(Object? v) => v is num ? v.toInt() : null;

bool? _b(Object? v) => v is bool ? v : null;

String? _s(Object? v) => v is String ? v : null;

/// True when [values] carries any `notification.*` key — the nested object is
/// only sent when the user has touched it (or on an explicit reset).
bool _hasNotification(Map<String, Object?> values) =>
    values.keys.any((k) => k.startsWith('notification.'));

Notification _notificationFrom(Map<String, Object?> values) => Notification(
      title: _s(values['notification.title']),
      text: _s(values['notification.text']),
      channelId: _s(values['notification.channelId']),
      channelName: _s(values['notification.channelName']),
      smallIcon: _s(values['notification.smallIcon']),
      color: _s(values['notification.color']),
      priority: _i(values['notification.priority']),
    );

/// True when [values] carries any `crashDetection.*` key — the nested object
/// is only sent when the user has touched it (or on an explicit reset).
bool _hasCrashDetection(Map<String, Object?> values) =>
    values.keys.any((k) => k.startsWith('crashDetection.'));

CrashDetection _crashDetectionFrom(Map<String, Object?> values) => CrashDetection(
      enabled: _b(values['crashDetection.enabled']),
      minSpeed: _d(values['crashDetection.minSpeed']),
      impactThreshold: _d(values['crashDetection.impactThreshold']),
    );

/// Builds a [Config] patch from flat schema keys (dot paths included).
Config configFrom(Map<String, Object?> values) => Config(
      desiredAccuracy: _i(values['desiredAccuracy']),
      distanceFilter: _d(values['distanceFilter']),
      stationaryRadius: _d(values['stationaryRadius']),
      stationaryDistanceFilter: _d(values['stationaryDistanceFilter']),
      stationaryDesiredAccuracy: _s(values['stationaryDesiredAccuracy']),
      stationaryKeepAlive: _b(values['stationaryKeepAlive']),
      stationaryLocationUpdateInterval: _i(values['stationaryLocationUpdateInterval']),
      locationUpdateInterval: _i(values['locationUpdateInterval']),
      showsBackgroundLocationIndicator: _b(values['showsBackgroundLocationIndicator']),
      disableLocationFilter: _b(values['disableLocationFilter']),
      locationFilterMaxAccuracy: _d(values['locationFilterMaxAccuracy']),
      locationFilterMaxSpeed: _d(values['locationFilterMaxSpeed']),
      locationFilterPolicy: _s(values['locationFilterPolicy']),
      kalmanProfile: _s(values['kalmanProfile']),
      odometerAccuracyThreshold: _d(values['odometerAccuracyThreshold']),
      stopTimeout: _i(values['stopTimeout']),
      motionTriggerDelay: _i(values['motionTriggerDelay']),
      minimumActivityRecognitionConfidence:
          _i(values['minimumActivityRecognitionConfidence']),
      activityRecognitionInterval: _i(values['activityRecognitionInterval']),
      disableMotionActivityUpdates: _b(values['disableMotionActivityUpdates']),
      triggerActivities: _s(values['triggerActivities']),
      preventSuspend: _b(values['preventSuspend']),
      disableElasticity: _b(values['disableElasticity']),
      elasticityMultiplier: _d(values['elasticityMultiplier']),
      autoSync: _b(values['autoSync']),
      autoSyncThreshold: _i(values['autoSyncThreshold']),
      disableAutoSyncOnCellular: _b(values['disableAutoSyncOnCellular']),
      batchSync: _b(values['batchSync']),
      maxBatchSize: _i(values['maxBatchSize']),
      httpTimeoutMs: _i(values['httpTimeoutMs']),
      url: _s(values['url']),
      method: _s(values['method']),
      httpRootProperty: _s(values['httpRootProperty']),
      maxRecordsToPersist: _i(values['maxRecordsToPersist']),
      maxDaysToPersist: _i(values['maxDaysToPersist']),
      geofenceProximityRadius: _d(values['geofenceProximityRadius']),
      maxMonitoredGeofences: _i(values['maxMonitoredGeofences']),
      geofenceInitialTriggerEntry: _b(values['geofenceInitialTriggerEntry']),
      heartbeatInterval: _i(values['heartbeatInterval']),
      stopOnTerminate: _b(values['stopOnTerminate']),
      startOnBoot: _b(values['startOnBoot']),
      debug: _b(values['debug']),
      logLevel: _i(values['logLevel']),
      logMaxDays: _i(values['logMaxDays']),
      logUrl: _s(values['logUrl']),
      diagnosticExtras: _b(values['diagnosticExtras']),
      useSessionEngine: _b(values['useSessionEngine']),
      locationAuthorizationRequest: _s(values['locationAuthorizationRequest']),
      disableLocationAuthorizationAlert: _b(values['disableLocationAuthorizationAlert']),
      notification: _hasNotification(values) ? _notificationFrom(values) : null,
      crashDetection: _hasCrashDetection(values) ? _crashDetectionFrom(values) : null,
    );
