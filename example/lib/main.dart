/// Example console for the `bgeo_background_geolocation` plugin — the Flutter
/// twin of `react-native/example`: Map / Logs / Settings tabs over the same
/// palette as the web console, with device linking, geofence CRUD and every
/// working config key exposed in Settings.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' hide State;
import 'package:flutter/material.dart';

import 'src/app_store.dart';
import 'src/config_store.dart';
import 'src/device_link.dart';
import 'src/geofences.dart';
import 'src/log_uploader.dart';
import 'src/screens/logs_screen.dart';
import 'src/screens/map_screen.dart';
import 'src/screens/settings_screen.dart';
import 'src/theme.dart';

/// Runs in a background isolate with the app killed (Android).
@pragma('vm:entry-point')
Future<void> headlessTask(HeadlessEvent event) async {
  // ignore: avoid_print
  print('[bgeo headless] ${event.name} ${event.params}');
}

void main() {
  runApp(const BGeoExampleApp());
}

/// Redacts an `onAuthorization` event (`{success, accessToken, refreshToken}`,
/// per the engine's authorization body) down to `success` plus token-presence
/// booleans, for the Logs screen/bgeo.db//device/logs — none of which should
/// ever see a live JWT.
Map<String, Object?> redactAuthorizationLogData(AuthorizationEvent event) {
  return {
    'success': event.success,
    'hasAccessToken': (event.accessToken ?? '').isNotEmpty,
    'hasRefreshToken': (event.refreshToken ?? '').isNotEmpty,
  };
}

class BGeoExampleApp extends StatefulWidget {
  const BGeoExampleApp({super.key});

  @override
  State<BGeoExampleApp> createState() => _BGeoExampleAppState();
}

class _BGeoExampleAppState extends State<BGeoExampleApp> {
  @override
  void initState() {
    super.initState();
    themeController.hydrate().catchError((_) {});
    _boot();
  }

  @override
  void dispose() {
    BackgroundGeolocation.removeListeners();
    super.dispose();
  }

  /// Subscribe to every event, restore a previous console link, then bring the
  /// engine up with the base config merged with the user's persisted Settings
  /// overrides.
  Future<void> _boot() async {
    await BackgroundGeolocation.registerHeadlessTask(headlessTask);
    _subscribe();

    try {
      await restoreLink();
    } catch (_) {
      // Not linked / unreadable link — the engine still runs local-only.
    }

    try {
      final overrides = await loadOverrides();
      final state = await BackgroundGeolocation.ready(bootConfig(overrides));
      appStore.setStatus(ready: true, enabled: state.enabled);
      logEvent(
        'ready',
        'enabled=${state.enabled} odometer=${state.odometer}',
        null,
        LogLevel.info,
      );
      await syncGeofences();
    } catch (e) {
      logEvent('ready', e.toString(), null, LogLevel.error);
    }
  }

  void _subscribe() {
    BackgroundGeolocation.onLocation((location) {
      final c = location.coords;
      appStore.appendPoint(Point(
        uuid: location.uuid,
        latitude: c.latitude,
        longitude: c.longitude,
        timestamp: location.timestamp,
        accuracy: c.accuracy,
        speed: c.speed,
        heading: c.heading,
        odometer: location.odometer,
        activity: location.activity.type,
        isMoving: location.isMoving,
        event: location.event,
      ));
      appStore.setStatus(isMoving: location.isMoving, batteryLevel: location.battery.level);
      logEvent(
        'onLocation',
        '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)} '
            '±${c.accuracy.toStringAsFixed(0)}m',
        {
          'lat': c.latitude,
          'lng': c.longitude,
          'accuracy': c.accuracy,
          'isMoving': location.isMoving,
          if (location.extras != null) 'extras': location.extras,
        },
        LogLevel.debug,
      );
    });

    BackgroundGeolocation.onMotionChange((event) {
      appStore.setStatus(isMoving: event.isMoving);
      logEvent('onMotionChange', 'isMoving=${event.isMoving}', null, LogLevel.info);
    });

    BackgroundGeolocation.onHeartbeat((_) {
      logEvent('onHeartbeat', null, null, LogLevel.debug);
    });

    BackgroundGeolocation.onProviderChange((event) {
      logEvent('onProviderChange', 'status=${event.status}', {
        'status': event.status,
        'enabled': event.enabled,
        'gps': event.gps,
        'network': event.network,
        'accuracyAuthorization': event.accuracyAuthorization,
      }, LogLevel.warn);
    });

    BackgroundGeolocation.onAuthorization((event) {
      // event.raw is `{success, accessToken, refreshToken}` — live JWTs.
      // redactAuthorizationLogData strips them to a token-presence signal
      // before this goes anywhere near the Logs screen/bgeo.db//device/logs;
      // the real event (with the real tokens) still goes to
      // persistRotatedTokens below.
      logEvent(
        'onAuthorization',
        event.success ? 'refreshed' : 'failed',
        redactAuthorizationLogData(event),
        event.success ? LogLevel.info : LogLevel.error,
      );
      persistRotatedTokens(event).catchError((_) {});
    });

    BackgroundGeolocation.onGeofence((event) {
      logEvent('onGeofence', '${event.action} ${event.identifier}', {
        'identifier': event.identifier,
        'action': event.action,
        if (event.extras != null) 'extras': event.extras,
      }, LogLevel.info);
      // Geofence transitions don't ride onLocation — append the point here so
      // the map and the coordinates table show them (same as the web console).
      final location = event.location;
      final gc = location.coords;
      appStore.appendPoint(Point(
        uuid: location.uuid,
        latitude: gc.latitude,
        longitude: gc.longitude,
        timestamp: location.timestamp,
        accuracy: gc.accuracy,
        speed: gc.speed,
        heading: gc.heading,
        odometer: location.odometer,
        activity: location.activity.type,
        isMoving: location.isMoving,
        event: 'geofence',
        geofence: PointGeofence(identifier: event.identifier, action: event.action),
      ));
    });

    BackgroundGeolocation.onGeofencesChange((event) {
      logEvent(
        'onGeofencesChange',
        'on=${event.on.length} off=${event.off.length}',
        null,
        LogLevel.debug,
      );
      syncGeofences().catchError((_) {});
    });

    BackgroundGeolocation.onHttp((event) {
      logEvent(
        'onHttp',
        '${event.status} ${event.success ? 'ok' : 'fail'}',
        {
          'success': event.success,
          'status': event.status,
          'responseText': event.responseText,
        },
        event.success ? LogLevel.debug : LogLevel.warn,
      );
    });

    BackgroundGeolocation.onConnectivityChange((event) {
      logEvent(
        'onConnectivityChange',
        'connected=${event.connected}',
        {'connected': event.connected},
        event.connected ? LogLevel.info : LogLevel.warn,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        // Shown in the Android task switcher.
        title: 'BGeoExample',
        debugShowCheckedModeBanner: false,
        themeMode: themeController.mode,
        theme: themeDataFor(Brightness.light),
        darkTheme: themeDataFor(Brightness.dark),
        home: const HomeTabs(),
      ),
    );
  }
}

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return Scaffold(
      backgroundColor: c.background,
      body: IndexedStack(
        index: _index,
        children: const [MapScreen(), LogsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.tabBar,
          border: Border(top: BorderSide(color: c.tabBarBorder)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: states.contains(WidgetState.selected) ? c.accent : c.textDim,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 24,
                color: states.contains(WidgetState.selected) ? c.accent : c.textDim,
              ),
            ),
          ),
          child: NavigationBar(
            height: 62,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.terminal), label: 'Logs'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
