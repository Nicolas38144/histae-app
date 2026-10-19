import 'package:flutter/material.dart';

import '../../../core/models/public_profile_answer.dart';
import '../../../core/widgets/editorial_card.dart';

/// The same public text layout is used in discovery and the owner's preview.
class FeedProfileContent extends StatelessWidget {
  const FeedProfileContent({
    super.key,
    required this.firstname,
    required this.age,
    required this.bio,
    required this.distanceLabel,
    required this.traits,
    required this.answers,
  });

  final String firstname, distanceLabel;
  final int age;
  final String? bio;
  final List<String> traits;
  final List<PublicProfileAnswer> answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AU FIL DES MOTS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            '$firstname, $age',
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 46),
          ),
        ),
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
              child: Text(distanceLabel, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
        if (bio != null && bio!.isNotEmpty) ...[
          const EditorialDivider(),
          Text(
            bio!,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              height: 1.55,
            ),
          ),
        ],
        if (traits.isNotEmpty) ...[
          const EditorialDivider(),
          Text('Quelques traits', style: theme.textTheme.titleLarge),
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
          Text(answer.answer, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }
}
