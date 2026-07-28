import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

// A realistic native location payload (shape from RN types.ts / engine uploads).
final nativeLocation = <Object?, Object?>{
  'uuid': 'abc-123',
  'timestamp': '2026-07-27T10:00:00.000Z',
  'odometer': 1234.5,
  'is_moving': true,
  'coords': {
    'latitude': 52.23, 'longitude': 21.01, 'accuracy': 12.0,
    'speed': 8.4, 'speed_accuracy': 1.1, 'heading': 90.0,
    'altitude': 100.0, 'ellipsoidal_altitude': 130.0,
  },
  'activity': {'type': 'in_vehicle', 'confidence': 92},
  'battery': {'level': 0.81, 'is_charging': false},
  'extras': {'watch': true},
};

void main() {
  test('Location.fromMap parses a native payload', () {
    final l = Location.fromMap(nativeLocation);
    expect(l.uuid, 'abc-123');
    expect(l.isMoving, true);
    expect(l.coords.latitude, 52.23);
    expect(l.coords.speedAccuracy, 1.1);
    expect(l.activity.type, activityTypeInVehicle);
    expect(l.battery.isCharging, false);
    expect(l.extras?['watch'], true);
    expect(l.raw['uuid'], 'abc-123');
  });

  test('MotionChangeEvent tolerates a null location (first event of a session)', () {
    final e = MotionChangeEvent.fromMap({'isMoving': true, 'location': null});
    expect(e.isMoving, true);
    expect(e.location, isNull);
  });

  test('Geofence roundtrip omits nulls', () {
    final g = Geofence(identifier: 'home', radius: 200, latitude: 52.0, longitude: 21.0);
    final m = g.toMap();
    expect(m, {'identifier': 'home', 'radius': 200.0, 'latitude': 52.0, 'longitude': 21.0});
    final back = Geofence.fromMap(m);
    expect(back.identifier, 'home');
    expect(back.notifyOnEntry, isNull);
  });

  test('HttpEvent.fromMap', () {
    final e = HttpEvent.fromMap({'success': false, 'status': 0, 'responseText': 'timeout'});
    expect(e.success, false);
    expect(e.status, 0);
  });
}
