import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/privacy_controller.dart';
import 'privacy_frame.dart';
import 'privacy_request_form.dart';
import 'privacy_strings.dart';

class PrivacyDetailPage extends StatefulWidget {
  const PrivacyDetailPage({
    super.key,
    required this.controller,
    required this.section,
  });
  final PrivacyController controller;
  final PrivacySection section;

  @override
  State<PrivacyDetailPage> createState() => _PrivacyDetailPageState();
}

class _PrivacyDetailPageState extends State<PrivacyDetailPage> {
  PrivacyController get c => widget.controller;
  final _confirmation = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(c.enter(widget.section));
      }
    });
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  bool get enabled =>
      c.active && !c.busy && !c.loading && !c.sharing && c.retrySeconds == 0;

  Future<bool> _confirm(String title, String body, {String? action}) =>
      confirmAction(context, title, body, action: action);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      final title = switch (widget.section) {
        PrivacySection.sessions => AppStrings.of(
          context,
        ).messages.privacyDetailPageMySessions,
        PrivacySection.blocks => AppStrings.of(
          context,
        ).messages.privacyDetailPageBlockedPeople,
        PrivacySection.rights => AppStrings.of(
          context,
        ).messages.privacyDetailPageMyDataRequests,
        PrivacySection.export => AppStrings.of(
          context,
        ).messages.privacyDetailPageExportMyData,
        PrivacySection.deletion => AppStrings.of(
          context,
        ).messages.privacyDetailPageDeleteMyAccount,
      };
      return PopScope(
        canPop: !c.deleting && !c.sharing,
        child: PrivacyFrame(
          title: title,
          children: [
            if (c.loading || c.busy)
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: LinearProgressIndicator(
                  semanticsLabel: AppStrings.of(context)
                      .messages
                      .privacyDetailPageOperationInProgress,
                ),
              ),
            if (c.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(privacyNotice(AppStrings.of(context), c.notice)),
                ),
              ),
            if (c.failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    privacyFailure(AppStrings.of(context), c.failure!),
                  ),
                ),
              ),
            if (c.retrySeconds > 0)
              Text(
                AppStrings.of(context).messages
                    .appStringsTryAgainInS(c.retrySeconds),
              ),
            ...switch (widget.section) {
              PrivacySection.sessions => _sessions(),
              PrivacySection.blocks => _blocks(),
              PrivacySection.rights => _rights(),
              PrivacySection.export => _export(),
              PrivacySection.deletion => _delete(),
            },
          ],
        ),
      );
    },
  );

  List<Widget> _sessions() => [
    Text(
      AppStrings.of(context)
          .messages
          .privacyDetailPageClosingASessionRemovesItsAccess,
    ),
    const SizedBox(height: 16),
    if (c.pendingRevoke != null)
      Text(
        AppStrings.of(context)
            .messages
            .privacyDetailPageARevocationStillNeedsConfirmationRefresh,
      ),
    for (final session in c.sessions)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                session.current
                    ? AppStrings.of(context)
                          .messages
                          .privacyDetailPageThisDevice
                    : AppStrings.of(context)
                          .messages
                          .privacyDetailPageOtherSession,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                AppStrings.of(context).messages.privacyDetailPageCreatedOn(
                  privacyDate(AppStrings.of(context), session.createdAt),
                ),
              ),
              Text(
                AppStrings.of(context).messages.privacyDetailPageLastRenewedOn(
                  privacyDate(AppStrings.of(context), session.refreshedAt),
                ),
              ),
              Text(
                AppStrings.of(context).messages.privacyDetailPageExpiresOn(
                  privacyDate(AppStrings.of(context), session.expiresAt),
                ),
              ),
              HistaeButton.outlined(
                onPressed:
                    enabled &&
                        (c.pendingRevoke == null ||
                            c.pendingRevoke == session.id)
                    ? () async {
                        if (await _confirm(
                              AppStrings.of(context)
                                  .messages
                                  .privacyDetailPageCloseThisSession,
                              session.current
                                  ? AppStrings.of(context)
                                        .messages
                                        .privacyDetailPageYouWillBeSignedOutOn
                                  : AppStrings.of(context)
                                        .messages
                                        .privacyDetailPageThisAccessWillBeRevokedThe,
                            ) &&
                            mounted) {
                          await c.revoke(session);
                        }
                      }
                    : null,
                child: Text(
                  c.pendingRevoke == session.id
                      ? AppStrings.of(context)
                            .messages
                            .privacyDetailPageResumeRevocation
                      : AppStrings.of(context)
                            .messages
                            .privacyDetailPageCloseThisSession594,
                ),
              ),
            ],
          ),
        ),
      ),
    if (!c.loading && c.sessions.isEmpty)
      Text(AppStrings.of(context).messages.privacyDetailPageNoSessionsLoaded),
    HistaeButton.outlined(
      onPressed: enabled ? c.load : null,
      child: Text(
        AppStrings.of(context).messages.privacyDetailPageRefreshSessions,
      ),
    ),
    if (c.cursor != null)
      HistaeButton.outlined(
        onPressed: enabled ? () => c.load(more: true) : null,
        child: Text(AppStrings.of(context).messages.privacyDetailPageLoadMore),
      ),
    const SizedBox(height: 20),
    HistaeButton.text(
      onPressed: enabled
          ? () async {
              if (await _confirm(
                    AppStrings.of(context)
                        .messages
                        .privacyDetailPageCloseAllSessions,
                    AppStrings.of(context)
                        .messages
                        .privacyDetailPageYouWillAlsoBeSignedOut,
                    action: AppStrings.of(context)
                        .messages
                        .privacyDetailPageCloseAll,
                  ) &&
                  mounted) {
                await c.session.logoutEverywhere();
              }
            }
          : null,
      child: Text(
        AppStrings.of(context).messages.privacyDetailPageCloseAllMySessions,
      ),
    ),
  ];

  List<Widget> _blocks() => [
    Text(
      AppStrings.of(context)
          .messages
          .privacyDetailPageUnblockingSomeoneDoesNotRestoreAny,
    ),
    if (c.pendingUnblock != null)
      Text(
        AppStrings.of(context)
            .messages
            .privacyDetailPageUnblockingStillNeedsConfirmationRefreshBefore,
      ),
    const SizedBox(height: 16),
    for (final person in c.blocks)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                person.firstname ??
                    AppStrings.of(context)
                        .messages
                        .privacyDetailPageBlockedProfile,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                AppStrings.of(context).messages.privacyDetailPageBlockedOn(
                  privacyDate(AppStrings.of(context), person.blockedAt),
                ),
              ),
              HistaeButton.outlined(
                onPressed:
                    enabled &&
                        (c.pendingUnblock == null ||
                            c.pendingUnblock == person.id)
                    ? () async {
                        if (await _confirm(
                              AppStrings.of(context)
                                  .messages
                                  .privacyDetailPageUnblockThisPerson,
                              AppStrings.of(context)
                                  .messages
                                  .privacyDetailPageYouMayDiscoverEachOtherAgain,
                              action: AppStrings.of(context)
                                  .messages
                                  .privacyDetailPageUnblock,
                            ) &&
                            mounted) {
                          await c.unblock(person.id);
                        }
                      }
                    : null,
                child: Text(
                  c.pendingUnblock == person.id
                      ? AppStrings.of(context)
                            .messages
                            .privacyDetailPageResumeUnblocking
                      : AppStrings.of(context)
                            .messages
                            .privacyDetailPageUnblock,
                ),
              ),
            ],
          ),
        ),
      ),
    if (!c.loading && c.blocks.isEmpty)
      Text(
        AppStrings.of(context)
            .messages
            .privacyDetailPageNoBlockedPeopleInThisList,
      ),
    HistaeButton.outlined(
      onPressed: enabled ? c.load : null,
      child: Text(
        AppStrings.of(context).messages.privacyDetailPageRefreshBlocks,
      ),
    ),
  ];

  List<Widget> _rights() {
    return [
      Text(
        AppStrings.of(context)
            .messages
            .privacyDetailPageTheseRequestsAreSubmittedForProcessing,
      ),
      const SizedBox(height: 24),
      PrivacyRequestForm(controller: c, enabled: enabled),
      const SizedBox(height: 24),
      Text(
        AppStrings.of(context).messages.privacyDetailPageTrackYourRequests,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      for (final request in c.rights)
        Card(
          child: request.details == null && request.response == null
              ? ListTile(
                  title: Text(rightLabel(AppStrings.of(context), request.type)),
                  subtitle: Text(
                    '${rightStatus(AppStrings.of(context), request.status)} · ${privacyDate(AppStrings.of(context), request.requestedAt)}${request.completedAt == null ? '' : AppStrings.of(context).messages.privacyDetailPageCompletedOn(privacyDate(AppStrings.of(context), request.completedAt!))}',
                  ),
                )
              : ExpansionTile(
                  title: Text(rightLabel(AppStrings.of(context), request.type)),
                  subtitle: Text(
                    '${rightStatus(AppStrings.of(context), request.status)} · ${privacyDate(AppStrings.of(context), request.requestedAt)}',
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    if (request.details != null) ...[
                      Text(
                        AppStrings.of(context)
                            .messages
                            .privacyRequestYourMessage,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(request.details!),
                    ],
                    if (request.response != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context)
                            .messages
                            .privacyRequestTeamResponse,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(request.response!),
                    ],
                    if (request.completedAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.of(context).messages
                            .privacyDetailPageCompletedOn(
                              privacyDate(
                                AppStrings.of(context),
                                request.completedAt!,
                              ),
                            ),
                      ),
                    ],
                  ],
                ),
        ),
      if (!c.loading && c.rights.isEmpty)
        Text(
          AppStrings.of(context).messages.privacyDetailPageNoRequestsToTrack,
        ),
      HistaeButton.outlined(
        onPressed: enabled ? c.load : null,
        child: Text(
          AppStrings.of(context).messages.privacyDetailPageRefreshTracking,
        ),
      ),
    ];
  }

  List<Widget> _export() => [
    EditorialCard(
      eyebrow: AppStrings.of(context).messages.privacyDetailPageACopyForYou,
      title: AppStrings.of(context)
          .messages
          .privacyDetailPageYourDataWithinReach,
      body: AppStrings.of(context)
          .messages
          .privacyDetailPageYourExportContainsPersonalInformationIt,
    ),
    const SizedBox(height: 20),
    Text(
      AppStrings.of(context)
          .messages
          .privacyDetailPagePreparationMayTakeAFewMinutes,
    ),
    const SizedBox(height: 20),
    HistaeButton.icon(
      onPressed: enabled ? c.downloadExport : null,
      icon: const Icon(Icons.download_outlined),
      label: Text(
        c.exportPath == null
            ? AppStrings.of(context).messages.privacyDetailPageDownloadMyExport
            : AppStrings.of(context).messages.privacyDetailPageDownloadAgain,
      ),
    ),
    if (c.exportPath != null) ...[
      Builder(
        builder: (buttonContext) => HistaeButton.outlinedIcon(
          onPressed: enabled
              ? () async {
                  if (!await _confirm(
                        AppStrings.of(context)
                            .messages
                            .privacyDetailPageShareYourExport,
                        AppStrings.of(context)
                            .messages
                            .privacyDetailPageChooseATrustedDestinationForThis,
                        action: AppStrings.of(context)
                            .messages
                            .privacyDetailPageChooseADestination,
                      ) ||
                      !buttonContext.mounted) {
                    return;
                  }
                  final box = buttonContext.findRenderObject();
                  if (box is! RenderBox || !box.hasSize) return;
                  final origin = box.localToGlobal(Offset.zero) & box.size;
                  await c.shareExport((path) async {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(path, mimeType: 'application/json')],
                        title: AppStrings.of(context)
                            .messages
                            .privacyDetailPageMyHistaeExport,
                        sharePositionOrigin: origin,
                      ),
                    );
                  });
                }
              : null,
          icon: const Icon(Icons.ios_share),
          label: Text(
            AppStrings.of(context)
                .messages
                .privacyDetailPageChooseWhereToShareTheFile,
          ),
        ),
      ),
    ],
    HistaeButton.text(
      onPressed: enabled ? c.clearExport : null,
      child: Text(
        AppStrings.of(context).messages.privacyDetailPageEraseTemporaryFile,
      ),
    ),
  ];

  List<Widget> _delete() => [
    Text(AppStrings.of(context).messages.billingStoreDeletionNotice),
    const SizedBox(height: 16),
    EditorialCard(
      eyebrow: AppStrings.of(context)
          .messages
          .privacyDetailPageAPersonalDecision,
      title: AppStrings.of(context).messages.privacyDetailPageCloseThisChapter,
      body: AppStrings.of(context)
          .messages
          .privacyDetailPageDeletionClosesYourAccountAndSessions,
    ),
    const SizedBox(height: 24),
    Text(
      AppStrings.of(context)
          .messages
          .privacyDetailPageOnceAcceptedYourDataContinuesTo,
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _confirmation,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: AppStrings.of(context)
            .messages
            .privacyDetailPageTypeDeleteToConfirm,
      ),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 20),
    HistaeButton(
      onPressed:
          enabled &&
              _confirmation.text ==
                  AppStrings.of(context).messages.privacyDetailPageDelete
          ? () async {
              if (await _confirm(
                    AppStrings.of(context)
                        .messages
                        .privacyDetailPagePermanentlyDeleteYourAccount,
                    AppStrings.of(context)
                        .messages
                        .privacyDetailPageYourAccountClosesAsSoonAs,
                    action: AppStrings.of(context)
                        .messages
                        .privacyDetailPageDeleteMyAccount,
                  ) &&
                  mounted) {
                _confirmation.clear();
                await c.erase();
              }
            }
          : null,
      child: Text(
        c.deleting
            ? AppStrings.of(context).messages.privacyDetailPageRequestInProgress
            : AppStrings.of(context)
                  .messages
                  .privacyDetailPagePermanentlyDeleteMyAccount,
      ),
    ),
  ];
}
