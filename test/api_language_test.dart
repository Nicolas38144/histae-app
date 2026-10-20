import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/account_language_binding.dart';
import 'package:histae_app/core/l10n/api_language.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/auth/application/otp_controller.dart';
import 'package:histae_app/features/billing/data/billing_models.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/data/checkout_vault.dart';
import 'package:histae_app/features/catalog/application/catalog_controller.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/language/data/language_repository.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/catalog_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';
import 'support/profile_fixture.dart';

class LanguageMemoryStore implements LocalePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String language) async { value = language; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses exact supported codes and a dynamic header for JSON and multipart', () async {
    var language = ApiLanguage.fr;
    final sent = <String?>[];
    final api = ApiClient(origin: Uri.parse('https://api.example'),
      language: () => language, client: MockClient((request) async {
        sent.add(request.headers['Accept-Language']);
        expect(request.followRedirects, isFalse);
        return jsonResponse({});
      }));
    addTearDown(api.close);
    for (final value in ApiLanguage.values) {
      language = value;
      await api.getJson('/api/plans');
    }
    await api.requestJson('POST', '/api/users/me/photo', photo: [1, 2, 3],
      bearer: testTokens.accessToken, language: ApiLanguage.es);
    expect(sent, ['fr', 'en', 'es', 'it', 'es']);
    expect(ApiLanguage.tryParse('en-US'), isNull);
    expect(ApiLanguage.tryParse('fr,evil'), isNull);
  });

  test('pins language when a definitive expired-access rejection is refreshed', () async {
    var language = ApiLanguage.it;
    final headers = <String?>[];
    final session = testSession((request) async {
      if (request.url.path == '/api/language-probe') {
        headers.add(request.headers['Accept-Language']);
        if (headers.length == 1) {
          language = ApiLanguage.en;
          return apiError(401, 'invalid_or_expired_access_token');
        }
        return jsonResponse({});
      }
      return defaultAuthResponse(request, complete: true);
    }, language: () => language);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    await session.request('GET', '/api/language-probe', expectedStatus: 200,
      replayAfterRefresh: true);
    expect(headers, ['it', 'it']);
  });

  test('technical OTP resume retains language and UUID; explicit resend captures the new choice', () async {
    var language = ApiLanguage.it;
    final headers = <String?>[], keys = <String?>[];
    final session = testSession((request) async {
      headers.add(request.headers['Accept-Language']);
      keys.add(request.headers['Idempotency-Key']);
      expect(jsonDecode(request.body), {'phone_number': '+33612345678'});
      return headers.length == 1 ? apiError(503, 'otp_delivery_unknown')
          : jsonResponse({'message': 'accepted'}, 202);
    }, language: () => language);
    addTearDown(session.dispose);
    final otp = OtpController(session);
    addTearDown(otp.dispose);
    await otp.send('+33612345678');
    language = ApiLanguage.en;
    await otp.send('+33612345678', newIntention: false);
    await otp.send('+33612345678');
    expect(headers, ['it', 'it', 'en']);
    expect(keys[0], keys[1]);
    expect(keys[2], isNot(keys[1]));
  });

  test('persists Checkout locale with its immutable intent, including legacy records', () async {
    final intent = CheckoutAttempt.create('https://api.example', testUser,
      BillingPeriod.annual, language: ApiLanguage.es);
    final restored = CheckoutAttempt.decode(intent.encode())!;
    expect(restored.language, ApiLanguage.es);
    expect(restored.key, intent.key);
    final legacy = jsonDecode(intent.encode()) as Map<String, dynamic>;
    legacy.remove('language');
    expect(CheckoutAttempt.decode(jsonEncode(legacy))!.language, isNull);
    expect(() => CheckoutAttempt.decode(jsonEncode({...legacy, 'language': 'xx'})),
      throwsA(isA<ApiFailure>()));
    var language = ApiLanguage.it;
    final session = testSession((request) async {
      if (request.url.path.endsWith('/subscription/checkout')) {
        expect(request.headers['Accept-Language'], 'es');
        expect(request.headers['Idempotency-Key'], intent.key);
        expect(jsonDecode(request.body), {'billing_period': 'annual'});
        return jsonResponse({'session_id': 'synthetic-checkout',
          'url': 'https://checkout.stripe.com/c/pay/synthetic',
          'expires_at': '2099-01-01T00:00:00Z'}, 201);
      }
      return defaultAuthResponse(request, complete: true);
    }, language: () => language);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    language = ApiLanguage.en;
    await BillingRepository(session).checkout(restored, RequestCancellation());
  });

  test('models device overrides and explicit null to follow the account', () {
    expect(DeviceRegistration(syntheticRegistration, 'android', null,
      language: ApiLanguage.it).body['language'], 'it');
    final followAccount = DeviceRegistration(syntheticRegistration, 'android', null).body;
    expect(followAccount.containsKey('language'), isTrue);
    expect(followAccount['language'], isNull);
    expect(PushDevice.fromJson({...deviceJson(), 'language': 'es'}).language, ApiLanguage.es);
    expect(() => PushDevice.fromJson({...deviceJson(), 'language': 'xx'}),
      throwsA(isA<ApiFailure>()));
  });

  test('refreshes an opted-in device locale without asking for permission again', () async {
    final language = ValueNotifier(ApiLanguage.it);
    addTearDown(language.dispose);
    final bodies = <Map<String, dynamic>>[];
    final session = testSession((request) async {
      if (request.url.path == '/api/users/me/devices' && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        return jsonResponse({...deviceJson(), 'language': body['language']}, 201);
      }
      return defaultNotificationsResponse(request);
    }, language: () => language.value);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final gateway = FakePushGateway();
    addTearDown(gateway.close);
    final push = PushController(DeviceRepository(session), gateway, MemoryPushVault(),
      appVersion: () async => '1.0.0', language: () => language.value,
      languageChanges: language);
    addTearDown(push.dispose);
    await push.start();
    await pumpEventQueue();
    await push.enable();
    final requests = gateway.requests;
    language.value = ApiLanguage.es;
    await pumpEventQueue();
    expect(bodies.map((body) => body['language']), ['it', 'es']);
    expect(gateway.requests, requests);
  });

  test('keeps document language distinct from the historical acceptance language', () {
    final json = (consentJson()['consents'] as List<dynamic>).first as Map<String, dynamic>;
    final consent = PublicConsent.fromJson({...json, 'document_language': 'fr',
      'accepted_document_language': 'it'});
    expect(consent.documentLanguage, ApiLanguage.fr);
    expect(consent.acceptedDocumentLanguage, ApiLanguage.it);
    expect(() => PublicConsent.fromJson({...json, 'document_language': 'xx'}),
      throwsA(isA<ApiFailure>()));
  });

  test('refuses consent to a different URL/language even with the same legal version', () async {
    var changed = false;
    var puts = 0;
    final session = testSession((request) async {
      if (request.url.path == '/api/users/me/consents') {
        if (request.method == 'PUT') puts++;
        final data = consentJson();
        if (changed) {
          for (final value in data['consents'] as List<dynamic>) {
            final document = value as Map<String, dynamic>;
            document['document_language'] = 'en';
            document['document_url'] = '${document['document_url']}/en';
          }
        }
        return jsonResponse(data);
      }
      return defaultAuthResponse(request);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final shown = {for (final c in session.consents!.consents) c.type: c};
    changed = true;
    await expectLater(session.saveConsents({ConsentType.terms: true}, consentVersions(),
      displayedDocuments: shown), throwsA(isA<ApiFailure>().having((e) => e.code,
        'code', 'legal_documents_changed')));
    expect(puts, 0);
  });

  test('adopts the account only without a device choice and writes explicit connected selections', () async {
    final locale = LocaleController(store: LanguageMemoryStore());
    addTearDown(locale.dispose);
    await locale.restore();
    final writes = <Object?>[];
    final session = testSession((request) async {
      if (request.url.path == '/api/users/me/language') {
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body);
          writes.add(body);
          return jsonResponse(body);
        }
        return jsonResponse({'language': 'it'});
      }
      return defaultAuthResponse(request, complete: true);
    }, language: () => locale.apiLanguage, languageChanges: locale);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final key = session.resourceKey;
    final binding = AccountLanguageBinding(locale, session);
    addTearDown(binding.dispose);
    await pumpEventQueue();
    expect(locale.language, 'it');
    expect(writes, isEmpty);
    await locale.select('es');
    await pumpEventQueue();
    expect(writes, [{'language': 'es'}]);
    expect(session.resourceKey, key);
    locale.useAccountLanguage(ApiLanguage.en);
    expect(locale.language, 'es');
  });

  test('late account language cannot repopulate a signed-out session', () async {
    final locale = LocaleController();
    addTearDown(locale.dispose);
    final pending = Completer<http.Response>();
    final session = testSession((request) {
      if (request.url.path == '/api/users/me/language') return pending.future;
      return Future.value(defaultAuthResponse(request, complete: true));
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final binding = AccountLanguageBinding(locale, session);
    addTearDown(binding.dispose);
    await session.logout();
    pending.complete(jsonResponse({'language': 'it'}));
    await pumpEventQueue();
    expect(locale.language, 'fr');
    expect(locale.onSelected, isNull);
  });

  test('catalogue ignores an older language response and reloads the current projection', () async {
    final language = ValueNotifier(ApiLanguage.it);
    addTearDown(language.dispose);
    final first = Completer<http.Response>();
    final repository = CatalogRepository(ApiClient(origin: Uri.parse('https://api.example'),
      language: () => language.value, client: MockClient((request) async {
        if (request.headers['Accept-Language'] == 'it') return first.future;
        final data = catalogJson();
        ((data['offers'] as List<dynamic>).first as Map<String, dynamic>)['display_name'] = 'English offer';
        return jsonResponse(data);
      })), languageChanges: language);
    addTearDown(repository.close);
    final controller = CatalogController(repository);
    addTearDown(controller.dispose);
    final old = controller.load();
    await pumpEventQueue();
    language.value = ApiLanguage.en;
    await pumpEventQueue();
    first.complete(jsonResponse(catalogJson()));
    await old;
    await pumpEventQueue();
    expect(controller.offers.first.displayName, 'English offer');
  });

  test('profile and match language reloads keep the account boundary and chat drafts', () async {
    final language = ValueNotifier(ApiLanguage.fr);
    addTearDown(language.dispose);
    final session = testSession((request) async {
      if (request.url.path == '/api/users/me/language') {
        return jsonResponse({'language': request.headers['Accept-Language']});
      }
      return defaultProfileResponse(request);
    }, language: () => language.value, languageChanges: language);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final profile = ProfileController(ProfileRepository(session));
    addTearDown(profile.dispose);
    final matches = MatchesController(MatchesRepository(session), realtime: QuietRealtime(session));
    addTearDown(matches.dispose);
    matches.setDraft('22222222-2222-4222-8222-222222222222', 'My private draft');
    await profile.load();
    final key = session.resourceKey;
    language.value = ApiLanguage.it;
    await pumpEventQueue();
    expect(session.resourceKey, key);
    expect(profile.profile, isNotNull);
    expect(matches.draftFor('22222222-2222-4222-8222-222222222222'), 'My private draft');
  });

  test('account preference rejects malformed server codes', () async {
    final session = testSession((request) async {
      if (request.url.path == '/api/users/me/language') return jsonResponse({'language': 'xx'});
      return defaultAuthResponse(request, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    await expectLater(LanguageRepository(session).read(RequestCancellation()), throwsA(isA<ApiFailure>()));
  });

  test('a failed localized consent read keeps the session and resource boundary', () async {
    final language = ValueNotifier(ApiLanguage.fr);
    addTearDown(language.dispose);
    final session = testSession((request) async {
      if (language.value == ApiLanguage.it && request.url.path == '/api/users/me/consents') {
        throw http.ClientException('Synthetic offline transport');
      }
      return defaultAuthResponse(request, complete: true);
    }, language: () => language.value, languageChanges: language);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final key = session.resourceKey, phase = session.phase;
    language.value = ApiLanguage.it;
    await pumpEventQueue();
    expect(session.hasSession, isTrue);
    expect(session.phase, phase);
    expect(session.resourceKey, key);
    expect(session.failure?.kind, ApiFailureKind.network);
    expect(session.isSynchronizing, isFalse);
  });

  test('failed account persistence preserves the local choice and reports it', () async {
    final store = LanguageMemoryStore();
    final locale = LocaleController(store: store);
    addTearDown(locale.dispose);
    locale.onSelected = (_) async { throw const ApiFailure(ApiFailureKind.unavailable); };
    await locale.select('it');
    expect(locale.language, 'it');
    expect(store.value, 'it');
    expect(locale.saveFailed, isTrue);
    expect(locale.saving, isFalse);
  });

  test('account language writes respect Retry-After across new local selections', () async {
    final locale = LocaleController();
    addTearDown(locale.dispose);
    var writes = 0;
    final session = testSession((request) async {
      if (request.url.path == '/api/users/me/language') {
        if (request.method == 'PATCH') {
          writes++;
          return apiError(429, 'language_settings_rate_limit_exceeded', retryAfter: '60');
        }
        return jsonResponse({'language': 'fr'});
      }
      return defaultAuthResponse(request, complete: true);
    }, language: () => locale.apiLanguage, languageChanges: locale);
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final binding = AccountLanguageBinding(locale, session);
    addTearDown(binding.dispose);
    await pumpEventQueue();
    await locale.select('es');
    await locale.select('it');
    expect(writes, 1);
    expect(locale.language, 'it');
    expect(locale.saveFailed, isTrue);
  });

}
