/// Smoke test of the app shell: the tabs mount and switch without exceptions,
/// with the plugin's method channel stubbed out. Map tiles are left to fail —
/// the test binding stubs all network with a 400 and `flutter_map` handles tile
/// errors internally, so the chrome under test is unaffected.
library;

import 'package:bgeo_background_geolocation_example/main.dart';
import 'package:bgeo_background_geolocation_example/src/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.bgeo/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appStore.clearTrack();
    appStore.clearLogs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getLog':
          return <Object?, Object?>{'entries': <Object?>[]};
        case 'getGeofences':
          return <Object?, Object?>{'geofences': <Object?>[]};
        case 'getLocations':
          return <Object?, Object?>{'locations': <Object?>[]};
        case 'getCount':
          return 0;
        default:
          return <Object?, Object?>{'enabled': false};
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  /// Drains the async boot (`ready()`, `restoreLink()`, `syncGeofences()`)
  /// without `pumpAndSettle`, which would spin on the Logs screen's 3 s poll
  /// timer. Also means the widget isn't torn down mid-boot.
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const BGeoExampleApp());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('mounts the three tabs and switches between them', (tester) async {
    await boot(tester);

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Map screen chrome.
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Get position'), findsOneWidget);
    expect(find.text('Collected coordinates'), findsOneWidget);
    expect(find.text('not linked'), findsOneWidget);

    await tester.tap(find.text('Logs'));
    await tester.pump();
    // The level filter chips plus the `ready` line the boot logged.
    expect(find.text('verbose'), findsOneWidget);
    expect(find.text('follow'), findsOneWidget);
    expect(find.textContaining('ready'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Debug console'), findsOneWidget);
    expect(find.text('Registration code'), findsOneWidget);

    // Config sections render from the schema. The Settings list is long and
    // lazily built, so scroll the later sections into view.
    final settingsScrollable = find
        .descendant(
          of: find.byKey(const Key('settingsList')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Distance filter (m)'), 200,
        scrollable: settingsScrollable);
    expect(find.text('Geolocation'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Engine state'), 400,
        scrollable: settingsScrollable);
    expect(find.text('Sync now'), findsOneWidget);
  });

  testWidgets('a location point reaches the status row and the sheet badge', (tester) async {
    await boot(tester);

    // Both the map status row and the sheet header show the count.
    expect(find.text('0 pts'), findsNWidgets(2));

    appStore.appendPoint(const Point(
      latitude: 52.52,
      longitude: 13.405,
      timestamp: '2026-07-28T10:00:00.000Z',
    ));
    await tester.pump();

    expect(find.text('1 pts'), findsNWidgets(2));
  });
}
