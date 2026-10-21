import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/read_snapshots.dart';
import '../../auth/domain/authenticated_session.dart';
import 'match_models.dart';

abstract interface class MatchesRepository {
  factory MatchesRepository(
    AuthenticatedSession session, {
    ReadSnapshots? cache,
  }) = ApiMatchesRepository;

  AuthenticatedSession get session;

  String get owner;
  DateTime? get matchesReadAt;
  void invalidate({String? matchId});

  Future<MatchPage> matches(
    RequestCancellation scope, {
    String? cursor,
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<MessagePage> messages(
    UserMatch match,
    RequestCancellation scope, {
    String? cursor,
    ReadPolicy policy = ReadPolicy.refresh,
  });

  Future<ChatMessage> send(
    UserMatch match,
    MessageIntent intent,
    RequestCancellation scope,
  );

  Future<void> readThrough(
    String id,
    String messageId,
    RequestCancellation scope,
  );

  Future<void> readOne(String id, String messageId, RequestCancellation scope);

  Future<void> end(String id, RequestCancellation scope);

  Future<void> block(String partnerId, RequestCancellation scope);
}

final class ApiMatchesRepository implements MatchesRepository {
  ApiMatchesRepository(this.session, {ReadSnapshots? cache})
    : _reads = cache ?? ReadSnapshots();
  final ReadSnapshots _reads;
  String get _scopeKey => '${session.resourceKey}:${session.language.code}';
  @override
  final AuthenticatedSession session;
  @override
  DateTime? get matchesReadAt => _reads.readAt((DataResource.matches, null));
  @override
  void invalidate({String? matchId}) => _reads.invalidate({
    DataResource.matches,
    if (matchId == null)
      DataResource.messages
    else
      (DataResource.messages, matchId),
  });

  @override
  String get owner => session.identity?.userId ?? invalidResponse();

  Future<Object?> _request(
    String method,
    String path,
    RequestCancellation scope, {
    Object? body,
    String? key,
    Map<String, String>? query,
    int status = 200,
  }) => method == 'GET'
      ? session.request(
          method,
          path,
          body: body,
          idempotencyKey: key,
          query: query,
          expectedStatus: status,
          replayAfterRefresh: true,
          cancellation: scope,
        )
      : _reads.mutate(
          {
            DataResource.matches,
            if (path.startsWith('/api/matches/'))
              (DataResource.messages, path.split('/')[3])
            else
              DataResource.messages,
            if (path.startsWith('/api/users/me/blocks')) DataResource.blocks,
          },
          () => session.request(
            method,
            path,
            body: body,
            idempotencyKey: key,
            query: query,
            expectedStatus: status,
            replayAfterRefresh: true,
            cancellation: scope,
          ),
        );

  @override
  Future<MatchPage> matches(
    RequestCancellation scope, {
    String? cursor,
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: (DataResource.matches, cursor),
    policy: policy,
    tags: {DataResource.matches},
    cancellation: scope,
    fetch: () => _fetchMatches(scope, cursor: cursor),
  );

  Future<MatchPage> _fetchMatches(
    RequestCancellation scope, {
    String? cursor,
  }) async {
    final j = jsonObject(
      await _request(
        'GET',
        '/api/matches/me',
        scope,
        query: {'limit': '20', 'cursor': ?cursor},
      ),
    );
    return MatchPage(
      List.unmodifiable(
        jsonField<List<dynamic>>(
          j,
          'matches',
        ).map((v) => UserMatch.fromJson(v, owner)),
      ),
      pageCursor(j),
    );
  }

  String _path(String id) {
    serverId({'id': id}, 'id');
    return '/api/matches/$id';
  }

  @override
  Future<MessagePage> messages(
    UserMatch match,
    RequestCancellation scope, {
    String? cursor,
    ReadPolicy policy = ReadPolicy.refresh,
  }) => _reads.read(
    scope: _scopeKey,
    key: (DataResource.messages, match.id, cursor),
    policy: policy,
    tags: {DataResource.messages, (DataResource.messages, match.id)},
    cancellation: scope,
    fetch: () => _fetchMessages(match, scope, cursor: cursor),
  );

  Future<MessagePage> _fetchMessages(
    UserMatch match,
    RequestCancellation scope, {
    String? cursor,
  }) async {
    final j = jsonObject(
      await _request(
        'GET',
        '${_path(match.id)}/messages',
        scope,
        query: {'limit': '30', 'cursor': ?cursor},
      ),
    );
    return MessagePage(
      List.unmodifiable(
        jsonField<List<dynamic>>(j, 'messages').map(
          (v) => ChatMessage.fromJson(v, match.id, {owner, match.partner.id}),
        ),
      ),
      pageCursor(j),
    );
  }

  @override
  Future<ChatMessage> send(
    UserMatch match,
    MessageIntent intent,
    RequestCancellation scope,
  ) async {
    if (intent.matchId != match.id || validateMessage(intent.content) != null) {
      invalidResponse();
    }
    final message = ChatMessage.fromJson(
      await _request(
        'POST',
        '${_path(match.id)}/messages',
        scope,
        body: {'content': intent.content},
        key: intent.key,
        status: 201,
      ),
      match.id,
      {owner, match.partner.id},
    );
    if (message.senderId != owner || message.content != intent.content) {
      invalidResponse();
    }
    return message;
  }

  @override
  Future<void> readThrough(
    String id,
    String messageId,
    RequestCancellation scope,
  ) async {
    serverId({'id': messageId}, 'id');
    final j = jsonObject(
      await _request(
        'PATCH',
        '${_path(id)}/messages/read',
        scope,
        body: {'read_through_message_id': messageId},
      ),
    );
    if (serverId(j, 'read_through_message_id') != messageId ||
        jsonField<int>(j, 'updated_count') < 0) {
      invalidResponse();
    }
  }

  @override
  Future<void> readOne(
    String id,
    String messageId,
    RequestCancellation scope,
  ) async {
    serverId({'id': messageId}, 'id');
    await _request('PATCH', '${_path(id)}/messages/$messageId/read', scope);
  }

  @override
  Future<void> end(String id, RequestCancellation scope) async {
    final j = jsonObject(await _request('PATCH', '${_path(id)}/end', scope));
    if (jsonString(j, 'status') != 'ended') invalidResponse();
  }

  @override
  Future<void> block(String partnerId, RequestCancellation scope) async {
    serverId({'id': partnerId}, 'id');
    await _request(
      'POST',
      '/api/users/me/blocks/$partnerId',
      scope,
      status: 204,
    );
  }
}
