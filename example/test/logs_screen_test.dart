/// Logs screen layout + filtering.
///
/// The console viewport must span the full screen width whether or not there
/// are lines — with an empty state it used to shrink-wrap the placeholder text,
/// because a `ListView` child fills its box on its own but a `Text` does not.
library;

import 'package:bgeo_background_geolocation_example/src/app_store.dart';
import 'package:bgeo_background_geolocation_example/src/screens/logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.bgeo/methods');

/// Horizontal margin the console box is inset by, per side.
const _consoleMargin = 12.0;

/// Width of the *painted* console box. Measured on the DecoratedBox rather than
/// the Container, whose render box also covers its margin.
double _consoleWidth(WidgetTester tester) {
  final box = find.ancestor(
    of: find.byType(ListView).evaluate().isNotEmpty
        ? find.byType(ListView)
        : find.text('waiting for events…'),
    matching: find.byType(DecoratedBox),
  );
  return tester.getRect(box.first).width;
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LogsScreen())));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    appStore.clearLogs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'getLog') return <Object?, Object?>{'entries': <Object?>[]};
      return <Object?, Object?>{'enabled': false};
    });
  });

  tearDown(() {
    appStore.clearLogs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('the empty console spans the full width', (tester) async {
    await _pump(tester);

    expect(find.text('waiting for events…'), findsOneWidget);

    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(_consoleWidth(tester), screenWidth - _consoleMargin * 2);
  });

  testWidgets('the console keeps that width once lines arrive', (tester) async {
    await _pump(tester);
    final empty = _consoleWidth(tester);

    appStore.appendLog(const LogLine(
      ts: '2026-07-28T10:31:00.000Z',
      level: LogLevel.info,
      event: 'ready',
      message: 'enabled=false',
    ));
    await tester.pump();

    expect(find.text('waiting for events…'), findsNothing);
    expect(_consoleWidth(tester), empty,
        reason: 'width must not change between empty and populated states');
  });

  testWidgets('the level filter narrows the visible lines', (tester) async {
    await _pump(tester);

    appStore.appendLog(const LogLine(
      ts: '2026-07-28T10:31:00.000Z',
      level: LogLevel.info,
      event: 'ready',
    ));
    appStore.appendLog(const LogLine(
      ts: '2026-07-28T10:31:01.000Z',
      level: LogLevel.error,
      event: 'boom',
    ));
    await tester.pump();

    expect(find.textContaining('ready'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.ensureVisible(find.text('error'));
    await tester.pump();
    await tester.tap(find.text('error'));
    await tester.pump();

    expect(find.textContaining('ready'), findsNothing);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
