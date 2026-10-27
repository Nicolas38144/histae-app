import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/continuation_controller.dart';
import 'weekly_renewal_label.dart';

/// Displays only server-owned available balances, excluding reserved credits.
class ContinuationBalanceCard extends StatelessWidget {
  const ContinuationBalanceCard({
    super.key,
    required this.controller,
    required this.onOpenCredits,
    required this.onOpenSubscription,
    this.loading = false,
  });
  final ContinuationController controller;
  final VoidCallback onOpenCredits, onOpenSubscription;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.quota;
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 18;
    Widget balance(
      String label,
      String semantics,
      int count,
      Key key,
    ) => Semantics(
      label: AppStrings.of(context).messages
          .continuationBalanceCard(semantics, count),
      excludeSemantics: true,
      child: largeText
          ? Row(
              children: [
                Text('$count', key: key, style: theme.textTheme.headlineSmall),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', key: key, style: theme.textTheme.headlineSmall),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
    );
    return Card(
      child: Semantics(
        button: true,
        child: InkWell(
          key: const Key('open-credits'),
          onTap: onOpenCredits,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      AppStrings.of(context).messages.creditsPageYourCredits,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (!loading &&
                        !c.loading &&
                        q != null &&
                        c.quotaReadAt != null &&
                        !q.premium)
                      HistaeButton.textIcon(
                        key: Key(
                          q.weeklyLimitReached
                              ? 'open-credit-subscription'
                              : 'open-videos',
                        ),
                        onPressed: q.weeklyLimitReached
                            ? onOpenSubscription
                            : onOpenCredits,
                        icon: Icon(
                          q.weeklyLimitReached
                              ? Icons.auto_awesome_outlined
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          q.weeklyLimitReached
                              ? AppStrings.of(context)
                                    .messages
                                    .creditRecoveryViewSubscriptions
                              : q.suggestsRewardedVideo
                              ? AppStrings.of(context)
                                    .messages
                                    .rewardVideoCardWatchAVideo
                              : AppStrings.of(context)
                                    .messages
                                    .continuationBalanceCardVideos,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!loading &&
                    !c.loading &&
                    q != null &&
                    c.quotaReadAt != null &&
                    (q.weeklyLimitReached || q.suggestsRewardedVideo)) ...[
                  Text(
                    q.weeklyLimitReached
                        ? AppStrings.of(context)
                              .messages
                              .creditRecoveryWeeklyLimit
                        : AppStrings.of(context)
                              .messages
                              .creditRecoveryWatchDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                if (loading || c.loading) ...[
                  Text(
                    AppStrings.of(context)
                        .messages
                        .continuationBalanceCardRefreshingYourCredits,
                  ),
                ] else if (q == null || c.quotaReadAt == null) ...[
                  Text(
                    AppStrings.of(context)
                        .messages
                        .continuationBalanceCardYourBalanceCannotBeCheckedRight,
                  ),
                  HistaeButton.textIcon(
                    onPressed: c.retrySeconds > 0
                        ? null
                        : () async {
                            await c.activate();
                            await c.loadQuota();
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      c.retrySeconds > 0
                          ? AppStrings.of(context).messages
                                .continuationBalanceCardTryAgainInS(
                                  c.retrySeconds,
                                )
                          : AppStrings.of(context)
                                .messages
                                .continuationBalanceCardRefreshCredits,
                    ),
                  ),
                ] else if (q.premium) ...[
                  Text(
                    AppStrings.of(context)
                        .messages
                        .accountBenefitsActionsPremium,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .continuationBalanceCardNoCreditsAreNeededForYour,
                  ),
                ] else ...[
                  Flex(
                    direction: largeText ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: largeText ? 0 : 1,
                        child: balance(
                          AppStrings.of(context)
                              .messages
                              .continuationBalanceCardFreeRemaining,
                          AppStrings.of(context)
                              .messages
                              .continuationBalanceCardFreeCreditsRemaining,
                          q.freeRemaining,
                          const Key('free-credits-remaining'),
                        ),
                      ),
                      SizedBox(
                        width: largeText ? 0 : 16,
                        height: largeText ? 16 : 0,
                      ),
                      Flexible(
                        flex: largeText ? 0 : 1,
                        child: balance(
                          AppStrings.of(context)
                              .messages
                              .continuationBalanceCardVideoRemaining,
                          AppStrings.of(context)
                              .messages
                              .continuationBalanceCardVideoCreditsRemaining,
                          q.advertisingRemaining,
                          const Key('ad-credits-remaining'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (!loading &&
                    !c.loading &&
                    q != null &&
                    c.quotaReadAt != null &&
                    !q.premium) ...[
                  const WeeklyRenewalLabel(),
                  const SizedBox(height: 16),
                ],
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .continuationBalanceCardViewCredits,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
