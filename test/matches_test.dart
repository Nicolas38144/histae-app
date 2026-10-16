import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/match_models.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';

import 'support/auth_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('lost message keeps one immutable intention through navigation and explicit replay, then deduplicates', () async {
    final writes = <(String?, Object?)>[];
    var lost = true;
    final session = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
        writes.add((r.headers['Idempotency-Key'], jsonDecode(r.body)));
        if (lost) throw TimeoutException('Synthetic lost response');
        return jsonResponse(
          messageJson(id: outgoingId, sender: testUser, content: 'Bonjour 🌿'),
          201,
        );
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.openChat(testMatch);
    expect(validateMessage(List.filled(2000, '🌿').join()), isNull);
    expect(validateMessage(List.filled(2001, '🌿').join()), isNotNull);
    expect(trimMessage('\u0085'), '\u0085');
    await c.send(' \uFEFFBonjour 🌿\n');
    final key = c.pendingMessage!.key;
    expect(c.draftFor(testMatch), 'Bonjour 🌿');
    await c.send('A different message');
    expect(writes, hasLength(1));
    c.closeChat(testMatch);
    await c.openChat(testMatch);
    expect(c.pendingMessage?.key, key);
    lost = false;
    await c.resumeSend();
    expect(writes[0].$1, writes[1].$1);
    expect(writes[0].$2, writes[1].$2);
    expect(c.pendingMessage, isNull);
    expect(c.messages.where((m) => m.id == outgoingId), hasLength(1));
    expect(c.draftFor(testMatch), isEmpty);
  });

  test('opaque match and message cursors preserve server order and selected older match is located without admin route', () async {
    const cursor = 'opaque+/= ?&';
    final queries = <String?>[];
    var invalid = false;
    final session = testSession((r) async {
      expect(r.url.queryParameters.containsKey('offset'), isFalse);
      if (r.url.path == '/api/matches/me') {
        queries.add(r.url.queryParameters['cursor']);
        return jsonResponse({
          'matches': [
            publicMatchJson(
              id: r.url.queryParameters['cursor'] == null
                  ? secondMatch
                  : testMatch,
            ),
          ],
          'next_cursor': r.url.queryParameters['cursor'] == null
              ? cursor
              : null,
        });
      }
      if (r.url.path.endsWith('/messages')) {
        expect(r.url.queryParameters['limit'], '30');
        if (r.url.queryParameters['cursor'] != null) {
          expect(r.url.queryParameters['cursor'], cursor);
          if (invalid) return apiError(400, 'invalid_cursor');
          return jsonResponse({
            'messages': [messageJson(), messageJson(id: outgoingId)],
            'next_cursor': null,
          });
        }
        return jsonResponse({
          'messages': [messageJson(), messageJson()],
          'next_cursor': cursor,
        });
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.openChat(testMatch);
    expect(queries, [null, null, cursor]);
    expect(c.canSend, isTrue);
    await c.older();
    expect(c.messages.map((m) => m.id), [incomingId, outgoingId]);
    await c.refresh();
    invalid = true;
    await c.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    expect(c.messages.map((m) => m.id), [incomingId]);
    expect(c.verified, isTrue);
  });

  test('awaiting continuation keeps history, forbids sends; confirmed ignores old expiry and terminal clears content', () async {
    var status = 'awaiting_continuation';
    var expiry = DateTime.now().add(const Duration(hours: 1));
    var posts = 0;
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        return jsonResponse({
          'matches': [publicMatchJson(status: status, expiresAt: expiry)],
          'next_cursor': null,
        });
      }
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) posts++;
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.openChat(testMatch);
    expect(c.messages, isNotEmpty);
    expect(c.canRead, isTrue);
    expect(c.canSend, isFalse);
    await c.send('No write');
    expect(posts, 0);
    status = 'confirmed';
    expiry = DateTime.now().subtract(const Duration(hours: 1));
    await c.refresh();
    expect(c.canSend, isTrue);
    status = 'active';
    await c.refresh();
    expect(c.canSend, isFalse);
    status = 'expired';
    await c.refresh();
    expect(c.messages, isEmpty);
    expect(c.selected?.lastMessage, isNull);
    c.suspend();
    expect(c.canRead, isFalse);
  });

  test('invalidation and logout purge drafts, pending text and history, ignoring late reads', () async {
    Completer<http.Response>? pending;
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me' && pending != null) {
        return pending.future;
      }
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
        throw TimeoutException('lost');
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final realtime = QuietRealtime(session);
    final c = MatchesController(MatchesRepository(session), realtime: realtime);
    addTearDown(c.dispose);
    await c.activate();
    await c.openChat(testMatch);
    await c.send('Private synthetic draft');
    pending = Completer<http.Response>();
    final reading = c.refresh();
    realtime.emit(const MobileSignal('matches.invalidated'));
    expect(c.messages, isEmpty);
    expect(c.draftFor(testMatch), isEmpty);
    expect(c.pendingMessage, isNull);
    pending.complete(
      jsonResponse({
        'matches': [publicMatchJson()],
        'next_cursor': null,
      }),
    );
    await reading;
    expect(c.items, isEmpty);
    pending = null;
    await c.refresh();
    c.setDraft(testMatch, 'Another draft');
    await session.logout();
    expect(c.items, isEmpty);
    expect(c.messages, isEmpty);
    expect(c.draftFor(testMatch), isEmpty);
    expect(c.active, isFalse);
  });

  test('uncertain end freezes sending and explicit same end or block purges the conversation', () async {
    var ends = 0, blocks = 0;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/end')) {
        expect(r.method, 'PATCH');
        expect(r.body, isEmpty);
        ends++;
        if (ends == 1) throw TimeoutException('lost');
        return jsonResponse({'message': 'match ended', 'status': 'ended'});
      }
      if (r.url.path == '/api/users/me/blocks/$candidateOne') {
        blocks++;
        return http.Response('', 204);
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.openChat(testMatch);
    c.setDraft(testMatch, 'Draft');
    await c.endCurrent();
    await c.refresh();
    expect(c.pendingEnd, testMatch);
    expect(c.canSend, isFalse);
    expect(ends, 1);
    await c.endCurrent();
    expect(ends, 2);
    expect(c.selected, isNull);
    expect(c.draftFor(testMatch), isEmpty);
    final other = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(other.dispose);
    await other.activate();
    await other.openChat(testMatch);
    await other.endCurrent(block: true);
    expect(blocks, 1);
    expect(other.messages, isEmpty);
    expect(other.selected, isNull);
  });

  testWidgets(
    'read anchors come from visible incoming messages only; covered and background routes do not mark reads',
    (tester) async {
      var reads = 0;
      final session = testSession((r) async {
        if (r.url.path.endsWith('/messages/read')) {
          reads++;
          expectSync(jsonDecode(r.body), {
            'read_through_message_id': incomingId,
          });
        }
        return defaultMatchesResponse(r);
      });
      await session.establish(testTokens);
      final realtime = QuietRealtime(session);
      final c = MatchesController(
        MatchesRepository(session),
        realtime: realtime,
      );
      await c.activate();
      await c.openChat(testMatch);
      realtime.emit(const MobileSignal('message.created', matchId: testMatch));
      await tester.pump(const Duration(milliseconds: 250));
      expect(reads, 0);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: histaeTheme(Brightness.light),
          home: ChatPage(controller: c, matchId: testMatch),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      expect(reads, 0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      c.suspend();
      await tester.pump(const Duration(milliseconds: 600));
      expect(reads, 0);
      await c.activate();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      session.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  test('SSE frame decoder handles split CRLF, comments and multiline data, rejects oversized frames and drops incomplete data', () {
    final decoder = MobileEventDecoder();
    final text =
        '\uFEFF: comment\r\nevent: match.updated\rid: $outgoingId\rdata: {"match_id":"$testMatch",\rdata: "status":"ended"}\r\n\r\n';
    final signals = <MobileSignal>[];
    for (final rune in text.runes) {
      signals.addAll(decoder.add(String.fromCharCode(rune)));
    }
    expect(signals.single.ended, isTrue);
    expect(signals.single.matchId, testMatch);
    expect(
      decoder.add('event: message.created\ndata: {"match_id":"$testMatch"}'),
      isEmpty,
    );
    expect(
      () => MobileEventDecoder().add('data: ${List.filled(17000, 'x').join()}'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
