import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import 'subscription_plan.dart';

abstract interface class CatalogRepository {
  factory CatalogRepository(ApiClient api) = ApiCatalogRepository;
  Future<List<SubscriptionPlan>> load(RequestCancellation cancellation);
  void close();
}

final class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._api);
  final ApiClient _api;

  @override
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

  @override
  void close() => _api.close();
}
