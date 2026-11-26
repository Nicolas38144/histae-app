import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../application/profile_controller.dart';
import 'profile_panels.dart';
import 'profile_section.dart';
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
    final bio = p?.bio?.trim();
    final editable = !c.loading && !c.saving && !c.uncertain;
    final section = ProfileSection.introduction.describe(
      AppStrings.of(context).messages,
      createProfile: p == null,
    );
    return ProfilePanel(
      title: section.title,
      icon: section.icon,
      action: section.action,
      onPressed: editable && !c.errors.containsKey('profile') ? onEdit : null,
      child: c.errors.containsKey('profile')
          ? Text(
              AppStrings.of(context)
                  .messages
                  .profileSectionsYourIntroductionCouldNotBeRefreshed,
            )
          : Text(
              bio == null || bio.isEmpty
                  ? AppStrings.of(context)
                        .messages
                        .profileSectionsBooksYouLovePlacesYouFeel
                  : bio,
              style: Theme.of(context).textTheme.bodyLarge,
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
    final section = ProfileSection.answers.describe(
      AppStrings.of(context).messages,
    );
    return ProfilePanel(
      title: section.title,
      icon: section.icon,
      count: c.errors.containsKey('answers')
          ? AppStrings.of(context).messages.profileSectionsRefreshNeeded
          : AppStrings.of(context).messages
                .answersEditor3Answers(c.answers.length),
      action: section.action,
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
    final section = ProfileSection.preferences.describe(
      AppStrings.of(context).messages,
      sensitiveAllowed: c.sensitiveAllowed,
    );
    return ProfileDetailTile(
      title: section.title,
      icon: section.icon,
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
      action: section.action,
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
    final section = ProfileSection.traits.describe(
      AppStrings.of(context).messages,
    );
    return ProfileDetailTile(
      title: section.title,
      icon: section.icon,
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
      action: section.action,
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
    final text = AppStrings.of(context).messages;
    final profileUnavailable = c.errors.containsKey('profile');
    final section = ProfileSection.photo.describe(text);
    return ProfileDetailTile(
      title: section.title,
      icon: section.icon,
      summary: profileUnavailable
          ? text.profilePhotoLoadFailed
          : text.profileSectionsOnePhotoRevealedAfterMutualConsent,
      action: section.action,
      onTap: c.profile != null && !c.loading && !profileUnavailable
          ? onEdit
          : null,
    );
  }
}
