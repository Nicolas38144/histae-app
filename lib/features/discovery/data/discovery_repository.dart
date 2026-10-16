import '../../../core/network/api_client.dart';
import '../../auth/application/session_controller.dart';
import '../../profile/data/profile_models.dart';
import 'discovery_models.dart';

class DiscoveryRepository {
  DiscoveryRepository(this.session);
  final SessionController session;
  Future<Object?> _request(
    String method,
    String path,
    RequestCancellation scope, {
    Object? body,
    Map<String, String>? query,
    int status = 200,
  }) => session.request(
    method,
    path,
    body: body,
    query: query,
    expectedStatus: status,
    replayAfterRefresh: true,
    cancellation: scope,
  );
  Future<DiscoveryStatus> status(RequestCancellation scope) async =>
      DiscoveryStatus.fromJson(
        await _request('GET', '/api/users/me/discovery-status', scope),
      );
  Future<FeedPage> feed(String? cursor, RequestCancellation scope) async =>
      FeedPage.fromJson(
        await _request(
          'GET',
          '/api/feed',
          scope,
          query: {'limit': '20', 'cursor': ?cursor},
        ),
      );
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

  Future<SwipeResult> swipe(
    PendingChoice intent,
    RequestCancellation scope,
  ) async {
    final owner = session.identity?.userId;
    if (owner == null) invalidProfile();
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
