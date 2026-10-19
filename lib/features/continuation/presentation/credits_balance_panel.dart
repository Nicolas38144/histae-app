import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/continuation_models.dart';

class CreditsBalancePanel extends StatelessWidget {
  const CreditsBalancePanel({super.key, required this.quota});
  final ContinuationQuota quota;

  @override
  Widget build(BuildContext context) {
    final q = quota, theme = Theme.of(context), colors = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.primary.withValues(alpha: .3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .65),
            colors.surfaceContainerLow,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                AppStrings.of(context).messages.creditsBalancePanelYourBalance,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  q.premium
                      ? AppStrings.of(context)
                            .messages
                            .accountBenefitsActionsPremium
                      : AppStrings.of(context)
                            .messages
                            .creditsBalancePanelHistaeFree,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (q.premium) ...[
            Icon(Icons.all_inclusive_rounded, size: 52, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context)
                  .messages
                  .creditsBalancePanelTimeToDiscoverEachOther,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context)
                  .messages
                  .creditsBalancePanelNoCreditsAreNeededToContinue,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Semantics(
              label: AppStrings.of(context).messages
                  .availableContinuations(q.remaining!),
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    '${q.remaining}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 76,
                      height: 1,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.of(context).messages
                        .creditsAvailable(q.remaining!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Flex(
              direction: largeText ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: largeText ? 0 : 1,
                  child: _Balance(
                    icon: Icons.auto_awesome_outlined,
                    label: AppStrings.of(context)
                        .messages
                        .creditsBalancePanelFree,
                    count: q.freeRemaining,
                    color: colors.primary,
                  ),
                ),
                SizedBox(width: largeText ? 0 : 12, height: largeText ? 12 : 0),
                Flexible(
                  flex: largeText ? 0 : 1,
                  child: _Balance(
                    icon: Icons.play_circle_outline_rounded,
                    label: AppStrings.of(context)
                        .messages
                        .continuationBalanceCardVideos,
                    count: q.advertisingRemaining,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context)
                  .messages
                  .creditsBalancePanelAvailableBalancesExcludingReservedCredits,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: theme.textTheme.headlineMedium?.copyWith(color: color),
          ),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class CreditsWeekPanel extends StatelessWidget {
  const CreditsWeekPanel({super.key, required this.quota});
  final ContinuationQuota quota;

  @override
  Widget build(BuildContext context) {
    final q = quota, theme = Theme.of(context), colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context).messages.creditsBalancePanelThisWeek,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context).messages
                  .creditsBalancePanelContinuationsConfirmed(
                    q.used,
                    q.weeklyLimit!,
                  ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: q.weeklyLimit == 0
                  ? 0
                  : (q.used / q.weeklyLimit!).clamp(0, 1),
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
              semanticsLabel: AppStrings.of(context).messages
                  .creditsBalancePanelContinuationsConfirmedThisWeekOf(
                    q.used,
                    q.weeklyLimit!,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              AppStrings.of(context).messages
                  .creditsBalancePanelFreeCreditsRenewedOnMondaysAt(
                    q.weeklyCredits,
                  ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (q.remaining == 0) ...[
              const SizedBox(height: 10),
              Text(
                AppStrings.of(context)
                    .messages
                    .creditsBalancePanelNoNewContinuationAvailableRightNow,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CreditsExplanation extends StatelessWidget {
  const CreditsExplanation({super.key, required this.quota});
  final ContinuationQuota quota;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Text(
        AppStrings.of(context)
            .messages
            .creditsBalancePanelUnderstandingMyCredits,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.of(context).messages.reservedCredits(quota.reserved),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context)
                  .messages
                  .creditsBalancePanelACreditIsReservedWhenYou,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.of(context).messages.creditsBalancePanelVideoReserve(
                quota.advertisingBalance,
                quota.stockLimit,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context)
                  .messages
                  .creditsBalancePanelVideoCreditsAreKeptIncludingReserved,
            ),
          ],
        ),
      ],
    ),
  );
}
