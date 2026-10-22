import 'dart:async';

import 'package:histae_app/core/config/billing_config.dart';
import 'package:histae_app/features/billing/data/billing_gateway.dart';
import 'package:histae_app/features/billing/data/store_models.dart';

final testBillingConfig = BillingConfig.fromValues({'BILLING_ENABLED': 'true'});
Map<String, Object?> subscriptionJson({
  bool access = false,
  String? status,
  String? provider = 'google_play',
  bool cancel = false,
  bool portal = false,
}) => {
  'plan': access ? 'premium' : 'free',
  'provider': status == null ? null : provider,
  'status': status,
  'access_granted': access,
  'billing_period': status == null ? null : 'monthly',
  'cancel_at_period_end': cancel,
  'current_period_starts_at': status == null ? null : '2026-10-01T00:00:00Z',
  'current_period_ends_at': status == null ? null : '2099-11-01T00:00:00Z',
  'trial_ends_at': null,
  'canceled_at': status == 'canceled' ? '2026-10-15T00:00:00Z' : null,
  'customer_portal_available': portal,
  'management_url': null,
};
Map<String, Object?> storeProductsJson() => {
  'offers': [
    {
      'billing_period': 'monthly',
      'product_id': 'premium',
      'base_plan_id': 'monthly',
    },
    {
      'billing_period': 'annual',
      'product_id': 'premium',
      'base_plan_id': 'annual',
    },
  ],
};
Map<String, Object?> storeIntentJson() => {
  ...storeProductsJson(),
  'provider': 'google_play',
  'account_binding': 'a' * 64,
};
StorePurchase storePurchase({
  String id = 'receipt',
  StorePurchaseStatus status = StorePurchaseStatus.purchased,
}) =>
    StorePurchase(reference: id, status: status, pendingCompletePurchase: true);

class FakeBillingGateway implements BillingGateway {
  // Test owners close this stream with addTearDown.
  // ignore: close_sinks
  final stream = StreamController<List<StorePurchase>>.broadcast(sync: true);
  final bought = <StoreOffer>[];
  final completed = <StorePurchase>[];
  final managed = <String>[];
  bool accepted = true;
  int restores = 0;
  @override
  StoreProvider get provider => StoreProvider.googlePlay;
  @override
  Stream<List<StorePurchase>> get updates => stream.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<List<StoreOffer>> products(List<StoreProduct> products) async =>
      products
          .map(
            (product) => StoreOffer(
              product,
              product.period.name == 'annual' ? '48,00 EUR' : '5,00 EUR',
            ),
          )
          .toList();
  @override
  Future<bool> buy(StoreOffer offer, String accountBinding) async {
    bought.add(offer);
    return accepted;
  }

  @override
  String reference(StorePurchase purchase) => purchase.reference;
  @override
  Future<void> complete(StorePurchase purchase) async {
    completed.add(purchase);
  }

  @override
  Future<void> restore() async {
    restores++;
  }

  @override
  Future<bool> manage(String provider) async {
    managed.add(provider);
    return true;
  }
}
