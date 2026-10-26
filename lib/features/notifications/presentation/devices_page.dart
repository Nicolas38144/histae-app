import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../privacy/presentation/privacy_strings.dart' show privacyDate;
import '../application/devices_controller.dart';
import '../application/push_controller.dart';
import '../data/device_repository.dart';
import '../data/push_gateway.dart';

String notificationFailure(
  AppStrings strings,
  ApiFailure e,
) => switch (e.kind) {
  ApiFailureKind.secureStorage =>
    strings.messages.devicesPageSecureSettingsAreUnavailableActivationRemains,
  ApiFailureKind.rateLimited =>
    strings.messages.devicesPageTooManyRequestsWaitBeforeTrying,
  _ => strings.messages.devicesPageTheResponseWasNotConfirmedRefresh,
};

class DevicesPage extends StatefulWidget {
  const DevicesPage({
    super.key,
    required this.session,
    this.push,
    this.repository,
  });
  final AuthenticatedSession session;
  final PushController? push;
  final DeviceRepository? repository;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> with WidgetsBindingObserver {
  late final c = DevicesController(
    widget.repository ??
        widget.push?.repository ??
        DeviceRepository(widget.session),
  );

  PushController? get p => widget.push;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(c.ensureLoaded());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(c.resume());
    } else if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, ?p]),
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      final enabled =
          c.active &&
          !c.loading &&
          !c.removing &&
          c.retrySeconds == 0 &&
          p?.busy != true;
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.of(context).messages.devicesPageDevicesAndNotifications,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  EditorialCard(
                    eyebrow: AppStrings.of(context)
                        .messages
                        .devicesPageStayInTouchAtYourPace,
                    title: AppStrings.of(context)
                        .messages
                        .devicesPageASignIfYouWish,
                    body: AppStrings.of(context)
                        .messages
                        .devicesPageChooseToReceiveNotificationsOnThis,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.of(context).messages.devicesPageOnThisDevice,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (p?.configured != true)
                    Text(
                      AppStrings.of(context)
                          .messages
                          .devicesPagePushNotificationsAreDisabledInThis,
                    )
                  else ...[
                    Text(
                      p!.stopping
                          ? AppStrings.of(context)
                                .messages
                                .devicesPageStoppingNotificationsStillNeedsConfirmation
                          : p!.pending != null ||
                                (p!.enabled && p!.deviceId == null)
                          ? AppStrings.of(context)
                                .messages
                                .devicesPageThisDeviceSRegistrationStillNeeds
                          : p!.enabled
                          ? AppStrings.of(context)
                                .messages
                                .devicesPageThisDeviceIsRegisteredForNotifications
                          : AppStrings.of(context)
                                .messages
                                .devicesPageNotificationsAreNotEnabledForThis,
                    ),
                    if (p!.permission == PushPermission.provisional)
                      Text(
                        AppStrings.of(context)
                            .messages
                            .devicesPageTheSystemAllowsQuietNotifications,
                      ),
                    if (p!.notice == 'permission_denied')
                      Text(
                        AppStrings.of(context)
                            .messages
                            .devicesPageTheSystemDidNotAllowNotifications,
                      ),
                    if (p!.notice == 'removed_elsewhere')
                      Text(
                        AppStrings.of(context)
                            .messages
                            .devicesPageThisDeviceWasRemovedFromYour,
                      ),
                    if (p!.failure != null)
                      Text(
                        notificationFailure(
                          AppStrings.of(context),
                          p!.failure!,
                        ),
                      ),
                    if (p!.retrySeconds > 0)
                      Text(
                        AppStrings.of(context).messages
                            .appStringsTryAgainInS(p!.retrySeconds),
                      ),
                    if ((!p!.enabled ||
                            p!.pending != null ||
                            p!.deviceId == null ||
                            p!.failure != null) &&
                        !p!.stopping)
                      HistaeButton(
                        onPressed: enabled && p!.retrySeconds == 0
                            ? () async {
                                if (!await confirmAction(
                                      context,
                                      AppStrings.of(context)
                                          .messages
                                          .devicesPageReceiveNotifications,
                                      AppStrings.of(context)
                                          .messages
                                          .devicesPageHistaeWillAskForSystemPermission,
                                      action: p!.pending == null
                                          ? AppStrings.of(context)
                                                .messages
                                                .devicesPageContinue
                                          : AppStrings.of(context)
                                                .messages
                                                .devicesPageResumeThisRegistration,
                                    ) ||
                                    !mounted) {
                                  return;
                                }
                                await p!.enable();
                                if (mounted) await c.load();
                              }
                            : null,
                        child: Text(
                          p!.pending == null
                              ? AppStrings.of(context)
                                    .messages
                                    .devicesPageEnableNotifications
                              : AppStrings.of(context)
                                    .messages
                                    .devicesPageResumeThisRegistration,
                        ),
                      ),
                    if (p!.enabled || p!.deviceId != null || p!.stopping)
                      HistaeButton.outlined(
                        onPressed: enabled
                            ? () async {
                                if (await confirmAction(
                                      context,
                                      AppStrings.of(context)
                                          .messages
                                          .devicesPageStopNotificationsHere,
                                      AppStrings.of(context)
                                          .messages
                                          .devicesPageThisDeviceWillBeRemovedFrom,
                                      action: AppStrings.of(context)
                                          .messages
                                          .devicesPageStop,
                                    ) &&
                                    mounted) {
                                  await p!.disable();
                                  if (mounted) await c.load();
                                }
                              }
                            : null,
                        child: Text(
                          AppStrings.of(context)
                              .messages
                              .devicesPageStopNotificationsOnThisDevice,
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .devicesPageYourRegisteredDevices,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .devicesPageThisListIsForNotificationsRemoving,
                  ),
                  if (c.loading || c.removing || p?.busy == true)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(
                        semanticsLabel: AppStrings.of(context)
                            .messages
                            .devicesPageRefreshingDevices,
                      ),
                    ),
                  if (c.failure != null)
                    Text(
                      notificationFailure(AppStrings.of(context), c.failure!),
                    ),
                  if (c.retrySeconds > 0)
                    Text(
                      AppStrings.of(context).messages
                          .appStringsTryAgainInS(c.retrySeconds),
                    ),
                  if (c.notice == 'device_removed')
                    Text(
                      AppStrings.of(context)
                          .messages
                          .devicesPageThisRegistrationWasRemovedFromYour,
                    ),
                  if (c.pendingRemoval != null)
                    Text(
                      AppStrings.of(context)
                          .messages
                          .devicesPageARemovalStillNeedsConfirmationRefresh,
                    ),
                  if (!c.loading && c.failure == null && c.devices.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .devicesPageNoDevicesRegisteredForNotifications,
                      ),
                    ),
                  for (final device in c.devices)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${device.platform == 'ios' ? AppStrings.of(context).messages.devicesPageIos : AppStrings.of(context).messages.devicesPageAndroid}${p?.deviceId == device.id ? AppStrings.of(context).messages.devicesPageThisDevice : ''}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (device.version != null)
                              Text(
                                AppStrings.of(context).messages
                                    .appVersion(device.version!),
                              ),
                            Text(
                              AppStrings.of(context).messages
                                  .devicesPageRegisteredOn(
                                    privacyDate(
                                      AppStrings.of(context),
                                      device.createdAt,
                                    ),
                                  ),
                            ),
                            if (device.lastUsedAt != null)
                              Text(
                                AppStrings.of(context).messages
                                    .devicesPageLastRefreshedOn(
                                      privacyDate(
                                        AppStrings.of(context),
                                        device.lastUsedAt!,
                                      ),
                                    ),
                              ),
                            HistaeButton.outlined(
                              onPressed:
                                  enabled &&
                                      (c.pendingRemoval == null ||
                                          c.pendingRemoval == device.id)
                                  ? () async {
                                      if (!await confirmAction(
                                            context,
                                            AppStrings.of(context)
                                                .messages
                                                .devicesPageRemoveThisDevice,
                                            AppStrings.of(context)
                                                .messages
                                                .devicesPageFutureNotificationsWillNoLongerBe,
                                            action: AppStrings.of(context)
                                                .messages
                                                .devicesPageRemove,
                                          ) ||
                                          !mounted) {
                                        return;
                                      }
                                      final removed = await c.remove(device.id);
                                      if (removed && mounted) {
                                        await p?.removed(device.id);
                                      }
                                    }
                                  : null,
                              child: Text(
                                c.pendingRemoval == device.id
                                    ? AppStrings.of(context)
                                          .messages
                                          .devicesPageResumeThisRemoval
                                    : AppStrings.of(context)
                                          .messages
                                          .devicesPageRemoveThisDevice573,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  HistaeButton.outlined(
                    onPressed: enabled ? c.load : null,
                    child: Text(
                      AppStrings.of(context).messages.devicesPageRefreshDevices,
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
