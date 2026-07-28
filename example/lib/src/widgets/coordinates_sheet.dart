/// Collapsible bottom sheet with the collected-coordinates table (newest first).
/// Peeks as the drag handle + header by default; drag or tap to expand.
/// The table scrolls horizontally (fixed-width columns) and vertically.
library;

import 'package:flutter/material.dart';

import '../app_store.dart';
import '../theme.dart';
import 'touchable_opacity.dart';

const _handleZoneHeight = 26.0;
const _headerHeight = 44.0;
const sheetPeekHeight = _handleZoneHeight + _headerHeight;

/// Table-head block height (used to bound the list so it can virtualize).
/// No trailing gap — the head sits directly on the first row's separator.
const _tableHeadHeight = 22.0;

/// Fixed row height — lets the list skip measurement.
const _rowHeight = 36.0;

// Column widths, matching the RN sheet.
const _colNum = 34.0;
const _colTime = 86.0;
const _colCoord = 96.0;
const _colWide = 116.0;
const _colMid = 96.0;
const _colEvent = 170.0;
const _tableWidth =
    _colNum + _colTime + _colCoord * 2 + _colMid * 5 + _colWide + _colEvent + 32;

String _formatTime(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '--:--:--';
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
}

String _num(double? v, int digits) => v != null && v >= 0 ? v.toStringAsFixed(digits) : '–';

/// Same palette as the web console's geofence-event markers, in the ink shades
/// that stay readable on the sheet.
Color _actionColor(ThemeColors c, String? action) {
  if (action == 'ENTER') return c.successText;
  if (action == 'EXIT') return c.dangerText;
  return c.warningText;
}

class CoordinatesSheet extends StatefulWidget {
  const CoordinatesSheet({super.key, required this.points});

  final List<Point> points;

  @override
  State<CoordinatesSheet> createState() => _CoordinatesSheetState();
}

class _CoordinatesSheetState extends State<CoordinatesSheet> {
  bool _expanded = false;
  double _height = sheetPeekHeight;
  double _dragStart = sheetPeekHeight;
  bool _dragging = false;

