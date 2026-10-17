import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../catalog/data/subscription_plan.dart';
import 'continuation_models.dart';

abstract interface class ContinuationRepository {
  factory ContinuationRepository(AuthenticatedSession session) =
      ApiContinuationRepository;
  AuthenticatedSession get session;
  Future<ContinuationQuota> quota(RequestCancellation scope);
  Future<List<SubscriptionPlan>> plans(RequestCancellation scope);
  Future<bool> reveal(String id, RequestCancellation scope);
  Future<bool> continueMatch(String id, int cost, RequestCancellation scope);
  Future<RewardIntent> createReward(String platform, RequestCancellation scope);
  Future<RewardIntent> reward(String id, RequestCancellation scope);
  Future<void> cancelReward(String id, RequestCancellation scope);
}

final class ApiContinuationRepository implements ContinuationRepository {
  ApiContinuationRepository(this.session);
  @override
  final AuthenticatedSession session;
  Future<Object?> _request(
    String method,
    String path,
    RequestCancellation scope, {
    Object? body,
    int status = 200,
  }) => session.request(
    method,
    path,
    body: body,
    cancellation: scope,
    expectedStatus: status,
    replayAfterRefresh: true,
  );
  @override
  Future<ContinuationQuota> quota(RequestCancellation scope) async =>
      ContinuationQuota.fromJson(
        await _request('GET', '/api/users/me/continuation-quota', scope),
      );
  @override
  Future<List<SubscriptionPlan>> plans(RequestCancellation scope) async {
    final j = jsonObject(
      await session.publicJson('/api/plans', cancellation: scope),
    );
    try {
      return List.unmodifiable(
        jsonField<List<dynamic>>(j, 'plans').map(SubscriptionPlan.fromJson),
      );
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
  }

  String _path(String id) {
    serverId({'id': id}, 'id');
    return '/api/matches/$id';
  }

  @override
  Future<bool> reveal(String id, RequestCancellation scope) async =>
      jsonField<bool>(
        jsonObject(await _request('PATCH', '${_path(id)}/reveal', scope)),
        'photos_revealed',
      );
  @override
  Future<bool> continueMatch(
    String id,
    int cost,
    RequestCancellation scope,
  ) async {
    if (cost != 0 && cost != 1) invalidResponse();
    return jsonField<bool>(
      jsonObject(
        await _request(
          'PATCH',
          '${_path(id)}/continue',
          scope,
          body: {'credit_cost': cost},
        ),
      ),
      'match_confirmed',
    );
  }

  @override
  Future<RewardIntent> createReward(
    String platform,
    RequestCancellation scope,
  ) async {
    if (!['android', 'ios'].contains(platform)) invalidResponse();
    return RewardIntent.fromJson(
      await _request(
        'POST',
        '/api/users/me/advertising-rewards',
        scope,
        body: {'platform': platform},
      ),
    );
  }

  String _rewardPath(String id) {
    serverId({'id': id}, 'id');
    return '/api/users/me/advertising-rewards/$id';
  }

  @override
  Future<RewardIntent> reward(String id, RequestCancellation scope) async {
    final result = RewardIntent.fromJson(
      await _request('GET', _rewardPath(id), scope),
    );
    if (result.id != id) invalidResponse();
    return result;
  }

  @override
  Future<void> cancelReward(String id, RequestCancellation scope) async =>
      _request('DELETE', _rewardPath(id), scope, status: 204);
}
