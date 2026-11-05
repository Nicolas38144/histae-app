import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  testWidgets(
    'photo URL renewal and other-match events retain current history; manual refresh still reads it',
    (tester) async {
      var lists = 0, histories = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') lists++;
        if (r.method == 'GET' && r.url.path.endsWith('/messages')) histories++;
        return defaultMatchesResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final realtime = QuietRealtime(session);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: realtime,
      );
      addTearDown(c.dispose);
      await c.activate();
      await c.openChat(testMatch);
      final initialLists = lists, initialHistories = histories;
      await Future.wait([c.refreshPhotos(), c.refreshPhotos()]);
      expect(lists, initialLists + 1);
      expect(histories, initialHistories);
      realtime.emit(
        const MobileSignal('message.created', matchId: secondMatch),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      expect(lists, initialLists + 2);
      expect(histories, initialHistories);
      realtime.emit(const MobileSignal('subscription.updated'));
      await tester.pump(const Duration(milliseconds: 180));
      expect(lists, initialLists + 2);
      expect(histories, initialHistories);
      await c.refresh();
      expect(histories, initialHistories + 1);
      c.suspend();
    },
  );

  testWidgets(
    'reopening history reuses data; a new message event still reads fresh history',
    (tester) async {
      var lists = 0, histories = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/matches/me') lists++;
        if (r.url.path.endsWith('/messages')) histories++;
        return defaultMatchesResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final realtime = QuietRealtime(session);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: realtime,
      );
      addTearDown(c.dispose);
      await c.activate();
      await c.openChat(testMatch);
      final firstLists = lists, firstHistories = histories;
      final readAt = c.readAt;
      c.closeChat(testMatch);
      await c.openChat(testMatch);
      expect(lists, firstLists);
      expect(histories, firstHistories);
      expect(c.readAt, readAt);
      realtime.emit(const MobileSignal('message.created', matchId: testMatch));
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      expect(lists, firstLists + 1);
      expect(histories, firstHistories + 1);
      expect(c.messages, isNotEmpty);
      c.suspend();
    },
  );
}
