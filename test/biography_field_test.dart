import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/theme/histae_tokens.dart';
import 'package:histae_app/features/profile/data/profile_models.dart';
import 'package:histae_app/features/profile/presentation/biography_field.dart';

void main() {
  testWidgets(
    'byte-limit emphasis keeps the text, focus and IME composition intact',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: Scaffold(body: BiographyField(controller: controller)),
        ),
      );
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.enterText(field, 'é' * 1000);
      await tester.pumpAndSettle();
      expect(biographyByteLength(controller.text), biographyByteLimit);
      expect(
        (tester.widget<TextField>(field).decoration!.enabledBorder!
                as OutlineInputBorder)
            .borderSide
            .color,
        HistaeTokens.coral,
      );
      final composing = TextEditingValue(
        text: 'é' * 1001,
        selection: const TextSelection.collapsed(offset: 1001),
        composing: const TextRange(start: 1000, end: 1001),
      );
      controller.value = composing;
      await tester.pumpAndSettle();
      expect(controller.value, composing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(field, 'Une présentation plus courte.');
      await tester.pumpAndSettle();
      expect(
        (tester.widget<TextField>(field).decoration!.enabledBorder!
                as OutlineInputBorder)
            .borderSide
            .color,
        isNot(HistaeTokens.coral),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
