import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import 'help_scope.dart';

Future<void> showFeedGuide(BuildContext context) async {
  final controller = HelpScope.maybeOf(context);
  if (controller?.showing == true) return;
  if (controller != null) controller.showing = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final text = AppStrings.of(context).messages;
        return FractionallySizedBox(
          heightFactor: .9,
          child: SingleChildScrollView(
            key: const Key('feed-mini-guide'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text.feedGuideTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(text.feedGuideIntro),
                const SizedBox(height: 24),
                for (final step in [
                  (
                    Icons.timer_outlined,
                    text.feedGuideReadTitle,
                    text.feedGuideReadBody,
                  ),
                  (
                    Icons.favorite_outline,
                    text.feedGuideLikeTitle,
                    text.feedGuideLikeBody,
                  ),
                  (
                    Icons.swipe_up_outlined,
                    text.feedGuidePassTitle,
                    text.feedGuidePassBody,
                  ),
                  (
                    Icons.swipe_outlined,
                    text.feedGuideTabsTitle,
                    text.feedGuideTabsBody,
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          step.$1,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.$2,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(step.$3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                HistaeButton(
                  key: const Key('feed-guide-done'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(text.feedGuideDone),
                ),
              ],
            ),
          ),
        );
      },
    );
    await controller?.markSeen();
  } finally {
    if (controller != null) controller.showing = false;
  }
}
