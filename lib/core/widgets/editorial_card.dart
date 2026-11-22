import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

class EditorialDivider extends StatelessWidget {
  const EditorialDivider({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: HistaeTokens.sectionSpacing),
      child: Divider(height: 1),
    ),
  );
}

/// Shared section heading with an optional description.
class EditorialCard extends StatelessWidget {
  const EditorialCard({super.key, required this.title, this.body});
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HistaeTokens.textSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.replaceAll('\n', ' '),
              style: theme.textTheme.headlineLarge,
            ),
          ),
          if (body case final description?) ...[
            const SizedBox(height: HistaeTokens.textSpacing),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
