import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/read_snapshots.dart';
import '../../auth/domain/authenticated_session.dart';
import 'discovery_models.dart';

abstract interface class DiscoveryRepository {
  factory DiscoveryRepository(
    AuthenticatedSession session, {
    ReadSnapshots? cache,
  }) = ApiDiscoveryRepository;

  AuthenticatedSession get session;

  Future<DiscoveryStatus> status(RequestCancellation scope);

  Future<FeedPage> feed(String? cursor, RequestCancellation scope);

  Future<void> presence(
    double latitude,
    double longitude,
    RequestCancellation scope,
  );

  Future<SwipeResult> swipe(PendingChoice intent, RequestCancellation scope);

  Future<void> block(PendingChoice intent, RequestCancellation scope);
}

final class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository(this.session, {ReadSnapshots? cache})
    : _reads = cache ?? ReadSnapshots();
  final ReadSnapshots _reads;
  @override
  final AuthenticatedSession session;

  Future<Object?> _request(
    String method,
    String path,
    RequestCancellation scope, {
    Object? body,
    Map<String, String>? query,
    int status = 200,
  }) => _reads.mutate(
    path.startsWith('/api/users/me/blocks')
        ? {DataResource.blocks, DataResource.matches, DataResource.messages}
        : path == '/api/swipes'
        ? {DataResource.matches}
        : {},
    () => session.request(
      method,
      path,
      body: body,
      query: query,
      expectedStatus: status,
      replayAfterRefresh: true,
      cancellation: scope,
    ),
  );

  @override
  Future<DiscoveryStatus> status(RequestCancellation scope) async =>
      DiscoveryStatus.fromJson(
        await _request('GET', '/api/users/me/discovery-status', scope),
      );

  @override
  Future<FeedPage> feed(String? cursor, RequestCancellation scope) async =>
      FeedPage.fromJson(
        await _request(
          'GET',
          '/api/feed',
          scope,
          query: {'limit': '20', 'cursor': ?cursor},
        ),
      );

  @override
  Future<void> presence(
    double latitude,
    double longitude,
    RequestCancellation scope,
  ) async {
    await _request(
      'PATCH',
      '/api/users/me/presence',
      scope,
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  @override
  Future<SwipeResult> swipe(
    PendingChoice intent,
    RequestCancellation scope,
  ) async {
    final owner = session.identity?.userId;
    if (owner == null) invalidResponse();
    return SwipeResult.fromJson(
      await _request(
        'POST',
        '/api/swipes',
        scope,
        body: {
          'target_user_id': intent.profile.id,
          'decision': intent.action.name,
        },
        status: 201,
      ),
      owner,
      intent,
    );
  }

  @override
  Future<void> block(PendingChoice intent, RequestCancellation scope) async {
    serverId({'id': intent.profile.id}, 'id');
    await _request(
      'POST',
      '/api/users/me/blocks/${intent.profile.id}',
      scope,
      status: 204,
    );
  }
}
