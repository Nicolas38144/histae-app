import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/session_vault.dart';
import 'package:histae_app/features/privacy/application/privacy_controller.dart';
import 'package:histae_app/features/privacy/application/report_controller.dart';
import 'package:histae_app/features/privacy/data/privacy_models.dart';
import 'package:histae_app/features/privacy/data/privacy_repository.dart';
import 'package:histae_app/features/privacy/data/private_export_store.dart';

import 'support/auth_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/privacy_fixture.dart';

void main() {
  test('report 201 validates owner and match, while 429 blocks repeated sends until Retry-After', () async {
    var limited = false, calls = 0;
    final session = testSession((r) async {
      if (r.url.path == '/api/reports') {
        calls++;
        if (limited) {
          return apiError(429, 'report_rate_limit_exceeded', retryAfter: '30');
        }
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['match_id'], privacyId);
        expect(body.containsKey('description'), isFalse);
        return jsonResponse({
          'id': otherSessionId,
          'reporter_id': testUser,
          'reported_id': candidateOne,
          'match_id': privacyId,
          'reason': 'spam',
          'status': 'pending',
          'created_at': '2026-10-16T00:00:00Z',
        }, 201);
      }
      return defaultPrivacyResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final accepted = ReportController(
      PrivacyRepository(session),
      candidateOne,
      matchId: privacyId,
    );
    addTearDown(accepted.dispose);
    await accepted.submit(ReportReason.spam, '  ');
    expect(accepted.submitted, isTrue);
    expect(accepted.alreadyPending, isFalse);
    limited = true;
    final held = ReportController(PrivacyRepository(session), candidateTwo);
    addTearDown(held.dispose);
    await held.submit(ReportReason.other, 'description');
    expect(held.retrySeconds, greaterThan(0));
    await held.submit(ReportReason.spam, 'autre');
    expect(calls, 2);
    expect(held.pending!.reason, ReportReason.other);
  });
  test('account deletion crosses durable closing barrier once, accepts 202 then purges tokens and resources', () async {
    final vault = MemorySessionVault();
    var deletes = 0;
    final result = Completer<http.Response>();
    final session = testSession((r) async {
      if (r.method == 'DELETE' && r.url.path == '/api/users/me') {
        deletes++;
        expect(SessionRecord.decode(vault.value)!.phase, 'closing');
        expect(vault.value, isNot(contains(testTokens.refreshToken)));
        expect(vault.value, isNot(contains(deletionToken)));
        expect(jsonDecode(r.body), {'confirmation_token': deletionToken});
        expect(r.headers['Authorization'], 'Bearer ${testTokens.accessToken}');
        return result.future;
      }
      return defaultPrivacyResponse(r);
    }, vault: vault);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final controller = PrivacyController(
      PrivacyRepository(session),
      exportStore: PreviewExportStore(),
    );
    addTearDown(controller.dispose);
    await controller.enter(PrivacySection.sessions);
    expect(controller.sessions, isNotEmpty);
    final first = session.eraseAccount(deletionToken),
        second = session.eraseAccount(deletionToken);
    await Future<void>.delayed(Duration.zero);
    expect(controller.sessions, isEmpty);
    expect(session.resourceRevision, greaterThan(0));
    await expectLater(
      session.request(
        'GET',
        '/api/auth/me',
        expectedStatus: 200,
        replayAfterRefresh: true,
      ),
      throwsA(isA<ApiFailure>()),
    );
    result.complete(
      jsonResponse({'request_id': privacyId, 'status': 'in_progress'}, 202),
    );
    await Future.wait([first, second]);
    expect(deletes, 1);
    expect(session.phase, SessionPhase.signedOut);
    expect(session.notice, 'erasure_accepted');
    expect(session.identity, isNull);
    expect(SessionRecord.decode(vault.value)!.phase, 'signed_out');
  });
  test('lost deletion response is not replayed or probed, closing marker cold restore never refreshes', () async {
    final calls = <String>[];
    final vault = MemorySessionVault();
    final session = testSession((r) async {
      calls.add(r.url.path);
      if (r.method == 'DELETE') {
        throw const SocketException('synthetic lost response');
      }
      return defaultPrivacyResponse(r);
    }, vault: vault);
    await session.establish(testTokens);
    calls.clear();
    await session.eraseAccount(deletionToken);
    expect(calls, ['/api/users/me']);
    expect(session.notice, 'erasure_unconfirmed');
    expect(session.hasSession, isFalse);
    session.dispose();
    vault.value = const SessionRecord(
      'https://api.example',
      'closing',
    ).encode();
    calls.clear();
    final restored = testSession((r) async {
      calls.add(r.url.path);
      return defaultPrivacyResponse(r);
    }, vault: vault);
    addTearDown(restored.dispose);
    await restored.start();
    expect(calls, isEmpty);
    expect(restored.phase, SessionPhase.signedOut);
    expect(restored.notice, 'closure_unconfirmed');
  });
  test('secure storage barrier failure prevents destructive request; logout-all and current revoke close locally', () async {
    for (final action in ['storage', 'all', 'current']) {
      final vault = MemorySessionVault();
      final calls = <http.Request>[];
      final session = testSession((r) async {
        calls.add(r);
        if (r.url.path.endsWith('/logout-all')) {
          expect(jsonDecode(r.body), {'confirm': true});
          return jsonResponse({'revoked_sessions': 2});
        }
        if (r.method == 'DELETE') {
          expect(r.body, isEmpty);
          return http.Response('', 204);
        }
        return defaultPrivacyResponse(r);
      }, vault: vault);
      await session.establish(testTokens);
      calls.clear();
      if (action == 'storage') {
        vault.failWrites = true;
        await session.eraseAccount(deletionToken);
        expect(calls, isEmpty);
        expect(session.phase, SessionPhase.storageFailure);
      } else if (action == 'all') {
        await session.logoutEverywhere();
        expect(calls.single.url.path, '/api/auth/logout-all');
        expect(session.notice, 'logout_all_confirmed');
      } else {
        await session.revokeCurrentSession(privacyId);
        expect(calls.single.url.path, '/api/auth/sessions/$privacyId');
        expect(session.notice, 'logout_confirmed');
      }
      expect(session.hasSession, isFalse);
      session.dispose();
    }
  });
  test('reports validate raw UTF8 then keep exact intent after loss; 409 is existing report, logout drops late response', () async {
    final bodies = <String>[];
    var conflict = false;
    final late = Completer<http.Response>();
    var delay = false;
    final session = testSession((r) async {
      if (r.url.path == '/api/reports') {
        bodies.add(r.body);
        if (delay) return late.future;
        if (conflict) return apiError(409, 'report_already_pending');
        throw const SocketException('synthetic');
      }
      return defaultPrivacyResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = ReportController(PrivacyRepository(session), candidateOne);
    addTearDown(c.dispose);
    await c.submit(ReportReason.harassment, '😀' * 501);
    expect(bodies, isEmpty);
    expect(c.validation, isNotNull);
    await c.submit(ReportReason.harassment, ' ' * 2001);
    expect(bodies, isEmpty);
    await c.submit(ReportReason.harassment, '  Récit des faits.\uFEFF');
    expect(jsonDecode(bodies.single), {
      'reported_user_id': candidateOne,
      'reason': 'harassment',
      'description': 'Récit des faits.',
    });
    conflict = true;
    await c.submit(ReportReason.spam, 'texte remplacé');
    expect(bodies[1], bodies[0]);
    expect(c.submitted, isTrue);
    expect(c.alreadyPending, isTrue);
    final other = ReportController(PrivacyRepository(session), candidateTwo);
    addTearDown(other.dispose);
    delay = true;
    final send = other.submit(ReportReason.other, 'privé');
    await Future<void>.delayed(Duration.zero);
    await session.logout();
    expect(other.pending, isNull);
    late.complete(apiError(409, 'report_already_pending'));
    await send;
    expect(other.submitted, isFalse);
    expect(other.failure, isNull);
  });
  test('onboarding allows rights and opaque session pagination, uncertain mutations resolve from authoritative lists', () async {
    var created = false, revoked = false, requestCalls = 0;
    final queries = <String?>[];
    final session = testSession((r) async {
      if (r.url.path == '/api/auth/sessions') {
        queries.add(r.url.queryParameters['cursor']);
        expect(r.url.queryParameters['limit'], '20');
        expect(r.url.queryParameters.containsKey('offset'), isFalse);
        return jsonResponse({
          'sessions': r.url.queryParameters['cursor'] == null
              ? [mobileSessionJson()]
              : [
                  if (!revoked)
                    mobileSessionJson(id: otherSessionId, current: false),
                ],
          'next_cursor': r.url.queryParameters['cursor'] == null
              ? 'opaque+/=&?'
              : null,
        });
      }
      if (r.method == 'DELETE') {
        revoked = true;
        throw const SocketException('synthetic');
      }
      if (r.url.path == '/api/users/me/data-subject-requests') {
        expect(r.url.query, isEmpty);
        if (r.method == 'POST') {
          requestCalls++;
          created = true;
          return apiError(409, 'data_request_already_open');
        }
        return jsonResponse({
          'requests': [if (created) rightsJson()],
        });
      }
      return defaultPrivacyResponse(r, complete: false);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    expect(session.phase, SessionPhase.needsConsents);
    final c = PrivacyController(
      PrivacyRepository(session),
      exportStore: PreviewExportStore(),
    );
    addTearDown(c.dispose);
    await c.enter(PrivacySection.sessions);
    await c.load(more: true);
    expect(queries, [null, 'opaque+/=&?']);
    await c.revoke(c.sessions.last);
    expect(c.pendingRevoke, isNull);
    expect(c.sessions.any((s) => s.id == otherSessionId), isFalse);
    expect(session.hasSession, isTrue);
    await c.enter(PrivacySection.rights);
    await c.request(DataRight.access);
    expect(c.rights.single.status, RightStatus.pending);
    expect(c.pendingRight, isNull);
    await c.request(DataRight.access);
    expect(requestCalls, 1);
  });
  test('unblocking has no photo fetch or match restoration; logout purges all privacy lists', () async {
    final calls = <String>[];
    var blocked = true;
    final session = testSession((r) async {
      calls.add(r.url.path);
      if (r.url.path == '/api/users/me/blocks') {
        return jsonResponse({
          'blocks': [
            if (blocked)
              {
                'user_id': candidateOne,
                'firstname': null,
                'photo': 'https://private.invalid/never-fetch',
                'blocked_at': '2026-10-16T00:00:00Z',
              },
          ],
        });
      }
      if (r.method == 'DELETE') {
        blocked = false;
        return http.Response('', 204);
      }
      return defaultPrivacyResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = PrivacyController(
      PrivacyRepository(session),
      exportStore: PreviewExportStore(),
    );
    addTearDown(c.dispose);
    await c.enter(PrivacySection.blocks);
    await c.unblock(candidateOne);
    expect(c.blocks, isEmpty);
    expect(c.notice, 'unblocked');
    expect(
      calls.any((s) => s.contains('matches') || s.contains('never-fetch')),
      isFalse,
    );
    await c.enter(PrivacySection.rights);
    await session.logout();
    expect(c.rights, isEmpty);
    expect(c.pendingUnblock, isNull);
  });
  test('export streams authenticated once after definitive 401 refresh, rejects truncation and cleans only own files', () async {
    final dir = await Directory.systemTemp.createTemp('histae-export-test-');
    final store = PrivateExportStore(temporaryDirectory: () async => dir);
    final calls = <http.Request>[];
    var gets = 0;
    final session = testSession((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/data-export')) {
        gets++;
        expect(r.followRedirects, isFalse);
        expect(r.url.query, isEmpty);
        expect(r.headers['Accept'], 'application/json');
        expect(r.headers['Accept-Encoding'], 'identity');
        if (gets == 1) return apiError(401, 'invalid_or_expired_access_token');
        expect(
          r.headers['Authorization'],
          'Bearer ${rotatedTokens.accessToken}',
        );
        return http.Response(
          '{"user":"synthetic"}',
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'content-length': '21',
          },
        );
      }
      return defaultPrivacyResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final stream = await session.openDataExport(RequestCancellation());
    // The response intentionally declares one extra byte: no partial export may survive.
    await expectLater(
      store.save(stream, RequestCancellation()),
      throwsA(isA<ApiFailure>()),
    );
    expect(gets, 2);
    expect(calls.where((r) => r.url.path.endsWith('/refresh')).length, 1);
    final path = await store.save(
      ApiDownload(
        Stream.fromIterable([utf8.encode('{"ok":'), utf8.encode('true}')]),
        () {},
        11,
      ),
      RequestCancellation(),
    );
    expect(await File(path).readAsString(), '{"ok":true}');
    final unrelated = File(
      '${File(path).parent.path}${Platform.pathSeparator}keep.json',
    );
    await unrelated.writeAsString('unrelated');
    final share = await Directory(
      '${dir.path}${Platform.pathSeparator}share_plus',
    ).create();
    final copy = File(
      '${share.path}${Platform.pathSeparator}${File(path).uri.pathSegments.last}',
    );
    await copy.writeAsString('{}');
    await store.clean();
    expect(await File(path).exists(), isFalse);
    expect(await copy.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    await unrelated.delete();
    await File(path).parent.delete();
    await share.delete();
    await dir.delete();
  });
  test('stream cancellation removes partial export; share handoff survives suspension then is cleaned on return', () async {
    final dir = await Directory.systemTemp.createTemp('histae-export-cancel-');
    final store = PrivateExportStore(temporaryDirectory: () async => dir);
    final scope = RequestCancellation();
    final chunks = StreamController<List<int>>();
    final saving = store.save(ApiDownload(chunks.stream, () {}, 4), scope);
    chunks.add([123]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    scope.cancel();
    final failure = expectLater(saving, throwsA(isA<ApiFailure>()));
    chunks.add([125]);
    await chunks.close();
    await failure;
    final own = Directory(
      '${dir.path}${Platform.pathSeparator}histae_private_exports',
    );
    expect(await own.list().toList(), isEmpty);
    final session = testSession((r) async => defaultPrivacyResponse(r));
    await session.establish(testTokens);
    final fake = PreviewExportStore();
    final c = PrivacyController(PrivacyRepository(session), exportStore: fake);
    c.exportPath = 'synthetic-path';
    final chooser = Completer<void>();
    final sharing = c.shareExport((p) => chooser.future);
    c.suspend();
    expect(fake.cleanCount, 0);
    chooser.complete();
    await sharing;
    expect(fake.cleanCount, 0);
    await c.resume();
    expect(fake.cleanCount, 1);
    expect(c.exportPath, isNull);
    c.dispose();
    session.dispose();
    await own.delete();
    await dir.delete();
  });
}
