import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';

abstract interface class DiscoveryVisibilityRepository {
  factory DiscoveryVisibilityRepository(AuthenticatedSession session) =
      ApiDiscoveryVisibilityRepository;

  AuthenticatedSession get session;
  Future<bool> read(RequestCancellation cancellation);
  Future<bool> setPaused(bool paused, RequestCancellation cancellation);
}

final class ApiDiscoveryVisibilityRepository
    implements DiscoveryVisibilityRepository {
  ApiDiscoveryVisibilityRepository(this.session);

  @override
  final AuthenticatedSession session;

  Future<bool> _request(
    String method,
    RequestCancellation cancellation, {
    bool? paused,
  }) async => jsonField<bool>(
    jsonObject(
      await session.request(
        method,
        '/api/users/me/discovery-settings',
        body: paused == null ? null : {'paused': paused},
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: cancellation,
      ),
    ),
    'paused',
  );

  @override
  Future<bool> read(RequestCancellation cancellation) =>
      _request('GET', cancellation);

  @override
  Future<bool> setPaused(bool paused, RequestCancellation cancellation) =>
      _request('PATCH', cancellation, paused: paused);
}
