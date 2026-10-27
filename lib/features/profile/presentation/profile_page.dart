import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/language_picker.dart';
import '../../../core/widgets/account_benefits_actions.dart';
import '../../../core/widgets/account_identifier.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
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
import '../../help/presentation/help_page.dart';
import '../../notifications/data/device_repository.dart';
import '../../notifications/presentation/devices_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../../privacy/data/privacy_repository.dart';
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
    this.privacyRepository,
    this.deviceRepository,
  });
  final ProfileController controller;
  final ContinuationController continuation;
  final CatalogRepository? catalog;
  final PrivacyRepository? privacyRepository;
  final DeviceRepository? deviceRepository;
  final DiscoveryVisibilityController? visibility;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureLoaded());
    });
  }

  Future<void> _ensureLoaded() async {
    await Future.wait([
      controller.ensureLoaded(),
      widget.continuation.activate(),
      if (widget.visibility case final visibility?) visibility.ensureLoaded(),
    ]);
  }

  Future<void> _load() async {
    await Future.wait([
      controller.load(),
      _loadBalance(),
      if (widget.visibility case final visibility?) visibility.load(),
    ]);
  }

  Future<void> _loadBalance() async {
    await widget.continuation.refreshQuota();
  }

  @override
  void dispose() {
    widget.continuation.suspend(notify: false);
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    final route = MaterialPageRoute<void>(builder: (_) => page);
    await Navigator.of(context).push(route);
    await route.completed;
    if (mounted) await widget.continuation.activate();
  }

  Future<void> _openSubscription() async {
    final billing = BillingScope.maybeOf(context);
    await _open(
      billing == null
          ? CatalogPage(repository: widget.catalog)
          : SubscriptionPage(controller: billing, catalog: widget.catalog),
    );
    if (mounted &&
        billing?.subscription != null &&
        billing!.fresh &&
        billing.subscription!.accessGranted !=
            widget.continuation.quota?.premium) {
      await widget.continuation.activate();
      await widget.continuation.loadQuota();
    }
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
        appBar: AppBar(
          title: Text(strings.accountTitle),
          actions: [
            IconButton(
              tooltip: c.retrySeconds > 0
                  ? strings.retryIn(c.retrySeconds)
                  : strings.messages.profilePageRefreshMyProfile,
              onPressed: c.loading || c.saving || c.retrySeconds > 0
                  ? null
                  : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const LanguageButton(),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                EditorialCard(
                  eyebrow: AppStrings.of(context)
                      .messages
                      .profilePageYourProfile,
                  title: p == null
                      ? AppStrings.of(context)
                            .messages
                            .profilePageAMeetingStartsWithYou
                      : AppStrings.of(context).messages
                            .profilePageTheWordsOf(p.firstname),
                  body: AppStrings.of(context)
                      .messages
                      .profilePageAWayToTellYourStory,
                ),
                const SizedBox(height: 16),
                HistaeButton.outlinedIcon(
                  key: const Key('profile-feed-preview'),
                  onPressed: editable && c.hasFeedPreview
                      ? () => _open(ProfileFeedPreviewPage(controller: c))
                      : null,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(
                    AppStrings.of(context).messages.profilePagePreviewMyProfile,
                  ),
                ),
                const SizedBox(height: 16),
                if (c.loading)
                  LinearProgressIndicator(
                    semanticsLabel: AppStrings.of(context)
                        .messages
                        .profilePageLoadingProfile,
                  ),
                for (final entry in c.errors.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        ProfileStrings(AppStrings.of(context))
                            .failure(entry.value),
                      ),
                    ),
                  ),
                if (c.uncertain)
                  Text(
                    AppStrings.of(context)
                        .messages
                        .profilePageSavingIsUncertainRefreshTheData,
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
                  AppStrings.of(context)
                      .messages
                      .profilePageTheDetailsThatMatter,
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
                if (widget.visibility case final visibility?) ...[
                  const EditorialDivider(),
                  Semantics(
                    header: true,
                    child: Text(
                      strings.messages.profileAtYourPace,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DiscoveryPauseCard(controller: visibility),
                ],
                const EditorialDivider(),
                Text(
                  AppStrings.of(context).messages.profilePageYourAccount,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (c.session.identity case final identity?) ...[
                  AccountIdentifier(userId: identity.userId),
                  const SizedBox(height: 16),
                ],
                AccountBenefitsActions(
                  isPremium: widget.continuation.quotaReadAt == null
                      ? null
                      : widget.continuation.quota?.premium,
                  onSubscription: _openSubscription,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmark_border_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  title: Text(
                    strings.messages.profilePageMyContinuationCredits,
                  ),
                  onTap: () => _open(
                    CreditsPage(
                      controller: widget.continuation,
                      catalog: widget.catalog,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  title: Text(strings.privacyTitle),
                  onTap: () => _open(
                    PrivacyHubPage(
                      session: controller.session,
                      repository: widget.privacyRepository,
                      deviceRepository: widget.deviceRepository,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_none),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  title: Text(
                    strings.messages.devicesPageDevicesAndNotifications,
                  ),
                  onTap: () => _open(
                    DevicesPage(
                      session: controller.session,
                      repository: widget.deviceRepository,
                      push: PushScope.maybeOf(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                HistaeButton.text(
                  onPressed: controller.session.logout,
                  child: Text(strings.logout),
                ),
                HistaeButton.outlinedIcon(
                  key: const Key('profile-help'),
                  onPressed: () => _open(const HelpPage()),
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(strings.messages.helpTitle),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
