// Manual visual review with synthetic data and bundled production fonts.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/rewarded_video_fixture.dart';

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

  testWidgets('review translated welcome, profile, credits and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/histae-signature-dark.png'),
          tester.element(find.byType(HistaeApp)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('locale-preview')),
        matchesGoldenFile('../build/previews/localization/$name.png'),
      );
    }

    for (final language in ['fr', 'en', 'es', 'it']) {
      final locale = LocaleController();
      await locale.select(language);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('locale-preview'),
          child: HistaeApp(localeController: locale),
        ),
      );
      await capture('$language-welcome');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      final privateLocale = LocaleController();
      await privateLocale.select(language);
      final session = testSession(
        (request) async => request.url.path == '/api/plans'
            ? jsonResponse(rewardedCatalogJson())
            : defaultContinuationResponse(request),
      );
      await session.establish(testTokens);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('locale-preview'),
          child: HistaeApp(
            localeController: privateLocale,
            sessionController: session,
            rewardedVideoGateway: FakeRewardedVideoGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await capture('$language-profile');
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      final matches = tester
          .widget<MatchesPage>(find.byType(MatchesPage))
          .controller;
      final context = tester.element(find.byType(MatchesPage));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreditsPage(controller: matches.continuation),
          ),
        ),
      );
      await capture('$language-credits');
      await tester.scrollUntilVisible(
        find.byKey(const Key('watch-rewarded-video')),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.byKey(const Key('watch-rewarded-video')));
      await capture('$language-videos');
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('watch-rewarded-video')),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.byKey(const Key('watch-rewarded-video')));
      await capture('$language-videos-large');
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .jumpTo(0);
      await capture('$language-credits-large');
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
