import 'package:flutter/material.dart';

import '../application/profile_controller.dart';
import 'profile_panels.dart';
import 'profile_strings.dart';

class ProfileIntroductionCard extends StatelessWidget {
  const ProfileIntroductionCard({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.profile;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfilePanel(
      title: 'Quelques mots sur vous',
      icon: Icons.format_quote_rounded,
      action: p == null ? 'Créer mon profil' : 'Modifier ma présentation',
      onPressed: editable && !c.errors.containsKey('profile') ? onEdit : null,
      child: c.errors.containsKey('profile')
          ? const Text('Votre présentation n’a pas pu être relue.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p?.bio ?? 'Les livres que vous aimez, les lieux où vous vous sentez bien… Quelques mots suffisent pour commencer.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (p?.bioModeration != null) ...[
                  const SizedBox(height: 12),
                  ProfileModerationLabel(moderation: p!.bioModeration),
                ],
              ],
            ),
    );
  }
}

class ProfileAnswersCard extends StatelessWidget {
  const ProfileAnswersCard({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.profile;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfilePanel(
      title: 'Des débuts de conversation',
      icon: Icons.chat_bubble_outline_rounded,
      count: c.errors.containsKey('answers')
          ? 'À actualiser'
          : '${c.answers.length} / 3 réponses',
      action: 'Écrire mes réponses',
      onPressed:
          editable &&
              p != null &&
              !c.errors.containsKey('questions') &&
              !c.errors.containsKey('answers')
          ? onEdit
          : null,
      child: ProfileAnswersPreview(
        answers: c.answers,
        unavailable: c.errors.containsKey('answers'),
      ),
    );
  }
}

class ProfilePreferencesTile extends StatelessWidget {
  const ProfilePreferencesTile({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfileDetailTile(
      title: 'Vos envies de rencontre',
      icon: Icons.tune_rounded,
      summary: c.errors.containsKey('preferences')
          ? 'Vos préférences n’ont pas pu être relues.'
          : c.preferences == null
          ? 'Les personnes, les âges et la distance qui vous correspondent.'
          : '${ProfileStrings.lookingFor[c.preferences!.lookingFor]} · ${c.preferences!.minAge}–${c.preferences!.maxAge} ans · ${c.preferences!.distance} km',
      action: c.sensitiveAllowed
          ? 'Modifier mes préférences'
          : 'Choisir mes consentements',
      onTap: editable && !c.errors.containsKey('preferences') ? onEdit : null,
    );
  }
}

class ProfileTraitsTile extends StatelessWidget {
  const ProfileTraitsTile({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final editable = !c.loading && !c.saving && !c.uncertain;
    return ProfileDetailTile(
      title: 'Ce qui vous ressemble',
      icon: Icons.spa_outlined,
      summary: c.errors.containsKey('selectedTraits')
          ? 'Vos traits n’ont pas pu être relus.'
          : c.selectedTraits.isEmpty
          ? 'Quelques traits pour donner un aperçu de votre personnalité.'
          : 'Les traits que vous avez choisis pour vous raconter.',
      details:
          c.errors.containsKey('selectedTraits') || c.selectedTraits.isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final trait in c.selectedTraits)
                  Chip(label: Text(trait.name)),
              ],
            ),
      action: 'Choisir mes traits',
      onTap:
          editable &&
              !c.errors.containsKey('traits') &&
              !c.errors.containsKey('selectedTraits')
          ? onEdit
          : null,
    );
  }
}

class ProfilePhotoTile extends StatelessWidget {
  const ProfilePhotoTile({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final ProfileController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.profile;
    return ProfileDetailTile(
      title: 'Une photo, pour plus tard',
      icon: Icons.photo_outlined,
      summary: c.errors.containsKey('profile')
          ? 'Votre photo n’a pas pu être vérifiée.'
          : p?.photo == null
          ? 'Une seule photo, révélée après votre accord mutuel.'
          : ProfileStrings.moderation(p?.photoModeration),
      action: 'Gérer ma photo',
      onTap: p != null && !c.loading && !c.errors.containsKey('profile')
          ? onEdit
          : null,
    );
  }
}
