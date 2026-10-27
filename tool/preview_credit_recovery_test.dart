// Real Flutter routes with synthetic quotas, advertising and store purchases.
// This renderer does not call production services or change native screen privacy.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/presentation/billing_scope.dart';
import 'package:histae_app/features/billing/presentation/subscription_page.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/catalog/presentation/subscription_plan_carousel.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/continuation/presentation/rewarded_video_scope.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/billing_fixture.dart';
import '../test/support/continuation_fixture.dart';
import '../test/support/matches_fixture.dart';
import '../test/support/rewarded_video_fixture.dart';

const _output = 'build/previews/credit-recovery-2026-10-27';
const _boundary = Key('credit-recovery-preview');

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

  testWidgets('preview depleted free credits and exhausted weekly quota', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    var weeklyLimit = false;
    var rewardStatus = 'pending';
    final session = testSession((request) async {
      return switch (request.url.path) {
        '/api/plans' => jsonResponse(rewardedCatalogJson()),
        '/api/users/me/continuation-quota' => jsonResponse({
          ...quotaJson(),
          'used': weeklyLimit ? 5 : 2,
          'remaining': !weeklyLimit && rewardStatus == 'credited' ? 1 : 0,
          'free_remaining': 0,
          'advertising_balance': rewardStatus == 'credited' ? 1 : 0,
          'advertising_remaining': rewardStatus == 'credited' ? 1 : 0,
          'reserved': 0,
        }),
        '/api/matches/me' => jsonResponse({
          'matches': <Map<String, dynamic>>[],
          'next_cursor': null,
        }),
        '/api/users/me/subscription' => jsonResponse(subscriptionJson()),
        '/api/billing/store-products' => jsonResponse(storeProductsJson()),
        '/api/users/me/advertising-rewards' => jsonResponse(rewardJson()),
        '/api/users/me/advertising-rewards/$rewardId' =>
          request.method == 'DELETE'
              ? http.Response('', 204)
              : jsonResponse(rewardJson(status: rewardStatus)),
        _ => defaultContinuationResponse(request),
      };
    });
    await session.establish(testTokens);
    final matches = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    final store = FakeBillingGateway();
    final billing = BillingController(
      BillingRepository(session),
      testBillingConfig,
      store,
      realtime: QuietRealtime(session),
    );
    final catalog = CatalogRepository(
      ApiClient(
        origin: Uri.parse('https://api.example'),
        client: MockClient((_) async => jsonResponse(rewardedCatalogJson())),
      ),
    );
    final gateway = FakeRewardedVideoGateway();
    final touch = ValueNotifier<Offset?>(null);
    addTearDown(() async {
      matches.dispose();
      billing.dispose();
      await store.stream.close();
      catalog.close();
      session.dispose();
      touch.dispose();
    });
    var frame = 0;
    Future<void> capture(String path) async {
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundary),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
    }

    Future<void> record(double seconds) async {
      for (var i = 0; i < (seconds * 12).round(); i++) {
        await tester.pump(const Duration(microseconds: 83333));
        await capture(
          '$_output/frames/${(frame++).toString().padLeft(4, '0')}.png',
        );
      }
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      touch.value = tester.getCenter(finder);
      await record(.2);
      await tester.tap(finder);
      await record(.45);
      touch.value = null;
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: Stack(
          textDirection: TextDirection.ltr,
          fit: StackFit.expand,
          children: [
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: histaeTheme(Brightness.dark),
              locale: const Locale('fr'),
              localizationsDelegates: AppMessages.localizationsDelegates,
              supportedLocales: AppMessages.supportedLocales,
              builder: (_, child) => BillingScope(
                controller: billing,
                child: RewardedVideoScope(gateway: gateway, child: child!),
              ),
              home: MatchesPage(controller: matches, catalog: catalog),
            ),
            const Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  'DÉMONSTRATION · PUBLICITÉ ET ACHATS SIMULÉS',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8,
                    color: Color(0xFFAFAAB9),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<Offset?>(
              valueListenable: touch,
              builder: (_, point, _) => point == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: point.dx - 14,
                      top: point.dy - 14,
                      child: IgnorePointer(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .8),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-videos')));
    await tester.pumpAndSettle();
    await capture('$_output/free-exhausted.png');
    await record(1.5);
    await tap(find.byKey(const Key('open-videos')));
    expect(find.byType(CreditsPage), findsOneWidget);
    await record(1.3);
    await capture('$_output/watch-video.png');
    gateway.video.showGate = Completer<bool>();
    await tap(find.byKey(const Key('watch-rewarded-video')));
    await record(.8);
    expect(gateway.video.shows, 1);
    gateway.video.showGate!.complete(true);
    await tester.pumpAndSettle();
    rewardStatus = 'credited';
    await matches.continuation.rewards.refresh();
    await tester.pumpAndSettle();
    await record(1);
    // Second scenario: the weekly ceiling is reached, regardless of stock.
    weeklyLimit = true;
    Navigator.of(tester.element(find.byType(CreditsPage))).pop();
    await record(.5);
    await matches.continuation.refreshQuota();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('open-credit-subscription')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-videos')), findsNothing);
    await capture('$_output/weekly-limit.png');
    await record(1.5);
    await tap(find.byKey(const Key('open-credit-subscription')));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionPage), findsOneWidget);
    await record(1);
    await tester.ensureVisible(find.byType(SubscriptionPlanCarousel));
    await tester.pumpAndSettle();
    await record(2);
    await capture('$_output/subscriptions.png');
    expect(store.bought, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => File('$_output/recording.json').writeAsString(
        jsonEncode({
          'frames': frame,
          'fps': 12,
          'duration_seconds': frame / 12,
        }),
      ),
    );
  });
}
