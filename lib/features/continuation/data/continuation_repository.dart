import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/data/subscription_plan.dart';
import '../../profile/data/profile_models.dart';
import 'continuation_models.dart';

class ContinuationRepository {
  ContinuationRepository(this.session);
  final SessionController session;
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
  Future<ContinuationQuota> quota(RequestCancellation scope) async =>
      ContinuationQuota.fromJson(
        await _request('GET', '/api/users/me/continuation-quota', scope),
      );
  Future<List<SubscriptionPlan>> plans(RequestCancellation scope) async {
    final j = jsonObject(
      await session.repository.api.getJson('/api/plans', cancellation: scope),
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

  Future<bool> reveal(String id, RequestCancellation scope) async =>
      jsonField<bool>(
        jsonObject(await _request('PATCH', '${_path(id)}/reveal', scope)),
        'photos_revealed',
      );
  Future<bool> continueMatch(
    String id,
    int cost,
    RequestCancellation scope,
  ) async {
    if (cost != 0 && cost != 1) invalidProfile();
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

  Future<RewardIntent> createReward(
    String platform,
    RequestCancellation scope,
  ) async {
    if (!['android', 'ios'].contains(platform)) invalidProfile();
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

  Future<RewardIntent> reward(String id, RequestCancellation scope) async {
    final result = RewardIntent.fromJson(
      await _request('GET', _rewardPath(id), scope),
    );
    if (result.id != id) invalidProfile();
    return result;
  }

  Future<void> cancelReward(String id, RequestCancellation scope) async =>
      _request('DELETE', _rewardPath(id), scope, status: 204);
}
