import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/account_benefits_actions.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../billing/presentation/billing_scope.dart';
import '../../billing/presentation/subscription_page.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../../consents/presentation/consents_page.dart';
import '../../continuation/application/continuation_controller.dart';
import '../../continuation/presentation/credits_page.dart';
import '../../discovery/application/discovery_visibility_controller.dart';
import '../../discovery/presentation/discovery_pause_card.dart';
import '../../notifications/presentation/devices_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../../privacy/presentation/privacy_hub_page.dart';
import '../application/profile_controller.dart';
import 'photo_page.dart';
import 'profile_editors.dart';
import 'profile_feed_preview_page.dart';
import 'profile_sections.dart';
import 'profile_strings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.continuation,
    this.catalog,
    this.visibility,
  });
  final ProfileController controller;
  final ContinuationController continuation;
  final CatalogRepository? catalog;
  final DiscoveryVisibilityController? visibility;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  ProfileController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    await Future.wait([
      controller.load(),
      widget.continuation.activate(),
      if (widget.visibility case final visibility?) visibility.load(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A credits route owns its quota while native consent/video UI is visible.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.continuation.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.continuation.suspend(notify: false);
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    widget.continuation.suspend();
    final route = MaterialPageRoute<void>(builder: (_) => page);
    await Navigator.of(context).push(route);
    await route.completed;
    if (mounted) unawaited(_load());
  }

  void _openSubscription() {
    final billing = BillingScope.maybeOf(context);
    _open(
      billing == null
          ? CatalogPage(repository: widget.catalog)
          : SubscriptionPage(controller: billing, catalog: widget.catalog),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, widget.continuation]),
    builder: (context, _) {
      final c = controller;
      final p = c.profile;
      final strings = AppStrings.of(context);
      final editable = !c.loading && !c.saving && !c.uncertain;
      return HistaeScaffold(
        appBar: AppBar(title: Text(strings.accountTitle)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AccountBenefitsActions(
                  isPremium: widget.continuation.quotaReadAt == null
                      ? null
                      : widget.continuation.quota?.premium,
                  onSubscription: _openSubscription,
                ),
                const SizedBox(height: 24),
                EditorialCard(
                  eyebrow: 'VOTRE PROFIL',
                  title: p == null
                      ? 'Une rencontre\ncommence par vous.'
                      : 'Les mots de\n${p.firstname}.',
                  body: 'Une façon de vous raconter, avant de vous rencontrer. Votre photo restera absente du feed.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('profile-feed-preview'),
                  onPressed: editable && c.hasFeedPreview
                      ? () => _open(ProfileFeedPreviewPage(controller: c))
                      : null,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Aperçu de mon profil'),
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
                if (widget.visibility case final visibility?) ...[
                  DiscoveryPauseCard(controller: visibility),
                  const SizedBox(height: 16),
                ],
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
                ProfileIntroductionCard(
                  controller: c,
                  onEdit: () => _open(IdentityEditor(controller: c)),
                ),
                const SizedBox(height: 12),
                ProfileAnswersCard(
                  controller: c,
                  onEdit: () => _open(AnswersEditor(controller: c)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Les détails qui comptent.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                ProfilePreferencesTile(
                  controller: c,
                  onEdit: () => _open(
                    c.sensitiveAllowed
                        ? PreferencesEditor(controller: c)
                        : ConsentsPage(session: c.session),
                  ),
                ),
                ProfileTraitsTile(
                  controller: c,
                  onEdit: () => _open(TraitsEditor(controller: c)),
                ),
                ProfilePhotoTile(
                  controller: c,
                  onEdit: () => _open(PhotoPage(controller: c)),
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
