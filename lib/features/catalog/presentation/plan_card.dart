import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/subscription_plan.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, this.action});
  final SubscriptionPlan plan;
  final Widget? action;

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
                    ? 'PRENDRE LE TEMPS, LIBREMENT'
                    : 'POUR FAIRE CONNAISSANCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  plan.displayName,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.monthly(plan.monthlyPriceCents, plan.currency),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                strings.annual(plan.annualPriceCents, plan.currency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.trial(plan.trialDays),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (plan.trialDays > 0)
                const Text(
                  'Selon votre éligibilité, confirmée lors de la souscription.',
                ),
              const Divider(height: 32),
              if (plan.weeklyIncludedCredits case final credits?)
                detail(strings.weeklyCredits(credits)),
              detail(
                plan.weeklyContinuationLimit == null
                    ? strings.noWeeklyLimit
                    : strings.weeklyLimit(plan.weeklyContinuationLimit!),
              ),
              detail(strings.adStock(plan.advertisingCreditStockLimit)),
              detail(strings.ads(plan.adsRemoved)),
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
