import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import 'subscription_plan.dart';

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  Future<List<SubscriptionPlan>> load(RequestCancellation cancellation) async {
    final body = await _api.getJson('/api/plans', cancellation: cancellation);
    try {
      if (body is! Map<String, dynamic> || body['plans'] is! List) {
        throw const FormatException('Invalid catalog envelope');
      }
      return List.unmodifiable(
        (body['plans'] as List).map(SubscriptionPlan.fromJson),
      );
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
  }

  void close() => _api.close();
}
