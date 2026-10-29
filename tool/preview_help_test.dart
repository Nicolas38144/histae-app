// Real Flutter help screen with local configuration; no provider or API calls.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/config/app_config.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/help/application/help_controller.dart';
import 'package:histae_app/features/help/data/feed_guide_store.dart';
import 'package:histae_app/features/help/presentation/help_page.dart';
import 'package:histae_app/features/help/presentation/help_scope.dart';

class _GuideStore implements FeedGuideStore {
  @override
  Future<bool> read() async => true;
  @override
  Future<void> markSeen() async {}
}

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
    final icons = await File(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  testWidgets('export the actual inline child-safety answer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final help = HelpController(
      AppConfig.fromDotEnv(
        await rootBundle.loadString('.env'),
        isDebug: true,
      ).support,
      store: _GuideStore(),
    );
    addTearDown(help.dispose);
    await help.load();
    const boundaryKey = Key('help-preview');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr'),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          theme: histaeTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 24, bottom: 20)),
            child: HelpScope(controller: help, child: child!),
          ),
          home: const HelpPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroller = find
        .descendant(
          of: find.byType(HelpPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final question = find.byKey(const Key('help-child-safety'));
    await tester.scrollUntilVisible(question, 250, scrollable: scroller);
    await tester.tap(question);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(question));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('build/previews/help/child-safety-inline.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
