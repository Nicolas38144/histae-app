// Real screens; fictional conversations and simulated provider/server responses.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/session_repositories.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/consents/presentation/consents_page.dart';
import 'package:histae_app/features/continuation/presentation/continuation_page.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:histae_app/features/matches/presentation/match_preview_card.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/testing.dart';

import '../test/support/auth_fixture.dart';
import '../test/support/billing_fixture.dart';
import '../test/support/continuation_scenario.dart';
import '../test/support/matches_fixture.dart';
import '../test/support/privacy_fixture.dart';
import '../test/support/rewarded_video_fixture.dart';
import '../test/support/scrolling.dart';

const _output = 'build/previews/continuation-2026-11-05';
const _boundary = Key('continuation-video');

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

  testWidgets('record continuation, automatic agreement and refresh controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final caption = ValueNotifier('Continuer depuis la conversation');
    final touch = ValueNotifier<Offset?>(null);
    var frame = 0;

    Future<void> capture(String path) async {
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_boundary),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    Future<void> record(double seconds) async {
      for (var i = 0; i < (seconds * 15).round(); i++) {
        await tester.pump(const Duration(microseconds: 66667));
        await capture(
          '$_output/frames/${(frame++).toString().padLeft(4, '0')}.png',
        );
      }
    }

    Future<void> tap(Finder target) async {
      if (target.hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(target);
      }
      await tester.pumpAndSettle();
      touch.value = tester.getCenter(target);
      await record(.2);
      await tester.tap(target);
      await record(.6);
      touch.value = null;
    }

    Widget framed(Widget app) => RepaintBoundary(
      key: _boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Container(
                  height: 56,
                  width: double.infinity,
                  color: const Color(0xff0b111c),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'DÉMONSTRATION · COMPTES FICTIFS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          color: Color(0xffb6a8cf),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ValueListenableBuilder<String>(
                        valueListenable: caption,
                        builder: (_, text, _) => Text(
                          text,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: app),
              ],
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
                              width: 1.5,
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

    final first = ContinuationScenario();
    first.responses['/api/users/me/subscription'] = subscriptionJson();
    first.responses['/api/billing/store-products'] = storeProductsJson();
    first.responses['/api/auth/sessions'] = {
      'sessions': [
        mobileSessionJson(),
        mobileSessionJson(id: otherSessionId, current: false),
      ],
      'next_cursor': null,
    };
    first.responses['/api/users/me/blocks'] = {'blocks': <Object?>[]};
    await first.session.establish(testTokens);
    final repositories = SessionRepositories(first.session);
    final locale = LocaleController();
    await locale.select('fr');
    final store = FakeBillingGateway();
    final billing = BillingController(
      BillingRepository(first.session),
      testBillingConfig,
      store,
      realtime: QuietRealtime(first.session),
    );
    final catalog = CatalogRepository(
      ApiClient(
        origin: Uri.parse('https://api.example'),
        client: MockClient((_) async => jsonResponse(rewardedCatalogJson())),
      ),
    );
    await tester.pumpWidget(
      framed(
        HistaeApp(
          sessionController: first.session,
          localeController: locale,
          repositories: repositories,
          billingController: billing,
          catalogRepository: catalog,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main-tab-matches')));
    await tester.pumpAndSettle();
    final c = tester.widget<MatchesPage>(find.byType(MatchesPage)).controller;
    repositories.realtime.reset();
    await tap(find.byType(MatchPreviewCard).first);
    await record(2.8);
    await capture('$_output/01-awaiting.png');
    await tap(find.byKey(const Key('continue-conversation')));
    await record(2.5);
    await tap(
      find.text(const AppStrings().messages.continuationPageAcceptUpTo1Credit),
    );
    caption.value = 'Votre accord est enregistré';
    await record(2.8);
    await capture('$_output/02-waiting.png');
    caption.value = 'Son accord ouvre automatiquement la conversation';
    first.partner = true;
    c.realtime.onSignal?.call(
      const MobileSignal('match.updated', matchId: testMatch),
    );
    await record(3.2);
    await capture('$_output/03-open.png');
    caption.value = 'Votre rencontre : uniquement les informations utiles';
    await tap(find.byKey(const Key('chat-options')));
    await tap(find.byKey(const Key('chat-decisions')));
    await record(2.5);
    expect(find.byType(ContinuationPage), findsOneWidget);
    expect(find.text('Continuer cette conversation'), findsNothing);
    await capture('$_output/04-details.png');
    await tap(find.byType(BackButton));
    await tap(find.byType(BackButton));
    caption.value = 'Matchs : les mises à jour arrivent automatiquement';
    await record(2.4);
    await capture('$_output/05-matches.png');
    await tap(find.byKey(const Key('main-tab-profile')));
    caption.value = 'Profil : plus de rechargement manuel';
    await record(2.5);
    await capture('$_output/06-profile.png');
    final subscription = find.byKey(const Key('profile-subscription'));
    await tester.scrollUntilVisible(
      subscription,
      210,
      scrollable: verticalScrollables.first,
    );
    await record(.5);
    await tap(subscription);
    caption.value = 'Abonnement : restauration conservée, état automatique';
    await record(2);
    final restore = find.text(
      const AppStrings().messages.billingRestorePurchases,
    );
    await tester.scrollUntilVisible(
      restore,
      180,
      scrollable: verticalScrollables.first,
    );
    await record(2);
    await capture('$_output/07-subscription.png');
    await tap(find.byType(BackButton));
    final privacy = find.text(const AppStrings().privacyTitle);
    await tester.scrollUntilVisible(
      privacy,
      180,
      scrollable: verticalScrollables.first,
    );
    await tap(privacy);
    await tap(find.text(const AppStrings().messages.privacyHubPageMyConsents));
    caption.value = 'Consentements : les choix restent accessibles';
    await record(2);
    expect(find.byType(ConsentsPage), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -800));
    await record(2);
    await capture('$_output/08-consents.png');
    await tap(find.byType(BackButton));
    await tap(
      find.text(const AppStrings().messages.privacyDetailPageMySessions),
    );
    caption.value = 'Sessions : les actions de sécurité sont conservées';
    await record(2.8);
    await capture('$_output/12-sessions.png');
    await tap(find.byType(BackButton));
    final blocked = find.text(
      const AppStrings().messages.privacyDetailPageBlockedPeople,
    );
    await tester.scrollUntilVisible(
      blocked,
      180,
      scrollable: verticalScrollables.first,
    );
    await tap(blocked);
    caption.value = 'Blocages : plus de bouton permanent de rechargement';
    await record(2.5);
    await capture('$_output/13-blocks.png');
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose(sessionAlreadyDisposed: true);
    await store.stream.close();

    final empty = ContinuationScenario(remaining: 0, advertising: 0);
    await empty.session.establish(testTokens);
    final secondRepositories = SessionRepositories(empty.session);
    final secondLocale = LocaleController();
    await secondLocale.select('fr');
    caption.value = 'Autre situation : aucun crédit disponible';
    await tester.pumpWidget(
      framed(
        HistaeApp(
          sessionController: empty.session,
          localeController: secondLocale,
          repositories: secondRepositories,
          rewardedVideoGateway: FakeRewardedVideoGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main-tab-matches')));
    await tester.pumpAndSettle();
    secondRepositories.realtime.reset();
    await tap(find.byType(MatchPreviewCard).first);
    await record(2.8);
    await capture('$_output/09-no-credits.png');
    await tap(find.byKey(const Key('continue-conversation')));
    caption.value = 'Le bouton ouvre directement Vos crédits';
    await record(3);
    expect(find.byType(CreditsPage), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsNothing);
    await capture('$_output/10-credits.png');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -520));
    await record(2);
    await capture('$_output/11-credit-balances.png');
    await tap(find.byType(BackButton));
    await tap(find.byType(BackButton));
    await tap(find.byKey(const Key('main-tab-discovery')));
    caption.value = 'Le feed conserve son actualisation manuelle';
    await tap(find.byType(PopupMenuButton<String>).first);
    await record(2.8);
    await capture('$_output/14-feed-refresh.png');
    await tester.pumpWidget(const SizedBox.shrink());
    empty.dispose(sessionAlreadyDisposed: true);
    caption.dispose();
    touch.dispose();
    await tester.runAsync(
      () => File('$_output/recording.json').writeAsString(
        '{"capture_fps":15,"frames":$frame,"duration_seconds":${frame / 15}}',
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
