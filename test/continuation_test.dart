import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/config/app_config.dart';
import 'package:histae_app/features/continuation/application/continuation_controller.dart';
import 'package:histae_app/features/continuation/application/reward_tracker.dart';
import 'package:histae_app/features/continuation/data/continuation_models.dart';
import 'package:histae_app/features/continuation/data/continuation_repository.dart';
import 'package:histae_app/features/continuation/presentation/partner_photo_page.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('continuation uses fresh owner quota; lost response keeps accepted cost through plan change and navigation', () async {
    var premium = false, recorded = false, lost = true;
    final costs = <int>[];
    final session = testSession((r) async {
      if (r.url.path.endsWith('/continuation-quota')) {
        return jsonResponse(quotaJson(premium: premium));
      }
      if (r.url.path == '/api/matches/me') {
        return jsonResponse({
          'matches': [
            {
              ...publicMatchJson(status: 'awaiting_continuation'),
              'my_continued': recorded,
            },
          ],
          'next_cursor': null,
        });
      }
      if (r.url.path.endsWith('/continue')) {
        costs.add((jsonDecode(r.body) as Map)['credit_cost'] as int);
        if (lost) throw TimeoutException('Synthetic response loss');
        recorded = true;
        return jsonResponse({'message': 'recorded', 'match_confirmed': false});
      }
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(access.dispose);
    await access.activate();
    await access.openChat(testMatch);
    final c = access.continuation;
    await c.activate();
    final offer = (await c.prepareContinuation())!;
    expect(offer.cost, 1);
    await c.accept(offer);
    expect(c.pendingCost, 1);
    expect(c.failure, isNotNull);
    expect(costs, [1]);
    c.suspend();
    premium = true;
    await c.activate();
    expect(c.quota!.premium, isTrue);
    expect(c.pendingCost, 1);
    expect(costs, [1]);
    lost = false;
    await c.resumeContinuation();
    expect(costs, [1, 1]);
    expect(c.myContinued, isTrue);
    expect(c.pendingCost, isNull);
    expect(
      access.canSend,
      isFalse,
      reason: 'acknowledgement false never invents confirmed state',
    );
  });
  test('Premium to Free requires new explicit acceptance after plan_changed; quota zero does not block replay of an existing intention', () async {
    var premium = true, remaining = 2, fail = true;
    final costs = <int>[];
    final session = testSession((r) async {
      if (r.url.path.endsWith('/continuation-quota')) {
        return jsonResponse(quotaJson(premium: premium, remaining: remaining));
      }
      if (r.url.path.endsWith('/continue')) {
        costs.add((jsonDecode(r.body) as Map)['credit_cost'] as int);
        if (fail) {
          premium = false;
          return apiError(409, 'continuation_plan_changed');
        }
        throw TimeoutException('unknown');
      }
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(access.dispose);
    await access.activate();
    await access.openChat(testMatch);
    final c = access.continuation;
    await c.activate();
    final initial = (await c.prepareContinuation())!;
    expect(initial.cost, 0);
    await c.accept(initial);
    expect(c.pendingCost, isNull);
    expect(c.failure?.code, 'continuation_plan_changed');
    await c.resumeContinuation();
    expect(costs, [0]);
    fail = false;
    final next = (await c.prepareContinuation())!;
    expect(next.cost, 1);
    await c.accept(next);
    remaining = 0;
    await c.loadQuota();
    expect(c.quota!.canStart, isFalse);
    await c.resumeContinuation();
    expect(costs, [0, 1, 1]);
  });
  test('week rollover and new match reads invalidate a displayed cost without silently accepting it', () async {
    var clock = DateTime.utc(2026, 10, 18, 23, 59, 50), writes = 0;
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        return jsonResponse({
          'matches': [
            publicMatchJson(
              status: 'awaiting_continuation',
              expiresAt: clock.add(const Duration(hours: 5)),
            ),
          ],
          'next_cursor': null,
        });
      }
      if (r.url.path.endsWith('/continue')) writes++;
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
      now: () => clock,
    );
    addTearDown(access.dispose);
    await access.activate();
    await access.openChat(testMatch);
    final c = ContinuationController(access, now: () => clock);
    addTearDown(c.dispose);
    await c.activate();
    final offer = (await c.prepareContinuation())!;
    clock = clock.add(const Duration(seconds: 20));
    await c.accept(offer);
    expect(writes, 0);
    expect(c.notice, 'cost_changed');
    final fresh = (await c.prepareContinuation())!;
    await access.refresh();
    await c.accept(fresh);
    expect(writes, 0);
  });
  test('revelation is a separate bodyless agreement; mutual server flag alone gates retained photo URLs', () async {
    var mine = false, both = false, reveals = 0;
    const url = 'https://photos.example/private?signature=synthetic';
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        return jsonResponse({
          'matches': [
            {
              ...publicMatchJson(),
              'my_revealed': mine,
              'photos_revealed': both,
              'other_user': {
                ...(publicMatchJson()['other_user'] as Map<String, dynamic>),
                'photo': url,
              },
            },
          ],
          'next_cursor': null,
        });
      }
      if (r.url.path.endsWith('/reveal')) {
        expect(r.method, 'PATCH');
        expect(r.body, isEmpty);
        reveals++;
        mine = true;
        return jsonResponse({'message': 'recorded', 'photos_revealed': false});
      }
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(access.dispose);
    await access.activate();
    await access.openChat(testMatch);
    final c = access.continuation;
    await c.activate();
    expect(access.selected!.partner.photo, isNull);
    await c.reveal();
    expect(reveals, 1);
    expect(c.myRevealed, isTrue);
    expect(access.selected!.partner.photo, isNull);
    expect(c.myContinued, isFalse);
    both = true;
    await access.refresh();
    expect(access.selected!.partner.photo, url);
    final terminal = {
      ...publicMatchJson(status: 'expired'),
      'photos_revealed': true,
      'other_user': {
        ...(publicMatchJson()['other_user'] as Map<String, dynamic>),
        'photo': url,
      },
    };
    expect(UserMatch.fromJson(terminal, testUser).partner.photo, isNull);
  });
  testWidgets(
    'partner photo makes no hidden request; after mutual reveal it uses no Bearer or redirects and ignores bytes after access loss',
    (tester) async {
      var both = false, requests = 0;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
      );
      final response = Completer<http.Response>();
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') {
          return jsonResponse({
            'matches': [
              {
                ...publicMatchJson(),
                'photos_revealed': both,
                'other_user': {
                  ...(publicMatchJson()['other_user'] as Map),
                  'photo': 'https://photos.example/synthetic',
                },
              },
            ],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      final access = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      await access.activate();
      await access.openChat(testMatch);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: PartnerPhotoPage(
            access: access,
            matchId: testMatch,
            photoClient: () => MockClient((r) async {
              requests++;
              expectSync(r.headers.containsKey('Authorization'), isFalse);
              expectSync(r.followRedirects, isFalse);
              if (requests == 1) return http.Response.bytes(png, 200);
              return response.future;
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      both = true;
      await access.refresh();
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.byType(Image), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Actualiser la photo'), 200);
      await tester.tap(find.text('Actualiser la photo'));
      await tester.pump();
      expect(requests, 2);
      access.removeUnavailable(testMatch);
      await tester.pump();
      response.complete(http.Response.bytes(png, 200));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      access.dispose();
      session.dispose();
    },
  );
  test('invalidation and logout purge uncertain decisions and ignore a late continuation response', () async {
    final reply = Completer<http.Response>();
    final session = testSession(
      (r) async => r.url.path.endsWith('/continue')
          ? reply.future
          : defaultContinuationResponse(r),
    );
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final access = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    // Use the parent's bound stream callback to simulate access invalidation.
    addTearDown(access.dispose);
    await access.activate();
    await access.openChat(testMatch);
    final c = access.continuation;
    await c.activate();
    final offer = (await c.prepareContinuation())!;
    final writing = c.accept(offer);
    await Future<void>.delayed(Duration.zero);
    access.realtime.onSignal!(const MobileSignal('matches.invalidated'));
    expect(c.pendingCost, isNull);
    expect(c.quota, isNull);
    reply.complete(
      jsonResponse({'message': 'recorded', 'match_confirmed': true}),
    );
    await writing;
    expect(c.myContinued, isFalse);
    expect(c.quota, isNull);
    await session.logout();
    expect(c.active, isFalse);
    expect(c.pendingReveal, isFalse);
  });
  test('video callback never grants credits; expired server intent can later be credited, and completed video is not cancelled implicitly', () async {
    var state = 'pending', creditsRead = 0, deletes = 0;
    final platforms = <Object?>[];
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/advertising-rewards') {
        platforms.add(jsonDecode(r.body));
        return jsonResponse(rewardJson());
      }
      if (r.url.path.endsWith('/$rewardId')) {
        if (r.method == 'DELETE') {
          deletes++;
          return http.Response('', 204);
        }
        return jsonResponse(rewardJson(status: state));
      }
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final tracker = RewardTracker(
      ContinuationRepository(session),
      onCredited: () async {
        creditsRead++;
      },
    );
    addTearDown(tracker.dispose);
    tracker.activate();
    final intent = await tracker.prepare('android');
    expect(intent!.customData, rewardId);
    expect(platforms, [
      {'platform': 'android'},
    ]);
    await tracker.videoCompleted();
    expect(creditsRead, 0);
    expect(tracker.intent!.status, RewardStatus.pending);
    await tracker.cancel();
    expect(deletes, 0);
    state = 'expired';
    await tracker.refresh();
    expect(creditsRead, 0);
    state = 'credited';
    await tracker.refresh();
    expect(creditsRead, 1);
    expect(tracker.intent!.status, RewardStatus.credited);
    await tracker.cancel(completedVideoWarningAccepted: true);
    expect(deletes, 0);
    await session.logout();
    expect(tracker.intent, isNull);
  });
  test('future public AdMob fields can remain empty, accept application IDs and never accept ad-unit IDs as application IDs', () {
    final config = AppConfig.fromDotEnv(
      'APP_ENV=production\nAPI_BASE_URL=https://api.example\nADMOB_ANDROID_APP_ID=\nADMOB_IOS_APP_ID=',
      isDebug: false,
    );
    expect(config.admobAndroidAppId, isNull);
    expect(config.admobIosAppId, isNull);
    final filled = AppConfig.fromValues(
      environment: 'production',
      apiBaseUrl: 'https://api.example',
      isDebug: false,
      admobAndroidAppId: 'ca-app-pub-3940256099942544~3347511713',
    );
    expect(filled.admobAndroidAppId, isNotNull);
    final units = AppConfig.fromDotEnv(
      'APP_ENV=production\nAPI_BASE_URL=https://api.example\nADMOB_ANDROID_REWARDED_AD_UNIT=ca-app-pub-3940256099942544/5224354917\nADMOB_IOS_REWARDED_AD_UNIT=',
      isDebug: false,
    );
    expect(units.admobAndroidRewardedAdUnit, isNotNull);
    expect(units.admobIosRewardedAdUnit, isNull);
    expect(
      () => AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'https://api.example',
        isDebug: false,
        admobIosAppId: 'ca-app-pub-3940256099942544/1712485313',
      ),
      throwsFormatException,
    );
    final premium = ContinuationQuota.fromJson(quotaJson(premium: true));
    expect(premium.remaining, isNull);
    expect(premium.creditCost, 0);
  });
}
