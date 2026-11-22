import 'dart:convert';
import 'dart:math' as math;

/// Maximum Unicode code points in long-form app fields.
const longTextCharacterLimit = 1000;

class TextLengthLimit {
  const TextLengthLimit(this.characters, {this.utf8Bytes});

  final int characters;
  final int? utf8Bytes;

  bool allows(String text) => overflow(text) == (0, 0);

  bool reached(String text) =>
      text.runes.length >= characters ||
      (utf8Bytes != null && utf8.encode(text).length >= utf8Bytes!);

  (int, int) overflow(String text) => (
    math.max(0, text.runes.length - characters),
    utf8Bytes == null ? 0 : math.max(0, utf8.encode(text).length - utf8Bytes!),
  );
}
