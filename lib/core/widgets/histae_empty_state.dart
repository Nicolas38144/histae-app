import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';
import 'connection_artwork.dart';

/// A quiet invitation, with no invented people, activity or promises.
class HistaeEmptyState extends StatelessWidget {
  const HistaeEmptyState({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: HistaeTokens.sectionSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ConnectionArtwork(height: 96, framed: false),
          const SizedBox(height: HistaeTokens.sectionSpacing),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineSmall),
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
