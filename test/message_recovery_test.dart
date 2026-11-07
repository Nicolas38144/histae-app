import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/features/drafts/application/draft_controller.dart';
import 'package:histae_app/features/drafts/data/draft_snapshot.dart';
import 'package:histae_app/features/drafts/data/draft_vault.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reconnected realtime resumes a pending send immediately with its original key', () async {
    final keys = <String?>[];
    final session = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
        keys.add(r.headers['Idempotency-Key']);
        if (keys.length == 1) {
          throw http.ClientException('Synthetic connection switch');
        }
        return jsonResponse(
          messageJson(
            id: outgoingId,
            sender: testUser,
            content: 'Changement de réseau',
          ),
          201,
        );
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
    await c.send('Changement de réseau');
    realtime.onState?.call(false, null);
    realtime.onState?.call(true, null);
    await pumpEventQueue();
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
    expect(c.pendingMessages, isEmpty);
  });

  test('process loss during POST restores ordered send keys and a separate composer draft', () async {
    final vault = MemoryDraftVault();
    final lostResponse = Completer<http.Response>();
    final keys = <String>[];
    final server = <String, Map<String, dynamic>>{};
    final firstSession = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
        final key = r.headers['Idempotency-Key']!;
        keys.add(key);
        server[key] = messageJson(
          id: outgoingId,
          sender: testUser,
          content:
              (jsonDecode(r.body) as Map<String, dynamic>)['content'] as String,
        );
        return lostResponse.future;
      }
      return defaultMatchesResponse(r);
    });
    await firstSession.establish(testTokens);
    final local = DraftController(firstSession, vault);
    final first = MatchesController(
      MatchesRepository(firstSession),
      drafts: local,
      realtime: QuietRealtime(firstSession),
    );
    await first.activate();
    await first.openChat(testMatch);
    final sending = first.send('Premier message');
    await pumpEventQueue();
    expect(keys, hasLength(1));
    await first.send('Deuxième message');
    first.setDraft(testMatch, 'Mon texte suivant');
    await local.flush();
    // The second process starts from the last durable bytes, without relying on
    // any dispose callback from the killed process.
    final afterKill = MemoryDraftVault()..value = vault.value;
    final snapshot = DraftSnapshot.decode(afterKill.value!);
    expect(snapshot.pending.map((i) => i.content), [
      'Premier message',
      'Deuxième message',
    ]);
    first.dispose();
    lostResponse.completeError(http.ClientException('Synthetic lost response'));
    await sending;
    local.dispose();
    firstSession.dispose();

    final restoredSession = testSession((r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
        final key = r.headers['Idempotency-Key']!;
        keys.add(key);
        final value = server.putIfAbsent(
          key,
          () => messageJson(
            id: incomingId,
            sender: testUser,
            content:
                (jsonDecode(r.body) as Map<String, dynamic>)['content']
                    as String,
          ),
        );
        return jsonResponse(value, 201);
      }
      return defaultMatchesResponse(r);
    });
    addTearDown(restoredSession.dispose);
    await restoredSession.establish(rotatedTokens);
    final restoredDrafts = DraftController(restoredSession, afterKill);
    addTearDown(restoredDrafts.dispose);
    final restored = MatchesController(
      MatchesRepository(restoredSession),
      drafts: restoredDrafts,
      realtime: QuietRealtime(restoredSession),
    );
    addTearDown(restored.dispose);
    await restored.activate();
    await restored.openChat(testMatch);
    await pumpEventQueue();
    expect(keys, [
      snapshot.pending[0].key,
      snapshot.pending[0].key,
      snapshot.pending[1].key,
    ]);
    expect(server, hasLength(2));
    expect(restored.pendingMessages, isEmpty);
    expect(restored.draftFor(testMatch), 'Mon texte suivant');
    await restoredDrafts.flush();
    expect(DraftSnapshot.decode(afterKill.value!).pending, isEmpty);
    await restoredSession.logout();
    await restoredDrafts.ready;
    expect(afterKill.value, isNull);
  });

  testWidgets(
    'transient network failure retries with the same key without clearing the next draft',
    (tester) async {
      final keys = <String?>[];
      final session = testSession((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/messages')) {
          keys.add(r.headers['Idempotency-Key']);
          if (keys.length == 1) {
            throw http.ClientException('Synthetic Wi-Fi loss');
          }
          return jsonResponse(
            messageJson(id: outgoingId, sender: testUser, content: 'À envoyer'),
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
      await c.send('À envoyer');
      c.setDraft(testMatch, 'Je continue à écrire');
      expect(keys, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(c.pendingMessages, isEmpty);
      expect(c.draftFor(testMatch), 'Je continue à écrire');
      c.suspend();
    },
  );
}
