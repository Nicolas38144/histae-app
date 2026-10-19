import 'package:flutter/material.dart';

import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/discovery_models.dart';
import 'discovery_strings.dart';

class DiscoveryReadinessIntro extends StatelessWidget {
  const DiscoveryReadinessIntro({super.key, required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) => EditorialCard(
    eyebrow: 'AVANT LA RENCONTRE',
    title: paused ? 'Prenez votre temps.' : 'Un peu de vous.\nPuis les autres.',
    body: paused
        ? 'Les nouvelles rencontres attendront. Vos matchs et vos conversations restent accessibles.'
        : 'Complétez ces étapes à votre rythme. Vos choix de vie privée restent accessibles.',
  );
}

class DiscoveryReadinessCard extends StatelessWidget {
  const DiscoveryReadinessCard({
    super.key,
    required this.action,
    required this.onRepair,
  });

  final DiscoveryAction action;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DiscoveryStrings.actionTitle(action),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(DiscoveryStrings.actionBody(action)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRepair,
            child: Text(
              action == DiscoveryAction.freshPresence
                  ? 'Actualiser ma position'
                  : action == DiscoveryAction.resumeDiscovery
                  ? 'Reprendre la découverte'
                  : 'Compléter cette étape',
            ),
          ),
        ],
      ),
    ),
  );
}

class DiscoveryPendingChoiceCard extends StatelessWidget {
  const DiscoveryPendingChoiceCard({
    super.key,
    required this.intent,
    required this.uncertain,
    required this.onResume,
  });

  final PendingChoice intent;
  final bool uncertain;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Votre choix pour ${intent.profile.firstname}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            uncertain
                ? 'La réponse n’est pas confirmée. Votre choix reste en mémoire ; seul le même choix sera renvoyé.'
                : 'Votre demande attend sa confirmation. Aucun autre choix ne sera envoyé pour ce profil.',
          ),
          const SizedBox(height: 20),
          HistaeButton(
            onPressed: onResume,
            child: Text(DiscoveryStrings.pending(intent.action)),
          ),
        ],
      ),
    ),
  );
}
