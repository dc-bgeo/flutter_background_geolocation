/// Port of `react-native/example/__tests__/history.test.ts`.
library;

import 'package:bgeo_background_geolocation_example/src/app_store.dart';
import 'package:bgeo_background_geolocation_example/src/history.dart';
import 'package:flutter_test/flutter_test.dart';

Point _p(String timestamp) => Point(latitude: 1, longitude: 2, timestamp: timestamp);

void main() {
  test('filterPointsByRange keeps only points inside [from, to]', () {
    final points = [
      _p('2026-07-18T08:00:00.000Z'),
      _p('2026-07-18T10:00:00.000Z'),
      _p('2026-07-18T12:00:00.000Z'),
    ];

    final got = filterPointsByRange(points, '2026-07-18T09:00:00Z', '2026-07-18T11:00:00Z');
    expect(got.map((p) => p.timestamp), ['2026-07-18T10:00:00.000Z']);

    // Open-ended bounds.
    expect(filterPointsByRange(points, null, '2026-07-18T09:00:00Z'), hasLength(1));
    expect(filterPointsByRange(points, '2026-07-18T09:00:00Z', null), hasLength(2));
    expect(filterPointsByRange(points, null, null), hasLength(3));
  });

  test('serverLocationToPoint maps the console camelCase shape', () {
    final point = serverLocationToPoint({
      'uuid': 'u1',
      'recordedAt': '2026-07-18T10:00:00Z',
      'lat': 52.5,
      'lng': 13.4,
      'isMoving': true,
      'event': 'geofence',
    });

    expect(point.uuid, 'u1');
    expect(point.timestamp, '2026-07-18T10:00:00Z');
    expect(point.latitude, 52.5);
    expect(point.longitude, 13.4);
    expect(point.isMoving, isTrue);
    expect(point.event, 'geofence');
    // Absent numeric fields stay null rather than defaulting to 0.
    expect(point.accuracy, isNull);
    expect(point.speed, isNull);
    expect(point.odometer, isNull);
  });

  test('serverLocationToPoint falls back to `activity` when `activityType` is absent', () {
    expect(
      serverLocationToPoint({'recordedAt': 't', 'lat': 0, 'lng': 0, 'activity': 'walking'})
          .activity,
      'walking',
    );
    expect(
      serverLocationToPoint({
        'recordedAt': 't',
        'lat': 0,
        'lng': 0,
        'activityType': 'in_vehicle',
        'activity': 'walking',
      }).activity,
      'in_vehicle',
    );
  });
}
