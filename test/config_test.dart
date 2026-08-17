import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Config.toMap serializes only non-null fields', () {
    const c = Config(
      desiredAccuracy: desiredAccuracyHigh,
      distanceFilter: 30,
      stopTimeout: 5,
      url: 'https://api.example.com/locations',
      headers: {'Authorization': 'Bearer x'},
      notification: Notification(title: 'Tracking', channelId: 'bgeo'),
      authorization: Authorization(strategy: 'JWT', accessToken: 'a', refreshUrl: 'https://r'),
    );
    final m = c.toMap();
    expect(m['desiredAccuracy'], -1);
    expect(m['distanceFilter'], 30.0);
    expect(m['url'], 'https://api.example.com/locations');
    expect((m['notification'] as Map)['channelId'], 'bgeo');
    expect((m['authorization'] as Map)['strategy'], 'JWT');
    expect(m.containsKey('stopOnTerminate'), false); // unset → absent
    expect(m.containsKey('logLevel'), false);
  });

  test('Config.toMap covers all 58 keys when fully populated', () {
    // Construct a Config with EVERY field set, assert toMap().length == 58.
    // Written out longhand — this test is the drift guard for the port.
    const c = Config(
      locationAuthorizationRequest: 'Always',
      locationAuthorizationAlert: {'titleWhenNotEnabled': 'Location required'},
      disableLocationAuthorizationAlert: true,
      backgroundPermissionRationale: {'title': 'Background location'},
      desiredAccuracy: desiredAccuracyHigh,
      distanceFilter: 30,
      disableLocationFilter: false,
      locationFilterMaxAccuracy: 100,
      locationFilterMaxSpeed: 60,
      locationFilterPolicy: 'Conservative',
      kalmanProfile: 'DEFAULT',
      odometerAccuracyThreshold: 0,
      disableElasticity: false,
      elasticityMultiplier: 1.0,
      stationaryDesiredAccuracy: 'BALANCED',
      stationaryLocationUpdateInterval: 30000,
      triggerActivities: 'in_vehicle,on_bicycle,walking,running,on_foot',
      minimumActivityRecognitionConfidence: 75,
      activityRecognitionInterval: 10000,
      disableMotionActivityUpdates: false,
      stopTimeout: 5,
      showsBackgroundLocationIndicator: true,
      stationaryRadius: 25,
      stationaryDistanceFilter: 25,
      preventSuspend: true,
      heartbeatInterval: 60,
      motionTriggerDelay: 0,
      locationUpdateInterval: 1000,
      foregroundService: true,
      notification: Notification(title: 'Tracking', channelId: 'bgeo'),
      stopOnTerminate: false,
      startOnBoot: true,
      debug: false,
      logLevel: logLevelInfo,
      logMaxDays: 3,
      logUrl: 'https://logs.example.com',
      maxDaysToPersist: 7,
      url: 'https://api.example.com/locations',
      method: 'POST',
      headers: {'Authorization': 'Bearer x'},
      params: {'device_id': 'abc'},
      extras: {'app_version': '1.0'},
      httpRootProperty: 'location',
      autoSync: true,
      disableAutoSyncOnCellular: false,
      autoSyncThreshold: 5,
      batchSync: true,
      maxBatchSize: 50,
      httpTimeoutMs: 60000,
      maxRecordsToPersist: 10000,
      authorization: Authorization(
        strategy: 'JWT',
        accessToken: 'a',
        refreshToken: 'r',
        refreshUrl: 'https://r',
        refreshPayload: {'refresh_token': '{refreshToken}'},
        refreshHeaders: {'X-Api-Key': 'k'},
      ),
      stationaryKeepAlive: true,
      diagnosticExtras: false,
      useSessionEngine: true,
      geofenceProximityRadius: 1000,
      maxMonitoredGeofences: -1,
      geofenceInitialTriggerEntry: true,
      crashDetection: CrashDetection(enabled: true, minSpeed: 11.11, impactThreshold: 4.0),
    );
    final m = c.toMap();
    expect(m.length, 58);
  });

  test('State keeps permissive access to unknown keys', () {
    final s = State.fromMap({'enabled': true, 'odometer': 12.5, 'sessionEngineActive': true});
    expect(s.enabled, true);
    expect(s.odometer, 12.5);
    expect(s['sessionEngineActive'], true);
  });
}
