Map<String, dynamic> _castStringMap(Object? m) =>
    (m as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? <String, dynamic>{};

/// @platform android Foreground-service notification. No-op on iOS.
/// `priority` is Transistor NOTIFICATION_PRIORITY_*: -2 MIN (default) .. 2 MAX —
/// it also sets the channel importance, which Android freezes per channelId
/// (change channelId to change it). `smallIcon` = "drawable/name" | "mipmap/name";
/// `color` = "#RRGGBB".
class Notification {
  final String? title;
  final String? text;
  final String? channelId;
  final String? channelName;
  final String? smallIcon;
  final String? color;
  final int? priority;

  const Notification({
    this.title,
    this.text,
    this.channelId,
    this.channelName,
    this.smallIcon,
    this.color,
    this.priority,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String key, dynamic v) {
      if (v != null) m[key] = v;
    }

    put('title', title);
    put('text', text);
    put('channelId', channelId);
    put('channelName', channelName);
    put('smallIcon', smallIcon);
    put('color', color);
    put('priority', priority);
    return m;
  }
}

/// Native token refresh: on a 401/403 the uploader exchanges `refreshToken`
/// at `refreshUrl` (headers `refreshHeaders`, body `refreshPayload` with the
/// "{refreshToken}" placeholder substituted; default { refresh_token }) so
/// killed-app uploads survive an access-token expiry without a live JS
/// context. Outcomes surface via onAuthorization.
class Authorization {
  final String? strategy;
  final String? accessToken;
  final String? refreshToken;
  final String? refreshUrl;
  final Map<String, dynamic>? refreshPayload;
  final Map<String, String>? refreshHeaders;

  const Authorization({
    this.strategy,
    this.accessToken,
    this.refreshToken,
    this.refreshUrl,
    this.refreshPayload,
    this.refreshHeaders,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String key, dynamic v) {
      if (v != null) m[key] = v;
    }

    put('strategy', strategy);
    put('accessToken', accessToken);
    put('refreshToken', refreshToken);
    put('refreshUrl', refreshUrl);
    put('refreshPayload', refreshPayload);
    put('refreshHeaders', refreshHeaders);
    return m;
  }
}

/// On-device collision detection. Off by default. When enabled, the engine
/// samples the accelerometer at ~50 Hz while moving and emits a `crash`
/// event when an impact signature (>= impactThreshold g, sustained,
/// multi-axis, pre-impact speed >= minSpeed) is followed by a speed collapse.
class CrashDetection {
  /// default false
  final bool? enabled;
  /// Pre-impact speed gate in m/s. Default 11.11 (40 km/h).
  final double? minSpeed;
  /// Impact peak threshold in g. Default 4.0.
  final double? impactThreshold;

  const CrashDetection({
    this.enabled,
    this.minSpeed,
    this.impactThreshold,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String key, dynamic v) {
      if (v != null) m[key] = v;
    }

    put('enabled', enabled);
    put('minSpeed', minSpeed);
    put('impactThreshold', impactThreshold);
    return m;
  }
}

/// On-device distracted-driving detection. Off by default. While moving, the
/// engine watches the shared ~50 Hz accelerometer stream (plus screen state
/// on Android) for a phone-handling signature and emits a `distraction`
/// event when an episode closes.
class DistractionDetection {
  /// default false
  final bool? enabled;
  /// Episode-open speed gate in m/s. Default 5.0 (18 km/h).
  final double? minSpeed;
  /// Minimum episode length in seconds; shorter handling is ignored. Default 5.
  final double? minEpisodeSec;

  const DistractionDetection({
    this.enabled,
    this.minSpeed,
    this.minEpisodeSec,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String key, dynamic v) {
      if (v != null) m[key] = v;
    }

    put('enabled', enabled);
    put('minSpeed', minSpeed);
    put('minEpisodeSec', minEpisodeSec);
    return m;
  }
}

/// Permissive config — only the keys the app passes are documented here.
class Config {
  // The license key is NOT a config option — set it in the app manifest:
  //   Android: <meta-data android:name="com.bgeo.license" android:value="BGEO1..."/>
  //   iOS:     Info.plist <key>BGeoLicense</key><string>BGEO1...</string>
  // Same mechanism for React Native / native / Flutter; read at launch before
  // JS runs. In a RELEASE build a bad key makes ready()/start() reject with a
  // LICENSE_* code; debuggable builds / the iOS simulator always run unlicensed
  // (evaluation), whatever the key state.
  final String? locationAuthorizationRequest;
  final Map<String, String>? locationAuthorizationAlert;
  /// Suppress the Settings-nudge alert driven by `locationAuthorizationAlert`. Default false.
  final bool? disableLocationAuthorizationAlert;
  /// @unsupported No-op on iOS; Android uses the OS permission rationale flow.
  final Map<String, String>? backgroundPermissionRationale;
  final int? desiredAccuracy;
  final double? distanceFilter;
  /// Bypass the Kalman/accuracy/teleport filter entirely. Default false.
  final bool? disableLocationFilter;
  /// Reject fixes with accuracy worse than this (metres). Default 100.
  final double? locationFilterMaxAccuracy;
  /// Teleport rejection: max implied speed between fixes (m/s). Default 60.
  final double? locationFilterMaxSpeed;
  /// Filter decision phase: 'Conservative' (default — reject teleport fixes) |
  /// 'Adjust' (cap teleports to the kinematic limit instead of dropping) |
  /// 'PassThrough' (accuracy gate only; no teleport rejection, no Kalman
  /// smoothing). Case-insensitive. Applied when the filter is (re)built at
  /// tracking start/stop — not live on setConfig.
  final String? locationFilterPolicy;
  /// Kalman tuning preset: 'DEFAULT' | 'AGGRESSIVE' (faster response, less lag)
  /// | 'CONSERVATIVE' (maximum smoothing). Case-insensitive. Applied when the
  /// filter is (re)built at tracking start/stop — not live on setConfig.
  final String? kalmanProfile;
  /// Fixes with accuracy worse than this (metres) don't advance the odometer.
  /// 0 = off (default; tracking/upload unaffected — odometer only).
  final double? odometerAccuracyThreshold;
  /// Pin distanceFilter to its base value (no speed-elastic scaling). Default false.
  final bool? disableElasticity;
  /// Speed-elastic distanceFilter scaling intensity. Default 1.0.
  final double? elasticityMultiplier;
  /// Accuracy tier for the stationary keep-alive stream: HIGH | BALANCED | LOW. Default BALANCED.
  final String? stationaryDesiredAccuracy;
  /// @platform android Stationary fused request interval (ms). Default 30000. No-op on iOS.
  final int? stationaryLocationUpdateInterval;
  /// CSV of activity names that count as "moving" (e.g. "in_vehicle,on_bicycle,walking,running,on_foot").
  final String? triggerActivities;
  /// Min activity-recognition confidence 0-100. Default 75 Android; 50 iOS (coarse 33/66/100 scale).
  final int? minimumActivityRecognitionConfidence;
  /// @platform android Activity-recognition poll interval (ms). Default 10000. No-op on iOS.
  final int? activityRecognitionInterval;
  /// Ignore motion-activity updates (motion machine falls back to speed + stationary geofence). Default false.
  final bool? disableMotionActivityUpdates;
  final int? stopTimeout;
  /// @platform ios Show the blue background-location pill under Always auth. false + Always also skips the session engine's CLBackgroundActivitySession to hide the pill (beta — needs field tests). No-op on Android.
  final bool? showsBackgroundLocationIndicator;
  final double? stationaryRadius;
  /// @platform ios Satellites in the stationary wake ring (entry-monitored regions
  /// around the parked anchor). 0 disables. Default 8. Each one takes a slot
  /// from the 20-region iOS budget shared with app geofences: app geofences are
  /// capped at 19 − wakeRegionRingCount concurrently monitored (11 by default),
  /// and changing it at runtime re-balances the geofence budget. Counts 1–7 leave
  /// directional gaps; use 0 or ≥ 8. No-op on Android.
  final int? wakeRegionRingCount;
  /// @platform ios Distance from the anchor to each satellite center, metres.
  /// Default 2 × stationaryRadius; values below 2 × stationaryRadius are raised to
  /// it — satellites use stationaryRadius as their own radius, so a closer ring
  /// would contain the anchor. No-op on Android.
  final double? wakeRegionRingDistance;
  /// @platform ios Experimental. Lay a chain of entry-monitored wake regions ahead along the course while moving, so a swipe-killed (never-in-use) process is woken by each crossing instead of only by the 5-min-throttled significant-change service. Default false. No-op on Android.
  final bool? wakeTrailEnabled;
  /// @platform ios Experimental. Regions in the wake trail (spaced 200 m, radius 100 m). Default 8, cap 18, 0 disables. Shares the reserved slots with the wake ring: app geofences are capped at 19 − max(wakeRegionRingCount, wakeTrailCount). No-op on Android.
  final int? wakeTrailCount;
  /// @platform ios Low-power continuous wake distance; independent of the larger region radius. No-op on Android.
  final double? stationaryDistanceFilter;
  /// @platform ios Hold a background task while backgrounded+stationary. No-op on Android.
  final bool? preventSuspend;
  final int? heartbeatInterval;
  final int? motionTriggerDelay;
  /// @platform android Fused moving-request interval (ms). Default 1000. No-op on iOS.
  final int? locationUpdateInterval;
  /// @unsupported No-op. The Android foreground service is always on while tracking.
  final bool? foregroundService;
  final Notification? notification;
  final bool? stopOnTerminate;
  final bool? startOnBoot;
  /// Plays a one-shot debug sound cue per event (Android/iOS). Does NOT affect tracking.
  final bool? debug;
  /// Native log persistence gate: 0=OFF (default) .. 5=VERBOSE (LOG_LEVEL_* constants).
  final int? logLevel;
  /// Days to retain native log rows. Default 3.
  final int? logMaxDays;
  /// Absolute URL for native log batch upload ({events:[...]}); unset = local-only.
  final String? logUrl;
  final int? maxDaysToPersist;
  final String? url;
  /// HTTP verb for uploads: POST (default) | PUT | PATCH.
  final String? method;
  final Map<String, String>? headers;
  /// Merged into the request body root alongside the location payload.
  final Map<String, dynamic>? params;
  /// Merged into every uploaded record's `extras` (per-call extras win).
  final Map<String, dynamic>? extras;
  /// Body key carrying the location(s); default "location". "." merges a single record into the root.
  final String? httpRootProperty;
  /// Default true.
  final bool? autoSync;
  /// Defer AUTO-sync while on cellular (queue drains on Wi-Fi/ethernet arrival).
  /// Explicit sync() always uploads. Default false.
  final bool? disableAutoSyncOnCellular;
  final int? autoSyncThreshold;
  final bool? batchSync;
  final int? maxBatchSize;
  final int? httpTimeoutMs;
  final int? maxRecordsToPersist;
  final Authorization? authorization;
  /// Keep a low-power location request alive while stationary (fast wake source
  /// on trip start). Default true; false restores fully-sleep-GPS (slower wake).
  final bool? stationaryKeepAlive;
  /// Android only: drop the foreground service (and its permanent notification)
  /// while parked, waking on a Doze-proof alarm instead of a live location
  /// stream. Default false. Requires background location permission and takes
  /// effect at the device's next park; costs trip-start latency.
  final bool? dormantOnStationary;
  /// Seconds between dormant wakes while [dormantOnStationary] is on. Default
  /// 1800; floored at 60, and Doze floors inexact alarms again at ~9-15 min.
  final int? dormantWakeInterval;

  /// Android-only. Seconds to keep the low-power stationary stream after a park
  /// before dropping the foreground service (dormantOnStationary); 0 = immediate.
  /// Default 120.
  final int? dormantGrace;
  /// Upload a compact native diagnostic snapshot in every point's `extras`
  /// (counters, app/motion state, manager config) — test devices only.
  final bool? diagnosticExtras;
  /// Session engine (iOS 17+): deliver via CLLocationUpdate.liveUpdates +
  /// CLBackgroundActivitySession while moving instead of legacy
  /// startUpdatingLocation (which iOS suspends between significant-change wakes).
  /// Default true (since 2026-07-23); kept as a remote-config kill-switch.
  /// iOS < 17 always uses the legacy path regardless of this flag.
  /// Android: silently ignored (stored but unread) — iOS-only key.
  final bool? useSessionEngine;
  /// Proximity slicing for app-facing geofences: only the nearest N within this
  /// radius (metres) of the last fix are registered with the OS. Default 1000.
  final double? geofenceProximityRadius;
  /// Cap on OS-registered geofences after proximity filtering (platform budget:
  /// 19 iOS / 99 Android). <=0 uses the platform budget as-is. Default -1.
  final int? maxMonitoredGeofences;
  /// Requests a synthetic ENTER for geofences already-inside on registration
  /// (iOS requestStateForRegion / Android INITIAL_TRIGGER_ENTER). Default true.
  final bool? geofenceInitialTriggerEntry;
  /// On-device collision detection. Off by default. See [CrashDetection].
  final CrashDetection? crashDetection;
  /// On-device distracted-driving detection. Off by default. See [DistractionDetection].
  final DistractionDetection? distractionDetection;

  const Config({
    this.locationAuthorizationRequest,
    this.locationAuthorizationAlert,
    this.disableLocationAuthorizationAlert,
    this.backgroundPermissionRationale,
    this.desiredAccuracy,
    this.distanceFilter,
    this.disableLocationFilter,
    this.locationFilterMaxAccuracy,
    this.locationFilterMaxSpeed,
    this.locationFilterPolicy,
    this.kalmanProfile,
    this.odometerAccuracyThreshold,
    this.disableElasticity,
    this.elasticityMultiplier,
    this.stationaryDesiredAccuracy,
    this.stationaryLocationUpdateInterval,
    this.triggerActivities,
    this.minimumActivityRecognitionConfidence,
    this.activityRecognitionInterval,
    this.disableMotionActivityUpdates,
    this.stopTimeout,
    this.showsBackgroundLocationIndicator,
    this.stationaryRadius,
    this.wakeRegionRingCount,
    this.wakeRegionRingDistance,
    this.wakeTrailEnabled,
    this.wakeTrailCount,
    this.stationaryDistanceFilter,
    this.preventSuspend,
    this.heartbeatInterval,
    this.motionTriggerDelay,
    this.locationUpdateInterval,
    this.foregroundService,
    this.notification,
    this.stopOnTerminate,
    this.startOnBoot,
    this.debug,
    this.logLevel,
    this.logMaxDays,
    this.logUrl,
    this.maxDaysToPersist,
    this.url,
    this.method,
    this.headers,
    this.params,
    this.extras,
    this.httpRootProperty,
    this.autoSync,
    this.disableAutoSyncOnCellular,
    this.autoSyncThreshold,
    this.batchSync,
    this.maxBatchSize,
    this.httpTimeoutMs,
    this.maxRecordsToPersist,
    this.authorization,
    this.stationaryKeepAlive,
    this.dormantOnStationary,
    this.dormantWakeInterval,
    this.dormantGrace,
    this.diagnosticExtras,
    this.useSessionEngine,
    this.geofenceProximityRadius,
    this.maxMonitoredGeofences,
    this.geofenceInitialTriggerEntry,
    this.crashDetection,
    this.distractionDetection,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    void put(String key, dynamic v) {
      if (v != null) m[key] = v;
    }

    put('locationAuthorizationRequest', locationAuthorizationRequest);
    put('locationAuthorizationAlert', locationAuthorizationAlert);
    put('disableLocationAuthorizationAlert', disableLocationAuthorizationAlert);
    put('backgroundPermissionRationale', backgroundPermissionRationale);
    put('desiredAccuracy', desiredAccuracy);
    put('distanceFilter', distanceFilter);
    put('disableLocationFilter', disableLocationFilter);
    put('locationFilterMaxAccuracy', locationFilterMaxAccuracy);
    put('locationFilterMaxSpeed', locationFilterMaxSpeed);
    put('locationFilterPolicy', locationFilterPolicy);
    put('kalmanProfile', kalmanProfile);
    put('odometerAccuracyThreshold', odometerAccuracyThreshold);
    put('disableElasticity', disableElasticity);
    put('elasticityMultiplier', elasticityMultiplier);
    put('stationaryDesiredAccuracy', stationaryDesiredAccuracy);
    put('stationaryLocationUpdateInterval', stationaryLocationUpdateInterval);
    put('triggerActivities', triggerActivities);
    put('minimumActivityRecognitionConfidence', minimumActivityRecognitionConfidence);
    put('activityRecognitionInterval', activityRecognitionInterval);
    put('disableMotionActivityUpdates', disableMotionActivityUpdates);
    put('stopTimeout', stopTimeout);
    put('showsBackgroundLocationIndicator', showsBackgroundLocationIndicator);
    put('stationaryRadius', stationaryRadius);
    put('wakeRegionRingCount', wakeRegionRingCount);
    put('wakeRegionRingDistance', wakeRegionRingDistance);
    put('wakeTrailEnabled', wakeTrailEnabled);
    put('wakeTrailCount', wakeTrailCount);
    put('stationaryDistanceFilter', stationaryDistanceFilter);
    put('preventSuspend', preventSuspend);
    put('heartbeatInterval', heartbeatInterval);
    put('motionTriggerDelay', motionTriggerDelay);
    put('locationUpdateInterval', locationUpdateInterval);
    put('foregroundService', foregroundService);
    put('notification', notification?.toMap());
    put('stopOnTerminate', stopOnTerminate);
    put('startOnBoot', startOnBoot);
    put('debug', debug);
    put('logLevel', logLevel);
    put('logMaxDays', logMaxDays);
    put('logUrl', logUrl);
    put('maxDaysToPersist', maxDaysToPersist);
    put('url', url);
    put('method', method);
    put('headers', headers);
    put('params', params);
    put('extras', extras);
    put('httpRootProperty', httpRootProperty);
    put('autoSync', autoSync);
    put('disableAutoSyncOnCellular', disableAutoSyncOnCellular);
    put('autoSyncThreshold', autoSyncThreshold);
    put('batchSync', batchSync);
    put('maxBatchSize', maxBatchSize);
    put('httpTimeoutMs', httpTimeoutMs);
    put('maxRecordsToPersist', maxRecordsToPersist);
    put('authorization', authorization?.toMap());
    put('stationaryKeepAlive', stationaryKeepAlive);
    put('dormantOnStationary', dormantOnStationary);
    put('dormantWakeInterval', dormantWakeInterval);
    put('dormantGrace', dormantGrace);
    put('diagnosticExtras', diagnosticExtras);
    put('useSessionEngine', useSessionEngine);
    put('geofenceProximityRadius', geofenceProximityRadius);
    put('maxMonitoredGeofences', maxMonitoredGeofences);
    put('geofenceInitialTriggerEntry', geofenceInitialTriggerEntry);
    put('crashDetection', crashDetection?.toMap());
    put('distractionDetection', distractionDetection?.toMap());
    return m;
  }
}

/// Live tracker state snapshot. Permissive read access via `raw`/`[]` replaces
/// TS's `[key: string]: any` — unknown/untyped keys remain reachable.
class State {
  /// The untouched native payload (permissive escape hatch).
  final Map<String, dynamic> raw;
  final bool enabled;
  final bool? isMoving;
  final double? odometer;
  final int? trackingMode;
  final bool? connected;
  final int? geofenceCount;

  State._({
    required this.raw,
    required this.enabled,
    this.isMoving,
    this.odometer,
    this.trackingMode,
    this.connected,
    this.geofenceCount,
  });

  factory State.fromMap(Map map) {
    final casted = _castStringMap(map);
    return State._(
      raw: casted,
      enabled: casted['enabled'] as bool? ?? false,
      isMoving: casted['isMoving'] as bool?,
      odometer: (casted['odometer'] as num?)?.toDouble(),
      trackingMode: (casted['trackingMode'] as num?)?.toInt(),
      connected: casted['connected'] as bool?,
      geofenceCount: (casted['geofenceCount'] as num?)?.toInt(),
    );
  }

  dynamic operator [](String key) => raw[key];
}
