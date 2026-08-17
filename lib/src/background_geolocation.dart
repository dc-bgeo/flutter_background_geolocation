import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'event_bridge.dart';
import 'models.dart';
import 'config.dart';
import 'headless.dart';

Map<Object?, Object?> _asMap(Object? map) => (map as Map?) ?? const {};

List<T> _mapList<T>(Object? list, T Function(Map<Object?, Object?>) fromMap) {
  if (list is! List) return <T>[];
  return list.map((e) => fromMap(e as Map<Object?, Object?>)).toList();
}

int _errorCodeFromEventMap(Map<String, dynamic> map) => (map['code'] as num?)?.toInt() ?? 0;

int _errorCodeFromPlatformException(Object error) {
  if (error is PlatformException) {
    return int.tryParse(error.code) ?? 0;
  }
  return 0;
}

/// Delegates every [StreamSubscription] method to [_inner], but marks
/// `removed` when cancelled — used by [BackgroundGeolocation.onConnectivityChange]
/// to guard its synthetic initial-state replay (RN parity).
class _GuardedSubscription<T> implements StreamSubscription<T> {
  _GuardedSubscription(this._inner, this._onCancel);

  final StreamSubscription<T> _inner;
  final void Function() _onCancel;

  @override
  Future<void> cancel() {
    _onCancel();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) =>
      futureValue == null ? _inner.asFuture<E>() : _inner.asFuture<E>(futureValue);
}

/// App log lines persisted natively (same queue as engine logs, `src:"js"`).
/// Every method swallows all errors — logging must never throw into app code.
class Logger {
  const Logger();

  Future<void> error(String message, [Map<String, dynamic>? data]) => _write(1, message, data);
  Future<void> warn(String message, [Map<String, dynamic>? data]) => _write(2, message, data);
  Future<void> info(String message, [Map<String, dynamic>? data]) => _write(3, message, data);
  Future<void> debug(String message, [Map<String, dynamic>? data]) => _write(4, message, data);
  Future<void> verbose(String message, [Map<String, dynamic>? data]) => _write(5, message, data);

  Future<void> _write(int level, String message, Map<String, dynamic>? data) async {
    try {
      await BackgroundGeolocation._channel.invokeMethod('log', {
        'level': level,
        'event': 'app',
        'message': message,
        'dataJson': data == null ? '' : jsonEncode(data),
      });
    } catch (_) {
      // Logging must never throw into app code.
    }
  }
}

/// Drop-in facade for the `com.bgeo` native engine — full RN
/// `react-native-background-geolocation` API parity, ported to Futures/Streams.
class BackgroundGeolocation {
  static const MethodChannel _channel = MethodChannel('com.bgeo/methods');
  static final Set<StreamSubscription<dynamic>> _subs = {};
  static StreamSubscription<Location>? _watchLocationSub;
  static StreamSubscription<int>? _watchErrorSub;

  static const Logger logger = Logger();

  // ---- lifecycle ------------------------------------------------------------

  static Future<State> ready(Config config) async => State.fromMap(
      _asMap(await _channel.invokeMapMethod<Object?, Object?>('ready', config.toMap())));

  static Future<State> setConfig(Config config) async => State.fromMap(
      _asMap(await _channel.invokeMapMethod<Object?, Object?>('setConfig', config.toMap())));

  static Future<State> start() async =>
      State.fromMap(_asMap(await _channel.invokeMapMethod<Object?, Object?>('start')));

  static Future<State> stop() async =>
      State.fromMap(_asMap(await _channel.invokeMapMethod<Object?, Object?>('stop')));

  static Future<State> getState() async =>
      State.fromMap(_asMap(await _channel.invokeMapMethod<Object?, Object?>('getState')));

  /// Manually force the moving/stationary state; rejects `PlatformException(DISABLED)`
  /// while stopped.
  static Future<void> changePace(bool isMoving) =>
      _channel.invokeMethod('changePace', isMoving);

  // ---- single-shot / watch ----------------------------------------------------

  static Future<Location> getCurrentPosition([CurrentPositionOptions? options]) async =>
      Location.fromMap(_asMap(await _channel.invokeMapMethod<Object?, Object?>(
          'getCurrentPosition', options?.toMap() ?? {})));

  static Future<void> watchPosition(
    void Function(Location) onLocation, {
    void Function(int errorCode)? onError,
    WatchPositionOptions? options,
  }) async {
    // Re-arm: drop any previous watch wiring first.
    _clearWatchSubscriptions();

    _watchLocationSub = EventBridge.on('location').map(Location.fromMap).listen((location) {
      // Native flags watch fixes via the echoed options.extras.watch marker so
      // the continuous watch stream stays distinct from ambient onLocation.
      if (location.extras?['watch'] == true) {
        onLocation(location);
      }
    });

    if (onError != null) {
      _watchErrorSub =
          EventBridge.on('locationerror').map(_errorCodeFromEventMap).listen(onError);
    }

    try {
      await _channel.invokeMethod('watchPosition', options?.toMap() ?? {});
    } catch (error) {
      onError?.call(_errorCodeFromPlatformException(error));
    }
  }

