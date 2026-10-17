import 'package:histae_app/features/privacy/data/private_export_store.dart';
import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'discovery_fixture.dart';

const privacyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherSessionId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const deletionToken = '$privacyId:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
Map<String, Object?> mobileSessionJson({
  String id = privacyId,
  bool current = true,
}) => {
  'id': id,
  'created_at': '2026-10-15T00:00:00Z',
  'last_refreshed_at': '2026-10-16T00:00:00Z',
  'expires_at': '2026-11-16T00:00:00Z',
  'current': current,
};
Map<String, Object?> rightsJson({
  String type = 'access',
  String status = 'pending',
}) => {
  'id': privacyId,
  'user_id': testUser,
  'type': type,
  'status': status,
  'requested_at': '2026-10-16T00:00:00Z',
  'completed_at': null,
  'handled_by': null,
};
http.Response defaultPrivacyResponse(http.Request r, {bool complete = true}) =>
    switch (r.url.path) {
      '/api/auth/sessions' => jsonResponse({
        'sessions': [
          mobileSessionJson(),
          mobileSessionJson(id: otherSessionId, current: false),
        ],
        'next_cursor': null,
      }),
      '/api/users/me/blocks' => jsonResponse({
        'blocks': [
          {
            'user_id': candidateOne,
            'firstname': 'Léa',
            'photo': null,
            'blocked_at': '2026-10-16T00:00:00Z',
          },
        ],
      }),
      '/api/users/me/data-subject-requests' => jsonResponse({
        'requests': [rightsJson()],
      }),
      '/api/users/me/deletion-token' => jsonResponse({
        'confirmation_token': deletionToken,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      }, 201),
      _ => defaultAuthResponse(r, complete: complete),
    };

class PreviewExportStore extends PrivateExportStore {
  int cleanCount = 0;
  @override
  Future<void> clean() async {
    cleanCount++;
  }
}
