import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/session_vault.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:http/http.dart' as http;

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
        final saved = SessionRecord.decode(vault.value)!;
        expect(saved.phase, 'refreshing');
        expect(saved.refreshToken, 'test-refresh-old');
        expect(request.headers['Idempotency-Key'], saved.attemptId);
        expect(jsonDecode(request.body), {
          'refresh_token': 'test-refresh-old',
          'recovery_id': saved.attemptId,
        });
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
      'https://api.example',
      'refreshing',
      'test-refresh-old',
    ),
    const SessionRecord(
      'https://different.example',
      'refreshing',
      'test-refresh-old',
      '11111111-1111-4111-8111-111111111111',
    ),
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
    'a lost refresh response resumes the exact sealed attempt after restart',
    () async {
      final vault = MemorySessionVault()
        ..value = const SessionRecord(
          'https://api.example',
          'ready',
          'test-refresh-old',
        ).encode();
      final keys = <String?>[];
      final session = testSession((request) async {
        keys.add(request.headers['Idempotency-Key']);
        throw http.ClientException('Synthetic lost response');
      }, vault: vault);
      addTearDown(session.dispose);
      await session.start();
      expect(session.phase, SessionPhase.unavailable);
      expect(session.hasSession, isTrue);
      expect(session.identity, isNull);
      final saved = SessionRecord.decode(vault.value)!;
      expect(saved.phase, 'refreshing');
      expect(saved.attemptId, keys.single);
      final restarted = testSession((request) async {
        if (request.url.path == '/api/auth/refresh') {
          keys.add(request.headers['Idempotency-Key']);
          expect(jsonDecode(request.body), {
            'refresh_token': testTokens.refreshToken,
            'recovery_id': saved.attemptId,
          });
        }
        return defaultAuthResponse(request, complete: true);
      }, vault: vault);
      addTearDown(restarted.dispose);
      await restarted.start();
      expect(restarted.phase, SessionPhase.ready);
      expect(keys, [saved.attemptId, saved.attemptId]);
      expect(SessionRecord.decode(vault.value)!.attemptId, isNull);
      expect(
        SessionRecord.decode(vault.value)!.refreshToken,
        rotatedTokens.refreshToken,
      );
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

  test('temporary and unsupported-server failures keep the same attempt until explicit retry', () async {
    for (final response in [
      apiError(503, 'service_unavailable'),
      apiError(429, 'refresh_rate_limit_exceeded', retryAfter: '60'),
      apiError(400, 'invalid_request_body'),
    ]) {
      final vault = MemorySessionVault()
        ..value = const SessionRecord(
          'https://api.example',
          'ready',
          'test-refresh-old',
        ).encode();
      var recovering = false;
      var refreshes = 0;
      final keys = <String?>[];
      final session = testSession((r) async {
        if (r.url.path == '/api/auth/refresh') {
          refreshes++;
          keys.add(r.headers['Idempotency-Key']);
          if (!recovering) return response;
        }
        return defaultAuthResponse(r, complete: true);
      }, vault: vault);
      await session.start();
      expect(session.phase, SessionPhase.unavailable);
      expect(session.hasSession, isTrue);
      expect(session.identity, isNull);
      final saved = vault.value;
      if (response.statusCode == 429) {
        await session.synchronize();
        expect(refreshes, 1);
        expect(vault.value, saved);
        // A restart does not create a different attempt key.
        session.dispose();
        final resumed = testSession((r) async {
          if (r.url.path == '/api/auth/refresh') {
            keys.add(r.headers['Idempotency-Key']);
          }
          return defaultAuthResponse(r, complete: true);
        }, vault: vault);
        await resumed.start();
        expect(resumed.phase, SessionPhase.ready);
        resumed.dispose();
      } else {
        recovering = true;
        await session.synchronize();
        expect(session.phase, SessionPhase.ready);
        session.dispose();
      }
      expect(keys.length, 2);
      expect(keys.last, keys.first);
    }
  });

  test('a definitive rejection clears the recovery credential and never retries it', () async {
    final vault = MemorySessionVault()
      ..value = const SessionRecord(
        'https://api.example',
        'refreshing',
        'test-refresh-old',
        '11111111-1111-4111-8111-111111111111',
      ).encode();
    var calls = 0;
    final session = testSession((r) async {
      calls++;
      return apiError(401, 'invalid_or_expired_refresh_token');
    }, vault: vault);
    await session.start();
    expect(session.phase, SessionPhase.signedOut);
    expect(session.hasSession, isFalse);
    expect(vault.value, isNot(contains('test-refresh-old')));
    await session.synchronize();
    expect(calls, 1);
    session.dispose();
  });

  test('logout discards an unresolved attempt and a late refresh cannot resurrect it', () async {
    final vault = MemorySessionVault()
      ..value = const SessionRecord(
        'https://api.example',
        'ready',
        'test-refresh-old',
      ).encode();
    final reply = Completer<http.Response>();
    final started = Completer<void>();
    final session = testSession((r) async {
      if (r.url.path == '/api/auth/refresh') {
        started.complete();
        return reply.future;
      }
      return defaultAuthResponse(r, complete: true);
    }, vault: vault);
    final restoring = session.start();
    await started.future;
    final closing = session.logout();
    reply.complete(jsonResponse(tokenJson(rotatedTokens)));
    await Future.wait([restoring, closing]);
    expect(session.phase, SessionPhase.signedOut);
    expect(session.hasPendingRefresh, isFalse);
    expect(SessionRecord.decode(vault.value)!.phase, 'signed_out');
    session.dispose();
  });

  test(
    'a replacement storage failure never publishes the new access token',
    () async {
      var expired = false;
      var failedStorage = false;
      var newTokenReads = 0;
      final vault = MemorySessionVault();
      final session = testSession((request) async {
        if (request.headers['Authorization'] == 'Bearer test-access-new') {
          newTokenReads++;
        }
        if (request.url.path == '/api/auth/refresh') {
          if (!failedStorage) {
            vault.failNextReady = true;
            failedStorage = true;
          }
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
      expect(session.hasSession, isTrue);
      expect(newTokenReads, 0);
      expect(SessionRecord.decode(vault.value)!.phase, 'refreshing');
      expired = false;
      await session.synchronize();
      expect(session.phase, SessionPhase.ready);
      expect(SessionRecord.decode(vault.value)!.phase, 'ready');
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
      expect(session.notice, isNull);
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
