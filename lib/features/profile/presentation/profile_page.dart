import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../billing/presentation/billing_scope.dart';
import '../../billing/presentation/subscription_page.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../../consents/presentation/consents_page.dart';
import '../../continuation/application/continuation_controller.dart';
import '../../continuation/presentation/credits_page.dart';
import '../../notifications/presentation/devices_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../../privacy/presentation/privacy_hub_page.dart';
import '../application/profile_controller.dart';
import 'photo_page.dart';
import 'profile_editors.dart';
import 'profile_strings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.continuation,
    this.catalog,
  });
  final ProfileController controller;
  final ContinuationController continuation;
  final CatalogRepository? catalog;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  ProfileController get controller => widget.controller;
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onTap, child: Text(action)),
            ],
          ),
        ),
      );
      final editable = !c.loading && !c.saving && !c.uncertain;
      return HistaeScaffold(
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
                              : ConsentsPage(session: controller.session),
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
                Text(
                  'Votre compte',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      _open(CreditsPage(controller: widget.continuation)),
                  child: const Text('Mes crédits de continuation'),
                ),
                TextButton(
                  onPressed: () =>
                      _open(PrivacyHubPage(session: controller.session)),
                  child: Text(strings.privacyTitle),
                ),
                TextButton.icon(
                  onPressed: () => _open(
                    DevicesPage(
                      session: controller.session,
                      push: PushScope.maybeOf(context),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Appareils et notifications'),
                ),
                OutlinedButton(
                  onPressed: () {
                    final billing = BillingScope.maybeOf(context);
                    _open(
                      billing == null
                          ? CatalogPage(repository: widget.catalog)
                          : SubscriptionPage(
                              controller: billing,
                              catalog: widget.catalog,
                            ),
                    );
                  },
                  child: const Text('Mon abonnement et les formules'),
                ),
                TextButton(
                  onPressed: controller.session.logout,
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
