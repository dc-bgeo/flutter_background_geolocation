## 0.1.2

* Engine 0.13.0 embeds the production licence signing key in place of the
  development key that previously shipped. Licence tokens issued or re-signed
  before 2026-07-29 will not verify against this build — copy the current
  token from your dashboard at https://bgeo.dev before upgrading.
* iOS: the vendored `BGeoCore.xcframework` now ships an Apple privacy manifest
  (`PrivacyInfo.xcprivacy`) declaring precise/coarse location collection for
  app functionality and the `NSUserDefaults` required-reason API (`CA92.1`).
* Android: the engine AAR's Maven coordinate moved from
  `com.bgeo:bgeo-android:0.12.1` to `dev.bgeo:bgeo-android:0.13.0`. It's
  vendored in this package's local Maven repo per the documented setup, so no
  action is needed unless you hand-wrote the old coordinate directly.

## 0.1.1

* No functional changes. Release-infrastructure housekeeping: first version
  published through CI (GitHub Actions → pub.dev automated publishing);
  engine binaries verified current (BGeoCore / bgeo-android 0.12.1).

## 0.1.0

Initial release.

* Full RN/native `react-native-background-geolocation` API parity ported to
  Futures/Streams: `ready`/`start`/`stop`/`setConfig`/`getState`, `changePace`,
  `getCurrentPosition`/`watchPosition`, permission + provider-state queries,
  odometer, upload queue (`sync`/`getLocations`/`destroyLocation(s)`/`getCount`/
  `insertLocation`), auth state, persisted logger (`getLog`/`destroyLog`/
  `uploadLog`), and geofences (`add`/`remove`/`getGeofences`/`geofenceExists`).
* Event streams: `onLocation`, `onLocationError`, `onMotionChange`,
  `onHeartbeat`, `onGeofence`, `onGeofencesChange`, `onProviderChange`,
  `onPowerSaveChange`, `onHttp`, `onConnectivityChange`, `onAuthorization`.
* Headless (killed-app) event dispatch on Android via a top-level/static
  Dart entrypoint running in a background `FlutterEngine`.
* iOS (`BGeoCore.xcframework`, iOS 15.5+) and Android (`bgeo-android` AAR,
  minSdk 24) closed-source engine binaries vendored with the package.
* Offline license evaluation in debug builds and the iOS simulator; license
  key required for release builds via manifest meta-data / Info.plist.
