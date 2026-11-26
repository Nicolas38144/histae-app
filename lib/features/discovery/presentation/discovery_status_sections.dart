import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../profile/presentation/profile_panels.dart';
import '../../profile/presentation/profile_section.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';
import 'discovery_strings.dart';

class DiscoveryReadinessIntro extends StatelessWidget {
  const DiscoveryReadinessIntro({super.key, required this.paused});
  final bool paused;

  @override
  Widget build(BuildContext context) => EditorialCard(
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
    required this.sensitiveAllowed,
    this.feedback,
  });
  final DiscoveryAction action;
  final VoidCallback? onRepair;
  final bool sensitiveAllowed;
  final Widget? feedback;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final summary = DiscoveryStrings(strings).actionBody(action);
    final section = switch (action) {
      DiscoveryAction.profile ||
      DiscoveryAction.biography => ProfileSection.introduction.describe(
        text,
        createProfile: action == DiscoveryAction.profile,
      ),
      DiscoveryAction.conversationStarters => ProfileSection.answers.describe(
        text,
      ),
      DiscoveryAction.traits => ProfileSection.traits.describe(text),
      DiscoveryAction.photo => ProfileSection.photo.describe(text),
      DiscoveryAction.preferences => ProfileSection.preferences.describe(
        text,
        sensitiveAllowed: sensitiveAllowed,
      ),
      DiscoveryAction.sex => (
        title: text.discoveryStringsYourProfileSSex,
        action: sensitiveAllowed
            ? text.discoveryRequestIdentityCorrection
            : text.profileSectionsChooseMyConsents,
        icon: Icons.badge_outlined,
      ),
      DiscoveryAction.sensitiveConsent => (
        title: text.discoveryStringsSensitiveData,
        action: text.profileSectionsChooseMyConsents,
        icon: Icons.shield_outlined,
      ),
      DiscoveryAction.locationConsent => (
        title: text.discoveryStringsYourLocationChoice,
        action: text.profileSectionsChooseMyConsents,
        icon: Icons.location_on_outlined,
      ),
      DiscoveryAction.freshPresence => (
        title: text.discoveryStringsARecentLocation,
        action: text.discoveryPageRefreshMyLocation,
        icon: Icons.location_on_outlined,
      ),
      DiscoveryAction.resumeDiscovery => (
        title: text.discoveryStringsYourProfileIsPaused,
        action: text.discoveryStatusSectionsResumeDiscovery,
        icon: Icons.pause_circle_outline_rounded,
      ),
    };
    return switch (action) {
      DiscoveryAction.profile ||
      DiscoveryAction.biography ||
      DiscoveryAction.conversationStarters => ProfilePanel(
        title: section.title,
        icon: section.icon,
        action: section.action,
        onPressed: onRepair,
        child: Text(summary),
      ),
      _ => ProfileDetailTile(
        title: section.title,
        icon: section.icon,
        summary: summary,
        action: section.action,
        onTap: onRepair,
        feedback: feedback,
      ),
    };
  }
}

class DiscoveryLocationFeedback extends StatelessWidget {
  const DiscoveryLocationFeedback({
    super.key,
    required this.issue,
    required this.onOpenSettings,
  });

  final LocationIssue issue;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(DiscoveryStrings(AppStrings.of(context)).location(issue)),
        ),
      ),
      if (issue == LocationIssue.deniedForever ||
          issue == LocationIssue.disabled)
        HistaeButton.outlined(
          onPressed: onOpenSettings,
          child: Text(
            AppStrings.of(context).messages.discoveryPageOpenSettings,
          ),
        ),
    ],
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
      padding: HistaeTokens.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.of(context).messages
                .discoveryStatusSectionsYourChoiceFor(intent.profile.firstname),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: HistaeTokens.textSpacing),
          Text(
            uncertain
                ? AppStrings.of(context)
                      .messages
                      .discoveryStatusSectionsTheResponseIsUnconfirmedYourChoice
                : AppStrings.of(context)
                      .messages
                      .discoveryStatusSectionsYourRequestIsAwaitingConfirmationNo,
          ),
          const SizedBox(height: HistaeTokens.labelSpacing),
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
