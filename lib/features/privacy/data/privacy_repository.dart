import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/data/profile_models.dart';
import 'privacy_models.dart';

class PrivacyRepository {
  PrivacyRepository(this.session);
  final SessionController session;
  String get owner => session.identity?.userId ?? invalidProfile();
  Future<Object?> _request(
    String method,
    String path,
    RequestCancellation scope, {
    Object? body,
    int status = 200,
    Map<String, String>? query,
  }) => session.request(
    method,
    path,
    body: body,
    expectedStatus: status,
    replayAfterRefresh: true,
    cancellation: scope,
    query: query,
  );
  Future<SessionPage> sessions(
    RequestCancellation scope, {
    String? cursor,
  }) async => SessionPage(
    jsonObject(
      await _request(
        'GET',
        '/api/auth/sessions',
        scope,
        query: {'limit': '20', 'cursor': ?cursor},
      ),
    ),
  );
  Future<void> revoke(String id, RequestCancellation scope) async {
    serverId({'id': id}, 'id');
    await _request('DELETE', '/api/auth/sessions/$id', scope, status: 204);
  }

  Future<List<BlockedPerson>> blocks(RequestCancellation scope) async =>
      List.unmodifiable(
        jsonField<List<dynamic>>(
          jsonObject(await _request('GET', '/api/users/me/blocks', scope)),
          'blocks',
        ).map(BlockedPerson.fromJson),
      );
  Future<void> block(String id, bool blocked, RequestCancellation scope) async {
    serverId({'id': id}, 'id');
    await _request(
      blocked ? 'POST' : 'DELETE',
      '/api/users/me/blocks/$id',
      scope,
      status: 204,
    );
  }

  Future<List<RightsRequest>> rights(RequestCancellation scope) async =>
      List.unmodifiable(
        jsonField<List<dynamic>>(
          jsonObject(
            await _request('GET', '/api/users/me/data-subject-requests', scope),
          ),
          'requests',
        ).map((v) => RightsRequest.fromJson(v, owner)),
      );
  Future<RightsRequest> requestRight(
    DataRight type,
    RequestCancellation scope,
  ) async => RightsRequest.fromJson(
    await _request(
      'POST',
      '/api/users/me/data-subject-requests',
      scope,
      body: {'type': type.name},
      status: 201,
    ),
    owner,
  );
  Future<void> report(ReportIntent intent, RequestCancellation scope) async {
    if (intent.target == owner || validateReport(intent.description) != null) {
      invalidProfile();
    }
    final j = jsonObject(
      await _request(
        'POST',
        '/api/reports',
        scope,
        body: intent.body,
        status: 201,
      ),
    );
    if (serverId(j, 'reporter_id') != owner ||
        serverId(j, 'reported_id') != intent.target ||
        j['reason'] != intent.reason.wire ||
        optionalText(j, 'match_id') != intent.matchId ||
        !['pending', 'reviewed', 'dismissed'].contains(j['status'])) {
      invalidProfile();
    }
    serverId(j, 'id');
  }

  Future<DeletionTicket> deletionTicket(RequestCancellation scope) async =>
      DeletionTicket.fromJson(
        await _request(
          'POST',
          '/api/users/me/deletion-token',
          scope,
          status: 201,
        ),
      );
}
