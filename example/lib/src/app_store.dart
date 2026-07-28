/// Tiny shared store for the example app: structured log lines (same shape as
/// /device/logs events), breadcrumb points, the SDK geofence set, engine status
/// and the device-link state. A `ChangeNotifier` — screens subscribe with
/// `ListenableBuilder`, so no state-management package is needed.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:flutter/foundation.dart';

enum LogLevel { verbose, debug, info, warn, error }

/// Exactly the event shape uploaded to /device/logs — what you see in the app
/// is what the web console shows.
class LogLine {
  final String ts; // ISO
  final LogLevel level;
  final String event;
  final String? message;
  final Object? data;

  const LogLine({
    required this.ts,
    required this.level,
    required this.event,
    this.message,
    this.data,
  });
}

/// Which region fired on an `event:"geofence"` point, and how.
class PointGeofence {
  final String identifier;
  final String? action;

  const PointGeofence({required this.identifier, this.action});
}

class Point {
  final String? uuid;
  final double latitude;
  final double longitude;
  final String timestamp; // ISO
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? odometer; // metres
  final String? activity;
  final bool? isMoving;
  final String? event;
  final PointGeofence? geofence;

  const Point({
    this.uuid,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.heading,
    this.odometer,
    this.activity,
    this.isMoving,
    this.event,
    this.geofence,
  });
}

class LinkState {
  final String serverUrl;
  final bool linked;
  final String? deviceId;

  const LinkState({required this.serverUrl, required this.linked, this.deviceId});

  LinkState copyWith({String? serverUrl, bool? linked, String? deviceId, bool clearDeviceId = false}) =>
      LinkState(
        serverUrl: serverUrl ?? this.serverUrl,
        linked: linked ?? this.linked,
        deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      );
}

class EngineStatus {
  final bool ready;
  final bool enabled;
  final bool isMoving;
  final double? batteryLevel;

  const EngineStatus({
    required this.ready,
    required this.enabled,
    required this.isMoving,
    this.batteryLevel,
  });

  EngineStatus copyWith({bool? ready, bool? enabled, bool? isMoving, double? batteryLevel}) =>
      EngineStatus(
        ready: ready ?? this.ready,
        enabled: enabled ?? this.enabled,
        isMoving: isMoving ?? this.isMoving,
        batteryLevel: batteryLevel ?? this.batteryLevel,
      );
}

/// Same buffer caps as the RN example.
const _maxLogs = 1000;
const _maxPoints = 2000;

class AppStore extends ChangeNotifier {
  final List<LogLine> _logs = [];
  final List<Point> _points = [];
  List<Geofence> _geofences = [];
  LinkState _link = const LinkState(serverUrl: 'https://app.bgeo.dev', linked: false);
  EngineStatus _status = const EngineStatus(ready: false, enabled: false, isMoving: false);

  List<LogLine> get logs => List.unmodifiable(_logs);
  List<Point> get points => List.unmodifiable(_points);
  List<Geofence> get geofences => List.unmodifiable(_geofences);
  LinkState get link => _link;
  EngineStatus get status => _status;

  void appendLog(LogLine line) {
    _logs.add(line);
    if (_logs.length > _maxLogs) _logs.removeRange(0, _logs.length - _maxLogs);
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void appendPoint(Point point) {
    _points.add(point);
    if (_points.length > _maxPoints) _points.removeRange(0, _points.length - _maxPoints);
    notifyListeners();
  }

  void clearTrack() {
    _points.clear();
    notifyListeners();
  }

  void setGeofences(List<Geofence> geofences) {
    _geofences = geofences;
    notifyListeners();
  }

  void setLink({String? serverUrl, bool? linked, String? deviceId, bool clearDeviceId = false}) {
    _link = _link.copyWith(
      serverUrl: serverUrl,
      linked: linked,
      deviceId: deviceId,
      clearDeviceId: clearDeviceId,
    );
    notifyListeners();
  }

  void setStatus({bool? ready, bool? enabled, bool? isMoving, double? batteryLevel}) {
    _status = _status.copyWith(
      ready: ready,
      enabled: enabled,
      isMoving: isMoving,
      batteryLevel: batteryLevel,
    );
    notifyListeners();
  }
}

final appStore = AppStore();
