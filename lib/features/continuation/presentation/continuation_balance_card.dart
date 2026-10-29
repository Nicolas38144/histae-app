import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/continuation_controller.dart';
import 'weekly_renewal_label.dart';

/// A local disclosure: expanding it never fetches or grants credits.
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
    final text = AppStrings.of(context).messages;
    final theme = Theme.of(context);
    final ready = !loading && !c.loading && q != null && c.quotaReadAt != null;
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 18;
    return Card(
      child: ExpansionTile(
        key: PageStorageKey((
          'credits-disclosure',
          c.access.session.resourceKey,
        )),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.account_balance_wallet_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          text.creditsPageYourCredits,
          key: const Key('matches-credits-toggle'),
          style: theme.textTheme.titleSmall,
        ),
        children: [
          if (loading || c.loading)
            Text(text.continuationBalanceCardRefreshingYourCredits)
          else if (!ready) ...[
            Text(text.continuationBalanceCardYourBalanceCannotBeCheckedRight),
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
                    ? text.continuationBalanceCardTryAgainInS(c.retrySeconds)
                    : text.continuationBalanceCardRefreshCredits,
              ),
            ),
          ] else if (q.premium)
            Text(text.continuationBalanceCardNoCreditsAreNeededForYour)
          else ...[
            Flex(
              direction: largeText ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: largeText ? 0 : 1,
                  child: _Balance(
                    count: q.freeRemaining,
                    label: text.continuationBalanceCardFreeRemaining,
                    semantics: text.continuationBalanceCardFreeCreditsRemaining,
                    countKey: const Key('free-credits-remaining'),
                  ),
                ),
                SizedBox(width: largeText ? 0 : 16, height: largeText ? 12 : 0),
                Flexible(
                  flex: largeText ? 0 : 1,
                  child: _Balance(
                    count: q.advertisingRemaining,
                    label: text.continuationBalanceCardVideoRemaining,
                    semantics:
                        text.continuationBalanceCardVideoCreditsRemaining,
                    countKey: const Key('ad-credits-remaining'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const WeeklyRenewalLabel(),
            if (q.weeklyLimitReached || q.suggestsRewardedVideo) ...[
              const SizedBox(height: 10),
              Text(
                q.weeklyLimitReached
                    ? text.creditRecoveryWeeklyLimit
                    : text.creditRecoveryWatchDescription,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              HistaeButton.textIcon(
                key: const Key('open-credits'),
                onPressed: onOpenCredits,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(text.continuationBalanceCardViewCredits),
              ),
              if (ready && !q.premium)
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
                    size: 18,
                  ),
                  label: Text(
                    q.weeklyLimitReached
                        ? text.creditRecoveryViewSubscriptions
                        : q.suggestsRewardedVideo
                        ? text.rewardVideoCardWatchAVideo
                        : text.continuationBalanceCardVideos,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.count,
    required this.label,
    required this.semantics,
    required this.countKey,
  });
  final int count;
  final String label, semantics;
  final Key countKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.of(context).messages
        .continuationBalanceCard(semantics, count),
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          key: countKey,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
