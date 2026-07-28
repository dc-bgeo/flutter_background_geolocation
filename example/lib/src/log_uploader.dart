/// Single log pipeline: [logEvent] writes the structured line into the app store
/// (Logs screen) AND into the plugin's native log queue (`src:"js"`), which
/// persists it in bgeo.db and uploads batches to /device/logs with the engine's
/// own auth — surviving app kills, unlike a plain in-memory buffer.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart';

import 'app_store.dart';

Future<void> _write(LogLevel level, String message, Map<String, dynamic> data) {
  const logger = BackgroundGeolocation.logger;
  switch (level) {
    case LogLevel.error:
      return logger.error(message, data);
    case LogLevel.warn:
      return logger.warn(message, data);
    case LogLevel.info:
      return logger.info(message, data);
    case LogLevel.debug:
      return logger.debug(message, data);
    case LogLevel.verbose:
      return logger.verbose(message, data);
  }
}

/// [data] must be JSON-encodable — pass an event's `raw` map, not the typed
/// event object (the native logger and the Logs screen both `jsonEncode` it).
void logEvent(String event, String? message, Map<String, Object?>? data, LogLevel level) {
  appStore.appendLog(LogLine(
    ts: DateTime.now().toUtc().toIso8601String(),
    level: level,
    event: event,
    message: message,
    data: data,
  ));
  _write(level, message ?? event, {'event': event, 'data': ?data});
}
