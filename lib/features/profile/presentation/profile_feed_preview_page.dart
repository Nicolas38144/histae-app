import 'package:flutter/material.dart';

import '../../../core/models/public_profile_answer.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../discovery/presentation/feed_profile_content.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';

class ProfileFeedPreviewPage extends StatefulWidget {
  const ProfileFeedPreviewPage({super.key, required this.controller});

  final ProfileController controller;

  @override
  State<ProfileFeedPreviewPage> createState() => _ProfileFeedPreviewPageState();
}

class _ProfileFeedPreviewPageState extends State<ProfileFeedPreviewPage> {
  late final _resourceKey = widget.controller.session.resourceKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.accessible || c.session.resourceKey != _resourceKey) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final profile = c.profile;
      final unavailable =
          profile == null ||
          ['profile', 'answers', 'selectedTraits'].any(c.errors.containsKey);
      final birthdate = profile == null
          ? null
          : parseBirthdate(profile.birthdate);
      final today = DateTime.now().toUtc();
      final age = birthdate == null
          ? null
          : today.year -
                birthdate.year -
                (today.month < birthdate.month ||
                        (today.month == birthdate.month &&
                            today.day < birthdate.day)
                    ? 1
                    : 0);
      final answers =
          c.answers
              .where((answer) => answer.moderation.status == 'approved')
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));
      return HistaeScaffold(
        appBar: AppBar(title: const Text('Mon profil dans le feed')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Comme au fil des mots.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Voici les éléments de votre profil présentés aux autres. '
                    'Seuls les textes approuvés sont affichés. Votre photo reste absente du feed.',
                  ),
                  const SizedBox(height: 20),
                  if (c.loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Actualisation de votre aperçu',
                    ),
                  if (unavailable || age == null)
                    const Text(
                      'Votre aperçu ne peut pas être affiché. Revenez à votre profil pour le compléter ou actualisez vos informations.',
                    )
                  else
                    Card(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: HistaeTokens.panelGradient(context),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FeedProfileContent(
                            firstname: profile.firstname,
                            age: age,
                            bio: profile.bioModeration?.status == 'approved'
                                ? profile.bio
                                : null,
                            distanceLabel: 'Distance selon la personne',
                            traits: [
                              for (final trait in c.selectedTraits) trait.name,
                            ],
                            answers: [
                              for (final answer in answers)
                                PublicProfileAnswer(
                                  answer.questionId,
                                  answer.question,
                                  answer.answer,
                                  answer.position,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
