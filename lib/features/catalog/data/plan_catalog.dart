import '../../../core/network/json_fields.dart';
import '../../billing/data/billing_models.dart' show BillingPeriod;
import 'subscription_plan.dart';

class SubscriptionOffer {
  const SubscriptionOffer._({
    required this.code,
    required this.planCode,
    required this.displayName,
    required this.billingPeriod,
    required this.priceCents,
    required this.currency,
    required this.trialDays,
  });

  factory SubscriptionOffer.fromJson(Object? value) {
    final json = jsonObject(value);
    final code = jsonString(json, 'code');
    final plan = jsonString(json, 'plan_code');
    final period = json['billing_period'];
    if (!json.containsKey('billing_period') ||
        ![null, 'monthly', 'annual'].contains(period) ||
        (plan == 'free'
            ? period != null || code != 'free'
            : plan != 'premium' ||
                  period == null ||
                  code != 'premium_$period')) {
      invalidResponse();
    }
    int nonNegative(String key) {
      final amount = jsonField<int>(json, key);
      if (amount < 0) invalidResponse();
      return amount;
    }

    return SubscriptionOffer._(
      code: code,
      planCode: plan,
      displayName: jsonString(json, 'display_name'),
      billingPeriod: period == null
          ? null
          : BillingPeriod.values.byName(period as String),
      priceCents: nonNegative('price_cents'),
      currency: jsonString(json, 'currency'),
      trialDays: nonNegative('trial_days'),
    );
  }

  final String code, planCode, displayName, currency;
  final BillingPeriod? billingPeriod;
  final int priceCents, trialDays;
}

class PlanCatalog {
  PlanCatalog._(this.plans, this.offers);

  factory PlanCatalog.fromJson(Object? value) {
    final json = jsonObject(value);
    final plans = List<SubscriptionPlan>.unmodifiable(
      jsonField<List<dynamic>>(json, 'plans').map(SubscriptionPlan.fromJson),
    );
    final offers = List<SubscriptionOffer>.unmodifiable(
      jsonField<List<dynamic>>(json, 'offers').map(SubscriptionOffer.fromJson),
    );
    final planCodes = plans.map((plan) => plan.code).toSet();
    if (planCodes.length != plans.length ||
        offers.map((offer) => offer.code).toSet().length != offers.length ||
        offers.any((offer) => !planCodes.contains(offer.planCode))) {
      invalidResponse();
    }
    return PlanCatalog._(plans, offers);
  }

  final List<SubscriptionPlan> plans;
  final List<SubscriptionOffer> offers;
}
