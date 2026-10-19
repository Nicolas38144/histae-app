import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/billing_models.dart';
import 'billing_strings.dart';

class SubscriptionSummary extends StatelessWidget {
  const SubscriptionSummary({super.key, required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.plan == 'premium'
                ? AppStrings.of(context)
                      .messages
                      .subscriptionSummaryHistaePremium
                : AppStrings.of(context).messages.subscriptionSummaryHistaeFree,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(BillingStrings(AppStrings.of(context)).status(state.status)),
          Text(
            state.accessGranted
                ? AppStrings.of(context)
                      .messages
                      .subscriptionSummaryPremiumAccessConfirmedAtTheLast
                : AppStrings.of(context)
                      .messages
                      .subscriptionSummaryYouCurrentlyHaveTheFreePlan,
          ),
          if (state.billingPeriod != null)
            Text(
              state.billingPeriod == BillingPeriod.monthly
                  ? AppStrings.of(context)
                        .messages
                        .subscriptionSummaryMonthlyPlan
                  : AppStrings.of(context)
                        .messages
                        .subscriptionSummaryAnnualPlan,
            ),
          if (state.trialEnd != null)
            Text(
              AppStrings.of(context).messages.subscriptionSummaryTrialEnds(
                BillingStrings(AppStrings.of(context)).date(state.trialEnd!),
              ),
            ),
          if (state.periodStart != null)
            Text(
              AppStrings.of(context).messages.subscriptionSummaryPeriodStarts(
                BillingStrings(AppStrings.of(context)).date(state.periodStart!),
              ),
            ),
          if (state.periodEnd != null)
            Text(
              AppStrings.of(context).messages.subscriptionSummaryPeriodEnds(
                BillingStrings(AppStrings.of(context)).date(state.periodEnd!),
              ),
            ),
          if (state.cancelAtPeriodEnd)
            Text(
              AppStrings.of(context)
                  .messages
                  .subscriptionSummaryCancellationScheduledForTheEndOf,
            ),
          if (state.canceledAt != null)
            Text(
              AppStrings.of(context).messages
                  .subscriptionSummaryCancellationRecordedOn(
                    BillingStrings(AppStrings.of(context))
                        .date(state.canceledAt!),
                  ),
            ),
          if (state.status == 'past_due')
            Text(
              AppStrings.of(context)
                  .messages
                  .subscriptionSummaryYourPaymentNeedsAttentionTheEntitlements,
            ),
        ],
      ),
    ),
  );
}
