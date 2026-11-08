import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/profile_models.dart';
import 'profile_strings.dart';

/// Displays the latest owner snapshot without creating editable identity state.
class ProfileIdentitySummary extends StatelessWidget {
  const ProfileIdentitySummary({super.key, required this.profile});

  final OwnerProfile profile;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final text = strings.messages;
    final birthdate = MaterialLocalizations.of(context)
        .formatCompactDate(parseBirthdate(profile.birthdate)!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _detail(context, text.identityEditorFirstName, profile.firstname),
        _detail(context, text.identityEditorDateOfBirth, birthdate),
        _detail(
          context,
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

  Widget _detail(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: HistaeTokens.contentSpacing),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
