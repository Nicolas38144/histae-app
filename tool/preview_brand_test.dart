// Manual visual review, independent of real accounts and API configuration.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Inter', 'inter/Inter-Variable.ttf'),
      ('SourceSerif4', 'source_serif_4/SourceSerif4-Variable.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });

  testWidgets('preview the one-shot opening and final public page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const frame = Key('brand-preview');
    await tester.pumpWidget(
      const RepaintBoundary(key: frame, child: HistaeApp()),
    );
    for (var index = 0; index <= 25; index++) {
      if (index > 0) await tester.pump(const Duration(milliseconds: 60));
      await expectLater(
        find.byKey(frame),
        matchesGoldenFile(
          '../build/previews/brand/opening-${index.toString().padLeft(2, '0')}.png',
        ),
      );
    }
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(frame),
      matchesGoldenFile('../build/previews/brand/welcome.png'),
    );
  });
}
