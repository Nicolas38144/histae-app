import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:histae_app/features/matches/presentation/match_list_projection.dart';
import 'package:histae_app/features/matches/presentation/match_preview_card.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  test('terminal matches never enter search or archives; pending and confirmed matches stay visible', () {
    final now = DateTime.utc(2030, 1, 1);
    final matches = [
      for (final status in [
        'active',
        'awaiting_continuation',
        'confirmed',
        'expired',
        'ended',
      ])
        UserMatch.fromJson(
          publicMatchJson(
            status: status,
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          testUser,
        ),
    ];
    final list = MatchListProjection(matches, now: now, search: '');
    expect(list.current.map((m) => m.status), [
      MatchStatus.active,
      MatchStatus.awaitingContinuation,
      MatchStatus.confirmed,
    ]);
    final terminal = MatchListProjection(
      matches.skip(3),
      now: now,
      search: 'Someone',
    );
    expect(terminal.hasMatches, isFalse);
    expect(terminal.hasResults, isFalse);
    expect(terminal.query, isEmpty);
    final deadline = MatchListProjection(
      [matches[1]],
      now: now.add(const Duration(hours: 1)),
      search: '',
    );
    expect(deadline.hasMatches, isFalse);
  });

  testWidgets(
    'expired and ended matches disappear with their search and archive controls',
    (tester) async {
      var status = 'active';
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') {
          return jsonResponse({
            'matches': [publicMatchJson(status: status)],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(home: MatchesPage(controller: c)));
      await tester.pumpAndSettle();
      for (final terminal in ['expired', 'ended']) {
        status = 'active';
        await c.refresh();
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsOneWidget);
        status = terminal;
        await c.refresh();
        await tester.pumpAndSettle();
        expect(c.items, isEmpty);
        expect(find.byType(MatchPreviewCard), findsNothing);
        expect(find.byKey(const Key('matches-search')), findsNothing);
        expect(find.byKey(const Key('matches-archives')), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'continuation expiry removes a cached match even when verification is offline',
    (tester) async {
      var now = DateTime.utc(2030, 1, 1);
      final deadline = now.add(const Duration(seconds: 1));
      var reads = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') {
          reads++;
          if (reads > 1) throw http.ClientException('Synthetic offline');
          return jsonResponse({
            'matches': [
              publicMatchJson(
                status: 'awaiting_continuation',
                expiresAt: deadline,
              ),
            ],
            'next_cursor': null,
          });
        }
        return defaultMatchesResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
        now: () => now,
      );
      addTearDown(c.dispose);
      await c.activate();
      c.setDraft(testMatch, 'Private unfinished message');
      expect(c.items, hasLength(1));
      now = deadline;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(c.items, isEmpty);
      expect(c.draftFor(testMatch), isEmpty);
      expect(c.failure?.kind, ApiFailureKind.network);
      await tester.pump(const Duration(seconds: 2));
      expect(reads, 2, reason: 'Expired data must not trigger a refresh loop.');
    },
  );

  test('pagination and terminal live signals cannot reintroduce expired matches', () async {
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        final more = r.url.queryParameters.containsKey('cursor');
        return jsonResponse({
          'matches': more
              ? [
                  publicMatchJson(id: secondMatch, status: 'expired'),
                  publicMatchJson(id: incomingId, status: 'ended'),
                ]
              : [publicMatchJson()],
          'next_cursor': more ? null : 'next-page',
        });
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final realtime = QuietRealtime(session);
    final c = MatchesController(MatchesRepository(session), realtime: realtime);
    addTearDown(c.dispose);
    await c.activate();
    c.setDraft(secondMatch, 'Do not retain terminal data');
    await c.loadMore();
    expect(c.items.map((m) => m.id), [testMatch]);
    expect(c.draftFor(secondMatch), isEmpty);
    final signal = MobileEventDecoder()
        .add(
          'event: match.updated\ndata: {"match_id":"$testMatch","status":"expired"}\n\n',
        )
        .single;
    expect(signal.ended, isTrue);
    realtime.emit(signal);
    expect(c.items, isEmpty);
  });
}
