import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:http/http.dart' as http;

import 'auth_fixture.dart';
import 'discovery_fixture.dart';

const testMatch = '55555555-5555-4555-8555-555555555555';
const secondMatch = '66666666-6666-4666-8666-666666666666';
const incomingId = '77777777-7777-4777-8777-777777777777';
const outgoingId = '88888888-8888-4888-8888-888888888888';

Map<String, dynamic> messageJson({
  String id = incomingId,
  String match = testMatch,
  String sender = candidateOne,
  String content = 'Et si on parlait de nos lectures ?',
  String? readAt,
}) => {
  'id': id,
  'match_id': match,
  'sender_id': sender,
  'content': content,
  'created_at': '2026-10-16T12:00:00.123456Z',
  'read_at': readAt,
};
Map<String, dynamic> publicMatchJson({
  String id = testMatch,
  String status = 'active',
  DateTime? expiresAt,
}) => {
  'id': id,
  'status': status,
  'created_at': '2026-10-16T10:00:00Z',
  'expires_at':
      (expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 12)))
          .toUtc()
          .toIso8601String(),
  'other_user': {...candidateJson(candidateOne), 'photo': null},
  'my_revealed': false,
  'photos_revealed': false,
  'my_continued': false,
  'unread_count': 1,
  'last_message': messageJson(match: id),
};
http.Response defaultMatchesResponse(http.Request r) => switch (r.url.path) {
  '/api/matches/me' => jsonResponse({
    'matches': [publicMatchJson()],
    'next_cursor': null,
  }),
  '/api/matches/$testMatch/messages' => jsonResponse({
    'messages': [messageJson()],
    'next_cursor': null,
  }),
  '/api/matches/$testMatch/messages/read' => jsonResponse({
    'updated_count': 1,
    'read_through_message_id': incomingId,
  }),
  '/api/users/me/events' => http.Response(
    'event: connected\ndata: {"server_time":"${DateTime.now().toUtc().toIso8601String()}"}\n\n',
    200,
    headers: {'content-type': 'text/event-stream'},
  ),
  _ => defaultDiscoveryResponse(r),
};

// Controller tests drive signals explicitly. Network/stream tests use the real
// RealtimeClient separately, with no production credentials or SMS.
class QuietRealtime extends RealtimeClient {
  QuietRealtime(super.session);
  @override
  void start() {}
  @override
  void stop() {}
  void emit(MobileSignal signal) => onSignal?.call(signal);
}
