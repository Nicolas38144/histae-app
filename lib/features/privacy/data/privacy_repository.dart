import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';
import 'privacy_models.dart';

abstract interface class PrivacyRepository {
  factory PrivacyRepository(AuthenticatedSession session) =
      ApiPrivacyRepository;
  AuthenticatedSession get session;
  String get owner;
  Future<SessionPage> sessions(RequestCancellation scope, {String? cursor});
  Future<void> revoke(String id, RequestCancellation scope);
  Future<List<BlockedPerson>> blocks(RequestCancellation scope);
  Future<void> block(String id, bool blocked, RequestCancellation scope);
  Future<List<RightsRequest>> rights(RequestCancellation scope);
  Future<RightsRequest> requestRight(DataRight type, RequestCancellation scope);
  Future<void> report(ReportIntent intent, RequestCancellation scope);
  Future<DeletionTicket> deletionTicket(RequestCancellation scope);
}

final class ApiPrivacyRepository implements PrivacyRepository {
  ApiPrivacyRepository(this.session);
  @override
  final AuthenticatedSession session;
  @override
  String get owner => session.identity?.userId ?? invalidResponse();
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
  @override
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
  @override
  Future<void> revoke(String id, RequestCancellation scope) async {
    serverId({'id': id}, 'id');
    await _request('DELETE', '/api/auth/sessions/$id', scope, status: 204);
  }

  @override
  Future<List<BlockedPerson>> blocks(RequestCancellation scope) async =>
      List.unmodifiable(
        jsonField<List<dynamic>>(
          jsonObject(await _request('GET', '/api/users/me/blocks', scope)),
          'blocks',
        ).map(BlockedPerson.fromJson),
      );
  @override
  Future<void> block(String id, bool blocked, RequestCancellation scope) async {
    serverId({'id': id}, 'id');
    await _request(
      blocked ? 'POST' : 'DELETE',
      '/api/users/me/blocks/$id',
      scope,
      status: 204,
    );
  }

  @override
  Future<List<RightsRequest>> rights(RequestCancellation scope) async =>
      List.unmodifiable(
        jsonField<List<dynamic>>(
          jsonObject(
            await _request('GET', '/api/users/me/data-subject-requests', scope),
          ),
          'requests',
        ).map((v) => RightsRequest.fromJson(v, owner)),
      );
  @override
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
  @override
  Future<void> report(ReportIntent intent, RequestCancellation scope) async {
    if (intent.target == owner || validateReport(intent.description) != null) {
      invalidResponse();
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
      invalidResponse();
    }
    serverId(j, 'id');
  }

  @override
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
