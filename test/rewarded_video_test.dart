import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/continuation/application/rewarded_video_controller.dart';
import 'package:histae_app/features/continuation/data/continuation_models.dart';
import 'package:histae_app/features/continuation/data/rewarded_video_gateway.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/continuation/presentation/rewarded_video_scope.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/rewarded_video_fixture.dart';
import 'support/scrolling.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native completion uses server intent and cannot grant a credit; verified result rereads balances', () async {
    var status = 'pending', posts = 0, quotaReads = 0;
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/advertising-rewards') {
        posts++;
        expect(jsonDecode(r.body), {'platform': 'android'});
        return jsonResponse(rewardJson());
      }
      if (r.url.path.endsWith('/$rewardId')) {
        if (r.method == 'DELETE') return http.Response('', 204);
        return jsonResponse(rewardJson(status: status));
      }
      if (r.url.path.endsWith('/continuation-quota')) {
        quotaReads++;
        return jsonResponse({
          ...quotaJson(),
          'advertising_remaining': status == 'credited' ? 2 : 1,
        });
      }
      return r.url.path == '/api/plans'
          ? jsonResponse(rewardedCatalogJson())
          : defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(access.dispose);
    final c = access.continuation;
    await c.activate();
    c.rewards.activate();
    final gateway = FakeRewardedVideoGateway();
    final video = RewardedVideoController(c, gateway);
    addTearDown(video.dispose);
    expect(posts, 0);
    expect(gateway.consents, 0);
    await video.watch();
    expect(posts, 1);
    expect(gateway.intents.single.adUnit, rewardJson()['ad_unit']);
    expect(gateway.intents.single.customData, rewardId);
    expect(gateway.video.shows, 1);
    expect(gateway.video.disposals, 1);
    expect(c.rewards.completedVideo, isTrue);
    expect(c.rewards.intent!.status, RewardStatus.pending);
    expect(c.quota!.advertisingRemaining, 1);
    expect(video.canWatch, isFalse);
    final before = quotaReads;
    status = 'credited';
    await c.rewards.refresh();
    expect(quotaReads, before + 1);
    expect(c.quota!.advertisingRemaining, 2);
    // A credited intent doesn't lock the user out of the next video.
    status = 'pending';
    gateway.video = FakePreparedVideo()..earned = false;
    await video.watch();
    expect(posts, 2);
    expect(c.rewards.completedVideo, isFalse);
    expect(c.rewards.intent, isNull);
  });

  test(
    'eligibility and UMP failures prevent playback or reward creation',
    () async {
      var premium = true,
          full = false,
          weeklyLimit = false,
          failedQuota = false,
          posts = 0;
      final session = testSession((r) async {
        if (r.url.path.endsWith('/continuation-quota')) {
          if (failedQuota) return apiError(503, 'service_unavailable');
          return jsonResponse({
            ...quotaJson(premium: premium),
            if (full) 'advertising_balance': 3,
            if (weeklyLimit) ...{'used': 5, 'remaining': 0},
          });
        }
        if (r.url.path.endsWith('/advertising-rewards')) {
          posts++;
          return jsonResponse(rewardJson());
        }
        return r.url.path == '/api/plans'
            ? jsonResponse(rewardedCatalogJson())
            : defaultContinuationResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final access = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      addTearDown(access.dispose);
      final c = access.continuation;
      await c.activate();
      c.rewards.activate();
      final gateway = FakeRewardedVideoGateway();
      final video = RewardedVideoController(c, gateway);
      addTearDown(video.dispose);
      await video.watch();
      expect(gateway.consents, 0);
      premium = false;
      weeklyLimit = true;
      await c.loadQuota();
      expect(video.unavailableReason, ClientMessage.videoWeeklyLimitReached);
      await video.watch();
      expect(gateway.consents, 0);
      expect(posts, 0);
      weeklyLimit = false;
      full = true;
      await c.loadQuota();
      await video.watch();
      expect(gateway.consents, 0);
      full = false;
      failedQuota = true;
      await c.loadQuota();
      await video.watch();
      expect(gateway.consents, 0);
      failedQuota = false;
      await c.loadQuota();
      gateway.consentFailure = const RewardedVideoException(
        VideoFailure.consent,
      );
      await video.watch();
      expect(gateway.consents, 1);
      expect(posts, 0);
      expect(gateway.intents, isEmpty);
      expect(
        const AppStrings().clientMessage(video.message!),
        contains('préférences'),
      );
    },
  );

  test('a load failure releases its slot; changed rights discard a late native load', () async {
    var premium = false, posts = 0, deletes = 0;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/continuation-quota')) {
        return jsonResponse(quotaJson(premium: premium));
      }
      if (r.url.path.endsWith('/advertising-rewards')) {
        posts++;
        return jsonResponse(rewardJson());
      }
      if (r.url.path.endsWith('/$rewardId')) {
        if (r.method == 'DELETE') {
          deletes++;
          return http.Response('', 204);
        }
        return jsonResponse(rewardJson());
      }
      return r.url.path == '/api/plans'
          ? jsonResponse(rewardedCatalogJson())
          : defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(access.dispose);
    final c = access.continuation;
    await c.activate();
    c.rewards.activate();
    final gateway = FakeRewardedVideoGateway()
      ..loadFailure = const RewardedVideoException(VideoFailure.noFill);
    final video = RewardedVideoController(c, gateway);
    addTearDown(video.dispose);
    await video.watch();
    expect(
      const AppStrings().clientMessage(video.message!),
      contains('Aucune vidéo'),
    );
    expect(c.rewards.intent, isNull);
    expect(deletes, 1);
    gateway.loadFailure = null;
    gateway.loadGate = Completer<PreparedRewardedVideo>();
    final retry = video.watch();
    for (var n = 0; n < 15 && gateway.intents.length < 2; n++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(gateway.intents.length, 2);
    expect(posts, 2);
    premium = true;
    await c.loadQuota();
    gateway.loadGate!.complete(gateway.video);
    await retry;
    expect(gateway.video.shows, 0);
    expect(gateway.video.disposals, 1);
  });

  test('a late video completion after logout cannot poll or change another session', () async {
    var rewardReads = 0;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/advertising-rewards')) {
        return jsonResponse(rewardJson());
      }
      if (r.url.path.endsWith('/$rewardId')) {
        rewardReads++;
        return jsonResponse(rewardJson());
      }
      return r.url.path == '/api/plans'
          ? jsonResponse(rewardedCatalogJson())
          : defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(access.dispose);
    final c = access.continuation;
    await c.activate();
    c.rewards.activate();
    final gateway = FakeRewardedVideoGateway();
    gateway.video.showGate = Completer<bool>();
    final video = RewardedVideoController(c, gateway);
    addTearDown(video.dispose);
    final playing = video.watch();
    await gateway.video.shown.future;
    await session.logout();
    final before = rewardReads;
    gateway.video.showGate!.complete(true);
    await playing;
    expect(c.rewards.intent, isNull);
    expect(c.rewards.completedVideo, isFalse);
    expect(rewardReads, before);
    expect(gateway.video.disposals, 1);
  });

  for (final failure in [VideoFailure.noFill, VideoFailure.network]) {
    testWidgets(
      'no-fill popup distinguishes unavailable ads from ${failure.name}',
      (tester) async {
        final session = testSession((request) async {
          if (request.url.path.endsWith('/advertising-rewards')) {
            return jsonResponse(rewardJson());
          }
          if (request.url.path.endsWith('/$rewardId')) {
            return request.method == 'DELETE'
                ? http.Response('', 204)
                : jsonResponse(rewardJson());
          }
          return request.url.path == '/api/plans'
              ? jsonResponse(rewardedCatalogJson())
              : defaultContinuationResponse(request);
        });
        addTearDown(session.dispose);
        await session.establish(testTokens);
        final access = MatchesController(
          MatchesRepository(session),
          realtime: QuietRealtime(session),
        );
        addTearDown(access.dispose);
        final gateway = FakeRewardedVideoGateway()
          ..loadFailure = RewardedVideoException(failure);
        await tester.pumpWidget(
          RewardedVideoScope(
            gateway: gateway,
            child: MaterialApp(
              theme: histaeTheme(Brightness.dark),
              locale: const Locale('fr'),
              localizationsDelegates: AppMessages.localizationsDelegates,
              supportedLocales: AppMessages.supportedLocales,
              home: CreditsPage(controller: access.continuation),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final watch = find.byKey(const Key('watch-rewarded-video'));
        final dialog = find.byKey(const Key('rewarded-video-no-fill-dialog'));
        expect(dialog, findsNothing);
        await tester.scrollUntilVisible(watch, 200);
        await tester.ensureVisible(watch);
        await tester.pumpAndSettle();
        await tester.tap(watch);
        await tester.pumpAndSettle();
        expect(gateway.intents, hasLength(1));
        expect(gateway.video.shows, 0);
        expect(access.continuation.rewards.intent, isNull);
        expect(access.continuation.quota!.advertisingBalance, 2);

        if (failure == VideoFailure.noFill) {
          expect(dialog, findsOneWidget);
          expect(
            find.descendant(
              of: dialog,
              matching: find.text(
                const AppStrings().messages.rewardVideoNoAdsTitle,
              ),
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.descendant(of: dialog, matching: find.text('Fermer')),
          );
          await tester.pumpAndSettle();
          await access.continuation.refreshQuota();
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(gateway.intents, hasLength(1));

          gateway.loadFailure = null;
          gateway.video.earned = false;
          await tester.ensureVisible(watch);
          await tester.pumpAndSettle();
          await tester.tap(watch);
          await tester.pumpAndSettle();
          expect(gateway.video.shows, 1);
          expect(dialog, findsNothing);
        } else {
          expect(dialog, findsNothing);
          expect(
            find.text(
              const AppStrings().clientMessage(ClientMessage.videoNetwork),
            ),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final entry in ['matches', 'profile']) {
    testWidgets(
      'native overlay lifecycle preserves verification through the $entry route',
      (tester) async {
        final session = testSession((r) async {
          if (r.url.path.endsWith('/advertising-rewards') ||
              r.url.path.endsWith('/$rewardId')) {
            return jsonResponse(rewardJson());
          }
          return r.url.path == '/api/plans'
              ? jsonResponse(rewardedCatalogJson())
              : defaultContinuationResponse(r);
        });
        await session.establish(testTokens);
        final gateway = FakeRewardedVideoGateway();
        gateway.video.showGate = Completer<bool>();
        await tester.pumpWidget(
          HistaeApp(sessionController: session, rewardedVideoGateway: gateway),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('main-tab-$entry')));
        await tester.pumpAndSettle();
        if (entry == 'matches') {
          final toggle = find.byKey(const Key('matches-credits-toggle'));
          await tester.scrollUntilVisible(
            toggle,
            200,
            scrollable: verticalScrollables.first,
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }
        final openCredits = entry == 'matches'
            ? find.byKey(const Key('open-credits'))
            : find.text('Mes crédits');
        await tester.scrollUntilVisible(
          openCredits,
          200,
          scrollable: verticalScrollables.first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(openCredits);
        await tester.pumpAndSettle();
        await tester.tap(openCredits);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('watch-rewarded-video')),
          200,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('watch-rewarded-video')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('watch-rewarded-video')));
        for (var n = 0; n < 20 && gateway.video.shows == 0; n++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(gateway.video.shows, 1);
        final binding = tester.binding;
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          binding.handleAppLifecycleStateChanged(state);
          await tester.pump();
        }
        gateway.video.showGate!.complete(true);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Vidéo terminée. Votre récompense est en cours de validation.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
