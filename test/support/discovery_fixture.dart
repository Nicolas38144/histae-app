import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/consents/domain/consent_state.dart';
import 'package:histae_app/features/discovery/data/device_location.dart';
import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'profile_fixture.dart';

const candidateOne = questionOne;
const candidateTwo = questionTwo;
const candidateThree = traitOne;
Map<String, dynamic> discoveryStatusJson({
  bool ready = true,
  DateTime? expiresAt,
}) => {
  'ready': ready,
  'required_actions': ready ? <Object?>[] : ['fresh_presence'],
  'presence_expires_at':
      (expiresAt ??
              (ready
                  ? DateTime.now().toUtc().add(const Duration(minutes: 30))
                  : null))
          ?.toIso8601String(),
};
Map<String, dynamic> candidateJson(
  String id, {
  String name = 'Léa',
  String? bio = 'Les conversations qui prennent leur temps, les librairies et les détours imprévus.',
}) => {
  'user_id': id,
  'firstname': name,
  'age': 27,
  'sex': 'female',
  'bio': bio,
  'distance_km': 3.2,
  'traits': ['Curieuse', 'Attentionnée', 'Contemplative'],
  'profile_answers': [
    {
      'question_id': questionOne,
      'code': 'sunday',
      'question': 'Votre dimanche idéal ?',
      'answer': 'Un café, un livre et une promenade sans itinéraire.',
      'position': 0,
    },
  ],
};
Map<String, dynamic> matchJson(String target) => {
  'id': '55555555-5555-4555-8555-555555555555',
  'user1_id': testUser,
  'user2_id': target,
  'status': 'active',
  'created_at': '2026-10-16T12:00:00Z',
  'expires_at': '2026-10-17T12:00:00Z',
};
http.Response defaultDiscoveryResponse(http.Request r) => switch (r.url.path) {
  '/api/users/me/consents' => jsonResponse(
    consentJson(
      complete: true,
      grants: {ConsentType.sensitive: true, ConsentType.location: true},
    ),
  ),
  '/api/users/me/discovery-status' => jsonResponse(discoveryStatusJson()),
  '/api/feed' => jsonResponse({
    'profiles': [
      candidateJson(candidateOne),
      candidateJson(candidateTwo, name: 'Camille'),
    ],
    'next_cursor': null,
  }),
  '/api/swipes' => jsonResponse({'decision': 'pass', 'matched': false}, 201),
  '/api/users/me/presence' => jsonResponse({'message': 'presence updated'}),
  _ when r.url.path.startsWith('/api/users/me/blocks/') => http.Response(
    '',
    204,
  ),
  _ => defaultProfileResponse(r),
};

class TestLocationSource implements LocationSource {
  int calls = 0;
  RequestCancellation? scope;
  Future<LocationFix> Function()? handler;
  @override
  Future<LocationFix> locate(RequestCancellation cancellation) async {
    calls++;
    scope = cancellation;
    return handler == null
        ? LocationFix(48.85, 2.35, DateTime.now(), approximate: true)
        : await handler!();
  }

  @override
  Future<bool> openSettings({required bool services}) async => true;
}
