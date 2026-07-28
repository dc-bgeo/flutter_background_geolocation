/// Keep the app store and the web console in sync with the SDK's geofence set
/// (the device is the source of truth). Call after every CRUD operation and on
/// onGeofencesChange.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';

import 'app_store.dart';
import 'device_link.dart';

Future<void> syncGeofences() async {
  final geofences = await BackgroundGeolocation.getGeofences();
  appStore.setGeofences(geofences);
  // no-op (false) when not linked
  await putGeofences(geofences.map((g) => g.toMap()).toList());
}
