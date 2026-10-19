import 'package:flutter/material.dart';

import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../discovery/presentation/feed_profile_content.dart';
import '../application/profile_controller.dart';

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
      final preview = c.feedPreviewAt(DateTime.now().toUtc());
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
                  if (preview == null)
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
                            firstname: preview.firstname,
                            age: preview.age,
                            bio: preview.bio,
                            distanceLabel: 'Distance selon la personne',
                            traits: preview.traits,
                            answers: preview.answers,
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
