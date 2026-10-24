import 'dart:convert';

import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'profile_fixture.dart';

class RegistrationFixture {
  final requests = <http.Request>[];
  final grants = <ConsentType, bool>{};
  String version = 'v1';
  bool complete = false;
  bool losePreferencesResponse = false;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? preferences;

  Iterable<http.Request> get writes =>
      requests.where((request) => ['PATCH', 'PUT'].contains(request.method));

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/api/legal/documents':
        return jsonResponse({
          'documents': [
            for (final type in ConsentType.values)
              {
                'consent_type': type.wireName,
                'required_document_version': version,
                'document_url': 'https://legal.example/${type.name}/$version',
                'document_language': 'fr',
              },
          ],
        });
      case '/api/users/me/consents':
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          for (final change in body['consents'] as List) {
            grants[ConsentType.parse(change['consent_type'] as String)] =
                change['granted'] as bool;
          }
          complete =
              grants[ConsentType.terms] == true &&
              grants[ConsentType.privacy] == true;
        }
        return jsonResponse(
          consentJson(complete: complete, grants: grants, version: version),
        );
      case '/api/users/me':
        return profile == null
            ? apiError(404, 'profile_not_found')
            : jsonResponse(profile);
      case '/api/users/me/profile':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        profile = {...ownerJson(), ...body};
        return jsonResponse({'message': 'profile updated'});
      case '/api/users/me/preferences':
        if (request.method == 'PATCH') {
          preferences = {
            'user_id': testUser,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          };
          if (losePreferencesResponse) {
            losePreferencesResponse = false;
            return apiError(503, 'temporarily_unavailable');
          }
          return jsonResponse({'message': 'preferences updated'});
        }
        return preferences == null
            ? apiError(404, 'preferences_not_found')
            : jsonResponse(preferences);
      case '/api/auth/me':
        return jsonResponse(identityJson(complete: complete));
      default:
        return defaultAuthResponse(request, complete: complete);
    }
  }
}
