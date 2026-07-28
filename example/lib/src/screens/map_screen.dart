/// Map screen — console parity: status chips, start/stop, layer toggles
/// (follow/markers/polylines/geofences), from-to history range (hybrid source),
/// geofence CRUD (long-press to add, tap a fence pin to edit).
///
/// Uses `flutter_map` with OSM tiles so the example runs without a maps API key.
/// Two deliberate divergences from the RN screen, both from dropping the native
/// map: the satellite toggle swaps in key-free Esri World Imagery tiles instead
/// of a native satellite mapType, and dark mode applies a colour filter to the
/// tiles rather than flipping a native `userInterfaceStyle`.
library;

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_store.dart';
import '../history.dart';
import '../log_uploader.dart';
import '../theme.dart';
import '../widgets/coordinates_sheet.dart';
import '../widgets/date_time_field.dart';
import '../widgets/touchable_opacity.dart';
import 'geofence_form_screen.dart';

/// Markers get slow in the thousands — the map renders a paged window of at most
/// this many points (parity with the web console).
const _pageSize = 1000;

/// Geofence transition colors (parity with the web console's TrackMap).
const _geofenceActionColor = {
  'ENTER': Color(0xFF22C55E),
  'EXIT': Color(0xFFEF4444),
  'DWELL': Color(0xFFF59E0B),
};
const _geofenceFallbackColor = Color(0xFFF97316);

const _trackColor = Color(0xFF3A6FF0);
const _movingColor = Color(0xFF22C55E);

