Map<String, dynamic> _castMap(Object? m) =>
    (m as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? <String, dynamic>{};

List<Geofence> _geofenceList(Object? list) {
  if (list is! List) return <Geofence>[];
  return list.map((e) => Geofence.fromMap(_castMap(e))).toList();
}

class Coords {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? altitudeAccuracy;
  final double? speed;
  final double? speedAccuracy;
  final double? heading;
  final double? headingAccuracy;
  final double? ellipsoidalAltitude;

  Coords({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.altitudeAccuracy,
    this.speed,
    this.speedAccuracy,
    this.heading,
    this.headingAccuracy,
    this.ellipsoidalAltitude,
  });

  factory Coords.fromMap(Map<Object?, Object?> map) {
    return Coords(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      altitude: (map['altitude'] as num?)?.toDouble(),
      altitudeAccuracy: (map['altitude_accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      speedAccuracy: (map['speed_accuracy'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      headingAccuracy: (map['heading_accuracy'] as num?)?.toDouble(),
      ellipsoidalAltitude: (map['ellipsoidal_altitude'] as num?)?.toDouble(),
    );
  }
}

class MotionActivity {
  final String type;
  final int confidence;

  MotionActivity({required this.type, required this.confidence});

  factory MotionActivity.fromMap(Map<Object?, Object?> map) {
    return MotionActivity(
      type: map['type'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toInt() ?? 0,
    );
  }
}

class Battery {
  final double level;
  final bool isCharging;

  Battery({required this.level, required this.isCharging});

  factory Battery.fromMap(Map<Object?, Object?> map) {
    return Battery(
      level: (map['level'] as num?)?.toDouble() ?? 0,
      isCharging: map['is_charging'] as bool? ?? false,
    );
  }
}

class Location {
  final String uuid;
  final String timestamp;
  final double? age;
  final double odometer;
  final Coords coords;
  final MotionActivity activity;
  final Battery battery;
  /// Motion-state machine's verdict at the time of this fix.
  ///
  /// `null` while a cold-started session's first fixes are still in the
  /// unconfirmed-MOVING probing window — up to [Config.stopTimeout] minutes
  /// (default 5) after `start()`. Both engines send null there by design so a
  /// server falls back to speed rather than recording a phantom "started
  /// moving". Treat `null` the same as `false` unless you specifically care
  /// about the difference.
  final bool? isMoving;
  final bool? sample;
  final String? event;
  final Map<String, dynamic>? extras;
  /// The untouched native payload (permissive escape hatch).
  final Map<String, dynamic> raw;

  Location.fromMap(Map<Object?, Object?> map)
      : raw = _castMap(map),
        uuid = map['uuid'] as String? ?? '',
        timestamp = map['timestamp'] as String? ?? '',
        age = (map['age'] as num?)?.toDouble(),
        odometer = (map['odometer'] as num?)?.toDouble() ?? 0,
        coords = Coords.fromMap(_castMap(map['coords'])),
        activity = MotionActivity.fromMap(_castMap(map['activity'])),
        battery = Battery.fromMap(_castMap(map['battery'])),
        isMoving = map['is_moving'] as bool?,
        sample = map['sample'] as bool?,
        event = map['event'] as String?,
        extras = map['extras'] == null ? null : _castMap(map['extras']);
}

class ProviderChangeEvent {
  final int status;
  final bool enabled;
  final bool gps;
  final bool network;
  final int? accuracyAuthorization;

  ProviderChangeEvent({
    required this.status,
    required this.enabled,
    required this.gps,
    required this.network,
    this.accuracyAuthorization,
  });

  factory ProviderChangeEvent.fromMap(Map<Object?, Object?> map) {
    return ProviderChangeEvent(
      status: (map['status'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] as bool? ?? false,
      gps: map['gps'] as bool? ?? false,
      network: map['network'] as bool? ?? false,
      accuracyAuthorization: (map['accuracyAuthorization'] as num?)?.toInt(),
    );
  }
}

class MotionChangeEvent {
  final bool isMoving;
  final Location? location;

  MotionChangeEvent({required this.isMoving, this.location});

  factory MotionChangeEvent.fromMap(Map<Object?, Object?> map) {
    final locMap = map['location'];
    return MotionChangeEvent(
      isMoving: map['isMoving'] as bool? ?? false,
      location: locMap == null ? null : Location.fromMap(_castMap(locMap)),
    );
  }
}

class HeartbeatEvent {
  final Location? location;
  final Map<String, dynamic> raw;

  HeartbeatEvent({this.location, required this.raw});

  factory HeartbeatEvent.fromMap(Map<Object?, Object?> map) {
    final locMap = map['location'];
    return HeartbeatEvent(
      location: locMap == null ? null : Location.fromMap(_castMap(locMap)),
      raw: _castMap(map),
    );
  }
}

class GeofenceEvent {
  final String identifier;
  final String action;
  final Location location;
  final Map<String, dynamic>? extras;

  GeofenceEvent({
    required this.identifier,
    required this.action,
    required this.location,
    this.extras,
  });

  factory GeofenceEvent.fromMap(Map<Object?, Object?> map) {
    return GeofenceEvent(
      identifier: map['identifier'] as String? ?? '',
      action: map['action'] as String? ?? '',
      location: Location.fromMap(_castMap(map['location'])),
      extras: map['extras'] == null ? null : _castMap(map['extras']),
    );
  }
}

class Geofence {
  final String identifier;
  final double radius;
  final double latitude;
  final double longitude;
  final bool? notifyOnEntry;
  final bool? notifyOnExit;
  final bool? notifyOnDwell;
  final int? loiteringDelay;
  final Map<String, dynamic>? extras;

  Geofence({
    required this.identifier,
    required this.radius,
    required this.latitude,
    required this.longitude,
    this.notifyOnEntry,
    this.notifyOnExit,
    this.notifyOnDwell,
    this.loiteringDelay,
    this.extras,
  });

  factory Geofence.fromMap(Map<Object?, Object?> map) {
    return Geofence(
      identifier: map['identifier'] as String? ?? '',
      radius: (map['radius'] as num?)?.toDouble() ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      notifyOnEntry: map['notifyOnEntry'] as bool?,
      notifyOnExit: map['notifyOnExit'] as bool?,
      notifyOnDwell: map['notifyOnDwell'] as bool?,
      loiteringDelay: (map['loiteringDelay'] as num?)?.toInt(),
      extras: map['extras'] == null ? null : _castMap(map['extras']),
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'identifier': identifier,
      'radius': radius,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (notifyOnEntry != null) m['notifyOnEntry'] = notifyOnEntry;
    if (notifyOnExit != null) m['notifyOnExit'] = notifyOnExit;
    if (notifyOnDwell != null) m['notifyOnDwell'] = notifyOnDwell;
    if (loiteringDelay != null) m['loiteringDelay'] = loiteringDelay;
    if (extras != null) m['extras'] = extras;
    return m;
  }
}

class GeofencesChangeEvent {
  final List<Geofence> on;
  final List<Geofence> off;

  GeofencesChangeEvent({required this.on, required this.off});

  factory GeofencesChangeEvent.fromMap(Map<Object?, Object?> map) {
    return GeofencesChangeEvent(
      on: _geofenceList(map['on']),
      off: _geofenceList(map['off']),
    );
  }
}

class HttpEvent {
  final bool success;
  final int status;
  final String responseText;

  HttpEvent({
    required this.success,
    required this.status,
    required this.responseText,
  });

  factory HttpEvent.fromMap(Map<Object?, Object?> map) {
    return HttpEvent(
      success: map['success'] as bool? ?? false,
      status: (map['status'] as num?)?.toInt() ?? 0,
      responseText: map['responseText'] as String? ?? '',
    );
  }
}

class ConnectivityChangeEvent {
  final bool connected;

  ConnectivityChangeEvent({required this.connected});

  factory ConnectivityChangeEvent.fromMap(Map<Object?, Object?> map) {
    return ConnectivityChangeEvent(
      connected: map['connected'] as bool? ?? false,
    );
  }
}

class AuthorizationEvent {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final int? status;
  final Map<String, dynamic> raw;

  AuthorizationEvent({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.status,
    required this.raw,
  });

  factory AuthorizationEvent.fromMap(Map<Object?, Object?> map) {
    return AuthorizationEvent(
      success: map['success'] as bool? ?? false,
      accessToken: map['accessToken'] as String?,
      refreshToken: map['refreshToken'] as String?,
      status: (map['status'] as num?)?.toInt(),
      raw: _castMap(map),
    );
  }
}

class AuthState {
  final String? accessToken;
  final String? refreshToken;

  AuthState({this.accessToken, this.refreshToken});
}

class LogEntry {
  final String ts;
  final int level;
  final String src;
  final String event;
  final String? message;
  final dynamic data;

  LogEntry({
    required this.ts,
    required this.level,
    required this.src,
    required this.event,
    this.message,
    this.data,
  });

  factory LogEntry.fromMap(Map<Object?, Object?> map) {
    return LogEntry(
      ts: map['ts'] as String? ?? '',
      level: (map['level'] as num?)?.toInt() ?? 0,
      src: map['src'] as String? ?? '',
      event: map['event'] as String? ?? '',
      message: map['message'] as String?,
      data: map['data'],
    );
  }
}

class CurrentPositionOptions {
  final bool? persist;
  final int? samples;
  final int? timeout;
  final int? maximumAge;
  final int? desiredAccuracy;
  final Map<String, dynamic>? extras;

  CurrentPositionOptions({
    this.persist,
    this.samples,
    this.timeout,
    this.maximumAge,
    this.desiredAccuracy,
    this.extras,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    if (persist != null) m['persist'] = persist;
    if (samples != null) m['samples'] = samples;
    if (timeout != null) m['timeout'] = timeout;
    if (maximumAge != null) m['maximumAge'] = maximumAge;
    if (desiredAccuracy != null) m['desiredAccuracy'] = desiredAccuracy;
    if (extras != null) m['extras'] = extras;
    return m;
  }
}

class WatchPositionOptions {
  final int? interval;
  final int? desiredAccuracy;
  final bool? persist;
  final Map<String, dynamic>? extras;

  WatchPositionOptions({
    this.interval,
    this.desiredAccuracy,
    this.persist,
    this.extras,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    if (interval != null) m['interval'] = interval;
    if (desiredAccuracy != null) m['desiredAccuracy'] = desiredAccuracy;
    if (persist != null) m['persist'] = persist;
    if (extras != null) m['extras'] = extras;
    return m;
  }
}

class HeadlessEvent {
  final String name;
  final Map<String, dynamic> params;

  HeadlessEvent({required this.name, required this.params});

  factory HeadlessEvent.fromMap(Map<Object?, Object?> map) {
    final casted = _castMap(map);
    final name = casted['name'] as String? ?? '';
    final params = Map<String, dynamic>.from(casted)..remove('name');
    return HeadlessEvent(name: name, params: params);
  }
}

typedef HeadlessTask = Future<void> Function(HeadlessEvent event);
