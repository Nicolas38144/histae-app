import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/continuation_models.dart';

/// Suggests a recovery action without treating reserved credits as spent quota.
class CreditRecoveryCard extends StatelessWidget {
  const CreditRecoveryCard({
    super.key,
    required this.quota,
    required this.onWatchVideo,
    required this.onOpenSubscription,
    this.enabled = true,
  });

  final ContinuationQuota quota;
  final VoidCallback onWatchVideo, onOpenSubscription;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    final subscription = quota.weeklyLimitReached;
    if (!subscription && !quota.suggestsRewardedVideo) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              subscription
                  ? text.creditRecoveryWeeklyTitle
                  : text.creditRecoveryFreeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              subscription
                  ? text.creditRecoveryWeeklyLimit
                  : text.creditRecoveryWatchDescription,
            ),
            const SizedBox(height: 20),
            HistaeButton.icon(
              key: Key(subscription ? 'credit-subscription' : 'credit-video'),
              onPressed: enabled
                  ? (subscription ? onOpenSubscription : onWatchVideo)
                  : null,
              icon: Icon(
                subscription
                    ? Icons.auto_awesome_outlined
                    : Icons.play_circle_outline_rounded,
              ),
              label: Text(
                subscription
                    ? text.creditRecoveryViewSubscriptions
                    : text.rewardVideoCardWatchAVideo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
