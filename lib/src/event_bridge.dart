import 'dart:async';
import 'package:flutter/services.dart';

/// Fans the single native event stream out to per-event broadcast streams.
/// The native subscription is created on first use and intentionally never
/// cancelled: while the Dart side is alive the engine must keep routing
/// events here (cancelling would divert them to the headless dispatcher).
class EventBridge {
  static const EventChannel _channel = EventChannel('com.bgeo/events');
  static StreamSubscription<dynamic>? _nativeSub;
  static final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  static Stream<Map<String, dynamic>> on(String event) {
    _ensureNativeSubscription();
    return _controllerFor(event).stream;
  }

  static StreamController<Map<String, dynamic>> _controllerFor(String event) =>
      _controllers.putIfAbsent(event, () => StreamController.broadcast());

  static void _ensureNativeSubscription() {
    _nativeSub ??= _channel.receiveBroadcastStream().listen((dynamic envelope) {
      final map = envelope as Map;
      final name = map['event'] as String;
      final params = (map['params'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v)) ??
          <String, dynamic>{};
      _controllers[name]?.add(params);
    });
  }
}
