import 'dart:convert';

enum ReadingTextSize { standard, comfortable, large }

enum ReadingLineSpacing { standard, relaxed, spacious }

/// Device preferences for prose only. System text scaling stays independent.
class ReadingPreferences {
  const ReadingPreferences({
    this.textSize = ReadingTextSize.standard,
    this.lineSpacing = ReadingLineSpacing.standard,
  });

  final ReadingTextSize textSize;
  final ReadingLineSpacing lineSpacing;

  double get fontSize => switch (textSize) {
    ReadingTextSize.standard => 18,
    ReadingTextSize.comfortable => 20,
    ReadingTextSize.large => 22,
  };

  double get lineHeight => switch (lineSpacing) {
    ReadingLineSpacing.standard => 1.55,
    ReadingLineSpacing.relaxed => 1.8,
    ReadingLineSpacing.spacious => 2,
  };

  ReadingPreferences copyWith({
    ReadingTextSize? textSize,
    ReadingLineSpacing? lineSpacing,
  }) => ReadingPreferences(
    textSize: textSize ?? this.textSize,
    lineSpacing: lineSpacing ?? this.lineSpacing,
  );

  String encode() =>
      jsonEncode({'textSize': textSize.name, 'lineSpacing': lineSpacing.name});

  static ReadingPreferences decode(String? raw) {
    if (raw == null) return const ReadingPreferences();
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return const ReadingPreferences();
      return ReadingPreferences(
        textSize:
            ReadingTextSize.values
                .where((size) => size.name == data['textSize'])
                .firstOrNull ??
            ReadingTextSize.standard,
        lineSpacing:
            ReadingLineSpacing.values
                .where((spacing) => spacing.name == data['lineSpacing'])
                .firstOrNull ??
            ReadingLineSpacing.standard,
      );
    } on FormatException {
      return const ReadingPreferences();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingPreferences &&
      other.textSize == textSize &&
      other.lineSpacing == lineSpacing;

  @override
  int get hashCode => Object.hash(textSize, lineSpacing);
}
