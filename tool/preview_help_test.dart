// Visual review of localized help and the feed guide; no production requests.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/help/presentation/help_page.dart';

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
    final bytes = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  testWidgets('review help and guide in four languages and at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const boundaryKey = Key('help-preview');
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('build/previews/help/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    for (final language in ['fr', 'en', 'es', 'it']) {
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final name = '$language-${scale == 1 ? 'normal' : 'large'}';
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(language),
              supportedLocales: AppMessages.supportedLocales,
              localizationsDelegates: AppMessages.localizationsDelegates,
              theme: histaeTheme(Brightness.dark),
              home: const HelpPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('$name-help');
        await tester.ensureVisible(find.byKey(const Key('help-feed-guide')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('help-feed-guide')));
        await tester.pumpAndSettle();
        await capture('$name-guide');
        final scroller = find.descendant(
          of: find.byKey(const Key('feed-mini-guide')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('feed-guide-done')),
          200,
          scrollable: scroller,
        );
        await tester.pumpAndSettle();
        await capture('$name-guide-end');
        await tester.tap(find.byKey(const Key('feed-guide-done')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