  double _expandedHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).height * 0.55).clamp(240.0, 460.0);

  void _snapTo(bool next, double expandedHeight) {
    setState(() {
      _expanded = next;
      _height = next ? expandedHeight : sheetPeekHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    final expandedHeight = _expandedHeight(context);
    // Newest first.
    final rows = widget.points.reversed.toList();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: _height.clamp(sheetPeekHeight, expandedHeight),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                _dragging = true;
                _dragStart = _height;
              },
              onVerticalDragUpdate: (d) {
                setState(() {
                  _dragStart -= d.delta.dy;
                  _height = _dragStart.clamp(sheetPeekHeight, expandedHeight);
                });
              },
              onVerticalDragEnd: (d) {
                _dragging = false;
                final projected = _height - d.velocity.pixelsPerSecond.dy * 0.12;
                _snapTo(projected > (sheetPeekHeight + expandedHeight) / 2, expandedHeight);
              },
              onTap: () => _snapTo(!_expanded, expandedHeight),
              child: Column(
                children: [
                  SizedBox(
                    height: _handleZoneHeight,
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.handle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _headerHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (_) => Container(
                                width: 18,
                                height: 2.5,
                                margin: const EdgeInsets.symmetric(vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Flexible: at a 4-digit point count the badge plus
                          // title would otherwise overflow a narrow phone.
                          Flexible(
                            child: Text(
                              'Collected coordinates',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${widget.points.length} pts',
                              style: TextStyle(
                                color: c.accentText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: mono,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Its own button, as in the RN sheet — the
                          // surrounding area is a drag surface, which must not
                          // dim while you drag it.
                          TouchableOpacity(
                            onPressed: () => _snapTo(!_expanded, expandedHeight),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _expanded ? Icons.expand_more : Icons.expand_less,
                                size: 20,
                                color: c.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TableHead(colors: c),
                      if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'no points yet',
                            style: TextStyle(
                              color: c.textDim,
                              fontFamily: mono,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        // Expanded, not a computed height: the sheet's box
                        // animates between peek and expanded, so any height
                        // derived from `expandedHeight` overflows on every
                        // intermediate frame.
                        Expanded(
                          child: ListView.builder(
                            // REQUIRED: with a null padding, BoxScrollView
                            // injects MediaQuery.padding — which on a device
                            // with a notch/home indicator pushed the first row
                            // down by the top inset and ate list height at the
                            // bottom. The sheet sits inside the safe area
                            // already.
                            padding: EdgeInsets.zero,
                            physics: _expanded
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            itemExtent: _rowHeight,
                            itemCount: rows.length,
                            itemBuilder: (context, index) => _Row(
                              point: rows[index],
                              number: rows.length - index,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead({required this.colors});

  final ThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: colors.textDim,
      fontSize: 12,
      fontFamily: mono,
      letterSpacing: 1,
    );
    Widget cell(String label, double width, {bool right = false}) => SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.only(right: right ? 12 : 0),
            child: Text(
              label,
              style: style,
              textAlign: right ? TextAlign.right : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: _tableHeadHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            cell('#', _colNum),
            cell('TIME', _colTime),
            cell('LAT', _colCoord, right: true),
            cell('LNG', _colCoord, right: true),
            cell('ACCURACY (m)', _colMid, right: true),
            cell('SPEED (m/s)', _colWide, right: true),
            cell('ODOMETER (m)', _colMid, right: true),
            cell('HEADING', _colMid, right: true),
            cell('IS MOVING', _colMid, right: true),
            cell('ACTIVITY', _colMid, right: true),
            cell('EVENT', _colEvent),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.point, required this.number});

  final Point point;
  final int number;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    final td = TextStyle(
        color: c.text, fontSize: 13, fontFamily: mono, fontWeight: FontWeight.w600);
    final tdDim = TextStyle(color: c.textDim, fontSize: 13, fontFamily: mono);
    final tdAcc = TextStyle(
        color: c.accentText, fontSize: 13, fontFamily: mono, fontWeight: FontWeight.w600);
    final tdMoving = TextStyle(
        color: c.successText, fontSize: 13, fontFamily: mono, fontWeight: FontWeight.w600);

    Widget cell(String text, double width, TextStyle style, {bool right = false}) => SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.only(right: right ? 12 : 0),
            child: Text(
              text,
              style: style,
              textAlign: right ? TextAlign.right : TextAlign.left,
              maxLines: 1,
            ),
          ),
        );

    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: point.event == 'geofence' ? c.warningSoft : null,
        border: Border(top: BorderSide(color: c.separator, width: 0.5)),
      ),
      child: Row(
        children: [
          cell(number.toString().padLeft(2, '0'), _colNum, tdDim),
          cell(_formatTime(point.timestamp), _colTime, td),
          cell(point.latitude.toStringAsFixed(5), _colCoord, td, right: true),
          cell(point.longitude.toStringAsFixed(5), _colCoord, td, right: true),
          cell(point.accuracy != null ? point.accuracy!.round().toString() : '–', _colMid, tdAcc,
              right: true),
          cell(_num(point.speed, 1), _colWide, td, right: true),
          cell(point.odometer != null ? point.odometer!.round().toString() : '–', _colMid, td,
              right: true),
          cell(
              point.heading != null && point.heading! >= 0
                  ? '${point.heading!.round()}°'
                  : '–',
              _colMid,
              td,
              right: true),
          cell(
              point.isMoving == null ? '–' : (point.isMoving! ? 'yes' : 'no'),
              _colMid,
              point.isMoving == true ? tdMoving : tdDim,
              right: true),
          cell(point.activity ?? '–', _colMid, tdDim, right: true),
          SizedBox(width: _colEvent, child: _EventCell(point: point)),
        ],
      ),
    );
  }
}

class _EventCell extends StatelessWidget {
  const _EventCell({required this.point});

  final Point point;

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    if (point.event == 'geofence') {
      final action = point.geofence?.action?.toUpperCase();
      final color = _actionColor(c, action);
      return Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${point.geofence?.identifier ?? 'geofence'}${action != null ? ' · $action' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontFamily: mono,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      point.event ?? '-',
      maxLines: 1,
      style: TextStyle(color: c.textDim, fontSize: 13, fontFamily: mono),
    );
  }
}
