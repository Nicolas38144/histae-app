import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/session_vault.dart';
import 'package:histae_app/features/consents/data/consent_state.dart';

import 'support/auth_fixture.dart';

void main() {
  test('new account stays outside the private space until server consent completion', () async {
    final vault = MemorySessionVault();
    final calls = <http.Request>[];
    final session = testSession((request) async {
      calls.add(request);
      return defaultAuthResponse(request);
    }, vault: vault);
    addTearDown(session.dispose);
    await session.start();
    expect(session.phase, SessionPhase.signedOut);
    await session.establish(testTokens);
    expect(session.phase, SessionPhase.needsConsents);
    expect(session.identity!.userId, testUser);
    expect(calls.map((r) => r.url.path), [
      '/api/auth/me',
      '/api/users/me/consents',
    ]);
    expect(
      calls.every(
        (r) => r.headers['Authorization'] == 'Bearer test-access-old',
      ),
      isTrue,
    );
    expect(vault.value, isNot(contains(testTokens.accessToken)));
    expect(vault.value, isNot(contains(testUser)));
  });

  test('restoration is single-flight and consumes a refresh only after a durable marker', () async {
    final vault = MemorySessionVault()
      ..value = const SessionRecord(
        'https://api.example',
        'ready',
        'test-refresh-old',
      ).encode();
    var refreshes = 0;
    final session = testSession((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshes++;
        expect(SessionRecord.decode(vault.value)!.phase, 'rotating');
        expect(vault.value, isNot(contains('test-refresh-old')));
        expect(jsonDecode(request.body), {'refresh_token': 'test-refresh-old'});
        expect(request.headers['Authorization'], isNull);
      }
      return defaultAuthResponse(request, complete: true);
    }, vault: vault);
    addTearDown(session.dispose);
    await Future.wait([session.start(), session.start(), session.start()]);
    expect(refreshes, 1);
    expect(session.phase, SessionPhase.ready);
    expect(SessionRecord.decode(vault.value)!.refreshToken, 'test-refresh-new');
  });

  for (final record in [
    const SessionRecord('https://api.example', 'rotating'),
    const SessionRecord(
      'https://different.example',
      'ready',
      'test-refresh-old',
    ),
  ]) {
    test(
      'interrupted or foreign-origin records never send their credentials',
      () async {
        final vault = MemorySessionVault()..value = record.encode();
        final session = testSession(
          (_) async => fail('No network call allowed'),
          vault: vault,
        );
        addTearDown(session.dispose);
        await session.start();
        expect(session.phase, SessionPhase.signedOut);
        expect(session.failure!.kind, ApiFailureKind.sessionUncertain);
        expect(SessionRecord.decode(vault.value)!.phase, 'signed_out');
      },
    );
  }

  test(
    'concurrent 401s rotate once and replay only safe L2 requests',
    () async {
      var expired = false;
      var oldReads = 0;
      var refreshes = 0;
      final bothOld = Completer<void>();
      final session = testSession((request) async {
        if (request.url.path == '/api/auth/refresh') refreshes++;
        if (expired &&
            request.headers['Authorization'] == 'Bearer test-access-old') {
          oldReads++;
          if (oldReads == 2) bothOld.complete();
          await bothOld.future;
          return apiError(401, 'invalid_or_expired_access_token');
        }
        return defaultAuthResponse(request, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      expired = true;
      await Future.wait([
        session.synchronize(),
        session.saveConsents({ConsentType.location: true}, consentVersions()),
      ]);
      expect(refreshes, 1);
      expect(oldReads, 2);
      expect(session.phase, SessionPhase.ready);
    },
  );

  test('a revoked session is closed without a refresh', () async {
    var revoked = false;
    var refreshes = 0;
    final vault = MemorySessionVault();
    final session = testSession((request) async {
      if (request.url.path == '/api/auth/refresh') refreshes++;
      if (revoked) return apiError(401, 'authentication_required');
      return defaultAuthResponse(request, complete: true);
    }, vault: vault);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    revoked = true;
    await session.synchronize();
    expect(session.phase, SessionPhase.signedOut);
    expect(session.identity, isNull);
    expect(session.consents, isNull);
    expect(refreshes, 0);
    expect(vault.value, isNot(contains('test-refresh')));
  });

  test(
    'a second 401 after rotation closes the session without a refresh loop',
    () async {
      var expired = false;
      var refreshes = 0;
      final session = testSession((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          return jsonResponse(tokenJson(rotatedTokens));
        }
        if (expired) return apiError(401, 'invalid_or_expired_access_token');
        return defaultAuthResponse(request, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      expired = true;
      await session.synchronize();
      expect(refreshes, 1);
      expect(session.phase, SessionPhase.signedOut);
    },
  );

  test(
    'a lost refresh response is never replayed, including after restart',
    () async {
      final vault = MemorySessionVault()
        ..value = const SessionRecord(
          'https://api.example',
          'ready',
          'test-refresh-old',
        ).encode();
      var calls = 0;
      final session = testSession((request) async {
        calls++;
        throw http.ClientException('Synthetic lost response');
      }, vault: vault);
      addTearDown(session.dispose);
      await session.start();
      expect(session.phase, SessionPhase.signedOut);
      await session.synchronize();
      final restarted = testSession(
        (_) async => fail('Must not replay'),
        vault: vault,
      );
      addTearDown(restarted.dispose);
      await restarted.start();
      expect(restarted.phase, SessionPhase.signedOut);
      expect(calls, 1);
    },
  );

  test('secure marker failure prevents refresh from being sent', () async {
    var expired = false;
    var refreshes = 0;
    final vault = MemorySessionVault();
    final session = testSession((request) async {
      if (request.url.path == '/api/auth/refresh') refreshes++;
      return expired
          ? apiError(401, 'invalid_or_expired_access_token')
          : defaultAuthResponse(request, complete: true);
    }, vault: vault);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    vault.failWrites = true;
    expired = true;
    await session.synchronize();
    expect(session.phase, SessionPhase.storageFailure);
    expect(session.hasSession, isFalse);
    expect(refreshes, 0);
  });

  test(
    'a replacement storage failure never publishes the new access token',
    () async {
      var expired = false;
      var newTokenReads = 0;
      final vault = MemorySessionVault();
      final session = testSession((request) async {
        if (request.headers['Authorization'] == 'Bearer test-access-new') {
          newTokenReads++;
        }
        if (request.url.path == '/api/auth/refresh') {
          vault.failNextReady = true;
          return jsonResponse(tokenJson(rotatedTokens));
        }
        return expired
            ? apiError(401, 'invalid_or_expired_access_token')
            : defaultAuthResponse(request, complete: true);
      }, vault: vault);
      addTearDown(session.dispose);
      await session.establish(testTokens);
      expired = true;
      await session.synchronize();
      expect(session.hasSession, isFalse);
      expect(newTokenReads, 0);
      expect(SessionRecord.decode(vault.value)!.phase, 'signed_out');
    },
  );

  test(
    'logout waits for rotation and revokes the latest pair before clearing',
    () async {
      var expired = false;
      final refreshing = Completer<void>();
      final rotationResponse = Completer<http.Response>();
      final logoutBodies = <Object?>[];
      final vault = MemorySessionVault();
      final session = testSession((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshing.complete();
          return rotationResponse.future;
        }
        if (request.url.path == '/api/auth/logout') {
          logoutBodies.add(jsonDecode(request.body));
          expect(request.headers['Authorization'], 'Bearer test-access-new');
          return http.Response('', 204);
        }
        if (expired) return apiError(401, 'invalid_or_expired_access_token');
        return defaultAuthResponse(request, complete: true);
      }, vault: vault);
      addTearDown(session.dispose);
      await session.establish(testTokens);
      expired = true;
      final sync = session.synchronize();
      await refreshing.future;
      final logout = session.logout();
      expect(session.hasSession, isFalse);
      rotationResponse.complete(jsonResponse(tokenJson(rotatedTokens)));
      await Future.wait([sync, logout]);
      expect(logoutBodies, [
        {'refresh_token': 'test-refresh-new'},
      ]);
      expect(session.phase, SessionPhase.signedOut);
      expect(session.notice, 'logout_confirmed');
      expect(SessionRecord.decode(vault.value)!.phase, 'signed_out');
    },
  );

  test(
    'offline logout purges locally and reports unconfirmed remote revocation',
    () async {
      final vault = MemorySessionVault();
      final session = testSession((request) async {
        if (request.url.path == '/api/auth/logout') {
          throw http.ClientException('offline');
        }
        return defaultAuthResponse(request, complete: true);
      }, vault: vault);
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await session.logout();
      expect(session.phase, SessionPhase.signedOut);
      expect(session.notice, 'logout_unconfirmed');
      expect(session.identity, isNull);
      expect(session.consents, isNull);
      expect(vault.value, isNot(contains('test-refresh')));
    },
  );

  test(
    'late reads from a previous account cannot replace a newer session',
    () async {
      final oldMe = Completer<http.Response>();
      var oldPending = false;
      var user = testUser;
      final session = testSession((request) async {
        if (oldPending && request.url.path == '/api/auth/me') {
          return oldMe.future;
        }
        if (request.url.path == '/api/auth/me') {
          return jsonResponse(identityJson(user: user, complete: true));
        }
        return defaultAuthResponse(request, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      oldPending = true;
      final sync = session.synchronize();
      await session.logout();
      oldPending = false;
      user = '22222222-2222-4222-8222-222222222222';
      oldMe.complete(jsonResponse(identityJson(complete: true)));
      await sync;
      await session.establish(testTokens);
      expect(session.identity!.userId, user);
      expect(session.phase, SessionPhase.ready);
    },
  );

  test(
    'a consent version change is displayed before any PUT is sent',
    () async {
      var version = 'v1';
      var puts = 0;
      final session = testSession((request) async {
        if (request.url.path == '/api/users/me/consents') {
          if (request.method == 'PUT') puts++;
          return jsonResponse(consentJson(version: version));
        }
        return defaultAuthResponse(request);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      version = 'v2';
      await expectLater(
        session.saveConsents({ConsentType.terms: true}, consentVersions()),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'legal_documents_changed',
          ),
        ),
      );
      expect(puts, 0);
      expect(session.consents!.consents.first.requiredVersion, 'v2');
    },
  );

  test(
    'consent PUT sends only chosen types and booleans, without client versions',
    () async {
      var complete = false;
      final bodies = <Object?>[];
      final session = testSession((request) async {
        if (request.method == 'PUT') {
          bodies.add(jsonDecode(request.body));
          complete = true;
        }
        return defaultAuthResponse(request, complete: complete);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await session.saveConsents({
        ConsentType.terms: true,
        ConsentType.privacy: true,
      }, consentVersions());
      expect(bodies, [
        {
          'consents': [
            {'consent_type': 'terms_of_service_acceptance', 'granted': true},
            {'consent_type': 'privacy_notice_acknowledgement', 'granted': true},
          ],
        },
      ]);
      expect(session.phase, SessionPhase.ready);
      expect(
        session.consents!.consents
            .where((c) => c.type.withdrawable)
            .every((c) => !c.granted),
        isTrue,
      );
    },
  );

  test(
    'malformed consent projections fail closed instead of inventing choices',
    () {
      final json = consentJson();
      (json['consents'] as List).removeLast();
      expect(() => ConsentState.fromJson(json), throwsA(isA<ApiFailure>()));
      expect(() => ConsentType.parse('marketing'), throwsA(isA<ApiFailure>()));
    },
  );
}
