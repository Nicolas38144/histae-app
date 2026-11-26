import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/main_shell.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/widgets/histae_button.dart';
import 'package:histae_app/core/widgets/histae_empty_state.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/discovery/application/discovery_controller.dart';
import 'package:histae_app/features/discovery/data/device_location.dart';
import 'package:histae_app/features/discovery/data/discovery_models.dart';
import 'package:histae_app/features/discovery/data/discovery_repository.dart';
import 'package:histae_app/features/discovery/presentation/discovery_page.dart';
import 'package:histae_app/features/discovery/presentation/discovery_status_sections.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/profile_editors.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/profile_fixture.dart';
import 'support/scrolling.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'an exhausted feed refreshes from the menu and retries errors in place',
    (tester) async {
      var feedReads = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/feed') {
          if (++feedReads == 2) return apiError(500, 'internal_error');
          return jsonResponse({'profiles': <Object?>[], 'next_cursor': null});
        }
        return defaultDiscoveryResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: MainShell(session: session),
        ),
      );
      await tester.pumpAndSettle();

      final emptyState = find.byType(HistaeEmptyState);
      final refresh = find.text('Actualiser le feed');
      expect(feedReads, 1);
      expect(emptyState, findsOneWidget);
      expect(refresh, findsNothing);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(refresh, findsOneWidget);
      expect(find.text('Actualiser ma position'), findsOneWidget);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(feedReads, 2);
      expect(emptyState, findsNothing);

      final retry = find.widgetWithText(OutlinedButton, 'Réessayer');
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(feedReads, 3);
      expect(emptyState, findsOneWidget);
      expect(refresh, findsNothing);
      expect(retry, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a missing biography blocks the feed until a nonblank edit is saved',
    (tester) async {
      String? bio;
      var saves = 0, feedReads = 0;
      final session = testSession((r) async {
        switch (r.url.path) {
          case '/api/users/me':
            return jsonResponse(ownerJson(bio: bio));
          case '/api/users/me/profile':
            saves++;
            bio = jsonDecode(r.body)['bio'] as String;
          case '/api/feed':
            feedReads++;
        }
        return defaultDiscoveryResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: MainShell(session: session),
        ),
      );
      await tester.pumpAndSettle();
      expect(feedReads, 0);
      final edit = find.widgetWithText(TextButton, 'Modifier ma présentation');
      expect(
        find.text('Ajoutez une présentation pour accéder au feed.'),
        findsOneWidget,
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(IdentityEditor), findsOneWidget);

      final field = find.widgetWithText(TextField, 'Quelques mots sur vous');
      final save = find.widgetWithText(HistaeButton, 'Enregistrer');
      await tester.scrollUntilVisible(
        save,
        180,
        scrollable: verticalScrollables.first,
      );
      expect(tester.widget<HistaeButton>(save).onPressed, isNull);
      await tester.ensureVisible(field);
      await tester.enterText(field, ' \n\t  ');
      await tester.pumpAndSettle();
      expect(tester.widget<HistaeButton>(save).onPressed, isNull);
      expect(saves, 0);

      await tester.enterText(field, '  Les livres et les longues balades.  ');
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(bio, 'Les livres et les longues balades.');
      expect(saves, 1);
      expect(feedReads, 1);
      expect(edit, findsNothing);
      expect(find.byType(FeedProfileCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'returning from Mon profil rechecks a trait change once the server read catches up',
    (tester) async {
      var selected = false;
      bool? previousSelection;
      var statusReads = 0;
      final session = testSession((r) async {
        switch (r.url.path) {
          case '/api/users/me/discovery-status':
            statusReads++;
          case '/api/users/me/traits':
            if (r.method == 'GET') {
              return jsonResponse({
                'traits': [
                  if (previousSelection ?? selected)
                    {'id': traitOne, 'name': 'Curieux'},
                ],
              });
            }
            previousSelection = selected;
            selected = true;
            return http.Response('', 204);
          case '/api/users/me/traits/$traitOne':
            previousSelection = selected;
            selected = false;
            return http.Response('', 204);
        }
        return defaultDiscoveryResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: MainShell(session: session),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> selectTab(String tab) async {
        await tester.tap(find.byKey(ValueKey('main-tab-$tab')));
        await tester.pumpAndSettle();
      }

      Future<void> editTraits() async {
        await selectTab('profile');
        final edit = find.text('Choisir mes traits');
        await tester.scrollUntilVisible(
          edit,
          160,
          scrollable: verticalScrollables.first,
        );
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(find.byType(TraitsEditor), findsOneWidget);
        await tester.tap(find.byType(FilterChip));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      expect(find.text('Choisir mes traits'), findsOneWidget);
      final initialReads = statusReads;
      await editTraits();
      previousSelection = null;
      await selectTab('discovery');
      expect(find.text('Choisir mes traits'), findsNothing);
      expect(find.byType(FeedProfileCard), findsOneWidget);
      expect(statusReads, initialReads + 1);

      await editTraits();
      previousSelection = null;
      await selectTab('discovery');
      expect(find.text('Choisir mes traits'), findsOneWidget);
      expect(find.byType(FeedProfileCard), findsNothing);
      expect(statusReads, initialReads + 2);

      await selectTab('profile');
      await selectTab('discovery');
      expect(statusReads, initialReads + 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'feed opens after saving both profile details and closes when the last trait is removed',
    (tester) async {
      var selected = false, feedReads = 0, traitReadsAfterSelection = 0;
      var delayTraitRead = true;
      var answers = <Map<String, dynamic>>[];
      final session = testSession((r) async {
        switch (r.url.path) {
          case '/api/users/me/traits':
            if (r.method == 'GET') {
              // An independent read can lag behind the editor's confirmation.
              if (selected) traitReadsAfterSelection++;
              final hasTrait =
                  selected &&
                  !(delayTraitRead && traitReadsAfterSelection == 2);
              return jsonResponse({
                'traits': [
                  if (hasTrait) {'id': traitOne, 'name': 'Curieux'},
                ],
              });
            }
            selected = true;
            return http.Response('', 204);
          case '/api/users/me/traits/$traitOne':
            selected = false;
            return http.Response('', 204);
          case '/api/users/me/profile-answers':
            if (r.method == 'PUT') {
              final draft = (jsonDecode(r.body)['answers'] as List).single;
              answers = [answerJson(questionOne, draft['answer'] as String, 0)];
            }
            return jsonResponse({'answers': answers});
          case '/api/feed':
            feedReads++;
        }
        return defaultDiscoveryResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: MainShell(session: session),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tapText(String label) async {
        final finder = find.text(label);
        await tester.scrollUntilVisible(
          finder,
          150,
          scrollable: verticalScrollables.first,
        );
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expect(feedReads, 0);
      expect(
        find.widgetWithText(TextButton, 'Choisir mes traits'),
        findsOneWidget,
      );
      expect(find.textContaining('pour accéder au feed'), findsWidgets);
      await tapText('Choisir mes traits');
      expect(find.byType(TraitsEditor), findsOneWidget);
      await tapText('Curieux');
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Choisir mes traits'), findsNothing);
      expect(feedReads, 0);
      expect(traitReadsAfterSelection, 1);
      delayTraitRead = false;

      await tapText('Écrire mes réponses');
      expect(find.byType(AnswersEditor), findsOneWidget);
      await tapText('Ajouter une question');
      await tester.tap(find.text('Votre dimanche idéal ?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Un café et une promenade.',
      );
      expect(feedReads, 0);
      await tester.tap(find.text('Enregistrer mes réponses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedProfileCard), findsOneWidget);
      expect(feedReads, 1);

      final profile = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .profile;
      await profile.setTrait(traitOne, false);
      await tester.pumpAndSettle();
      expect(find.text('Choisir mes traits'), findsOneWidget);
      expect(find.byType(FeedProfileCard), findsNothing);
      expect(feedReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
    expect(c.choiceFeedback?.decision, SwipeDecision.pass);
    expect(c.notice, isNull);
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
    expect(c.choiceFeedback, isNull);
    expect(c.canChoose, isFalse);
    await c.decide(SwipeDecision.pass);
    expect(writes.length, 1);
    c.deactivate();
    await c.activate();
    expect(c.pending?.action, PendingAction.like);
    fail = false;
    final receipt = await c.resumeChoice();
    expect(c.choiceFeedback?.decision, SwipeDecision.like);
    expect(c.notice, isNull);
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
  testWidgets(
    'disabled location feedback stays with its action and opens service settings',
    (tester) async {
      var writes = 0;
      final source = _SettingsLocationSource()
        ..handler = () async =>
            throw const LocationFailure(LocationIssue.disabled);
      final session = testSession((r) async {
        if (r.url.path.endsWith('discovery-status')) {
          return jsonResponse(discoveryStatusJson(ready: false));
        }
        if (r.url.path.endsWith('/presence')) writes++;
        return defaultDiscoveryResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = DiscoveryController(DiscoveryRepository(session), source);
      final profile = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: DiscoveryPage(controller: c, profile: profile),
        ),
      );
      await tester.pumpAndSettle();
      final locate = find.text('Actualiser ma position');
      await tester.ensureVisible(locate);
      await tester.tap(locate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Localiser cet appareil'));
      await tester.pumpAndSettle();
      expect(c.locationIssue, LocationIssue.disabled);
      expect(writes, 0);
      expect(
        find.descendant(
          of: find.byType(DiscoveryReadinessCard),
          matching: find.byType(DiscoveryLocationFeedback),
        ),
        findsOneWidget,
      );
      final settings = find.text('Ouvrir les réglages');
      await tester.ensureVisible(settings);
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(source.settingsCalls, 1);
      expect(source.services, isTrue);
      expect(writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
    'presence expiry shows the location step and refreshes readiness once without automatic GPS',
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
      final profile = ProfileController(ProfileRepository(session));
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: DiscoveryPage(controller: c, profile: profile),
        ),
      );
      expect(find.byType(FeedProfileCard), findsOneWidget);
      now = expires;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(reads, 2);
      expect(c.ready, isFalse);
      expect(c.status, isNotNull);
      expect(c.requiredActions, [DiscoveryAction.freshPresence]);
      expect(c.current, isNull);
      expect(source.calls, 0);
      expect(find.byType(FeedProfileCard), findsNothing);
      expect(find.byType(DiscoveryReadinessCard), findsOneWidget);
      expect(find.text('Une position récente'), findsOneWidget);
      expect(
        find.text('Cette page a expiré. Actualisez les profils.'),
        findsNothing,
      );
      await tester.pump(const Duration(minutes: 5));
      expect(
        reads,
        2,
        reason: 'the expired deadline must not start a read loop',
      );
      await c.refresh();
      await tester.pump();
      expect(reads, 3);
      expect(c.ready, isFalse);
      expect(source.calls, 0);
      expect(find.byType(DiscoveryReadinessCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('an expired server deadline is refreshed once without a loop', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 16, 12);
    var feedReads = 0, statusReads = 0;
    final session = testSession((r) async {
      if (r.url.path.endsWith('discovery-status')) {
        statusReads++;
        return jsonResponse(
          discoveryStatusJson(
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
        );
      }
      if (r.url.path == '/api/feed') feedReads++;
      return defaultDiscoveryResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final source = TestLocationSource();
    final c = DiscoveryController(
      DiscoveryRepository(session),
      source,
      now: () => now,
    );
    addTearDown(c.dispose);
    await c.activate();
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(statusReads, 2);
    expect(c.ready, isFalse);
    expect(c.requiredActions, [DiscoveryAction.freshPresence]);
    expect(feedReads, 0);
    expect(source.calls, 0);
  });
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
    'feed gestures pass upward at the end and never reverse downward',
    (tester) async {
      var passes = 0;
      final p = FeedProfile.fromJson({
        ...candidateJson(candidateOne, bio: null),
        'traits': <Object?>[],
        'profile_answers': <Object?>[],
        'photo': 'https://must-not-be-read.example/private',
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.light),
          home: Scaffold(
            body: FeedProfileCard(
              profile: p,
              enabled: true,
              onLike: () {},
              onPass: () => passes++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
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
              onLike: () {},
              onPass: () => passes++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
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

class _SettingsLocationSource extends TestLocationSource {
  int settingsCalls = 0;
  bool? services;

  @override
  Future<bool> openSettings({required bool services}) async {
    settingsCalls++;
    this.services = services;
    return true;
  }
}
