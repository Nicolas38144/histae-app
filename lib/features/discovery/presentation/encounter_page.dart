import 'package:flutter/material.dart';

import '../../../core/widgets/editorial_card.dart';
import '../../profile/presentation/profile_editors.dart';
import '../application/discovery_controller.dart';

class EncounterPage extends StatelessWidget {
  const EncounterPage({
    super.key,
    required this.controller,
    required this.receipt,
    this.openMatch,
  });
  final DiscoveryController controller;
  final EncounterReceipt receipt;
  final Future<void> Function()? openMatch;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.accessible ||
          controller.encounter?.match.id != receipt.match.id) {
        return Scaffold(
          appBar: AppBar(title: const Text('Votre rencontre')),
          body: const Center(
            child: Text('Cette rencontre n’est plus disponible ici.'),
          ),
        );
      }
      final created = receipt.match.createdAt.toLocal();
      // This screen acknowledges the server-created match. It does not infer
      // live chat access, continuation or photo revelation from this snapshot.
      return Scaffold(
        appBar: AppBar(title: const Text('Une rencontre')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              EditorialCard(
                eyebrow: 'UN INTÉRÊT RÉCIPROQUE',
                title: 'Les mots vous\nont rapprochés.',
                body:
                    'Vous et ${receipt.profile.firstname} vous êtes choisis. Une rencontre a été créée dans Histae.',
              ),
              const SizedBox(height: 24),
              Text(
                '${receipt.profile.firstname}, ${receipt.profile.age}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Rencontre créée le ${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}.',
              ),
              const SizedBox(height: 20),
              const Text(
                'Vos photos restent privées. Cette rencontre ne vaut pas accord pour les révéler.',
              ),
              const SizedBox(height: 24),
              if (openMatch != null)
                FilledButton.icon(
                  onPressed: () async {
                    controller.deactivate();
                    await openMatch!();
                    if (context.mounted && controller.accessible) {
                      await controller.activate();
                    }
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Ouvrir la conversation'),
                ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Revenir aux découvertes'),
              ),
              TextButton(
                onPressed: controller.busy
                    ? null
                    : () async {
                        if (!await confirmProfileAction(
                              context,
                              'Bloquer cette personne ?',
                              'Votre rencontre sera terminée et vous ne pourrez plus échanger.',
                              action: 'Bloquer',
                            ) ||
                            !context.mounted) {
                          return;
                        }
                        if (!controller.active) await controller.activate();
                        await controller.blockProfile(receipt.profile);
                        if (context.mounted && controller.encounter == null) {
                          Navigator.of(context).pop();
                        }
                      },
                child: const Text('Bloquer cette personne'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
