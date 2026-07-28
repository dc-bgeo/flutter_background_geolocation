# bgeo_background_geolocation_example

Example console for the `bgeo_background_geolocation` plugin — the Flutter twin of
`react-native/example`. Same screens, same palette as the web console.

## What it does

Three tabs over the live SDK:

- **Map** — start/stop tracking, get-position, follow/points/line/geofences layer
  toggles, a from/to history range (server history when linked, otherwise the local
  session buffer), a 1000-point paging window, and a collapsible table of collected
  coordinates. Long-press the map to add a geofence; tap a geofence pin to edit or
  delete it.
- **Logs** — the same event stream and formatting as the web console's log view, with a
  level filter, follow-tail and clear. App lines stream live; native engine lines are
  polled from `getLog()` and merged in by timestamp.
- **Settings** — device linking, theme (system/light/dark), every working SDK config key
  (applied immediately via `setConfig` and persisted across restarts), reset-to-defaults,
  and engine state plus upload-queue tools (sync, destroy queue, upload logs, reset
  odometer).

`main.dart` registers a headless task and subscribes to `onLocation`, `onMotionChange`,
`onHeartbeat`, `onProviderChange`, `onAuthorization`, `onGeofence`, `onGeofencesChange`,
`onHttp` and `onConnectivityChange`.

## Map tiles

The Map screen uses [`flutter_map`] with OpenStreetMap raster tiles, so **no maps API key
is needed** — `flutter run` works out of the box. Two consequences versus the RN example's
native map:

- the satellite toggle switches to Esri World Imagery tiles rather than a native satellite
  layer;
- in dark mode the tiles get a colour filter, which approximates rather than matches a
  native dark map.

The OSM public tile servers are not free for general use — see the
[OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles) before
reusing this setup in a real app.

[`flutter_map`]: https://pub.dev/packages/flutter_map

## Linking to the web console (optional)

The app runs local-only until you link it. Create a registration code in the BGeo web
console (Dashboard → Registration codes), then in **Settings → Debug console** enter the
server URL and the code. Linking points the SDK's native uploader at `/device/locations`
and `/device/logs` with JWT auth (native refresh via `refreshUrl`, so killed-app uploads
survive token expiry), and mirrors your geofence set to the console.

Unlink from the same section.

## License key (evaluation)

Debug builds run unlicensed regardless of the configured key, so no real
license is required to run this example:

- Android: `com.bgeo.license` meta-data in `android/app/src/main/AndroidManifest.xml`
  is set to `EVALUATION`.
- iOS: `BGeoLicense` in `ios/Runner/Info.plist` is set to `EVALUATION`.

Replace these with a real `BGEO1...` key before shipping a release build.

## Headless task (Android)

`headlessTask` is a top-level function registered via
`BackgroundGeolocation.registerHeadlessTask`; it runs in a background
isolate when the app has been killed and simply prints the event name and
params.

## Running

```
flutter pub get
flutter run
```

## Verify without a device

```
flutter analyze
flutter test                                  # config store, history, app shell
flutter build ios --debug --no-codesign
flutter build apk --debug
```

GPS, background behaviour and the server link are only verifiable on real hardware.
