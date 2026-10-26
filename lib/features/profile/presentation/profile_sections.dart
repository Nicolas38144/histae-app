import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../application/profile_controller.dart';
import 'profile_panels.dart';
import 'profile_strings.dart';

class ProfileIntroductionCard extends StatelessWidget {
  const ProfileIntroductionCard({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.profile;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfilePanel(
      title: AppStrings.of(context).messages.identityEditorAFewWordsAboutYou,
      icon: Icons.format_quote_rounded,
      action: p == null
          ? AppStrings.of(context).messages.profileSectionsCreateMyProfile
          : AppStrings.of(context).messages.profileSectionsEditMyIntroduction,
      onPressed: editable && !c.errors.containsKey('profile') ? onEdit : null,
      child: c.errors.containsKey('profile')
          ? Text(
              AppStrings.of(context)
                  .messages
                  .profileSectionsYourIntroductionCouldNotBeRefreshed,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p?.bio ??
                      AppStrings.of(context)
                          .messages
                          .profileSectionsBooksYouLovePlacesYouFeel,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (p?.bioModeration != null) ...[
                  const SizedBox(height: 12),
                  ProfileModerationLabel(moderation: p!.bioModeration),
                ],
              ],
            ),
    );
  }
}

class ProfileAnswersCard extends StatelessWidget {
  const ProfileAnswersCard({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.profile;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfilePanel(
      title: AppStrings.of(context)
          .messages
          .profileSectionsConversationStarters,
      icon: Icons.chat_bubble_outline_rounded,
      count: c.errors.containsKey('answers')
          ? AppStrings.of(context).messages.profileSectionsRefreshNeeded
          : AppStrings.of(context).messages
                .answersEditor3Answers(c.answers.length),
      action: AppStrings.of(context).messages.profileSectionsWriteMyAnswers,
      onPressed:
          editable &&
              p != null &&
              !c.errors.containsKey('questions') &&
              !c.errors.containsKey('answers')
          ? onEdit
          : null,
      child: ProfileAnswersPreview(
        answers: c.answers,
        unavailable: c.errors.containsKey('answers'),
      ),
    );
  }
}

class ProfilePreferencesTile extends StatelessWidget {
  const ProfilePreferencesTile({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfileDetailTile(
      title: AppStrings.of(context)
          .messages
          .discoveryStringsYourDatingPreferences,
      icon: Icons.tune_rounded,
      summary: c.errors.containsKey('preferences')
          ? AppStrings.of(context)
                .messages
                .profileSectionsYourPreferencesCouldNotBeRefreshed
          : c.preferences == null
          ? AppStrings.of(context)
                .messages
                .profileSectionsThePeopleAgesAndDistanceThat
          : AppStrings.of(context).messages.profileSectionsAgesKm(
              ProfileStrings(AppStrings.of(context))
                  .lookingFor[c.preferences!.lookingFor]!,
              c.preferences!.minAge,
              c.preferences!.maxAge,
              c.preferences!.distance,
            ),
      action: c.sensitiveAllowed
          ? AppStrings.of(context).messages.profileSectionsEditMyPreferences
          : AppStrings.of(context).messages.profileSectionsChooseMyConsents,
      onTap: editable && !c.errors.containsKey('preferences') ? onEdit : null,
    );
  }
}

class ProfileTraitsTile extends StatelessWidget {
  const ProfileTraitsTile({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfileDetailTile(
      title: AppStrings.of(context).messages.profileSectionsWhatMakesYouYou,
      icon: Icons.spa_outlined,
      summary: c.errors.containsKey('selectedTraits')
          ? AppStrings.of(context)
                .messages
                .profileSectionsYourTraitsCouldNotBeRefreshed
          : c.selectedTraits.isEmpty
          ? AppStrings.of(context).messages.profileSectionsAFewTraitsToShowYour
          : AppStrings.of(context)
                .messages
                .profileSectionsTheTraitsYouChoseToTell,
      details:
          c.errors.containsKey('selectedTraits') || c.selectedTraits.isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final trait in c.selectedTraits)
                  Chip(label: Text(trait.name)),
              ],
            ),
      action: AppStrings.of(context).messages.profileSectionsChooseMyTraits,
      onTap:
          editable &&
              !c.errors.containsKey('traits') &&
              !c.errors.containsKey('selectedTraits')
          ? onEdit
          : null,
    );
  }
}

class ProfilePhotoTile extends StatelessWidget {
  const ProfilePhotoTile({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.profile;
    return ProfileDetailTile(
      title: AppStrings.of(context).messages.profileSectionsAPhotoForLater,
      icon: Icons.photo_outlined,
      summary: c.errors.containsKey('profile')
          ? AppStrings.of(context).messages.profilePhotoLoadFailed
          : p?.photo == null
          ? AppStrings.of(context)
                .messages
                .profileSectionsOnePhotoRevealedAfterMutualConsent
          : AppStrings.of(context).messages.photoPageSaved,
      action: AppStrings.of(context).messages.profileSectionsManageMyPhoto,
      onTap: p != null && !c.loading && !c.errors.containsKey('profile')
          ? onEdit
          : null,
    );
  }
}
