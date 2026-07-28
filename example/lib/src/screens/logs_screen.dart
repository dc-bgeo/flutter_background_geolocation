/// Logs screen — the same event stream and formatting as the web console's
/// LogStream (ts / [LEVEL] / event / message / data, same colors), with a level
/// filter, follow-tail and clear. App lines stream live via [appStore]; native
/// engine lines (track.*, wake.*, motion.* — persisted by logLevel) are polled
/// from the plugin's getLog() history and merged in by timestamp.
library;

import 'dart:async';
import 'dart:convert';

import 'package:bgeo_background_geolocation/bgeo_background_geolocation.dart' hide State;
import 'package:flutter/material.dart';

import '../app_store.dart';
import '../theme.dart';
import '../widgets/touchable_opacity.dart';

const _levels = ['all', 'verbose', 'debug', 'info', 'warn', 'error'];

const _nativePollInterval = Duration(seconds: 3);
const _nativeFetchLimit = 300;

/// Native numeric levels -> [LogLevel].
const _levelNames = {
  1: LogLevel.error,
  2: LogLevel.warn,
  3: LogLevel.info,
  4: LogLevel.debug,
  5: LogLevel.verbose,
};

/// App lines (`src:"js"`) already stream via [appStore] — only merge native rows.
LogLine _toLogLine(LogEntry entry) => LogLine(
      ts: entry.ts,
      level: _levelNames[entry.level] ?? LogLevel.info,
      event: entry.event,
      message: entry.message,
      data: entry.data,
    );

/// Level inks, sourced from the palette so both themes stay readable. The web
/// console paints `info` green like the event name; here it takes the accent so
/// the level and the event stay distinguishable.
Color _levelColor(ThemeColors c, LogLevel level) {
  switch (level) {
    case LogLevel.verbose:
      return c.placeholder;
    case LogLevel.debug:
      return c.textDim;
    case LogLevel.info:
      return c.accentText;
    case LogLevel.warn:
      return c.warningText;
    case LogLevel.error:
      return c.dangerText;
  }
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  String _level = 'all';
  bool _follow = true;
  List<LogLine> _nativeLines = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchNative();
    _timer = Timer.periodic(_nativePollInterval, (_) => _fetchNative());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNative() async {
    try {
      final entries = await BackgroundGeolocation.getLog(limit: _nativeFetchLimit);
      if (!mounted) return;
      setState(() {
        _nativeLines =
            entries.where((e) => e.src == 'native').map(_toLogLine).toList();
      });
    } catch (_) {
      // A missing native side (tests, hot restart) must not break the screen.
    }
  }

  void _scrollToEndIfFollowing() {
    if (!_follow) return;
    // Post-frame so wrapped multi-line rows finish layout, else the scroll lands short.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final merged = [...appStore.logs, ..._nativeLines]..sort((a, b) => a.ts.compareTo(b.ts));
        final filtered =
            _level == 'all' ? merged : merged.where((l) => l.level.name == _level).toList();
        _scrollToEndIfFollowing();

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final l in _levels) ...[
                              _chip(c, l, _level == l, () => setState(() => _level = l)),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _chip(c, 'follow', _follow, () => setState(() => _follow = !_follow)),
                    const SizedBox(width: 6),
                    _chip(c, 'clear', false, appStore.clearLogs),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  // Without this the viewport shrink-wraps the empty-state text
                  // (the Column gives it loose horizontal constraints); a
                  // ListView child fills on its own, so only the empty state
                  // showed it.
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.field,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'waiting for events…',
                            style: TextStyle(
                              color: c.placeholder,
                              fontSize: 12,
                              fontFamily: mono,
                            ),
                          ),
                        )
                      : NotificationListener<ScrollStartNotification>(
                          // A user drag drops follow-tail; programmatic
                          // scrolls (dragDetails == null) must not.
                          onNotification: (n) {
                            if (n.dragDetails != null && _follow) {
                              setState(() => _follow = false);
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _LogRow(line: filtered[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(ThemeColors c, String label, bool active, VoidCallback onTap) {
    return TouchableOpacity(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c.onAccent : c.textDim,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.line});

  final LogLine line;

  String? _encodedData() {
    if (line.data == null) return null;
    try {
      return jsonEncode(line.data);
    } catch (_) {
      return line.data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    const base = TextStyle(fontSize: 12, height: 1.5);
    final data = _encodedData();
    return Text.rich(
      TextSpan(
        style: base.copyWith(fontFamily: mono),
        children: [
          TextSpan(
            text: '${line.ts.length >= 23 ? line.ts.substring(11, 23) : line.ts} ',
            style: TextStyle(color: c.textDim),
          ),
          TextSpan(
            text: '[${line.level.name.toUpperCase()}] ',
            style: TextStyle(color: _levelColor(c, line.level)),
          ),
          TextSpan(text: line.event, style: TextStyle(color: c.successText)),
          if (line.message != null)
            TextSpan(text: ' ${line.message}', style: TextStyle(color: c.text2)),
          if (data != null) TextSpan(text: ' $data', style: TextStyle(color: c.textDim)),
        ],
      ),
    );
  }
}
