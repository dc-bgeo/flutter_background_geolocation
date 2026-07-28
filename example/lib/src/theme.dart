/// Light/dark palette for the example app chrome (panels, tab bar, sheet).
///
/// The values are the web console's design tokens (`web/src/index.css`) converted
/// from oklch to hex — same palette on all three clients. Two roles per status
/// color: `success`/`warning`/`danger` are FILLS (the web's `--success` … tokens,
/// meant to carry a contrasting foreground), `*Text` are the readable inks for
/// type on `background`/`surface`. In dark they coincide; in light the fill stays
/// bright and the ink is the same hue darkened to clear 4.5:1.
///
/// Map-overlay colors (geofence actions, track polyline, breadcrumb dots) are NOT
/// theme-scoped — the web console keeps them fixed too.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeColors {
  /// Screen background.
  final Color background;

  /// Cards and raised chrome.
  final Color surface;

  /// Buttons, toggles, chips.
  final Color surfaceRaised;

  /// Text inputs and the log/terminal viewport.
  final Color field;
  final Color border;
  final Color separator;

  /// Floating panels over the map — translucent over `surface`.
  final Color panel;

  /// Bottom-sheet drag handle.
  final Color handle;

  final Color text;

  /// Secondary type (labels, values).
  final Color text2;

  /// Dimmed type (metadata, table gutters).
  final Color textDim;
  final Color placeholder;

  final Color accent;

  /// Accent as type — darkened in light so it clears 4.5:1.
  final Color accentText;

  /// Tinted accent background (badges).
  final Color accentSoft;

  /// Type on an `accent`/`danger` fill.
  final Color onAccent;

  final Color success;
  final Color warning;
  final Color danger;
  final Color successText;
  final Color warningText;
  final Color dangerText;

  /// Row tint for geofence events.
  final Color warningSoft;

  final Color tabBar;
  final Color tabBarBorder;

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.field,
    required this.border,
    required this.separator,
    required this.panel,
    required this.handle,
    required this.text,
    required this.text2,
    required this.textDim,
    required this.placeholder,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.successText,
    required this.warningText,
    required this.dangerText,
    required this.warningSoft,
    required this.tabBar,
    required this.tabBarBorder,
  });
}

const lightColors = ThemeColors(
  background: Color(0xFFF5F5F6),
  surface: Color(0xFFFFFFFF),
  surfaceRaised: Color(0xFFEFEFF0),
  field: Color(0xFFFFFFFF),
  border: Color(0xFFDDDEDF),
  separator: Color(0xFFE4E4E5),
  panel: Color.fromRGBO(255, 255, 255, 0.94),
  handle: Color(0xFFCFD0D2),
  text: Color(0xFF181819),
  text2: Color(0xFF525864),
  textDim: Color(0xFF717273),
  placeholder: Color(0xFF81868F),
  accent: Color(0xFF3A6FF0),
  accentText: Color(0xFF3265E5),
  accentSoft: Color.fromRGBO(58, 111, 240, 0.12),
  onAccent: Color(0xFFFFFFFF),
  success: Color(0xFF00C967),
  warning: Color(0xFFF4A620),
  danger: Color(0xFFFF3836),
  successText: Color(0xFF028845),
  warningText: Color(0xFFA16B08),
  dangerText: Color(0xFFE81420),
  warningSoft: Color.fromRGBO(244, 166, 32, 0.14),
  tabBar: Color(0xFFFFFFFF),
  tabBarBorder: Color(0xFFDDDEDF),
);

const darkColors = ThemeColors(
  background: Color(0xFF06080D),
  surface: Color(0xFF181819),
  surfaceRaised: Color(0xFF232324),
  field: Color(0xFF000000),
  border: Color(0xFF292929),
  separator: Color(0xFF212222),
  panel: Color.fromRGBO(24, 24, 25, 0.94),
  handle: Color(0xFF3F4045),
  text: Color(0xFFFCFCFD),
  text2: Color(0xFF9CA5B1),
  textDim: Color(0xFF9FA0A1),
  placeholder: Color(0xFF6D7580),
  accent: Color(0xFF3A6FF0),
  accentText: Color(0xFF6895F4),
  accentSoft: Color.fromRGBO(58, 111, 240, 0.28),
  onAccent: Color(0xFFFFFFFF),
  success: Color(0xFF00C967),
  warning: Color(0xFFF6B84F),
  danger: Color(0xFFDB3B3A),
  successText: Color(0xFF00C967),
  warningText: Color(0xFFF6B84F),
  dangerText: Color(0xFFDB3B3A),
  warningSoft: Color.fromRGBO(246, 184, 79, 0.10),
  tabBar: Color(0xFF0F0F14),
  tabBarBorder: Color(0xFF292929),
);

/// The palette for the scheme this subtree resolves to. `MaterialApp` owns the
/// system/light/dark decision (via [ThemeController]); widgets just read this.
ThemeColors colorsOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkColors : lightColors;

bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

final String mono = Platform.isIOS ? 'Menlo' : 'monospace';

/// `ThemeData` carrying only what the app chrome needs — every screen paints
/// itself from [ThemeColors], so this exists for `brightness` (which
/// [colorsOf] reads) plus the handful of Material defaults we do inherit
/// (switches, text fields, dialogs, pickers).
ThemeData themeDataFor(Brightness brightness) {
  final c = brightness == Brightness.dark ? darkColors : lightColors;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(primary: c.accent, surface: c.surface),
  );
}

// --- theme mode store ------------------------------------------------------

const _themeModeKey = 'bgeo:themeMode';

/// What the user picked; `ThemeMode.system` follows the OS (same contract as
/// the web console). Persisted across restarts.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode next) async {
    _mode = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, next.name);
  }

  /// Restore the persisted choice at boot.
  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    final match = ThemeMode.values.where((m) => m.name == raw).firstOrNull;
    if (match != null) {
      _mode = match;
      notifyListeners();
    }
  }
}

final themeController = ThemeController();
