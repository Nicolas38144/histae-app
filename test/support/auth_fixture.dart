import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:histae_app/core/l10n/api_language.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/auth/application/session_controller.dart';
import 'package:histae_app/features/auth/data/auth_repository.dart';
import 'package:histae_app/features/auth/data/session_vault.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Synthetic, test-only credentials; no real SMS or production account is used.
const testTokens = TokenPair('test-access-old', 'test-refresh-old');
const rotatedTokens = TokenPair('test-access-new', 'test-refresh-new');
const testUser = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> tokenJson(TokenPair tokens) => {
  'access_token': tokens.accessToken,
  'refresh_token': tokens.refreshToken,
};
Map<String, dynamic> identityJson({
  bool complete = false,
  String user = testUser,
}) => {'user_id': user, 'onboarding_complete': complete};

Map<String, dynamic> consentJson({
  bool complete = false,
  Map<ConsentType, bool> grants = const {},
  String version = 'v1',
}) => {
  'consents': [
    for (final type in ConsentType.values)
      {
        'consent_type': type.wireName,
        'granted': grants[type] ?? (complete && !type.withdrawable),
        if (grants[type] ?? (complete && !type.withdrawable)) ...{
          'document_version': version,
          'updated_at': '2026-10-16T00:00:00Z',
        },
        'required_document_version': version,
        'document_url': 'https://legal.example/${type.name}/$version',
        'document_language': 'fr',
      },
  ],
  'onboarding_complete': complete,
  'required_actions': complete
      ? <Object?>[]
      : [ConsentType.terms.wireName, ConsentType.privacy.wireName],
};
Map<ConsentType, String> consentVersions([String version = 'v1']) => {
  for (final type in ConsentType.values) type: version,
};

http.Response jsonResponse(
  Object? body, [
  int status = 200,
  Map<String, String>? headers,
]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', ...?headers},
);
http.Response apiError(int status, String code, {String? retryAfter}) =>
    jsonResponse(
      {
        'error': {
          'code': code,
          'message': 'Do not display this English message.',
        },
      },
      status,
      {'retry-after': ?retryAfter},
    );

class MemorySessionVault implements SessionVault {
  String? value;
  final writes = <String>[];
  bool failWrites = false;
  bool failRead = false;
  bool failNextReady = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Test secure storage is locked');
    return value;
  }

  @override
  Future<void> write(String next) async {
    if (failWrites ||
        (failNextReady && SessionRecord.decode(next)?.phase == 'ready')) {
      failNextReady = false;
      throw StateError('Test storage write failed');
    }
    value = next;
    writes.add(next);
  }
}

SessionController testSession(
  Future<http.Response> Function(http.Request request) handle, {
  MemorySessionVault? vault,
  ApiLanguage Function()? language,
  Listenable? languageChanges,
}) => SessionController(
  AuthRepository(
    ApiClient(
      origin: Uri.parse('https://api.example'),
      client: MockClient(handle),
      language: language,
    ),
  ),
  vault ?? MemorySessionVault(),
  languageChanges: languageChanges,
);

http.Response defaultAuthResponse(
  http.Request request, {
  bool complete = false,
}) => switch (request.url.path) {
  '/api/users/me/language' => jsonResponse({'language': 'fr'}),
  '/api/auth/me' => jsonResponse(identityJson(complete: complete)),
  '/api/users/me/consents' => jsonResponse(consentJson(complete: complete)),
  '/api/auth/otp/send' => jsonResponse({'message': 'accepted'}, 202),
  '/api/auth/otp/verify' => jsonResponse(tokenJson(testTokens)),
  '/api/auth/refresh' => jsonResponse(tokenJson(rotatedTokens)),
  '/api/auth/logout' => http.Response('', 204),
  _ => apiError(404, 'route_not_found'),
};
