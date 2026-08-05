/// Keep the app store and the web console in sync with the SDK's geofence set
/// (the device is the source of truth). Call after every CRUD operation and on
/// onGeofencesChange.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';

import 'app_store.dart';
import 'device_link.dart';
import 'log_uploader.dart';

Future<void> syncGeofences() async {
  final geofences = await BackgroundGeolocation.getGeofences();
  appStore.setGeofences(geofences);
  // The push is the one step whose failure is otherwise invisible: the fence
  // is on the device and drawn on the map, the console just never hears about
  // it. `putGeofences` is a no-op (false) when not linked, and swallows a
  // rejected request — so log the outcome rather than discarding it.
  final pushed = await putGeofences(geofences.map((g) => g.toMap()).toList());
  logEvent(
    'putGeofences',
    pushed
        ? '${geofences.length} mirrored to console'
        : 'console not updated (${geofences.length} local)',
    null,
    pushed ? LogLevel.info : LogLevel.warn,
  );
}
