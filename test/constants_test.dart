import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constant values match the RN/native contract', () {
    expect(desiredAccuracyNavigation, -2);
    expect(desiredAccuracyHigh, -1);
    expect(desiredAccuracyMedium, 10);
    expect(desiredAccuracyLow, 100);
    expect(desiredAccuracyVeryLow, 1000);
    expect(desiredAccuracyLowest, 3000);
    expect(logLevelOff, 0);
    expect(logLevelVerbose, 5);
    expect(authorizationStatusAlways, 3);
    expect(authorizationStatusWhenInUse, 4);
    expect(accuracyAuthorizationFull, 0);
    expect(accuracyAuthorizationReduced, 1);
    expect(licenseMissing, 'LICENSE_MISSING');
    expect(activityTypeInVehicle, 'in_vehicle');
  });
}
