import 'store_models.dart';

enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

class StorePurchase {
  const StorePurchase({
    required this.reference,
    required this.status,
    required this.pendingCompletePurchase,
  });
  final String reference;
  final StorePurchaseStatus status;
  final bool pendingCompletePurchase;
}

class StoreOffer {
  const StoreOffer(this.product, this.price);
  final StoreProduct product;
  final String price;
}

/// Native billing boundary, independent of Flutter purchase SDK objects.
abstract interface class BillingGateway {
  StoreProvider get provider;
  Stream<List<StorePurchase>> get updates;
  Future<bool> available();
  Future<List<StoreOffer>> products(List<StoreProduct> products);
  Future<bool> buy(StoreOffer offer, String accountBinding);
  String reference(StorePurchase purchase);
  Future<void> complete(StorePurchase purchase);
  Future<void> restore();
  Future<bool> manage(String provider);
}
