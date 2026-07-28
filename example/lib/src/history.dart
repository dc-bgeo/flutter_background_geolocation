/// Hybrid history source for the Map screen's from/to range: server history when
/// the device is linked (same data the web console shows), otherwise the local
/// session buffer filtered by timestamp.
library;

import 'app_store.dart';
import 'device_link.dart';

List<Point> filterPointsByRange(List<Point> points, String? from, String? to) {
  final fromMs = from == null ? null : DateTime.tryParse(from)?.millisecondsSinceEpoch;
  final toMs = to == null ? null : DateTime.tryParse(to)?.millisecondsSinceEpoch;
  return points.where((p) {
    final t = DateTime.tryParse(p.timestamp)?.millisecondsSinceEpoch;
    if (t == null) return false;
    return (fromMs == null || t >= fromMs) && (toMs == null || t <= toMs);
  }).toList();
}

double? _d(Object? v) => v is num ? v.toDouble() : null;

/// Console /v1 + /device history camelCase shape -> app [Point].
Point serverLocationToPoint(Map<String, Object?> loc) => Point(
      uuid: loc['uuid'] as String?,
      timestamp: loc['recordedAt'] as String? ?? '',
      latitude: _d(loc['lat']) ?? 0,
      longitude: _d(loc['lng']) ?? 0,
      accuracy: _d(loc['accuracy']),
      speed: _d(loc['speed']),
      heading: _d(loc['heading']),
      odometer: _d(loc['odometer']),
      activity: (loc['activityType'] ?? loc['activity']) as String?,
      isMoving: loc['isMoving'] as bool?,
      event: loc['event'] as String?,
    );

Future<List<Point>> loadHistory(String? from, String? to) async {
  if (await currentLink() != null) {
    final query = {'limit': '2000', 'from': ?from, 'to': ?to};
    final qs = Uri(queryParameters: query).query;
    final res = await deviceFetch('/device/locations?$qs');
    final locations = res?['locations'];
    if (locations is List) {
      // Server returns newest-first; polylines want oldest-first.
      return locations
          .whereType<Map>()
          .map((l) => serverLocationToPoint(l.map((k, v) => MapEntry(k.toString(), v))))
          .toList()
          .reversed
          .toList();
    }
  }
  return filterPointsByRange(appStore.points, from, to);
}
