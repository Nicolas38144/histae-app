import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../billing/data/billing_models.dart' show BillingPeriod;
import '../data/plan_catalog.dart';
import '../data/subscription_plan.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.offer,
    this.action,
    this.priceLabel,
  });
  final SubscriptionPlan plan;
  final SubscriptionOffer offer;
  final Widget? action;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final featured = plan.code == 'premium';
    Widget detail(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      color: featured ? Colors.transparent : null,
      shape: featured
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HistaeTokens.panelRadius),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.55),
              ),
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: featured ? HistaeTokens.panelGradient(context) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                featured
                    ? AppStrings.of(context).messages.planCardTakeYourTimeFreely
                    : AppStrings.of(context)
                          .messages
                          .planCardToGetToKnowEachOther,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  offer.displayName,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                priceLabel ??
                    switch (offer.billingPeriod) {
                      BillingPeriod.monthly => strings.monthly(
                        offer.priceCents,
                        offer.currency,
                      ),
                      BillingPeriod.annual => strings.annual(
                        offer.priceCents,
                        offer.currency,
                      ),
                      null => strings.money(offer.priceCents, offer.currency),
                    },
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                switch (offer.billingPeriod) {
                  BillingPeriod.monthly => AppStrings.of(
                    context,
                  ).messages.planCardBilledMonthlyAutomaticRenewal,
                  BillingPeriod.annual => AppStrings.of(
                    context,
                  ).messages.planCardBilledInFullEachYearAutomatic,
                  null => AppStrings.of(
                    context,
                  ).messages.planCardNoPaidSubscription,
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (offer.billingPeriod == BillingPeriod.annual &&
                  priceLabel == null) ...[
                const SizedBox(height: 6),
                Text(
                  AppStrings.of(context).messages.planCardEquivalentToAbout(
                    strings.monthly(
                      (offer.priceCents / 12).round(),
                      offer.currency,
                    ),
                  ),
                ),
              ],
              const Divider(height: 32),
              if (plan.weeklyIncludedCredits case final credits?)
                detail(strings.weeklyCredits(credits)),
              detail(
                plan.weeklyContinuationLimit == null
                    ? strings.noWeeklyLimit
                    : strings.weeklyLimit(plan.weeklyContinuationLimit!),
              ),
              if (!plan.adsRemoved)
                detail(strings.adStock(plan.advertisingCreditStockLimit)),
              detail(strings.ads(plan.adsRemoved)),
              if (!plan.adsRemoved)
                detail(strings.rewards(plan.rewardedAdvertisingEnabled)),
              for (final feature in plan.features)
                if (feature.displayName != null ||
                    feature.description != null) ...[
                  const SizedBox(height: 12),
                  if (strings.featureTitle(feature.code, feature.displayName)
                      case final title?)
                    Text(title, style: theme.textTheme.titleMedium),
                  if (strings.featureDescription(
                        feature.code,
                        feature.description,
                      )
                      case final description?)
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
