/// Regression test for `unlinkDevice`'s config clear — companion to the
/// Android (`DeviceLinkTest.unlink clears the config via the CLEAR sentinel`)
/// and iOS (`DeviceLinkTests.testUnlinkEmitsClearSentinelForUrlAndAuthorization`)
/// unlink tests. Flutter's `Config` has no clear sentinel (see `config.dart`'s
/// `Config.toMap()`, which simply omits nulls), so `device_link.dart` already
/// uses the empty-string workaround for `url`/`logUrl`/`authorization` on
/// unlink — this only guards against that call losing `logUrl` again.
library;

import 'package:bgeo_background_geolocation_example/src/app_store.dart';
import 'package:bgeo_background_geolocation_example/src/device_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.bgeo/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final setConfigCalls = <Map<Object?, Object?>>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setConfigCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'setConfig') {
        setConfigCalls.add(call.arguments as Map<Object?, Object?>);
      }
      return <Object?, Object?>{'enabled': false};
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('unlinkDevice clears logUrl the same way it clears url', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'bgeo:link',
      '{"serverUrl":"https://app.bgeo.dev","deviceId":"dev-1",'
          '"accessToken":"at-1","refreshToken":"rt-1","installUuid":"uuid-1"}',
    );
    appStore.setLink(serverUrl: 'https://app.bgeo.dev', linked: true, deviceId: 'dev-1');

    await unlinkDevice();

    expect(setConfigCalls, hasLength(1));
    // Not an omitted key: logUrl must be present in the same setConfig call
    // that clears url, or the engine keeps POSTing this device's logs to the
    // server it just unlinked from, now with the auth block stripped.
    expect(setConfigCalls.single['url'], '');
    expect(setConfigCalls.single['logUrl'], '');
    expect(setConfigCalls.single['authorization'], {
      'strategy': '',
      'accessToken': '',
      'refreshToken': '',
      'refreshUrl': '',
    });
    expect(prefs.getString('bgeo:link'), isNull);
    expect(appStore.link.linked, isFalse);
    expect(appStore.link.deviceId, isNull);
  });
}