  static Future<void> stopWatchPosition() {
    _clearWatchSubscriptions();
    return _channel.invokeMethod('stopWatchPosition');
  }

  static void _clearWatchSubscriptions() {
    _watchLocationSub?.cancel();
    _watchErrorSub?.cancel();
    _watchLocationSub = null;
    _watchErrorSub = null;
  }

  // ---- permission / provider --------------------------------------------------

  static Future<int> requestPermission() async =>
      (await _channel.invokeMethod<num>('requestPermission'))?.toInt() ?? 0;

  /// iOS 14+: ask for temporary Precise accuracy. Resolves
  /// `ACCURACY_AUTHORIZATION_FULL` (0) or `ACCURACY_AUTHORIZATION_REDUCED` (1).
  static Future<int> requestTemporaryFullAccuracy(String purpose) async =>
      (await _channel.invokeMethod<num>('requestTemporaryFullAccuracy', purpose))?.toInt() ?? 0;

  static Future<ProviderChangeEvent> getProviderState() async => ProviderChangeEvent.fromMap(
      _asMap(await _channel.invokeMapMethod<Object?, Object?>('getProviderState')));

  /// Current OS battery-saver (Android) / Low Power Mode (iOS) state.
  static Future<bool> isPowerSaveMode() async =>
      await _channel.invokeMethod<bool>('isPowerSaveMode') ?? false;

  // ---- odometer ---------------------------------------------------------------

  static Future<double> getOdometer() async =>
      (await _channel.invokeMethod<num>('getOdometer'))?.toDouble() ?? 0;

  static Future<Location> setOdometer(double value) async => Location.fromMap(
      _asMap(await _channel.invokeMapMethod<Object?, Object?>('setOdometer', value)));

  /// Zero the odometer; resolves the current [Location] (Transistor semantics).
  static Future<Location> resetOdometer() => setOdometer(0.0);

  // ---- upload queue -------------------------------------------------------------

  /// Manually drain the native upload queue; resolves with the queued records
  /// (snapshotted before `sync` is invoked, Transistor semantics).
  static Future<List<Location>> sync() async {
    final snapshot = await getLocations();
    await _channel.invokeMethod('sync');
    return snapshot;
  }

  /// Records currently queued for upload, oldest-first.
  static Future<List<Location>> getLocations() async {
    final result = await _channel.invokeMethod<Object?>('getLocations');
    return _mapList(_asMap(result)['locations'], Location.fromMap);
  }

  /// Delete every queued record; resolves with how many were removed.
  static Future<int> destroyLocations() async {
    final result = await _channel.invokeMethod<Object?>('destroyLocations');
    return (_asMap(result)['count'] as num?)?.toInt() ?? 0;
  }

  /// Number of records currently queued for upload.
  static Future<int> getCount() async =>
      (await _channel.invokeMethod<num>('getCount'))?.toInt() ?? 0;

  /// Delete one queued record by uuid; rejects `PlatformException(NOT_FOUND)` when absent.
  static Future<void> destroyLocation(String uuid) =>
      _channel.invokeMethod('destroyLocation', uuid);

  /// Manually enqueue a record through the normal persist path (autoSync applies).
  static Future<void> insertLocation(Map<String, dynamic> location) =>
      _channel.invokeMethod('insertLocation', location);

  // ---- auth ---------------------------------------------------------------------

  static Future<AuthState> getAuthState() async {
    final map = _asMap(await _channel.invokeMapMethod<Object?, Object?>('getAuthState'));
    return AuthState(
      accessToken: map['accessToken'] as String?,
      refreshToken: map['refreshToken'] as String?,
    );
  }

  // ---- logger ---------------------------------------------------------------------

  /// Newest-first persisted log entries.
  static Future<List<LogEntry>> getLog({int limit = 500}) async {
    final result = await _channel.invokeMethod<Object?>('getLog', limit);
    return _mapList(_asMap(result)['entries'], LogEntry.fromMap);
  }

  /// Delete all persisted log entries; resolves with rows removed.
  static Future<int> destroyLog() async =>
      (await _channel.invokeMethod<num>('destroyLog'))?.toInt() ?? 0;

  /// Manually trigger a log upload; resolves with rows handed to the flusher.
  static Future<int> uploadLog() async =>
      (await _channel.invokeMethod<num>('uploadLog'))?.toInt() ?? 0;

  // ---- geofences ------------------------------------------------------------------

  static Future<void> addGeofence(Geofence geofence) =>
      _channel.invokeMethod('addGeofence', geofence.toMap());

  static Future<void> addGeofences(List<Geofence> geofences) => _channel.invokeMethod(
      'addGeofences', {'geofences': geofences.map((g) => g.toMap()).toList()});

