import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';

/// Stays at the top of the card while its biography scrolls independently.
class FeedReadingProgress extends StatelessWidget {
  const FeedReadingProgress({
    super.key,
    required this.progress,
    required this.remainingSeconds,
  });

  final Animation<double> progress;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) {
      final messages = AppStrings.of(context).messages;
      return Semantics(
        label: messages.feedReadingProgress,
        value: remainingSeconds == 0
            ? messages.feedReadingReady
            : messages.feedReadingCountdown(remainingSeconds),
        child: ExcludeSemantics(
          child: SizedBox(
            height: 3,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.1),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  key: const Key('feed-reading-fill'),
                  widthFactor: progress.value,
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: HistaeTokens.actionGradient,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
