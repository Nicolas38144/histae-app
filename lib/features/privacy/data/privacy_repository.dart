import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/read_snapshots.dart';
import '../../auth/domain/authenticated_session.dart';
import 'privacy_models.dart';

abstract interface class PrivacyRepository {
  factory PrivacyRepository(
    AuthenticatedSession session, {
    ReadSnapshots? cache,
  }) = ApiPrivacyRepository;

  AuthenticatedSession get session;

  String get owner;

  Future<SessionPage> sessions(
    RequestCancellation scope, {
    String? cursor,
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<void> revoke(String id, RequestCancellation scope);

  Future<List<BlockedPerson>> blocks(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<void> block(String id, bool blocked, RequestCancellation scope);

  Future<List<RightsRequest>> rights(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<RightsRequest> requestRight(DataRight type, RequestCancellation scope);

  Future<void> report(ReportIntent intent, RequestCancellation scope);

  Future<DeletionTicket> deletionTicket(RequestCancellation scope);
}

final class ApiPrivacyRepository implements PrivacyRepository {
  ApiPrivacyRepository(this.session, {ReadSnapshots? cache})
    : _reads = cache ?? ReadSnapshots();
  final ReadSnapshots _reads;
  String get _scopeKey => '${session.resourceKey}:${session.language.code}';
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
  }) => method == 'GET'
      ? session.request(
          method,
          path,
          body: body,
          expectedStatus: status,
          replayAfterRefresh: true,
          cancellation: scope,
          query: query,
        )
      : _reads.mutate(
          _affected(path),
          () => session.request(
            method,
            path,
            body: body,
            expectedStatus: status,
            replayAfterRefresh: true,
            cancellation: scope,
            query: query,
          ),
        );

  Set<Object> _affected(String path) => switch (path) {
    _ when path.startsWith('/api/auth/sessions') => {DataResource.sessions},
    _ when path.startsWith('/api/users/me/blocks') => {
      DataResource.blocks,
      DataResource.matches,
      DataResource.messages,
    },
    '/api/users/me/data-subject-requests' => {DataResource.rights},
    _ => {},
  };

  @override
  Future<SessionPage> sessions(
    RequestCancellation scope, {
    String? cursor,
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: (DataResource.sessions, cursor),
    policy: policy,
    tags: {DataResource.sessions},
    cancellation: scope,
    fetch: () => _fetchSessions(scope, cursor: cursor),
  );

  Future<SessionPage> _fetchSessions(
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
  Future<List<BlockedPerson>> blocks(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.blocks,
    policy: policy,
    tags: {DataResource.blocks},
    cancellation: scope,
    fetch: () => _fetchBlocks(scope),
  );

  Future<List<BlockedPerson>> _fetchBlocks(RequestCancellation scope) async =>
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
  Future<List<RightsRequest>> rights(
    RequestCancellation scope, {
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: DataResource.rights,
    policy: policy,
    tags: {DataResource.rights},
    cancellation: scope,
    fetch: () => _fetchRights(scope),
  );

  Future<List<RightsRequest>> _fetchRights(RequestCancellation scope) async =>
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
