import 'package:flutter/material.dart';

import '../application/continuation_controller.dart';

/// Displays only server-owned available balances, excluding reserved credits.
class ContinuationBalanceCard extends StatelessWidget {
  const ContinuationBalanceCard({
    super.key,
    required this.controller,
    required this.onVideos,
    this.loading = false,
  });

  final ContinuationController controller;
  final VoidCallback onVideos;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.quota;
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 18;
    Widget balance(
      String label,
      String semantics,
      int count,
      Key key,
    ) => Semantics(
      label: '$semantics : $count',
      excludeSemantics: true,
      child: largeText
          ? Row(
              children: [
                Text('$count', key: key, style: theme.textTheme.headlineSmall),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', key: key, style: theme.textTheme.headlineSmall),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pour continuer', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (loading || c.loading) ...[
              const Text('Actualisation de vos crédits…'),
            ] else if (q == null || c.quotaReadAt == null) ...[
              const Text(
                'Votre solde ne peut pas être vérifié pour le moment.',
              ),
              TextButton.icon(
                onPressed: c.retrySeconds > 0 ? null : c.activate,
                icon: const Icon(Icons.refresh),
                label: Text(
                  c.retrySeconds > 0
                      ? 'Réessayer dans ${c.retrySeconds} s'
                      : 'Actualiser les crédits',
                ),
              ),
            ] else if (q.premium) ...[
              Text('Premium', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Vos continuations ne nécessitent aucun crédit.'),
            ] else ...[
              Flex(
                direction: largeText ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: largeText ? 0 : 1,
                    child: balance(
                      'Gratuits restants',
                      'Crédits gratuits restants',
                      q.freeRemaining,
                      const Key('free-credits-remaining'),
                    ),
                  ),
                  SizedBox(
                    width: largeText ? 0 : 16,
                    height: largeText ? 16 : 0,
                  ),
                  Flexible(
                    flex: largeText ? 0 : 1,
                    child: balance(
                      'Publicitaires restants',
                      'Crédits publicitaires restants',
                      q.advertisingRemaining,
                      const Key('ad-credits-remaining'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('open-videos'),
                onPressed: onVideos,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Vidéos'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
