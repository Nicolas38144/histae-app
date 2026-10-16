import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../../consents/presentation/consents_page.dart';
import '../../discovery/application/discovery_controller.dart';
import '../../discovery/data/discovery_repository.dart';
import '../../discovery/data/device_location.dart';
import '../../discovery/presentation/discovery_page.dart';
import '../../matches/application/matches_controller.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/presentation/matches_page.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';
import 'profile_editors.dart';
import 'photo_page.dart';
import 'profile_strings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session, this.catalog});
  final SessionController session;
  final CatalogRepository? catalog;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  late final controller = ProfileController(ProfileRepository(widget.session));
  late final discovery = DiscoveryController(
    DiscoveryRepository(widget.session),
    DeviceLocation(),
  );
  late final matches = MatchesController(
    MatchesRepository(widget.session),
    onRemoved: discovery.forgetEncounter,
  );

  Future<void> _matches([String? id]) =>
      _open(MatchesPage(controller: matches, initialMatchId: id));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(controller.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    matches.dispose();
    discovery.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) unawaited(controller.load());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final p = c.profile;
      final strings = AppStrings.of(context);
      Widget section(
        String title,
        String body,
        String action,
        VoidCallback? onTap,
        IconData icon,
      ) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(body),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onTap, child: Text(action)),
            ],
          ),
        ),
      );
      final editable = !c.loading && !c.saving && !c.uncertain;
      return Scaffold(
        appBar: AppBar(title: Text(strings.accountTitle)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                EditorialCard(
                  eyebrow: 'VOTRE PROFIL',
                  title: p == null
                      ? 'Une rencontre\ncommence par vous.'
                      : 'Les mots de\n${p.firstname}.',
                  body: 'Une façon de vous raconter, avant de vous rencontrer. Votre photo restera absente du feed.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _open(
                    DiscoveryPage(
                      controller: discovery,
                      profile: controller,
                      openMatches: _matches,
                    ),
                  ),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Découvrir les profils'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _matches,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Vos rencontres'),
                ),
                TextButton(
                  onPressed: () => _open(ConsentsPage(session: widget.session)),
                  child: Text(strings.privacyTitle),
                ),
                if (c.loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Chargement du profil',
                  ),
                for (final entry in c.errors.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(ProfileStrings.failure(entry.value)),
                    ),
                  ),
                if (c.uncertain)
                  const Text(
                    'L’enregistrement reste incertain. Relisez les données avant de renouveler une modification. Une demande photo peut être reprise à l’identique.',
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: c.loading || c.saving || c.retrySeconds > 0
                        ? null
                        : c.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      c.retrySeconds > 0
                          ? strings.retryIn(c.retrySeconds)
                          : 'Actualiser mon profil',
                    ),
                  ),
                ),
                section(
                  'Quelques mots sur vous',
                  p == null
                      ? 'Votre prénom, votre majorité et une présentation à votre image.'
                      : '${p.bio ?? 'Ajoutez une présentation.'}\n\nPrésentation : ${ProfileStrings.moderation(p.bioModeration)}',
                  p == null ? 'Créer mon profil' : 'Modifier ma présentation',
                  editable && !c.errors.containsKey('profile')
                      ? () => _open(IdentityEditor(controller: c))
                      : null,
                  Icons.edit_outlined,
                ),
                const SizedBox(height: 16),
                section(
                  'Vos envies de rencontre',
                  c.preferences == null
                      ? 'Les personnes, les âges et la distance qui vous correspondent.'
                      : '${ProfileStrings.lookingFor[c.preferences!.lookingFor]} · ${c.preferences!.minAge}–${c.preferences!.maxAge} ans · ${c.preferences!.distance} km',
                  c.sensitiveAllowed
                      ? 'Modifier mes préférences'
                      : 'Choisir mes consentements',
                  editable && !c.errors.containsKey('preferences')
                      ? () => _open(
                          c.sensitiveAllowed
                              ? PreferencesEditor(controller: c)
                              : ConsentsPage(session: widget.session),
                        )
                      : null,
                  Icons.tune,
                ),
                const SizedBox(height: 16),
                section(
                  'Ce qui vous ressemble',
                  c.selectedTraits.isEmpty
                      ? 'Quelques traits, choisis parmi ceux proposés par Histae.'
                      : c.selectedTraits.map((t) => t.name).join(' · '),
                  'Choisir mes traits',
                  editable &&
                          !c.errors.containsKey('traits') &&
                          !c.errors.containsKey('selectedTraits')
                      ? () => _open(TraitsEditor(controller: c))
                      : null,
                  Icons.spa_outlined,
                ),
                const SizedBox(height: 16),
                section(
                  'Des débuts de conversation',
                  '${c.answers.length} réponse(s) sur 3. Racontez vos habitudes, vos envies ou ce qui vous anime.',
                  'Écrire mes réponses',
                  editable &&
                          p != null &&
                          !c.errors.containsKey('questions') &&
                          !c.errors.containsKey('answers')
                      ? () => _open(AnswersEditor(controller: c))
                      : null,
                  Icons.chat_bubble_outline,
                ),
                const SizedBox(height: 16),
                section(
                  'Une photo, pour plus tard',
                  p?.photo == null
                      ? 'Une seule photo. Elle se révélera après votre accord mutuel.'
                      : ProfileStrings.moderation(p?.photoModeration),
                  'Gérer ma photo',
                  p != null && !c.loading && !c.errors.containsKey('profile')
                      ? () => _open(PhotoPage(controller: c))
                      : null,
                  Icons.photo_outlined,
                ),
                const EditorialDivider(),
                OutlinedButton(
                  onPressed: () =>
                      _open(CatalogPage(repository: widget.catalog)),
                  child: Text(strings.catalogAction),
                ),
                TextButton(
                  onPressed: widget.session.logout,
                  child: Text(strings.logout),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
