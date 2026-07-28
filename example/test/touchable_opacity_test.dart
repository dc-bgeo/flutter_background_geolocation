/// Verifies the RN `TouchableOpacity` semantics the buttons rely on.
library;

import 'package:bgeo_background_geolocation_example/src/widgets/touchable_opacity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _opacityOf(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('dims to activeOpacity while pressed and restores on release',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(TouchableOpacity(
      onPressed: () => taps++,
      child: const Text('tap me'),
    )));

    expect(_opacityOf(tester), 1.0);

    final gesture = await tester.startGesture(tester.getCenter(find.text('tap me')));
    await tester.pump();
    expect(_opacityOf(tester), 0.2, reason: "RN's default activeOpacity");

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_opacityOf(tester), 1.0);
    expect(taps, 1);
  });

  testWidgets('restores opacity when the press is cancelled without firing', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(TouchableOpacity(
      onPressed: () => taps++,
      child: const Text('tap me'),
    )));

    final gesture = await tester.startGesture(tester.getCenter(find.text('tap me')));
    await tester.pump();
    expect(_opacityOf(tester), 0.2);

    // Drag far away, then release: RN treats this as a cancel.
    await gesture.moveBy(const Offset(0, 400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_opacityOf(tester), 1.0);
    expect(taps, 0);
  });

  testWidgets('a null onPressed holds disabledOpacity and swallows taps', (tester) async {
    await tester.pumpWidget(_host(const TouchableOpacity(
      onPressed: null,
      disabledOpacity: 0.4,
      child: Text('tap me'),
    )));

    expect(_opacityOf(tester), 0.4);

    await tester.tap(find.text('tap me'));
    await tester.pump();
    // Still disabled-dim, never went to activeOpacity.
    expect(_opacityOf(tester), 0.4);
  });

  testWidgets('disabled defaults to no dimming', (tester) async {
    await tester.pumpWidget(_host(const TouchableOpacity(
      onPressed: null,
      child: Text('tap me'),
    )));
    expect(_opacityOf(tester), 1.0);
  });
}
