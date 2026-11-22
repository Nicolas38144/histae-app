import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/text/text_limit_input_formatter.dart';
import 'package:histae_app/core/text/text_limits.dart';

TextEditingValue editing(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  test('rejects over-limit typing and paste without losing the selection', () {
    const formatter = TextLimitInputFormatter(TextLengthLimit(3, utf8Bytes: 8));
    final full = editing('😀éé');
    final afterSelection = full.copyWith(
      selection: const TextSelection(baseOffset: 2, extentOffset: 4),
    );
    expect(formatter.formatEditUpdate(TextEditingValue.empty, full), full);
    expect(
      formatter.formatEditUpdate(afterSelection, editing('😀😀😀')),
      afterSelection,
    );
    expect(formatter.formatEditUpdate(full, editing('😀éé ')), full);

    final replacement = editing('😀ab')
        .copyWith(composing: const TextRange(start: 2, end: 4));
    expect(
      formatter.formatEditUpdate(afterSelection, replacement),
      replacement,
    );
    final committed = replacement.copyWith(composing: TextRange.empty);
    expect(formatter.formatEditUpdate(replacement, committed), committed);
  });

  test('existing oversized drafts allow reductions and caret changes', () {
    const formatter = TextLimitInputFormatter(TextLengthLimit(3));
    final saved = editing('abcde');
    final shortened = editing('abcd');
    final cursor = shortened.copyWith(
      selection: const TextSelection.collapsed(offset: 2),
    );
    expect(formatter.formatEditUpdate(saved, shortened), shortened);
    expect(formatter.formatEditUpdate(shortened, cursor), cursor);
    expect(formatter.formatEditUpdate(cursor, saved), cursor);
    expect(formatter.formatEditUpdate(cursor, editing('abc')), editing('abc'));
  });
}
