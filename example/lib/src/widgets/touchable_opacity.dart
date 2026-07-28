/// Flutter twin of React Native's `TouchableOpacity`, so the example's buttons
/// give the same press feedback as `react-native/example` (which never
/// overrides `activeOpacity`, so RN's defaults apply throughout):
///
/// - press-in dims to [activeOpacity] immediately (RN uses duration 0 for the
///   granted responder);
/// - press-out fades back to full over 250 ms;
/// - a null [onPressed] disables the control and holds it at [disabledOpacity].
///
/// Deliberately not `InkWell`: a Material ripple is a different interaction
/// language from the RN app this screen set mirrors.
library;

import 'package:flutter/widgets.dart';

/// RN's `TouchableOpacity` default.
const _rnActiveOpacity = 0.2;

/// RN's press-out fade (`_opacityInactive(250)`).
const _fadeBackDuration = Duration(milliseconds: 250);

class TouchableOpacity extends StatefulWidget {
  const TouchableOpacity({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.activeOpacity = _rnActiveOpacity,
    this.disabledOpacity = 1.0,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;

  /// Null disables the control: no press feedback, held at [disabledOpacity].
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Opacity while pressed.
  final double activeOpacity;

  /// Opacity while [onPressed] is null. Defaults to 1.0 (no dimming) — pass the
  /// value the corresponding RN style used (0.4 on the map, 0.5 elsewhere).
  final double disabledOpacity;

  final HitTestBehavior behavior;

  bool get _enabled => onPressed != null || onLongPress != null;

  @override
  State<TouchableOpacity> createState() => _TouchableOpacityState();
}

class _TouchableOpacityState extends State<TouchableOpacity> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget._enabled;
    final target = !enabled
        ? widget.disabledOpacity
        : (_pressed ? widget.activeOpacity : 1.0);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: AnimatedOpacity(
        opacity: target,
        // Dim instantly, fade back — matching RN's asymmetric timing.
        duration: _pressed ? Duration.zero : _fadeBackDuration,
        child: widget.child,
      ),
    );
  }
}
