import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/plan_catalog.dart';
import '../../catalog/presentation/plan_card.dart';
import '../../catalog/presentation/subscription_plan_carousel.dart';
import '../data/billing_gateway.dart';
import '../data/billing_models.dart';

class SubscriptionPlans extends StatelessWidget {
  const SubscriptionPlans({
    super.key,
    required this.catalog,
    required this.paymentsAvailable,
    required this.canSubscribe,
    required this.hasPending,
    required this.canAct,
    required this.onChoose,
    required this.storeOffers,
  });
  final CatalogController catalog;
  final List<StoreOffer> storeOffers;
  final bool paymentsAvailable, canSubscribe, hasPending, canAct;
  final Future<void> Function(SubscriptionOffer offer) onChoose;

  String? _price(BuildContext context, SubscriptionOffer offer) {
    if (offer.billingPeriod == null) return null;
    final native = storeOffers
        .where((item) => item.product.period == offer.billingPeriod)
        .firstOrNull;
    final copy = AppStrings.of(context).messages;
    if (native == null) return copy.billingStorePriceUnavailable;
    return offer.billingPeriod == BillingPeriod.monthly
        ? copy.billingStorePricePerMonth(native.price)
        : copy.billingStorePricePerYear(native.price);
  }

  @override
  Widget build(BuildContext context) {
    if (catalog.status == CatalogStatus.loading ||
        catalog.status == CatalogStatus.idle) {
      return LinearProgressIndicator(
        semanticsLabel: AppStrings.of(context)
            .messages
            .subscriptionPlansLoadingPlans,
      );
    }
    if (catalog.failure != null || catalog.offers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            catalog.failure == null
                ? AppStrings.of(context)
                      .messages
                      .subscriptionPlansNoPlansAvailable
                : AppStrings.of(context)
                      .messages
                      .appStringsPlansAreCurrentlyUnavailable,
          ),
          OutlinedButton(
            onPressed: catalog.retrySeconds > 0 ? null : catalog.load,
            child: Text(
              catalog.retrySeconds > 0
                  ? AppStrings.of(context).retryIn(catalog.retrySeconds)
                  : AppStrings.of(context)
                        .messages
                        .subscriptionPlansRefreshPlans,
            ),
          ),
        ],
      );
    }
    final copy = AppStrings.of(context).messages;
    return SubscriptionPlanCarousel(
      initialSlideId: catalog.offers
          .where((offer) => offer.billingPeriod == BillingPeriod.monthly)
          .firstOrNull
          ?.code,
      slides: [
        for (final offer in catalog.offers)
          (
            id: offer.code,
            label: switch (offer.billingPeriod) {
              null => copy.subscriptionFreeOffer,
              BillingPeriod.monthly => copy.subscriptionMonthlyOffer,
              BillingPeriod.annual => copy.subscriptionAnnualOffer,
            },
            child: PlanCard(
              key: ValueKey('plan-offer-${offer.code}'),
              plan: catalog.plans.firstWhere(
                (plan) => plan.code == offer.planCode,
              ),
              offer: offer,
              priceLabel: _price(context, offer),
              action:
                  offer.billingPeriod != null &&
                      paymentsAvailable &&
                      canSubscribe &&
                      hasPending == false
                  ? HistaeButton(
                      onPressed: canAct ? () => onChoose(offer) : null,
                      child: Text(
                        AppStrings.of(context).messages
                            .chooseOffer(offer.displayName),
                      ),
                    )
                  : offer.billingPeriod != null && !paymentsAvailable
                  ? OutlinedButton(
                      onPressed: null,
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .subscriptionPlansPaymentUnavailable,
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
