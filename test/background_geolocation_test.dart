import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.bgeo/methods');
  const events = EventChannel('com.bgeo/events');
  final calls = <MethodCall>[];

  Future<void> mock(Object? Function(MethodCall) handler) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);

  test('ready passes config map and parses State', () async {
    await mock((c) => {'enabled': true, 'odometer': 0.0});
    final state = await BackgroundGeolocation.ready(const Config(distanceFilter: 30));
    expect(calls.single.method, 'ready');
    expect((calls.single.arguments as Map)['distanceFilter'], 30.0);
    expect(state.enabled, true);
  });

  test('sync snapshots the queue before draining', () async {
    await mock((c) => switch (c.method) {
          'getLocations' => {
              'locations': [
                {
                  'uuid': 'u1',
                  'coords': {'latitude': 1.0, 'longitude': 2.0, 'accuracy': 3.0},
                  'activity': {'type': 'still', 'confidence': 100},
                  'battery': {'level': 1.0, 'is_charging': false},
                  'is_moving': false,
                  'odometer': 0.0,
                  'timestamp': 't',
                }
              ]
            },
          'sync' => {'count': 1},
          _ => null,
        });
    final locations = await BackgroundGeolocation.sync();
    expect(calls.map((c) => c.method).toList(), ['getLocations', 'sync']);
    expect(locations.single.uuid, 'u1');
  });

  test('changePace surfaces PlatformException(DISABLED)', () async {
    await mock((c) => throw PlatformException(code: 'DISABLED'));
    expect(() => BackgroundGeolocation.changePace(true),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'DISABLED')));
  });

  test('addGeofences wraps the list', () async {
    await mock((c) => null);
    await BackgroundGeolocation.addGeofences(
        [Geofence(identifier: 'a', radius: 100, latitude: 1, longitude: 2)]);
    expect(calls.single.method, 'addGeofences');
    expect(((calls.single.arguments as Map)['geofences'] as List).length, 1);
  });

  test('getLog unwraps entries and defaults limit 500', () async {
    await mock((c) => {'entries': [{'ts': 't', 'level': 3, 'src': 'native', 'event': 'e'}]});
    final log = await BackgroundGeolocation.getLog();
    expect(calls.single.arguments, 500);
    expect(log.single.level, 3);
  });

  test('resetOdometer invokes setOdometer with 0.0', () async {
    await mock((c) => {
          'uuid': 'u1',
          'coords': {'latitude': 1.0, 'longitude': 2.0, 'accuracy': 3.0},
          'activity': {'type': 'still', 'confidence': 100},
          'battery': {'level': 1.0, 'is_charging': false},
          'is_moving': false,
          'odometer': 0.0,
          'timestamp': 't',
        });
    await BackgroundGeolocation.resetOdometer();
    expect(calls.single.method, 'setOdometer');
    expect(calls.single.arguments, 0.0);
  });

  // EventBridge lazily creates its native stream subscription exactly once
  // and never tears it down (see lib/src/event_bridge.dart), so the mock
  // stream handler's `listen` response is only ever driven once across the
  // whole file. Both event-based assertions therefore have to share the one
  // sink from a single `setMockStreamHandler` registration, inside a single
  // test (setMockStreamHandler ties its teardown to the enclosing test).
  test('event streams: onPowerSaveChange unwraps the bool; removeListeners cancels', () async {
    late MockStreamHandlerEventSink eventSink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(events, MockStreamHandler.inline(
      onListen: (args, sink) => eventSink = sink,
    ));

    final values = <bool>[];
    final powerSaveSub = BackgroundGeolocation.onPowerSaveChange(values.add);
    // Make sure EventBridge's native subscription exists before we push.
    await Future<void>.delayed(Duration.zero);

    eventSink.success({
      'event': 'powersavechange',
      'params': {'isPowerSaveMode': true}
    });
    await Future<void>.delayed(Duration.zero);
    expect(values, [true]);
    await powerSaveSub.cancel();

    final locations = <Location>[];
    BackgroundGeolocation.onLocation(locations.add);
    await Future<void>.delayed(Duration.zero);

    eventSink.success({
      'event': 'location',
      'params': {'uuid': 'before'}
    });
    await Future<void>.delayed(Duration.zero);
    expect(locations.map((l) => l.uuid), ['before']);

    await BackgroundGeolocation.removeListeners();

    eventSink.success({
      'event': 'location',
      'params': {'uuid': 'after'}
    });
    await Future<void>.delayed(Duration.zero);

    expect(locations.map((l) => l.uuid), ['before']);
  });
}
