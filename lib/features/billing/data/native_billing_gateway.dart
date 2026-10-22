import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_failure.dart';
import 'billing_gateway.dart';
import 'store_models.dart';

// SDK objects remain inside this adapter; application state uses immutable values.
class _NativeOffer extends StoreOffer {
  _NativeOffer(StoreProduct product, this.details, {this.offerToken})
    : super(product, details.price);
  final ProductDetails details;
  final String? offerToken;
}

class _NativePurchase extends StorePurchase {
  _NativePurchase(this.details, StoreProvider provider)
    : super(
        reference: provider == StoreProvider.appStore
            ? details.purchaseID ?? ''
            : details.verificationData.serverVerificationData,
        status: StorePurchaseStatus.values.byName(details.status.name),
        pendingCompletePurchase: details.pendingCompletePurchase,
      );
  final PurchaseDetails details;
}

final class NativeBillingGateway implements BillingGateway {
  NativeBillingGateway({InAppPurchase? store}) : _providedStore = store;
  final InAppPurchase? _providedStore;
  InAppPurchase get _store => _providedStore ?? InAppPurchase.instance;
  @override
  StoreProvider get provider => defaultTargetPlatform == TargetPlatform.iOS
      ? StoreProvider.appStore
      : StoreProvider.googlePlay;
  @override
  Stream<List<StorePurchase>> get updates => _store.purchaseStream.map(
    (batch) => batch
        .map((purchase) => _NativePurchase(purchase, provider))
        .toList(growable: false),
  );
  @override
  Future<bool> available() => _store.isAvailable();
  @override
  Future<List<StoreOffer>> products(List<StoreProduct> products) async {
    final result = await _store.queryProductDetails(
      products.map((product) => product.productId).toSet(),
    );
    if (result.error != null || result.notFoundIDs.isNotEmpty) {
      throw const ApiFailure(
        ApiFailureKind.unavailable,
        code: 'store_unavailable',
      );
    }
    final offers = <StoreOffer>[];
    for (final product in products) {
      for (final details in result.productDetails.where(
        (details) => details.id == product.productId,
      )) {
        if (provider == StoreProvider.googlePlay) {
          if (details is! GooglePlayProductDetails ||
              details.subscriptionIndex == null) {
            continue;
          }
          final offer = details
              .productDetails
              .subscriptionOfferDetails![details.subscriptionIndex!];
          // No introductory or free offers: select only the base plan itself.
          if (offer.basePlanId != product.basePlanId ||
              offer.offerId != null ||
              offer.installmentPlanDetails != null) {
            continue;
          }
          offers.add(
            _NativeOffer(product, details, offerToken: offer.offerIdToken),
          );
        } else {
          offers.add(_NativeOffer(product, details));
        }
      }
    }
    if (offers.length != products.length) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return offers;
  }

  @override
  Future<bool> buy(StoreOffer offer, String accountBinding) {
    if (offer is! _NativeOffer) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return _store.buyNonConsumable(
      purchaseParam: provider == StoreProvider.appStore
          ? Sk2PurchaseParam(
              productDetails: offer.details,
              applicationUserName: accountBinding,
            )
          : GooglePlayPurchaseParam(
              productDetails: offer.details,
              applicationUserName: accountBinding,
              offerToken: offer.offerToken,
            ),
    );
  }

  @override
  String reference(StorePurchase purchase) {
    final reference = purchase.reference;
    if (reference.isEmpty || reference.length > 4096) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return reference;
  }

  @override
  Future<void> complete(StorePurchase purchase) {
    if (purchase is! _NativePurchase) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return _store.completePurchase(purchase.details);
  }

  @override
  Future<void> restore() => _store.restorePurchases();
  @override
  Future<bool> manage(String provider) async {
    final url = switch (provider) {
      'app_store' => Uri.parse('https://apps.apple.com/account/subscriptions'),
      'google_play' => Uri.parse(
        'https://play.google.com/store/account/subscriptions',
      ),
      _ => null,
    };
    return url != null &&
        await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
