import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/public_profile_answer.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../reading/domain/reading_preferences.dart';
import '../../reading/presentation/reading_scope.dart';

/// Public profile text shared by discovery, the owner preview and matches.
class FeedProfileContent extends StatelessWidget {
  const FeedProfileContent({
    super.key,
    required this.firstname,
    required this.age,
    required this.bio,
    this.distanceLabel,
    required this.traits,
    required this.answers,
  });
  final String firstname;
  final String? distanceLabel;
  final int age;
  final String? bio;
  final List<String> traits;
  final List<PublicProfileAnswer> answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading =
        ReadingScope.maybeOf(context)?.preferences ??
        const ReadingPreferences();
    final prose = theme.textTheme.bodyLarge?.copyWith(
      fontSize: reading.fontSize,
      height: reading.lineHeight,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).messages.feedProfileContentThroughWords,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            AppStrings.of(context).messages.encounterPage(firstname, age),
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 46),
          ),
        ),
        if (distanceLabel != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(distanceLabel!, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
        ],
        if (bio != null && bio!.isNotEmpty) ...[
          const EditorialDivider(),
          Text(bio!, key: const Key('feed-biography'), style: prose),
        ],
        if (traits.isNotEmpty) ...[
          const EditorialDivider(),
          Text(
            AppStrings.of(context).messages.feedProfileContentAFewTraits,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: traits
                .map(
                  (t) => Chip(
                    label: Text(t),
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                )
                .toList(),
          ),
        ],
        for (final answer in answers) ...[
          const EditorialDivider(),
          Text(answer.question, style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          Text(answer.answer, style: prose),
        ],
      ],
    );
  }
}
