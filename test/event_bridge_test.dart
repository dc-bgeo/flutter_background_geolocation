import 'package:bgeo_background_geolocation/src/event_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('com.bgeo/events');

  test('envelopes demux to the right per-event stream', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, MockStreamHandler.inline(
      onListen: (args, sink) {
        sink.success({'event': 'heartbeat', 'params': {'foo': 1}});
        sink.success({'event': 'location', 'params': {'uuid': 'u1'}});
        sink.success({'event': 'heartbeat', 'params': {'foo': 2}});
      },
    ));

    final beats = <Map<String, dynamic>>[];
    final locs = <Map<String, dynamic>>[];
    EventBridge.on('heartbeat').listen(beats.add);
    EventBridge.on('location').listen(locs.add);
    await Future<void>.delayed(Duration.zero);

    expect(beats.map((e) => e['foo']), [1, 2]);
    expect(locs.single['uuid'], 'u1');
  });
}
