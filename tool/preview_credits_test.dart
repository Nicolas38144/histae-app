// Manual visual review only; all accounts, ads and server responses are fake.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/continuation/presentation/rewarded_video_scope.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/matches_fixture.dart';
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
  testWidgets('review credits states and large text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const frame = Key('credits-preview');
    Future<void> capture(String name) => expectLater(
      find.byKey(frame),
      matchesGoldenFile('../build/previews/credits/$name.png'),
    );
    for (final state in [
      'free',
      'pending',
      'stock-full',
      'premium',
      'unavailable',
      'large-text',
    ]) {
      final session = testSession((r) async {
        if (r.url.path.endsWith('/continuation-quota')) {
          if (state == 'unavailable') {
            return apiError(503, 'service_unavailable');
          }
          return jsonResponse({
            ...quotaJson(premium: state == 'premium'),
            if (state == 'stock-full') 'advertising_balance': 3,
          });
        }
        if (r.url.path == '/api/plans') {
          return jsonResponse(rewardedCatalogJson());
        }
        if (r.url.path.endsWith('/advertising-rewards') ||
            r.url.path.endsWith('/$rewardId')) {
          return jsonResponse(rewardJson());
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      final access = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      final large = state == 'large-text';
      tester.view.physicalSize = large
          ? const Size(320, 568)
          : const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frame,
          child: MaterialApp(
            theme: histaeTheme(Brightness.dark),
            debugShowCheckedModeBanner: false,
            home: RewardedVideoScope(
              gateway: FakeRewardedVideoGateway(),
              child: CreditsPage(controller: access.continuation),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(state);
      if (state == 'free' ||
          state == 'stock-full' ||
          state == 'pending' ||
          large) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('watch-rewarded-video')),
          200,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('watch-rewarded-video')),
        );
        await tester.pumpAndSettle();
        if (state == 'pending') {
          await tester.tap(find.byKey(const Key('watch-rewarded-video')));
          await tester.pumpAndSettle();
        }
        await capture('$state-action');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
      session.dispose();
    }
  });
}
