import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/consents/data/consent_state.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_models.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('majority is based on UTC calendar and validates actual leap dates', () {
    expect(validateBirthdate('2008-10-16', DateTime.utc(2026, 10, 16)), isNull);
    expect(
      validateBirthdate('2008-10-17', DateTime.utc(2026, 10, 16)),
      isNotNull,
    );
    expect(
      validateBirthdate('2008-02-29', DateTime.utc(2026, 2, 28)),
      isNotNull,
    );
    expect(validateBirthdate('2008-02-29', DateTime.utc(2026, 3, 1)), isNull);
    expect(parseBirthdate('2007-02-29'), isNull);
    expect(parseBirthdate('1990-13-01'), isNull);
    expect(parseBirthdate('1990-1-01'), isNull);
    expect(
      validateBirthdate(
        '2008-10-16',
        DateTime.parse('2026-10-16T00:30:00+02:00'),
      ),
      isNotNull,
    );
  });
  test('profile byte limits preserve nullable fields explicitly', () {
    final draft = ProfileDraft(' Camille ', '1995-06-12', null, null);
    expect(draft.toJson(), {
      'firstname': 'Camille',
      'birthdate': '1995-06-12',
      'sex': null,
      'bio': null,
    });
    expect(
      ProfileDraft('é' * 51, '1995-06-12', null, null).validate(DateTime.now()),
      isNotNull,
    );
    expect(
      ProfileDraft(
        'Camille',
        '1995-06-12',
        null,
        'é' * 1001,
      ).validate(DateTime.now()),
      isNotNull,
    );
    expect(OwnerProfile.fromJson(ownerJson(sex: null, bio: null)).sex, isNull);
  });
  test(
    'preferences enforce four fields and integral age and distance bounds',
    () {
      expect(const Preferences(18, 99, 500, 'other').validate(), isNull);
      for (final p in [
        const Preferences(17, 25, 20, 'male'),
        const Preferences(30, 25, 20, 'male'),
        const Preferences(18, 100, 20, 'male'),
        const Preferences(18, 25, 0, 'male'),
        const Preferences(18, 25, 501, 'male'),
        const Preferences(18, 25, 20, ''),
      ]) {
        expect(p.validate(), isNotNull);
      }
      expect(
        () => Preferences.fromJson({...preferencesJson(), 'min_age': 25.5}),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test('answer validation counts Unicode code points and rejects controls and oversized UTF8', () {
    expect(AnswerDraft(questionOne, '😀' * 10).validate(), isNull);
    expect(AnswerDraft(questionOne, '😀' * 251).validate(), isNotNull);
    expect(AnswerDraft(questionOne, 'a' * 301).validate(), isNotNull);
    expect(AnswerDraft(questionOne, 'trop court').validate(), isNull);
    expect(AnswerDraft(questionOne, 'ligne\ninterdite').validate(), isNotNull);
    expect(AnswerDraft(questionOne, '123').validate(), isNotNull);
  });
  test('unknown moderation status and unsafe signed URLs fail closed', () {
    expect(
      () => Moderation.parse('future_status', []),
      throwsA(isA<ApiFailure>()),
    );
    expect(Moderation.parse('rejected', ['future_reason']).reasons, [
      'future_reason',
    ]);
    for (final url in [
      'http://storage.example/photo',
      'https://user:secret@storage.example/photo',
      'data:image/png,abc',
    ]) {
      expect(
        () => OwnerProfile.fromJson(ownerJson(photo: url)),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test(
    'all profile mutations follow Rust field names and answer PUT returns 200',
    () async {
      final writes = <http.Request>[];
      final session = testSession((r) async {
        if (r.method != 'GET') writes.add(r);
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final repo = ProfileRepository(session);
      await repo.saveProfile(
        const ProfileDraft(
          'Camille',
          '1995-06-12',
          'female',
          'Une bio conservée',
        ),
      );
      await repo.savePreferences(const Preferences(25, 38, 40, 'both'));
      await repo.setTrait(traitOne, true);
      await repo.setTrait(traitOne, false);
      await repo.saveAnswers([
        const AnswerDraft(questionTwo, 'La lumière du matin'),
        const AnswerDraft(questionOne, 'Une longue promenade'),
      ]);
      await repo.saveAnswers([]);
      await repo.removePhoto();
      expect(jsonDecode(writes[0].body), {
        'firstname': 'Camille',
        'birthdate': '1995-06-12',
        'sex': 'female',
        'bio': 'Une bio conservée',
      });
      expect(jsonDecode(writes[1].body), {
        'min_age': 25,
        'max_age': 38,
        'max_distance_km': 40,
        'looking_for': 'both',
      });
      expect(jsonDecode(writes[2].body), {'traitId': traitOne});
      expect(writes[3].url.path, '/api/users/me/traits/$traitOne');
      expect(jsonDecode(writes[4].body)['answers'], [
        {'question_id': questionTwo, 'answer': 'La lumière du matin'},
        {'question_id': questionOne, 'answer': 'Une longue promenade'},
      ]);
      expect(jsonDecode(writes[5].body), {'answers': <Object?>[]});
      expect(writes[6].method, 'DELETE');
      expect(
        writes.every(
          (r) =>
              r.headers['authorization'] == 'Bearer ${testTokens.accessToken}',
        ),
        isTrue,
      );
    },
  );
  test('owner resources reject another account and only exact 404 means new profile', () async {
    var mode = 0;
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me') {
        return mode == 0
            ? apiError(404, 'profile_not_found')
            : mode == 1
            ? apiError(404, 'route_not_found')
            : jsonResponse({...ownerJson(), 'user_id': questionOne});
      }
      if (r.url.path == '/api/users/me/preferences') {
        return jsonResponse({...preferencesJson(), 'user_id': questionOne});
      }
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final repo = ProfileRepository(session);
    expect(await repo.profile(RequestCancellation()), isNull);
    mode = 1;
    await expectLater(
      repo.profile(RequestCancellation()),
      throwsA(isA<ApiFailure>()),
    );
    mode = 2;
    await expectLater(
      repo.profile(RequestCancellation()),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      repo.preferences(RequestCancellation()),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('duplicate answers are refused before any HTTP mutation', () async {
    var puts = 0;
    final session = testSession((r) async {
      if (r.method == 'PUT') puts++;
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final a = const AnswerDraft(questionOne, 'Une longue promenade');
    await expectLater(
      ProfileRepository(session).saveAnswers([a, a]),
      throwsA(isA<ApiFailure>()),
    );
    expect(puts, 0);
  });
  test('multipart photo timeout keeps the same key, filename, MIME and bytes for explicit resume', () async {
    final bodies = <String>[];
    final keys = <String?>[];
    var failUpload = true;
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/photo' && r.method == 'PUT') {
        bodies.add(latin1.decode(r.bodyBytes));
        keys.add(r.headers['idempotency-key']);
        expect(r.headers['content-type'], startsWith('multipart/form-data;'));
        if (failUpload) {
          throw TimeoutException('Simulated lost upload response');
        }
      }
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = ProfileController(ProfileRepository(session));
    addTearDown(c.dispose);
    await c.load();
    final source = [255, 216, 255, 1, 2, 3, 4];
    c.setPhoto(source);
    source[3] = 9;
    final key = c.photoIntent!.key;
    await expectLater(c.upload(), throwsA(isA<ApiFailure>()));
    expect(bodies.length, 1);
    expect(c.uncertain, isTrue);
    expect(c.photoIntent!.key, key);
    expect(c.photoIntent!.bytes[3], 1);
    failUpload = false;
    await c.upload();
    expect(keys, [key, key]);
    expect(c.photoIntent, isNull);
    for (final body in bodies) {
      expect(body, contains('name="photo"; filename="photo.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
      expect(body, contains(latin1.decode([255, 216, 255, 1, 2, 3, 4])));
    }
  });
  test(
    'photo input is capped at 500000 and expired intents do not send',
    () async {
      expect(PhotoIntent(List.filled(500000, 1)).bytes.length, 500000);
      expect(
        () => PhotoIntent(List.filled(500001, 1)),
        throwsA(isA<ApiFailure>()),
      );
      final session = testSession((r) async => defaultProfileResponse(r));
      addTearDown(session.dispose);
      await session.establish(testTokens);
      await expectLater(
        ProfileRepository(session).upload(
          PhotoIntent([
            1,
          ], createdAt: DateTime.now().subtract(const Duration(hours: 24))),
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.expired,
          ),
        ),
      );
    },
  );
  test('consumed photo intent is discarded and cannot silently become a new request', () async {
    final session = testSession(
      (r) async => r.url.path == '/api/users/me/photo'
          ? apiError(409, 'idempotency_key_consumed')
          : defaultProfileResponse(r),
    );
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = ProfileController(ProfileRepository(session));
    addTearDown(c.dispose);
    await c.load();
    c.setPhoto([1, 2]);
    await expectLater(c.upload(), throwsA(isA<ApiFailure>()));
    expect(c.photoIntent, isNull);
  });
  test(
    'uncertain mutation requires a read and Retry-After blocks writes',
    () async {
      var fail = true;
      var calls = 0;
      final session = testSession((r) async {
        if (r.method == 'PATCH') {
          calls++;
          if (fail) throw http.ClientException('offline');
          return apiError(429, 'rate_limit_exceeded', retryAfter: '60');
        }
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      const draft = ProfileDraft('Camille', '1995-06-12', null, null);
      await expectLater(
        c.mutate(() => c.repository.saveProfile(draft)),
        throwsA(isA<ApiFailure>()),
      );
      expect(c.canWrite, isFalse);
      expect(calls, 1);
      await c.load();
      expect(c.canWrite, isTrue);
      fail = false;
      await expectLater(
        c.mutate(() => c.repository.saveProfile(draft)),
        throwsA(isA<ApiFailure>()),
      );
      expect(c.retrySeconds, greaterThan(0));
      expect(c.canWrite, isFalse);
    },
  );
  test('sensitive withdrawal purges profile, preferences, photo intent and ignores late owner response', () async {
    var sensitive = true;
    Completer<http.Response>? delayed;
    var holdNext = false;
    final session = testSession((r) async {
      if (r.url.path == '/api/users/me/consents') {
        return jsonResponse(
          consentJson(
            complete: true,
            grants: {ConsentType.sensitive: sensitive},
          ),
        );
      }
      if (r.url.path == '/api/users/me' && holdNext) {
        holdNext = false;
        return delayed!.future;
      }
      if (r.url.path == '/api/users/me' && !sensitive) {
        return jsonResponse(ownerJson(sex: null));
      }
      if (r.url.path == '/api/users/me/preferences' && !sensitive) {
        return apiError(404, 'preferences_not_found');
      }
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = ProfileController(ProfileRepository(session));
    addTearDown(c.dispose);
    await c.load();
    c.setPhoto([1, 2]);
    delayed = Completer<http.Response>();
    holdNext = true;
    final oldRead = c.load();
    sensitive = false;
    await session.saveConsents({
      ConsentType.sensitive: false,
    }, consentVersions());
    expect(c.photoIntent, isNull);
    expect(c.preferences, isNull);
    expect(c.profile, isNull);
    delayed.complete(jsonResponse(ownerJson()));
    await oldRead;
    await Future<void>.delayed(Duration.zero);
    // The synthetic transport ignores cancellation. Neither its stale profile
    // nor a response read under an old consent revision may become accessible.
    expect(c.profile?.sex, isNull);
  });
  test(
    'expired access refreshes photo once using the identical intent',
    () async {
      final keys = <String?>[];
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me/photo') {
          keys.add(r.headers['idempotency-key']);
          if (keys.length == 1) {
            return apiError(401, 'invalid_or_expired_access_token');
          }
          expect(
            r.headers['authorization'],
            'Bearer ${rotatedTokens.accessToken}',
          );
        }
        return defaultProfileResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final intent = PhotoIntent([255, 216, 255, 0]);
      await ProfileRepository(session).upload(intent);
      expect(keys, [intent.key, intent.key]);
    },
  );
  test('transport also rejects oversized multipart before sending', () async {
    var calls = 0;
    final session = testSession((r) async {
      calls++;
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final before = calls;
    await expectLater(
      session.request(
        'PUT',
        '/api/users/me/photo',
        photo: List.filled(500001, 1),
        expectedStatus: 200,
        replayAfterRefresh: true,
      ),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.payloadTooLarge,
        ),
      ),
    );
    expect(calls, before);
  });
  test('logout purges pending photo and every owner resource', () async {
    final session = testSession((r) async => defaultProfileResponse(r));
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = ProfileController(ProfileRepository(session));
    addTearDown(c.dispose);
    await c.load();
    c.setPhoto([1, 2]);
    await session.logout();
    expect(c.profile, isNull);
    expect(c.preferences, isNull);
    expect(c.answers, isEmpty);
    expect(c.traits, isEmpty);
    expect(c.photoIntent, isNull);
    expect(c.canWrite, isFalse);
  });
}
