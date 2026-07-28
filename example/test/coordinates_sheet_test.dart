/// Layout regressions for the coordinates sheet.
///
/// The headline one: `ListView` (via `BoxScrollView`) injects
/// `MediaQuery.padding` when its own `padding` is null. On a device with a
/// notch the sheet's table was pushed down by the top inset — a ~47 px gap
/// between the head and the first row — and lost the bottom inset worth of
/// list height. Both are invisible on a zero-inset test device, so these tests
/// set real insets.
library;

import 'package:bgeo_background_geolocation_example/src/app_store.dart';
import 'package:bgeo_background_geolocation_example/src/widgets/coordinates_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Row height the sheet lays out with (`itemExtent`).
const _rowHeight = 36.0;

List<Point> _points(int n) => [
      for (var i = 0; i < n; i++)
        Point(
          latitude: 37.2487,
          longitude: -121.808,
          timestamp: '2026-07-28T10:11:${(10 + i).toString().padLeft(2, '0')}.000Z',
          accuracy: 19,
        ),
    ];

/// Pumps the sheet on a notched phone and drags it open.
Future<void> _pumpExpanded(WidgetTester tester, {int points = 6}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  // 47 / 34 logical — iPhone-style notch + home indicator.
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Stack(children: [CoordinatesSheet(points: _points(points))])),
  ));
  await tester.pump();
  await tester.drag(find.text('Collected coordinates'), const Offset(0, -400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the table head sits directly on the first row, with no gap',
      (tester) async {
    await _pumpExpanded(tester);

    final head = tester.getRect(find.text('TIME'));
    final list = tester.getRect(find.byType(ListView));

    expect(list.top, head.bottom,
        reason: 'no padding between the head block and the list');
  });

  testWidgets('the list does not inherit MediaQuery insets as padding', (tester) async {
    await _pumpExpanded(tester);

    final list = tester.getRect(find.byType(ListView));
    final firstRow = tester.getRect(find.text('06')); // newest point, list index 0

    // The row text is vertically centred in its itemExtent; anything more than
    // that offset means padding crept back in.
    final textInset = (_rowHeight - firstRow.height) / 2;
    expect(firstRow.top - list.top, closeTo(textInset, 0.5),
        reason: 'first row must start at the very top of the list');
  });

  testWidgets('rows stay on the itemExtent grid', (tester) async {
    await _pumpExpanded(tester);

    final r6 = tester.getRect(find.text('06'));
    final r5 = tester.getRect(find.text('05'));
    expect(r5.top - r6.top, _rowHeight);
  });

  testWidgets('newest point is first and the badge counts every point',
      (tester) async {
    await _pumpExpanded(tester, points: 6);

    expect(find.text('6 pts'), findsOneWidget);
    final r6 = tester.getRect(find.text('06'));
    final r1 = tester.getRect(find.text('01'));
    expect(r6.top, lessThan(r1.top), reason: 'newest first');
  });
}
