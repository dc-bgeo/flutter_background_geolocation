/// Compact from/to picker field for the Map screen range bar. Uses Flutter's
/// built-in two-step date -> time dialogs on both platforms (the RN version
/// needed a platform split because Android has no combined datetime mode).
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'touchable_opacity.dart';

class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'set…',
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;

  Future<void> _pick(BuildContext context) async {
    final base = value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _formatted(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}.${pad(d.month)} ${pad(d.hour)}:${pad(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: c.textDim, fontSize: 13, fontFamily: mono)),
        const SizedBox(width: 8),
        TouchableOpacity(
          onPressed: () => _pick(context),
          child: Container(
            constraints: const BoxConstraints(minWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value != null ? _formatted(value!) : placeholder,
              style: TextStyle(
                color: value != null ? c.text : c.textDim,
                fontSize: 13,
                fontFamily: mono,
                fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
        if (value != null)
          TouchableOpacity(
            onPressed: () => onChanged(null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('✕', style: TextStyle(color: c.dangerText, fontSize: 13)),
            ),
          ),
      ],
    );
  }
}
