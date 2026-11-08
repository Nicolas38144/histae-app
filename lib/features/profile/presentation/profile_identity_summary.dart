import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/profile_models.dart';
import 'birthdate_field.dart';
import 'profile_strings.dart';

/// Displays the latest owner snapshot without creating editable identity state.
class ProfileIdentitySummary extends StatelessWidget {
  const ProfileIdentitySummary({super.key, required this.profile});

  final OwnerProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(text.identityEditorFirstName, profile.firstname),
        Padding(
          padding: const EdgeInsets.only(bottom: HistaeTokens.panelInset),
          child: BirthdateField(
            key: const Key('profile-birthdate'),
            value: parseBirthdate(profile.birthdate),
          ),
        ),
        _field(
          text.identityEditorSex,
          ProfileStrings(strings).sexes[profile.sex ?? '']!,
        ),
        Text(
          text.profileIdentityLocked,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: HistaeTokens.panelInset),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: false),
      child: Text(value),
    ),
  );
}
