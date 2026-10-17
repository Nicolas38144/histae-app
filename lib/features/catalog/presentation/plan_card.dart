import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/subscription_plan.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, this.action});
  final SubscriptionPlan plan;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                plan.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Text(strings.monthly(plan.monthlyPriceCents, plan.currency)),
            Text(strings.annual(plan.annualPriceCents, plan.currency)),
            Text(strings.trial(plan.trialDays)),
            if (plan.trialDays > 0)
              const Text(
                'Selon votre éligibilité, confirmée lors de la souscription.',
              ),
            const Divider(height: 32),
            if (plan.weeklyIncludedCredits case final credits?)
              Text(strings.weeklyCredits(credits)),
            Text(
              plan.weeklyContinuationLimit == null
                  ? strings.noWeeklyLimit
                  : strings.weeklyLimit(plan.weeklyContinuationLimit!),
            ),
            Text(strings.adStock(plan.advertisingCreditStockLimit)),
            Text(strings.ads(plan.adsRemoved)),
            Text(strings.rewards(plan.rewardedAdvertisingEnabled)),
            for (final feature in plan.features)
              if (feature.displayName != null ||
                  feature.description != null) ...[
                const SizedBox(height: 12),
                if (strings.featureTitle(feature.code, feature.displayName)
                    case final title?)
                  Text(title),
                if (strings.featureDescription(
                      feature.code,
                      feature.description,
                    )
                    case final description?)
                  Text(description),
              ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
