import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/discovery_models.dart';
import 'discovery_strings.dart';

class DiscoveryReadinessIntro extends StatelessWidget {
  const DiscoveryReadinessIntro({super.key, required this.paused});
  final bool paused;

  @override
  Widget build(BuildContext context) => EditorialCard(
    eyebrow: AppStrings.of(context)
        .messages
        .discoveryStatusSectionsBeforeYouMeet,
    title: paused
        ? AppStrings.of(context).messages.discoveryStatusSectionsTakeYourTime
        : AppStrings.of(context)
              .messages
              .discoveryStatusSectionsALittleAboutYouThenThe,
    body: paused
        ? AppStrings.of(context)
              .messages
              .discoveryStatusSectionsNewEncountersCanWaitYourMatches
        : AppStrings.of(context)
              .messages
              .discoveryStatusSectionsCompleteTheseStepsAtYourOwn,
  );
}

class DiscoveryReadinessCard extends StatelessWidget {
  const DiscoveryReadinessCard({
    super.key,
    required this.action,
    required this.onRepair,
  });
  final DiscoveryAction action;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DiscoveryStrings(AppStrings.of(context)).actionTitle(action),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(DiscoveryStrings(AppStrings.of(context)).actionBody(action)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRepair,
            child: Text(
              action == DiscoveryAction.freshPresence
                  ? AppStrings.of(context)
                        .messages
                        .discoveryPageRefreshMyLocation
                  : action == DiscoveryAction.resumeDiscovery
                  ? AppStrings.of(context)
                        .messages
                        .discoveryStatusSectionsResumeDiscovery
                  : AppStrings.of(context)
                        .messages
                        .discoveryStatusSectionsCompleteThisStep,
            ),
          ),
        ],
      ),
    ),
  );
}

class DiscoveryPendingChoiceCard extends StatelessWidget {
  const DiscoveryPendingChoiceCard({
    super.key,
    required this.intent,
    required this.uncertain,
    required this.onResume,
  });
  final PendingChoice intent;
  final bool uncertain;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.of(context).messages
                .discoveryStatusSectionsYourChoiceFor(intent.profile.firstname),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            uncertain
                ? AppStrings.of(context)
                      .messages
                      .discoveryStatusSectionsTheResponseIsUnconfirmedYourChoice
                : AppStrings.of(context)
                      .messages
                      .discoveryStatusSectionsYourRequestIsAwaitingConfirmationNo,
          ),
          const SizedBox(height: 20),
          HistaeButton(
            onPressed: onResume,
            child: Text(
              DiscoveryStrings(AppStrings.of(context)).pending(intent.action),
            ),
          ),
        ],
      ),
    ),
  );
}
