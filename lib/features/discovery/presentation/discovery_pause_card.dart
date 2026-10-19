import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../application/discovery_visibility_controller.dart';

class DiscoveryPauseCard extends StatelessWidget {
  const DiscoveryPauseCard({super.key, required this.controller});
  final DiscoveryVisibilityController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.paused != null && !c.uncertain)
                SwitchListTile(
                  key: const Key('discovery-paused'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode pause'),
                  value: c.paused!,
                  onChanged: c.canChange
                      ? (value) async {
                          try {
                            await c.setPaused(value);
                          } on ApiFailure {
                            // The controller displays failure without inventing success.
                          }
                        }
                      : null,
                )
              else
                Text(
                  'Mode pause',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Text(
                c.uncertain
                    ? 'Votre visibilité reste à vérifier. Actualisez son état avant de modifier ce choix.'
                    : c.paused == true
                    ? 'Votre profil est masqué des nouvelles découvertes. Vos matchs et vos conversations restent accessibles.'
                    : c.paused == false
                    ? 'Faites une pause dans les nouvelles rencontres en masquant votre profil. Vos conversations restent accessibles.'
                    : c.loading
                    ? 'Vérification de votre visibilité…'
                    : 'Votre visibilité ne peut pas être vérifiée pour le moment.',
              ),
              if (c.loading || c.saving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  semanticsLabel: 'Actualisation de votre visibilité',
                ),
              ],
              if (c.failure != null) ...[
                const SizedBox(height: 12),
                const Text('La visibilité n’a pas pu être confirmée.'),
                TextButton(
                  onPressed: c.loading || c.saving || c.retrySeconds > 0
                      ? null
                      : c.load,
                  child: Text(
                    c.retrySeconds > 0
                        ? 'Réessayez dans ${c.retrySeconds} s'
                        : 'Actualiser ma visibilité',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
