import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> topLevelTask(HeadlessEvent event) async {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.bgeo/methods');

  test('registerHeadlessTask sends two callback handles', () async {
    MethodCall? seen;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async { seen = call; return null; });
    await BackgroundGeolocation.registerHeadlessTask(topLevelTask);
    expect(seen!.method, 'registerHeadlessTask');
    final args = seen!.arguments as Map;
    expect(args['dispatcherHandle'], isA<int>());
    expect(args['taskHandle'], isA<int>());
  });

  test('closure task throws ArgumentError', () {
    expect(() => BackgroundGeolocation.registerHeadlessTask((e) async {}),
        throwsArgumentError);
  });
}
