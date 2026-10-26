import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../consents/presentation/consents_page.dart';
import '../../continuation/presentation/rewarded_video_scope.dart';
import '../../notifications/data/device_repository.dart';
import '../../notifications/presentation/devices_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../application/privacy_controller.dart';
import '../data/privacy_repository.dart';
import '../data/private_export_store.dart';
import 'privacy_detail_page.dart';
import 'privacy_frame.dart';

export 'privacy_detail_page.dart' show PrivacyDetailPage;

class PrivacyHubPage extends StatefulWidget {
  const PrivacyHubPage({
    super.key,
    required this.session,
    this.exportStore,
    this.repository,
    this.deviceRepository,
  });
  final AuthenticatedSession session;
  final PrivateExportStore? exportStore;
  final PrivacyRepository? repository;
  final DeviceRepository? deviceRepository;

  @override
  State<PrivacyHubPage> createState() => _PrivacyHubPageState();
}

class _PrivacyHubPageState extends State<PrivacyHubPage>
    with WidgetsBindingObserver {
  late final c = PrivacyController(
    widget.repository ?? PrivacyRepository(widget.session),
    exportStore: widget.exportStore,
  );
  late final Future<void> _startup;
  bool _advertisingFormOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startup = c.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_advertisingFormOpen) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(c.resume());
    } else {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  Future<void> _open(PrivacySection section) async {
    await _startup;
    if (!mounted || !c.accessible) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivacyDetailPage(controller: c, section: section),
      ),
    );
    if (mounted) {
      c.leave(section);
    }
  }

  Future<void> _advertisingChoices() async {
    if (_advertisingFormOpen) return;
    final gateway = RewardedVideoScope.maybeOf(context);
    if (gateway?.privacyOptionsRequired != true) return;
    setState(() => _advertisingFormOpen = true);
    try {
      await gateway!.showPrivacyOptions();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context)
                  .messages
                  .privacyHubPageYourAdvertisingPreferencesAreCurrentlyUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _advertisingFormOpen = false);
        unawaited(c.resume());
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      return PrivacyFrame(
        title: AppStrings.of(context).messages.privacyHubPagePrivacyAndSecurity,
        children: [
          EditorialCard(
            eyebrow: AppStrings.of(context)
                .messages
                .privacyHubPageYourSpaceYourChoices,
            title: AppStrings.of(context).messages.privacyHubPageWithConfidence,
            body: AppStrings.of(context)
                .messages
                .privacyHubPageFindYourChoicesAccessAndData,
          ),
          const SizedBox(height: 24),
          _tile(
            Icons.tune,
            AppStrings.of(context).messages.privacyHubPageMyConsents,
            AppStrings.of(context).messages.privacyHubPageViewOrChangeMyChoices,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ConsentsPage(session: widget.session),
              ),
            ),
          ),
          _tile(
            Icons.devices,
            AppStrings.of(context).messages.privacyDetailPageMySessions,
            AppStrings.of(context).messages.privacyHubPageViewAndRevokeAccess,
            () => _open(PrivacySection.sessions),
          ),
          if (RewardedVideoScope.maybeOf(context)?.privacyOptionsRequired ==
              true)
            _tile(
              Icons.tune_rounded,
              AppStrings.of(context)
                  .messages
                  .rewardVideoCardMyAdvertisingChoices,
              AppStrings.of(context)
                  .messages
                  .privacyHubPageReviewMyVideoPreferences,
              _advertisingChoices,
            ),
          if (c.onboarded)
            _tile(
              Icons.notifications_none,
              AppStrings.of(context)
                  .messages
                  .devicesPageDevicesAndNotifications,
              AppStrings.of(context)
                  .messages
                  .privacyHubPageChooseAlertsAndManageDevices,
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DevicesPage(
                    session: widget.session,
                    repository: widget.deviceRepository,
                    push: PushScope.maybeOf(context),
                  ),
                ),
              ),
            ),
          if (c.onboarded)
            _tile(
              Icons.person_off_outlined,
              AppStrings.of(context).messages.privacyDetailPageBlockedPeople,
              AppStrings.of(context).messages.privacyHubPageManageBlocks,
              () => _open(PrivacySection.blocks),
            ),
          _tile(
            Icons.fact_check_outlined,
            AppStrings.of(context).messages.privacyDetailPageMyDataRequests,
            AppStrings.of(context)
                .messages
                .privacyHubPageExerciseMyRightsAndTrackRequests,
            () => _open(PrivacySection.rights),
          ),
          _tile(
            Icons.download_outlined,
            AppStrings.of(context).messages.privacyDetailPageExportMyData,
            AppStrings.of(context)
                .messages
                .privacyHubPageDownloadThenChooseWhereToShare,
            () => _open(PrivacySection.export),
          ),
          _tile(
            Icons.delete_outline,
            AppStrings.of(context).messages.privacyDetailPageDeleteMyAccount,
            AppStrings.of(context)
                .messages
                .privacyHubPageCloseMyAccountAndRequestCleanup,
            () => _open(PrivacySection.deletion),
          ),
          HistaeButton.text(
            onPressed: widget.session.logout,
            child: Text(AppStrings.of(context).messages.appStringsSignOut),
          ),
        ],
      );
    },
  );

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );
}
