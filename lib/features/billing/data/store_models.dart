import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import 'billing_models.dart';

enum StoreProvider {
  appStore,
  googlePlay;

  String get wire => this == appStore ? 'app_store' : 'google_play';
}

class StoreProduct {
  const StoreProduct({
    required this.period,
    required this.productId,
    this.basePlanId,
  });
  factory StoreProduct.fromJson(Object? value) {
    final json = jsonObject(value);
    final period = jsonString(json, 'billing_period');
    if (!['monthly', 'annual'].contains(period)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return StoreProduct(
      period: BillingPeriod.values.byName(period),
      productId: jsonString(json, 'product_id'),
      basePlanId: optionalText(json, 'base_plan_id'),
    );
  }
  final BillingPeriod period;
  final String productId;
  final String? basePlanId;
}

class StoreIntent {
  const StoreIntent({
    required this.provider,
    required this.binding,
    required this.products,
  });
  factory StoreIntent.fromJson(Object? value) {
    final json = jsonObject(value);
    final wire = jsonString(json, 'provider');
    final provider = switch (wire) {
      'app_store' => StoreProvider.appStore,
      'google_play' => StoreProvider.googlePlay,
      _ => throw const ApiFailure(ApiFailureKind.invalidResponse),
    };
    final binding = jsonString(json, 'account_binding');
    final valid = provider == StoreProvider.appStore
        ? RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(binding)
        : RegExp(r'^[0-9a-f]{64}$').hasMatch(binding);
    if (!valid) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final items = json['offers'];
    if (items is! List) throw const ApiFailure(ApiFailureKind.invalidResponse);
    return StoreIntent(
      provider: provider,
      binding: binding,
      products: List.unmodifiable(items.map(StoreProduct.fromJson)),
    );
  }
  final StoreProvider provider;
  final String binding;
  final List<StoreProduct> products;
}
