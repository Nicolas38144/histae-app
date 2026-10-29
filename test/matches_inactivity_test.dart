import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/archived_matches_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/match_preview_card.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';

Map<String, dynamic> _confirmed(DateTime deadline) => {
  ...publicMatchJson(status: 'confirmed', expiresAt: deadline),
  'archived': false,
  'inactivity_expires_at': deadline.toIso8601String(),
};

void main() {
  testWidgets(
    'archive navigation reuses snapshots, opens chats and stays live without owning the controller',
    (tester) async {
      final clock = DateTime.utc(2030, 1, 1);
      var deadline = clock.add(const Duration(days: 20));
      var populated = true, reads = 0;
      final session = testSession((request) async {
        reads++;
        if (request.url.path == '/api/matches/me') {
          return jsonResponse({
            'matches': [if (populated) _confirmed(deadline)],
            'next_cursor': null,
          });
        }
        if (request.url.path.endsWith('/messages')) {
          return jsonResponse({'messages': <Object?>[], 'next_cursor': null});
        }
        return defaultContinuationResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
        now: () => clock,
      );
      try {
        await tester.pumpWidget(MaterialApp(home: MatchesPage(controller: c)));
        await tester.pumpAndSettle();
        final before = reads;
        await tester.tap(find.byKey(const Key('matches-archives')));
        await tester.pumpAndSettle();
        expect(find.byType(ArchivedMatchesPage), findsOneWidget);
        expect(find.byType(MatchPreviewCard), findsOneWidget);
        expect(find.text('Archivage et suppression'), findsNothing);
        expect(reads, before, reason: 'Opening archives is local navigation.');
        await tester.enterText(
          find.byKey(const Key('archives-search')),
          'Introuvable',
        );
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsNothing);
        expect(find.byKey(const Key('archives-search')), findsOneWidget);
        expect(reads, before);
        await tester.tap(find.byTooltip('Effacer la recherche'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MatchPreviewCard));
        await tester.pumpAndSettle();
        expect(find.byType(ChatPage), findsOneWidget);
        expect(c.canSend, isTrue);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(ArchivedMatchesPage), findsOneWidget);

        deadline = clock.add(const Duration(days: 30));
        await c.refresh();
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsNothing);
        expect(find.byKey(const Key('archives-search')), findsNothing);
        expect(
          find.text('Aucune conversation archivée pour le moment.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(c.active, isTrue);
        expect(find.byKey(const Key('matches-archives')), findsOneWidget);

        populated = false;
        await c.refresh();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('matches-archives')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        c.dispose();
      }
    },
  );

  test('list validation survives closing chat while private conversation access is suspended', () async {
    var reads = 0;
    final session = testSession((request) async {
      if (request.url.path == '/api/matches/me') reads++;
      return defaultMatchesResponse(request);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    expect(c.listVerified, isTrue);
    expect(c.verified, isFalse);
    await c.openChat(testMatch);
    expect(c.verified, isTrue);
    c.closeChat(testMatch);
    expect(c.listVerified, isTrue);
    expect(c.verified, isFalse);
    c.suspend();
    expect(c.listVerified, isFalse);
    await c.activate();
    expect(c.listVerified, isTrue);
    expect(reads, 1);
  });

  test('archive is accessible at day ten and expires at day thirty', () {
    final now = DateTime.utc(2030, 1, 1);
    final deadline = now.add(const Duration(days: 20));
    final match = UserMatch.fromJson({
      ...publicMatchJson(status: 'confirmed'),
      'archived': true,
      'inactivity_expires_at': deadline.toIso8601String(),
    }, testUser);
    expect(
      match.isArchivedAt(now.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(match.isArchivedAt(now), isTrue);
    expect(match.historyAllowed, isTrue);
    expect(match.sendAllowed, isTrue);
    expect(match.isInactivityExpiredAt(deadline), isTrue);
    expect(match.isArchivedAt(deadline), isFalse);
  });

  test('a renewed server deadline restores an archived conversation', () {
    final now = DateTime.utc(2030, 1, 1);
    final match = UserMatch.fromJson({
      ...publicMatchJson(status: 'confirmed'),
      'archived': false,
      'inactivity_expires_at': now
          .add(const Duration(days: 30))
          .toIso8601String(),
    }, testUser);
    expect(match.isArchivedAt(now), isFalse);
    expect(match.isInactivityExpiredAt(now), isFalse);
  });

  test('inactivity notification opens only the referenced conversation', () {
    final intent = PushIntent.parse({
      'notification_id': notificationOne,
      'type': 'match_expiring',
      'match_id': testMatch,
      'message': 'Untrusted provider text',
    });
    expect(intent?.kind, PushKind.matchExpiring);
    expect(intent?.matchId, testMatch);
    expect(
      PushIntent.parse({
        'notification_id': notificationOne,
        'type': 'match_expiring',
      }),
      isNull,
    );
  });

  testWidgets(
    'day ten archives locally; day thirty blocks actions and a renewed server deadline restores access',
    (tester) async {
      var clock = DateTime.utc(2030, 1, 1);
      var deadline = clock.add(const Duration(days: 30));
      var reads = 0, writes = 0;
      final session = testSession((request) async {
        if (request.method != 'GET') writes++;
        if (request.url.path == '/api/matches/me') {
          reads++;
          return jsonResponse({
            'matches': [_confirmed(deadline)],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
        now: () => clock,
      );
      try {
        await c.activate();
        await c.openChat(testMatch);
        await c.continuation.activate();
        final before = reads;
        clock = clock.add(const Duration(days: 10));
        await tester.pump(const Duration(days: 10));
        expect(c.selected!.isArchivedAt(clock), isTrue);
        expect(c.canRead, isTrue);
        expect(c.canSend, isTrue);
        expect(
          reads,
          before,
          reason: 'Archiving is a local presentation change.',
        );

        clock = deadline;
        expect(c.verified, isTrue);
        expect(c.canRead, isFalse);
        expect(c.canSend, isFalse);
        expect(c.continuation.canReveal, isFalse);
        await c.continuation.reveal();
        expect(writes, 0);

        // The other participant wrote before expiry; our cached date is stale.
        deadline = clock.add(const Duration(days: 30));
        await tester.pump(const Duration(days: 20));
        await tester.pump();
        expect(reads, before + 1);
        expect(c.selectedId, testMatch);
        expect(c.canRead, isTrue);
        expect(c.canSend, isTrue);
        expect(c.isRemoved(testMatch), isFalse);
        expect(c.selected!.isArchivedAt(clock), isFalse);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'resuming an expired cached conversation verifies its renewed deadline once',
    (tester) async {
      var clock = DateTime.utc(2030, 1, 1);
      var deadline = clock.add(const Duration(seconds: 1));
      var reads = 0;
      final session = testSession((request) async {
        if (request.url.path == '/api/matches/me') {
          reads++;
          return jsonResponse({
            'matches': [_confirmed(deadline)],
            'next_cursor': null,
          });
        }
        return defaultMatchesResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
        now: () => clock,
      );
      try {
        await c.activate();
        await c.openChat(testMatch);
        expect(reads, 1);
        c.suspend();
        clock = clock.add(const Duration(seconds: 2));
        deadline = clock.add(const Duration(days: 30));
        await c.activate();
        expect(c.messages, isEmpty);
        expect(c.canRead, isFalse);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(reads, 2);
        expect(c.canSend, isTrue);
        expect(c.isRemoved(testMatch), isFalse);
        await tester.pump(const Duration(seconds: 2));
        expect(reads, 2);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'an expired fresh response never restores private content or loops',
    (tester) async {
      final clock = DateTime.utc(2030, 1, 1);
      var reads = 0, histories = 0;
      final session = testSession((request) async {
        if (request.url.path == '/api/matches/me') {
          reads++;
          return jsonResponse({
            'matches': [_confirmed(clock)],
            'next_cursor': null,
          });
        }
        if (request.url.path.endsWith('/messages')) histories++;
        return defaultMatchesResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
        now: () => clock,
      );
      try {
        c.setDraft(testMatch, 'Private unsent text');
        await c.activate(refresh: true);
        expect(c.items, isEmpty);
        expect(c.draftFor(testMatch), isEmpty);
        expect(c.canSend, isFalse);
        expect(histories, 0);
        await tester.pump(const Duration(seconds: 2));
        expect(reads, 1);
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'search opens archived results without HTTP and disappears when the list becomes empty',
    (tester) async {
      final clock = DateTime.utc(2030, 1, 1);
      var populated = true, reads = 0;
      final session = testSession((request) async {
        reads++;
        if (request.url.path == '/api/matches/me') {
          return jsonResponse({
            'matches': [
              if (populated) _confirmed(clock.add(const Duration(days: 20))),
            ],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
        now: () => clock,
      );
      try {
        await tester.pumpWidget(MaterialApp(home: MatchesPage(controller: c)));
        await tester.pumpAndSettle();
        final before = reads;
        expect(find.byType(MatchPreviewCard), findsNothing);
        expect(find.text('Archivage et suppression'), findsNothing);
        await tester.enterText(find.byKey(const Key('matches-search')), 'lea');
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsOneWidget);
        expect(reads, before);
        populated = false;
        await c.refresh();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('matches-search')), findsNothing);
        expect(find.text('Archivage et suppression'), findsNothing);
        expect(find.byKey(const Key('matches-credits-toggle')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        c.dispose();
      }
    },
  );

  testWidgets(
    'the chat refresh button performs an explicit read and preserves its draft',
    (tester) async {
      var lists = 0, histories = 0;
      final session = testSession((request) async {
        if (request.url.path == '/api/matches/me') lists++;
        if (request.url.path.endsWith('/messages')) {
          histories++;
          return jsonResponse({'messages': <Object?>[], 'next_cursor': null});
        }
        return defaultMatchesResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      try {
        await c.activate();
        await c.openChat(testMatch);
        c.setDraft(testMatch, 'A draft to retain');
        await tester.pumpWidget(
          MaterialApp(
            home: ChatPage(controller: c, matchId: testMatch),
          ),
        );
        await tester.pumpAndSettle();
        final beforeLists = lists, beforeHistories = histories;
        await tester.tap(find.byKey(const Key('chat-refresh')));
        await tester.pumpAndSettle();
        expect(lists, beforeLists + 1);
        expect(histories, beforeHistories + 1);
        expect(c.draftFor(testMatch), 'A draft to retain');
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        c.dispose();
      }
    },
  );
}
