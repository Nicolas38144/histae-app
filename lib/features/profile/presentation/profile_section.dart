import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_messages.dart';

/// The titles, actions and icons shared by Profile and feed setup.
enum ProfileSection {
  introduction(Icons.format_quote_rounded),
  answers(Icons.chat_bubble_outline_rounded),
  preferences(Icons.tune_rounded),
  traits(Icons.spa_outlined),
  photo(Icons.photo_outlined);

  const ProfileSection(this.icon);
  final IconData icon;

  ({String title, String action, IconData icon}) describe(
    AppMessages text, {
    bool createProfile = false,
    bool sensitiveAllowed = true,
  }) => switch (this) {
    ProfileSection.introduction => (
      title: text.identityEditorAFewWordsAboutYou,
      action: createProfile
          ? text.profileSectionsCreateMyProfile
          : text.profileSectionsEditMyIntroduction,
      icon: icon,
    ),
    ProfileSection.answers => (
      title: text.profileSectionsConversationStarters,
      action: text.profileSectionsWriteMyAnswers,
      icon: icon,
    ),
    ProfileSection.preferences => (
      title: text.discoveryStringsYourDatingPreferences,
      action: sensitiveAllowed
          ? text.profileSectionsEditMyPreferences
          : text.profileSectionsChooseMyConsents,
      icon: icon,
    ),
    ProfileSection.traits => (
      title: text.profileSectionsWhatMakesYouYou,
      action: text.profileSectionsChooseMyTraits,
      icon: icon,
    ),
    ProfileSection.photo => (
      title: text.profileSectionsAPhotoForLater,
      action: text.profileSectionsManageMyPhoto,
      icon: icon,
    ),
  };
}
