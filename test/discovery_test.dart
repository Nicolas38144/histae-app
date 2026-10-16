import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/features/consents/data/consent_state.dart';
import 'package:histae_app/features/discovery/application/discovery_controller.dart';
import 'package:histae_app/features/discovery/data/device_location.dart';
import 'package:histae_app/features/discovery/data/discovery_models.dart';
import 'package:histae_app/features/discovery/data/discovery_repository.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';

import 'support/auth_fixture.dart';
import 'support/discovery_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('opaque cursor is encoded, pages deduplicated and expired cursor restarted without reversing choices', () async {
    final cursors = <String?>[];
    const opaque = 'opaque+/= cursor?&';
    var first = true;
    final session = testSession((r) async {
      if (r.url.path == '/api/feed') {
        expect(r.url.queryParameters['limit'], '20');
        cursors.add(r.url.queryParameters['cursor']);
        if (cursors.length == 2) return apiError(400, 'invalid_cursor');
        final page = first
            ? [candidateJson(candidateOne), candidateJson(candidateOne)]
            : [candidateJson(candidateOne), candidateJson(candidateTwo)];
        first = false;
        return jsonResponse({
          'profiles': page,
          'next_cursor': cursors.length == 1 ? opaque : null,
        });
      }
      return defaultDiscoveryResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DiscoveryController(
      DiscoveryRepository(session),
      TestLocationSource(),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.decide(SwipeDecision.pass);
    await Future<void>.delayed(Duration.zero);
    expect(cursors, [null, opaque, null]);
    expect(c.current?.id, candidateTwo);
    expect(c.exhausted, isTrue);
    await c.refresh();
    expect(c.current?.id, candidateTwo);
  });
  test('lost swipe response locks the exact choice and explicit resume opens only a validated reciprocal match', () async {
    final writes = <Object?>[];
    var fail = true;
    final session = testSession((r) async {
      if (r.url.path == '/api/swipes') {
        writes.add(jsonDecode(r.body));
        if (fail) throw TimeoutException('lost response');
        return jsonResponse({
          'decision': 'like',
          'matched': true,
          'match': matchJson(candidateOne),
        }, 201);
      }
      return defaultDiscoveryResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DiscoveryController(
      DiscoveryRepository(session),
      TestLocationSource(),
    );
    addTearDown(c.dispose);
    await c.activate();
    expect(await c.decide(SwipeDecision.like), isNull);
    expect(c.uncertain, isTrue);
    expect(c.canChoose, isFalse);
    await c.decide(SwipeDecision.pass);
    expect(writes.length, 1);
    c.deactivate();
    await c.activate();
    expect(c.pending?.action, PendingAction.like);
    fail = false;
    final receipt = await c.resumeChoice();
    expect(writes, [
      {'target_user_id': candidateOne, 'decision': 'like'},
      {'target_user_id': candidateOne, 'decision': 'like'},
    ]);
    expect(receipt?.match.id, matchJson(candidateOne)['id']);
    expect(c.pending, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(
      c.current?.id,
      candidateTwo,
      reason: 'the acknowledged profile never returns after reopening',
    );
  });
  test('location consent precedes native access, denial sends no coordinates and successful approximate fix sends only the contract fields', () async {
    var granted = false, ready = false;
    final writes = <Map<String, dynamic>>[];
    final source = TestLocationSource();
    final session = testSession((r) async {
      if (r.url.path.endsWith('consents')) {
        return jsonResponse(
          consentJson(complete: true, grants: {ConsentType.location: granted}),
        );
      }
      if (r.url.path.endsWith('discovery-status')) {
        return jsonResponse(discoveryStatusJson(ready: ready));
      }
      if (r.url.path.endsWith('/presence')) {
        writes.add(jsonDecode(r.body) as Map<String, dynamic>);
        ready = true;
      }
      return defaultDiscoveryResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DiscoveryController(DiscoveryRepository(session), source);
    addTearDown(c.dispose);
    await c.activate();
    await c.publishLocation();
    expect(source.calls, 0);
    granted = true;
    await session.synchronize();
    await c.activate();
    source.handler = () async =>
        throw const LocationFailure(LocationIssue.denied);
    await c.publishLocation();
    expect(c.locationIssue, LocationIssue.denied);
    expect(writes, isEmpty);
    source.handler = null;
    await c.publishLocation();
    expect(c.ready, isTrue);
    expect(c.approximate, isTrue);
    expect(writes.single.keys.toSet(), {'latitude', 'longitude'});
    expect(source.scope?.isCancelled, isFalse);
  });
  test('consent withdrawal and logout cancel native work and ignore late private responses', () async {
    var granted = true;
    final fix = Completer<LocationFix>();
    final source = TestLocationSource()..handler = () => fix.future;
    final lateFeed = Completer<http.Response>();
    var delayedFeed = false, writes = 0;
    final session = testSession((r) async {
      if (r.url.path.endsWith('consents')) {
        return jsonResponse(
          consentJson(complete: true, grants: {ConsentType.location: granted}),
        );
      }
      if (r.url.path == '/api/feed' && delayedFeed) return lateFeed.future;
      if (r.url.path.endsWith('/presence')) writes++;
      return defaultDiscoveryResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DiscoveryController(DiscoveryRepository(session), source);
    addTearDown(c.dispose);
    await c.activate();
    final locating = c.publishLocation();
    await Future<void>.delayed(Duration.zero);
    granted = false;
    await session.synchronize();
    expect(source.scope?.isCancelled, isTrue);
    fix.complete(LocationFix(48.85, 2.35, DateTime.now()));
    await locating;
    expect(writes, 0);
    expect(c.current, isNull);
    granted = true;
    await session.synchronize();
    await c.activate();
    delayedFeed = true;
    final read = c.refresh();
    await Future<void>.delayed(Duration.zero);
    await session.logout();
    lateFeed.complete(
      jsonResponse({
        'profiles': [candidateJson(candidateOne)],
        'next_cursor': null,
      }),
    );
    await read;
    expect(c.current, isNull);
    expect(c.status, isNull);
    expect(c.pending, isNull);
    expect(c.encounter, isNull);
  });
  testWidgets(
    'server presence deadline triggers a diagnostic read without requesting native location',
    (tester) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final expires = now.add(const Duration(seconds: 2));
      var reads = 0;
      final source = TestLocationSource();
      final session = testSession((r) async {
        if (r.url.path.endsWith('discovery-status')) {
          reads++;
          return jsonResponse(
            discoveryStatusJson(ready: reads == 1, expiresAt: expires),
          );
        }
        return defaultDiscoveryResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = DiscoveryController(
        DiscoveryRepository(session),
        source,
        now: () => now,
      );
      addTearDown(c.dispose);
      await c.activate();
      now = expires;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(reads, 2);
      expect(c.ready, isFalse);
      expect(c.current, isNull);
      expect(source.calls, 0);
    },
  );
  test('Retry-After prevents resending and explicit block supersedes an uncertain like safely', () async {
    var fail = true;
    final requests = <http.Request>[];
    final session = testSession((r) async {
      if (r.url.path == '/api/swipes') {
        return apiError(429, 'swipe_rate_limit_exceeded', retryAfter: '1');
      }
      if (r.url.path.startsWith('/api/users/me/blocks/')) {
        requests.add(r);
        if (fail) throw TimeoutException('lost block');
      }
      return defaultDiscoveryResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    var now = DateTime.now();
    final c = DiscoveryController(
      DiscoveryRepository(session),
      TestLocationSource(),
      now: () => now,
    );
    addTearDown(c.dispose);
    await c.activate();
    final profile = c.current!;
    await c.decide(SwipeDecision.like);
    expect(c.retrySeconds, greaterThan(0));
    await c.resumeChoice();
    expect(requests, isEmpty);
    now = now.add(const Duration(seconds: 2));
    await c.blockProfile(profile);
    expect(c.pending?.action, PendingAction.block);
    fail = false;
    await c.resumeChoice();
    expect(requests.length, 2);
    expect(
      requests.every(
        (r) =>
            r.url.path == '/api/users/me/blocks/$candidateOne' &&
            r.body.isEmpty,
      ),
      isTrue,
    );
    expect(c.pending, isNull);
    expect(c.current?.id, candidateTwo);
    expect(c.encounter, isNull);
  });
  test('foreign match members never produce a receipt or unlock the opposite decision', () async {
    final session = testSession(
      (r) async => r.url.path == '/api/swipes'
          ? jsonResponse({
              'decision': 'like',
              'matched': true,
              'match': {...matchJson(candidateOne), 'user1_id': candidateThree},
            }, 201)
          : defaultDiscoveryResponse(r),
    );
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = DiscoveryController(
      DiscoveryRepository(session),
      TestLocationSource(),
    );
    addTearDown(c.dispose);
    await c.activate();
    expect(await c.decide(SwipeDecision.like), isNull);
    expect(c.encounter, isNull);
    expect(c.pending?.action, PendingAction.like);
    expect(c.canChoose, isFalse);
  });
  testWidgets(
    'feed gestures like once on double tap, pass upward at end and never reverse downward',
    (tester) async {
      var likes = 0, passes = 0;
      final p = FeedProfile.fromJson({
        ...candidateJson(candidateOne, bio: null),
        'traits': [],
        'profile_answers': [],
        'photo': 'https://must-not-be-read.example/private',
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.light),
          home: Scaffold(
            body: FeedProfileCard(
              profile: p,
              enabled: true,
              onLike: () => likes++,
              onPass: () => passes++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Léa, 27'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.text('Léa, 27'));
      await tester.pumpAndSettle();
      expect(likes, 1);
      final scroll = find.byKey(const Key('feed-profile-scroll'));
      await tester.drag(scroll, const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(passes, 0);
      await tester.drag(scroll, const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(passes, 1);
      expect(find.byType(Image), findsNothing);
      final long = FeedProfile.fromJson(
        candidateJson(
          candidateOne,
          bio: 'Un dimanche à lire, discuter et marcher. ' * 30,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.light),
          home: Scaffold(
            body: FeedProfileCard(
              key: const ValueKey('long-profile'),
              profile: long,
              enabled: true,
              onLike: () => likes++,
              onPass: () => passes++,
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const Key('feed-profile-scroll')),
        const Offset(0, -10000),
      );
      await tester.pumpAndSettle();
      expect(
        passes,
        1,
        reason: 'reading a long profile to its end must not pass it',
      );
      await tester.drag(
        find.byKey(const Key('feed-profile-scroll')),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(
        passes,
        2,
        reason: 'a separate upward gesture at the end records the pass',
      );
    },
  );
}
