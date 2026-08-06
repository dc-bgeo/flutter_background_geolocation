# bgeo_background_geolocation

[![downloads](https://img.shields.io/pub/dm/bgeo_background_geolocation?label=downloads&color=success)](https://pub.dev/packages/bgeo_background_geolocation)
[![pub](https://img.shields.io/pub/v/bgeo_background_geolocation?label=pub&color=blue)](https://pub.dev/packages/bgeo_background_geolocation)

**Reliable background geolocation for Flutter — iOS & Android.** Motion-aware
tracking, an offline HTTP queue, geofences, and headless (killed-app) events,
backed by the same closed-source BGeo engine used by the native SDKs — no
Dart runs in the background.

**Fully functional in DEBUG builds — no license required.** Every feature
works unlicensed in debug builds and the iOS simulator, so you can evaluate
the engine on a real device before buying anything. A key is only needed for
release builds — see [License keys](https://bgeo.dev/docs/flutter/getting-started/license/).

Full docs, guides, and API reference: **[bgeo.dev/docs/flutter](https://bgeo.dev/docs/flutter/)**.

## Requirements

- Flutter **≥ 3.22**, Dart **≥ 3.4**
- iOS **≥ 15.5**, Android **minSdk 24**

## Install

```sh
flutter pub add bgeo_background_geolocation
```

Import with an `as bg` prefix — the SDK's own `State` class otherwise
collides with Flutter's `State<T>` widget-state class:

```dart
import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' as bg;
```

## Android setup

Add the plugin's local Maven repo (it ships the closed engine AAR) to your
**app's** `android/app/build.gradle.kts`:

```kotlin
repositories {
    maven { url = uri("${project(":bgeo_background_geolocation").projectDir}/libs") }
}
```

`minSdk 24` or higher, and a license meta-data entry in
`android/app/src/main/AndroidManifest.xml` (use the literal string
`EVALUATION` for local dev):

```xml
<application>
  <meta-data
    android:name="com.bgeo.license"
    android:value="EVALUATION" />
</application>
```

Google Play requires the **app**, not a library, to declare background
location:

```xml
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

## iOS setup

Set the deployment target to **15.5** in `ios/Podfile` and the Runner
target's Xcode build settings, then `cd ios && pod install`.

Add these keys to `ios/Runner/Info.plist`:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Explain why your app tracks location in the background.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Explain why your app needs your current location.</string>
<key>NSMotionUsageDescription</key>
<string>Motion activity is used to detect movement and pause tracking when stationary.</string>
<key>BGeoLicense</key>
<string>EVALUATION</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

Enable the **Background Modes** capability (Location updates) under Runner →
Signing & Capabilities in Xcode.

Full walkthrough, including why each key/permission is required:
[Installation](https://bgeo.dev/docs/flutter/getting-started/installation/) ·
[Permissions & background location](https://bgeo.dev/docs/flutter/getting-started/permissions/).

## Quick start

```dart
import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' as bg;

Future<void> startTracking() async {
  bg.BackgroundGeolocation.onLocation((location) {
    print('[location] ${location.coords}');
  });

  final state = await bg.BackgroundGeolocation.ready(bg.Config(
    desiredAccuracy: bg.desiredAccuracyHigh,
    distanceFilter: 30,
    stopTimeout: 5, // minutes
    url: 'https://your-server.example/locations',
    stopOnTerminate: false,
    startOnBoot: true,
  ));

  if (!state.enabled) {
    final status = await bg.BackgroundGeolocation.requestPermission();
    if (status == bg.authorizationStatusAlways) {
      await bg.BackgroundGeolocation.start();
    }
  }
}
```

See [Quickstart](https://bgeo.dev/docs/flutter/getting-started/quickstart/)
for the full `main.dart`, what to expect on first run, and common pitfalls.

## Headless events (app killed)

Register a **top-level or static** function to receive events in a
background isolate after the app process is terminated (Android):

```dart
@pragma('vm:entry-point')
Future<void> headlessTask(bg.HeadlessEvent event) async {
  print('[bgeo headless] ${event.name} ${event.params}');
}

// ... after ready():
await bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
```

See [Boot & killed-app tracking](https://bgeo.dev/docs/flutter/guides/boot-and-killed-app/).

## License

This package is dual-licensed: the Dart/native bridge sources are MIT; the
vendored `BGeoCore.xcframework` (iOS) and `bgeo-android` AAR (Android) are
proprietary and require a license key in release builds. See
[`LICENSE`](./LICENSE) for the full terms and
[License keys](https://bgeo.dev/docs/flutter/getting-started/license/) for
how keys work.
