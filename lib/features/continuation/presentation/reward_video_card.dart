import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/continuation_controller.dart';
import '../application/rewarded_video_controller.dart';
import '../data/continuation_models.dart';
import 'continuation_strings.dart';

class RewardVideoCard extends StatelessWidget {
  const RewardVideoCard({
    super.key,
    required this.credits,
    required this.video,
    required this.onCancel,
  });
  final ContinuationController credits;
  final RewardedVideoController video;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final r = credits.rewards, intent = r.intent;
    final pending = intent != null && r.canPoll;
    final label = switch (video.phase) {
      VideoPhase.idle => AppStrings.of(
        context,
      ).messages.rewardVideoCardWatchAVideo,
      VideoPhase.checking => AppStrings.of(
        context,
      ).messages.rewardVideoCardChecking,
      VideoPhase.consent || VideoPhase.privacy => AppStrings.of(
        context,
      ).messages.rewardVideoCardYourPreferences,
      VideoPhase.loading => AppStrings.of(
        context,
      ).messages.rewardVideoCardLoadingVideo,
      VideoPhase.playing => AppStrings.of(
        context,
      ).messages.rewardVideoCardVideoPlaying,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 28,
                  color: colors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppStrings.of(context).messages.rewardVideoCardAHelpingHand,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context)
                  .messages
                  .rewardVideoCardAVideoForTheNextChapter,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context).messages
                  .videoCreditReward(intent?.credits ?? 1),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context)
                  .messages
                  .rewardVideoCardIfYouWishWatchAVideo,
            ),
            const SizedBox(height: 20),
            HistaeButton.icon(
              key: const Key('watch-rewarded-video'),
              onPressed: video.canWatch ? video.watch : null,
              icon: video.busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(label),
            ),
            const SizedBox(height: 12),
            if (video.unavailableReason case final reason?)
              Text(
                AppStrings.of(context).clientMessage(reason),
                style: theme.textTheme.bodySmall,
              )
            else if (!pending)
              Text(
                AppStrings.of(context)
                    .messages
                    .rewardVideoCardAlwaysOptionalTheCreditAppearsAfter,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (video.message case final message?) ...[
              const SizedBox(height: 12),
              _Status(
                text: AppStrings.of(context).clientMessage(message),
                icon: Icons.info_outline,
              ),
            ],
            if (intent != null) ...[
              const SizedBox(height: 16),
              _Status(
                icon: intent.status == RewardStatus.credited
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined,
                text: switch (intent.status) {
                  RewardStatus.pending =>
                    r.completedVideo
                        ? AppStrings.of(context)
                              .messages
                              .rewardVideoCardVideoCompletedYourRewardIsBeing
                        : AppStrings.of(context)
                              .messages
                              .rewardVideoCardYourRequestIsReadyYouCan,
                  RewardStatus.credited => AppStrings.of(
                    context,
                  ).messages.videoRewardConfirmed(intent.credits),
                  RewardStatus.expired => AppStrings.of(
                    context,
                  ).messages.rewardVideoCardTheRequestExpiredAVideoCompleted,
                  RewardStatus.cancelled => AppStrings.of(
                    context,
                  ).messages.rewardVideoCardThisRequestWasCanceled,
                },
              ),
            ],
            if (r.failure case final error?) ...[
              const SizedBox(height: 12),
              _Status(
                text: ContinuationStrings(AppStrings.of(context))
                    .failure(error),
                icon: Icons.info_outline,
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: r.busy || r.waiting || video.busy ? null : r.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(
                  AppStrings.of(context).messages.rewardVideoCardCheckReward,
                ),
              ),
              TextButton(
                onPressed: r.busy || r.waiting || video.busy ? null : onCancel,
                child: Text(
                  AppStrings.of(context)
                      .messages
                      .rewardVideoCardCancelThisRequest,
                ),
              ),
            ],
            if (video.gateway?.privacyOptionsRequired == true) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: video.busy ? null : video.privacyOptions,
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  AppStrings.of(context)
                      .messages
                      .rewardVideoCardMyAdvertisingChoices,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    ),
  );
}
