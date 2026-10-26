import 'package:flutter/material.dart';

class EditorialDivider extends StatelessWidget {
  const EditorialDivider({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Divider(height: 1),
    ),
  );
}

/// Shared section heading, with the same hierarchy as the website's intros.
class EditorialCard extends StatelessWidget {
  const EditorialCard({
    super.key,
    required this.title,
    this.body,
    this.eyebrow,
  });
  final String title;
  final String? body;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Semantics(
            header: true,
            child: Text(
              title.replaceAll('\n', ' '),
              style: theme.textTheme.headlineLarge,
            ),
          ),
          if (body case final description?) ...[
            const SizedBox(height: 12),
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
