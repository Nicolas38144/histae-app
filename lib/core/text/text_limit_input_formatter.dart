import 'package:flutter/services.dart';

import 'text_limits.dart';

/// Rejects over-limit edits without cutting existing text or pasted graphemes.
class TextLimitInputFormatter extends TextInputFormatter {
  const TextLimitInputFormatter(this.limit);

  final TextLengthLimit limit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) return newValue;

    final next = limit.overflow(newValue.text);
    if (next == (0, 0)) return newValue;

    // A saved draft from an earlier version can already exceed today's limit.
    final previous = limit.overflow(oldValue.text);
    if (next.$1 <= previous.$1 && next.$2 <= previous.$2 && next != previous) {
      return newValue;
    }

    return newValue.composing.isCollapsed
        ? oldValue.copyWith(composing: TextRange.empty)
        : oldValue;
  }
}