const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _satelliteTiles =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// Approximates the native map's dark appearance: invert, then re-rotate the hue
/// so water/land keep their relative tones instead of going negative-film.
const _darkTileMatrix = <double>[
  -0.6, -0.3, -0.1, 0, 255, //
  -0.2, -0.7, -0.1, 0, 255, //
  -0.2, -0.3, -0.5, 0, 255, //
  0, 0, 0, 1, 0, //
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();

  bool _follow = true;
  bool _satellite = false;
  bool _showMarkers = true;
  bool _showPolylines = true;
  bool _showGeofences = true;
  bool _panelOpen = true;
  DateTime? _fromDraft;
  DateTime? _toDraft;
  List<Point>? _historyPoints;
  bool _loading = false;
  int _page = 0;
  int _fittedPage = 0;
  bool _mapReady = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _toggleTracking(bool enabled) async {
    if (enabled) {
      await BackgroundGeolocation.stop();
      appStore.setStatus(enabled: false);
      logEvent('stop', 'tracking stopped', null, LogLevel.info);
    } else {
      try {
        await BackgroundGeolocation.requestPermission();
      } catch (e) {
        logEvent('requestPermission', e.toString(), null, LogLevel.error);
      }
      await BackgroundGeolocation.start();
      appStore.setStatus(enabled: true);
      logEvent('start', 'tracking started', null, LogLevel.info);
    }
  }

  Future<void> _getPosition() async {
    try {
      final location = await BackgroundGeolocation.getCurrentPosition(
        CurrentPositionOptions(samples: 1, timeout: 30),
      );
      final c = location.coords;
      logEvent(
        'getCurrentPosition',
        '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}',
        null,
        LogLevel.info,
      );
    } catch (e) {
      logEvent('getCurrentPosition', e.toString(), null, LogLevel.error);
    }
  }

  Future<void> _applyRange() async {
    if (_fromDraft == null && _toDraft == null) return;
    setState(() {
      _loading = true;
      _follow = false;
    });
    final points = await loadHistory(
      _fromDraft?.toUtc().toIso8601String(),
      _toDraft?.toUtc().toIso8601String(),
    );
    if (!mounted) return;
    setState(() {
      _historyPoints = points;
      _loading = false;
      _page = 0;
    });
    // Fit to the newest window of the range — that's what the map will draw.
    final window = points.length > _pageSize ? points.sublist(points.length - _pageSize) : points;
    _fitTo(window);
  }

  void _resetRange() {
    setState(() {
      _historyPoints = null;
      _fromDraft = null;
      _toDraft = null;
      _page = 0;
    });
  }

  void _fitTo(List<Point> points) {
    if (points.length < 2 || !_mapReady) return;
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      padding: const EdgeInsets.only(top: 180, bottom: 60, left: 40, right: 40),
    ));
  }

  void _recenter(Point? last) {
    if (last != null && _mapReady) {
      _mapController.move(LatLng(last.latitude, last.longitude), 15);
    }
    setState(() => _follow = true);
  }

  Future<void> _openGeofenceForm({
    required double latitude,
    required double longitude,
    String? identifier,
  }) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GeofenceFormScreen(
          latitude: latitude,
          longitude: longitude,
          identifier: identifier,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final c = colorsOf(context);
        final status = appStore.status;
        final link = appStore.link;
        final geofences = appStore.geofences;

        final rangeActive = _historyPoints != null;
        final displayPoints = _historyPoints ?? appStore.points;

        // Paged window over the track: page 0 = the newest _pageSize points
        // (follows live), older pages step back through history.
        final pageCount = (displayPoints.length / _pageSize).ceil().clamp(1, 1 << 30);
        final effPage = _page.clamp(0, pageCount - 1);
        final windowEnd = displayPoints.length - effPage * _pageSize;
        final windowStart = (windowEnd - _pageSize).clamp(0, displayPoints.length);
        final view = displayPoints.isEmpty
            ? const <Point>[]
            : displayPoints.sublist(windowStart, windowEnd.clamp(0, displayPoints.length));
        final onNewestPage = effPage == 0;
        final last = displayPoints.isEmpty ? null : displayPoints.last;

        // Follow the live tail, and re-fit when the user pages through history.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_mapReady) return;
          if (_follow && !rangeActive && onNewestPage && last != null) {
            _mapController.move(LatLng(last.latitude, last.longitude), _mapController.camera.zoom);
          }
          if (_fittedPage != effPage) {
            _fittedPage = effPage;
            _fitTo(view);
          }
        });

        // Latest geofence transition per region in the window — the region
        // (circle, pin) and its event dot take the action's color; regions that
        // did not fire keep the fallback orange. Events whose region is no
        // longer in the SDK snapshot stay a plain dot (web console parity).
        final geofenceActionColor = <String, Color>{};
        final geofenceEvents = <(Point, Color)>[];
        if (_showGeofences) {
          final known = geofences.map((g) => g.identifier).toSet();
          for (final p in view) {
            if (p.event != 'geofence') continue;
            final action = p.geofence?.action?.toUpperCase();
            final color = _geofenceActionColor[action] ?? _geofenceFallbackColor;
            geofenceEvents.add((p, color));
            final id = p.geofence?.identifier;
            if (id != null && known.contains(id)) geofenceActionColor[id] = color;
          }
        }

        return Stack(
          children: [
            _buildMap(
              context: context,
              view: view,
              last: last,
              onNewestPage: onNewestPage,
              status: status,
              geofences: geofences,
              geofenceActionColor: geofenceActionColor,
              geofenceEvents: geofenceEvents,
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusRow(c, status, link, displayPoints.length, rangeActive),
                    const SizedBox(height: 8),
                    _controlCard(c, status),
                  ],
                ),
              ),
            ),
            _mapFab(
              c: c,
              bottom: sheetPeekHeight + 84,
              onTap: () => setState(() => _satellite = !_satellite),
              child: Icon(_satellite ? Icons.layers : Icons.map_outlined,
                  size: 22, color: c.text),
            ),
            _mapFab(
              c: c,
              bottom: sheetPeekHeight + 24,
              background: _follow ? c.accent : c.panel,
              onTap: _follow ? null : () => _recenter(last),
              child: Icon(
                _follow ? Icons.my_location : Icons.location_searching,
                size: 20,
                color: _follow ? c.onAccent : c.text,
              ),
            ),
            if (pageCount > 1)
              _pager(c, effPage, pageCount, windowStart, windowEnd, displayPoints.length,
                  onNewestPage, rangeActive),
            CoordinatesSheet(points: displayPoints),
          ],
        );
      },
    );
  }

  Widget _buildMap({
    required BuildContext context,
    required List<Point> view,
    required Point? last,
    required bool onNewestPage,
    required EngineStatus status,
    required List<Geofence> geofences,
    required Map<String, Color> geofenceActionColor,
    required List<(Point, Color)> geofenceEvents,
  }) {
    final tileLayer = TileLayer(
      urlTemplate: _satellite ? _satelliteTiles : _osmTiles,
      userAgentPackageName: 'com.bgeo.example.flutter',
      // Esri imagery goes no deeper than 19; OSM stops at 19 too.
      maxNativeZoom: 19,
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(last?.latitude ?? 52.52, last?.longitude ?? 13.405),
        initialZoom: 15,
        onMapReady: () => setState(() => _mapReady = true),
        onLongPress: (_, point) => _openGeofenceForm(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _follow) setState(() => _follow = false);
        },
      ),
      children: [
        if (isDark(context) && !_satellite)
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(_darkTileMatrix),
            child: tileLayer,
          )
        else
          tileLayer,
        if (_showPolylines && view.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: view.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              color: _trackColor,
              strokeWidth: 3,
            ),
          ]),
        if (_showGeofences)
          CircleLayer(circles: [
            for (final g in geofences)
              CircleMarker(
                point: LatLng(g.latitude, g.longitude),
                radius: g.radius,
                useRadiusInMeter: true,
                color: (geofenceActionColor[g.identifier] ?? _geofenceFallbackColor)
                    .withValues(alpha: 0.12),
                borderColor: geofenceActionColor[g.identifier] ?? _geofenceFallbackColor,
                borderStrokeWidth: 2,
              ),
          ]),
        if (_showMarkers)
          CircleLayer(circles: [
            for (final p in view)
              CircleMarker(
                point: LatLng(p.latitude, p.longitude),
                radius: 4,
                color: _trackColor.withValues(alpha: 0.8),
                borderColor: Colors.white.withValues(alpha: 0.7),
                borderStrokeWidth: 1,
              ),
          ]),
        CircleLayer(circles: [
          for (final (point, color) in geofenceEvents)
            CircleMarker(
              point: LatLng(point.latitude, point.longitude),
              radius: 7,
              color: color.withValues(alpha: 0.4),
              borderColor: color,
              borderStrokeWidth: 2,
            ),
        ]),
        if (_showGeofences)
          MarkerLayer(markers: [
            for (final g in geofences)
              Marker(
                point: LatLng(g.latitude, g.longitude),
                width: 32,
                height: 40,
                alignment: Alignment.topCenter,
                child: TouchableOpacity(
                  onPressed: () => _openGeofenceForm(
                    latitude: g.latitude,
                    longitude: g.longitude,
                    identifier: g.identifier,
                  ),
                  child: Tooltip(
                    message: '${g.identifier} · tap to edit',
                    child: Icon(
                      Icons.place,
                      size: 32,
                      color: geofenceActionColor[g.identifier] ?? _geofenceFallbackColor,
                    ),
                  ),
                ),
              ),
          ]),
        if (last != null && onNewestPage)
          MarkerLayer(markers: [
            Marker(
              point: LatLng(last.latitude, last.longitude),
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: status.isMoving ? _movingColor : _trackColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _statusRow(
    ThemeColors c,
    EngineStatus status,
    LinkState link,
    int pointCount,
    bool rangeActive,
  ) {
    final metaStyle = TextStyle(fontSize: 13, fontFamily: mono, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.ready
                  ? (status.enabled ? c.success : c.textDim)
                  : c.warning,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            link.linked ? 'linked' : 'not linked',
            style: TextStyle(
              color: c.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: mono,
            ),
          ),
          if (link.linked && link.deviceId != null) ...[
            const SizedBox(width: 8),
            Text(
              link.deviceId!.length > 8 ? link.deviceId!.substring(0, 8) : link.deviceId!,
              style: TextStyle(color: c.textDim, fontSize: 13, fontFamily: mono),
            ),
          ],
          const Spacer(),
          Text(
            '● ${status.isMoving ? 'moving' : 'stationary'}',
            style: metaStyle.copyWith(color: status.isMoving ? c.successText : c.textDim),
          ),
          if (status.batteryLevel != null) ...[
            const SizedBox(width: 6),
            Text('${(status.batteryLevel! * 100).round()}%',
                style: metaStyle.copyWith(color: c.textDim)),
          ],
          const SizedBox(width: 6),
          Text('·', style: metaStyle.copyWith(color: c.textDim)),
          const SizedBox(width: 6),
          Text(
            '$pointCount pts${rangeActive ? ' (hist)' : ''}',
            style: metaStyle.copyWith(color: c.warningText, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _controlCard(ThemeColors c, EngineStatus status) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            children: [
              TouchableOpacity(
                onPressed: () => _toggleTracking(status.enabled),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: status.enabled ? c.danger : c.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(status.enabled ? Icons.stop : Icons.play_arrow,
                          size: 18, color: c.onAccent),
                      const SizedBox(width: 8),
                      Text(
                        status.enabled ? 'Stop' : 'Start',
                        style: TextStyle(
                          color: c.onAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TouchableOpacity(
                  onPressed: _getPosition,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_searching, size: 16, color: c.text),
                        const SizedBox(width: 8),
                        Text(
                          'Get position',
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TouchableOpacity(
                onPressed: () => setState(() => _panelOpen = !_panelOpen),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _panelOpen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: c.textDim,
                  ),
                ),
              ),
            ],
          ),
          if (_panelOpen) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _layerToggle(c, 'Follow', _follow, () => setState(() => _follow = !_follow)),
                const SizedBox(width: 8),
                _layerToggle(c, 'Pts', _showMarkers,
                    () => setState(() => _showMarkers = !_showMarkers)),
                const SizedBox(width: 8),
                _layerToggle(c, 'Line', _showPolylines,
                    () => setState(() => _showPolylines = !_showPolylines)),
                const SizedBox(width: 8),
                _layerToggle(c, 'Geo', _showGeofences,
                    () => setState(() => _showGeofences = !_showGeofences)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DateTimeField(
                          label: 'From',
                          value: _fromDraft,
                          onChanged: (d) => setState(() => _fromDraft = d),
                        ),
                        const SizedBox(width: 8),
                        DateTimeField(
                          label: 'To',
                          value: _toDraft,
                          onChanged: (d) => setState(() => _toDraft = d),
                          placeholder: 'now',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_loading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                  )
                else
                  _smallButton(
                    c,
                    'Apply',
                    _fromDraft == null && _toDraft == null ? null : _applyRange,
                  ),
                if (_historyPoints != null) ...[
                  const SizedBox(width: 8),
                  _smallButton(c, 'Live', _resetRange),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _layerToggle(ThemeColors c, String label, bool active, VoidCallback onTap) {
    return TouchableOpacity(
      onPressed: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? c.onAccent : c.textDim,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? c.onAccent : c.textDim,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallButton(ThemeColors c, String label, VoidCallback? onTap) {
    return TouchableOpacity(
      onPressed: onTap,
      // RN MapScreen's `styles.disabled`.
      disabledOpacity: 0.4,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
        child: Text(
          label,
          style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _mapFab({
    required ThemeColors c,
    required double bottom,
    required Widget child,
    VoidCallback? onTap,
    Color? background,
  }) {
    return Positioned(
      right: 14,
      bottom: bottom,
      child: TouchableOpacity(
        onPressed: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background ?? c.panel,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _pager(
    ThemeColors c,
    int effPage,
    int pageCount,
    int windowStart,
    int windowEnd,
    int total,
    bool onNewestPage,
    bool rangeActive,
  ) {
    final atOldest = effPage >= pageCount - 1;
    Widget arrow(String glyph, bool disabled, VoidCallback onTap) => TouchableOpacity(
          onPressed: disabled ? null : onTap,
          disabledOpacity: 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              glyph,
              style: TextStyle(
                color: c.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: mono,
              ),
            ),
          ),
        );

    return Positioned(
      left: 14,
      bottom: sheetPeekHeight + 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            arrow('‹', atOldest, () => setState(() => _page = effPage + 1)),
            Text(
              '${windowStart + 1}–$windowEnd / $total'
              '${onNewestPage && !rangeActive ? ' · live' : ''}',
              style: TextStyle(
                color: c.text,
                fontSize: 12,
                fontFamily: mono,
                fontWeight: FontWeight.w600,
              ),
            ),
            arrow('›', onNewestPage, () => setState(() => _page = effPage - 1)),
          ],
        ),
      ),
    );
  }
}
