import 'package:flutter/material.dart';

import 'connection_artwork.dart';

/// A quiet invitation, with no invented people, activity or promises.
class HistaeEmptyState extends StatelessWidget {
  const HistaeEmptyState({super.key, required this.title, required this.body});

  final String title, body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ConnectionArtwork(height: 96, framed: false),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