  static Future<void> removeGeofence(String identifier) =>
      _channel.invokeMethod('removeGeofence', identifier);

  /// Removes ALL geofences (Transistor semantics).
  static Future<void> removeGeofences() => _channel.invokeMethod('removeGeofences');

  static Future<List<Geofence>> getGeofences() async {
    final result = await _channel.invokeMethod<Object?>('getGeofences');
    return _mapList(_asMap(result)['geofences'], Geofence.fromMap);
  }

  static Future<bool> geofenceExists(String identifier) async =>
      await _channel.invokeMethod<bool>('geofenceExists', identifier) ?? false;

  // ---- events -----------------------------------------------------------------------

  static StreamSubscription<Location> onLocation(void Function(Location) cb) {
    final sub = EventBridge.on('location').map(Location.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<int> onLocationError(void Function(int) cb) {
    final sub = EventBridge.on('locationerror').map(_errorCodeFromEventMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<MotionChangeEvent> onMotionChange(
      void Function(MotionChangeEvent) cb) {
    final sub = EventBridge.on('motionchange').map(MotionChangeEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<HeartbeatEvent> onHeartbeat(void Function(HeartbeatEvent) cb) {
    final sub = EventBridge.on('heartbeat').map(HeartbeatEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  /// Only armed while moving, and off by default (`crashDetection.enabled`)
  /// — see [Config.crashDetection].
  static StreamSubscription<CrashEvent> onCrash(void Function(CrashEvent) cb) {
    final sub = EventBridge.on('crash').map(CrashEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<GeofenceEvent> onGeofence(void Function(GeofenceEvent) cb) {
    final sub = EventBridge.on('geofence').map(GeofenceEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<GeofencesChangeEvent> onGeofencesChange(
      void Function(GeofencesChangeEvent) cb) {
    final sub = EventBridge.on('geofenceschange').map(GeofencesChangeEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<ProviderChangeEvent> onProviderChange(
      void Function(ProviderChangeEvent) cb) {
    final sub = EventBridge.on('providerchange').map(ProviderChangeEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<bool> onPowerSaveChange(void Function(bool) cb) {
    // Native emits {isPowerSaveMode}; the Transistor callback receives the bare boolean.
    final sub = EventBridge.on('powersavechange')
        .map((e) => e['isPowerSaveMode'] as bool? ?? false)
        .listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<HttpEvent> onHttp(void Function(HttpEvent) cb) {
    final sub = EventBridge.on('http').map(HttpEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  static StreamSubscription<ConnectivityChangeEvent> onConnectivityChange(
      void Function(ConnectivityChangeEvent) cb) {
    // Transistor parity: a new listener immediately receives the current state
    // — unless a real event beats the getState() round-trip or the listener is
    // already removed by then.
    var sawRealEvent = false;
    var removed = false;
    final sub = EventBridge.on('connectivitychange').map(ConnectivityChangeEvent.fromMap).listen(
        (e) {
      sawRealEvent = true;
      cb(e);
    });

    getState().then((state) {
      if (removed || sawRealEvent) return;
      cb(ConnectivityChangeEvent(connected: state.connected ?? false));
    }).catchError((_) {});

    final guarded = _GuardedSubscription<ConnectivityChangeEvent>(sub, () => removed = true);
    _subs.add(guarded);
    return guarded;
  }

  static StreamSubscription<AuthorizationEvent> onAuthorization(
      void Function(AuthorizationEvent) cb) {
    final sub = EventBridge.on('authorization').map(AuthorizationEvent.fromMap).listen(cb);
    _subs.add(sub);
    return sub;
  }

  // ---- headless -----------------------------------------------------------------

  /// Registers [task] to run in a background isolate when the app is
  /// terminated. [task] MUST be a top-level or static function annotated
  /// with `@pragma('vm:entry-point')` -- required so AOT (release) builds
  /// don't tree-shake the entry point; closures/instance methods cannot run
  /// in a killed-app isolate regardless.
  static Future<void> registerHeadlessTask(HeadlessTask task) =>
      _channel.invokeMethod('registerHeadlessTask', {
        'dispatcherHandle': dispatcherHandle(),
        'taskHandle': taskHandleOf(task),
      });

  /// Cancels every subscription handed out by the `onX` methods above (and the
  /// watchPosition subscriptions).
  static Future<void> removeListeners() async {
    _clearWatchSubscriptions();
    // Snapshot and clear BEFORE awaiting. `_subs` is static, so a listener
    // registered while these cancels are in flight (hot restart, a screen
    // subscribing as another disposes) would otherwise mutate the set being
    // iterated -- ConcurrentModificationError, leaving the rest uncancelled.
    // Clearing first also means such a listener stays live instead of being
    // dropped from the set without being cancelled.
    final pending = _subs.toList();
    _subs.clear();
    for (final sub in pending) {
      await sub.cancel();
    }
  }
}
