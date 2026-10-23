import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_empty_state.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../../core/widgets/histae_wordmark.dart';
import '../../consents/presentation/consents_page.dart';
import '../../privacy/presentation/report_page.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/presentation/profile_editors.dart';
import '../application/discovery_controller.dart';
import '../application/discovery_visibility_controller.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';
import 'discovery_status_sections.dart';
import 'discovery_strings.dart';
import 'encounter_page.dart';
import 'feed_profile_card.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({
    super.key,
    required this.controller,
    required this.profile,
    this.openMatches,
    this.visibility,
  });
  final DiscoveryController controller;
  final ProfileController profile;
  final Future<void> Function([String? id])? openMatches;
  final DiscoveryVisibilityController? visibility;

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  DiscoveryController get c => widget.controller;
  late final _key = c.session.resourceKey;
  String? _message;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    unawaited(c.activate());
    if (widget.visibility case final visibility?) {
      unawaited(visibility.ensureLoaded());
    }
  }

  @override
  void dispose() {
    c.deactivate(notify: false);
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _repair(DiscoveryAction action) async {
    if (_opening || c.busy) return;
    if (action == DiscoveryAction.resumeDiscovery) {
      final visibility = widget.visibility;
      if (visibility == null) return;
      setState(() => _opening = true);
      try {
        await visibility.load();
        if (!mounted || !c.accessible || c.session.resourceKey != _key) return;
        if (visibility.paused == true && visibility.canChange) {
          await visibility.setPaused(false);
        }
        if (mounted) await c.refresh();
      } on ApiFailure {
        if (mounted) {
          setState(
            () =>
                _message = AppStrings.of(context)
                    .messages
                    .discoveryPageResumingCouldNotBeConfirmedRefresh,
          );
        }
      } finally {
        if (mounted) setState(() => _opening = false);
      }
      return;
    }
    if (action == DiscoveryAction.freshPresence) {
      await _locate();
      return;
    }
    _opening = true;
    try {
      if (action == DiscoveryAction.locationConsent ||
          action == DiscoveryAction.sensitiveConsent ||
          ((action == DiscoveryAction.sex ||
                  action == DiscoveryAction.preferences) &&
              !widget.profile.sensitiveAllowed)) {
        await _open(ConsentsPage(session: c.session));
        return;
      }
      final profile = widget.profile;
      await profile.load();
      if (!mounted || !c.accessible || c.session.resourceKey != _key) return;
      final section = action == DiscoveryAction.preferences
          ? 'preferences'
          : 'profile';
      if (profile.loading ||
          profile.errors.containsKey(section) ||
          profile.uncertain) {
        setState(() {
          _message = AppStrings.of(context)
              .messages
              .discoveryPageYourProfileCouldNotBeRefreshed;
        });
        return;
      }
      await _open(
        action == DiscoveryAction.preferences
            ? PreferencesEditor(controller: profile)
            : IdentityEditor(controller: profile),
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> _locate() async {
    if (!c.locationConsent) {
      await _open(ConsentsPage(session: c.session));
      return;
    }
    if (!await confirmAction(
          context,
          AppStrings.of(context).messages.discoveryPageUseYourLocation,
          AppStrings.of(context).messages.discoveryPageHistaeWillTakeAOneOff,
          action: AppStrings.of(context).messages.discoveryPageLocateThisDevice,
        ) ||
        !mounted) {
      return;
    }
    await c.publishLocation();
  }

  Future<void> _showEncounter(EncounterReceipt receipt) async {
    if (!mounted || !c.accessible || c.session.resourceKey != _key) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EncounterPage(
          controller: c,
          receipt: receipt,
          openMatch: widget.openMatches == null
              ? null
              : () => widget.openMatches!(receipt.match.id),
        ),
      ),
    );
  }

  Future<void> _choose(SwipeDecision decision) async {
    final receipt = await c.decide(decision);
    if (receipt != null) await _showEncounter(receipt);
  }

  Future<void> _retry() async {
    final receipt = await c.resumeChoice();
    if (receipt != null) await _showEncounter(receipt);
  }

  Future<void> _block() async {
    final profile = c.current;
    if (profile == null || c.busy) return;
    if (!await confirmAction(
          context,
          AppStrings.of(context).messages.discoveryPageBlockThisProfile,
          AppStrings.of(context)
              .messages
              .discoveryPageYouWillNoLongerDiscoverOr,
          action: AppStrings.of(context).messages.discoveryPageBlock,
        ) ||
        !mounted) {
      return;
    }
    await c.blockProfile(profile);
  }

  Future<void> _report() async {
    final profile = c.current;
    if (profile == null || c.busy) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPage(
          session: c.session,
          target: profile.id,
          onBlock: () async {
            if (!c.active) await c.activate();
            await c.blockProfile(profile);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, widget.visibility]),
    builder: (context, _) {
      if (!c.accessible || c.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final profile = c.current;
      final required = c.requiredActions;
      final showFeed =
          c.ready &&
          !c.locating &&
          c.locationIssue == null &&
          profile != null &&
          c.pending == null &&
          c.failure == null;
      final enabled = !c.busy && c.retrySeconds == 0;
      final statusBody = <Widget>[
        if (c.status == null && !c.busy && c.failure == null)
          Text(
            AppStrings.of(context)
                .messages
                .discoveryStringsThisPageHasExpiredRefreshProfiles,
          ),
        if (!c.ready && c.status != null) ...[
          DiscoveryReadinessIntro(
            paused: required.contains(DiscoveryAction.resumeDiscovery),
          ),
          for (final action in required)
            DiscoveryReadinessCard(
              action: action,
              onRepair: enabled && !_opening ? () => _repair(action) : null,
            ),
        ],
        if (c.ready && profile == null && !c.loading && c.failure == null)
          if (c.exhausted)
            HistaeEmptyState(
              title: AppStrings.of(context)
                  .messages
                  .discoveryPageAQuietMomentForNow,
              body: AppStrings.of(context)
                  .messages
                  .discoveryPageYouHaveSeenTheAvailableProfiles,
            )
          else
            EditorialCard(
              eyebrow: AppStrings.of(context)
                  .messages
                  .discoveryPageTakeYourTime,
              title: AppStrings.of(context).messages.discoveryPageJustAMoment,
              body: AppStrings.of(context)
                  .messages
                  .discoveryPageTheSearchCanContinueLoadMore,
            ),
        if (c.pending case final intent?)
          DiscoveryPendingChoiceCard(
            intent: intent,
            uncertain: c.uncertain,
            onResume: c.canResume ? _retry : null,
          ),
        if (c.loading || c.locating || c.sending) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            semanticsLabel: AppStrings.of(context)
                .messages
                .discoveryPageLoadingDiscovery,
          ),
          const SizedBox(height: 12),
          Text(
            c.locating
                ? AppStrings.of(context)
                      .messages
                      .discoveryPageFindingARecentLocation
                : c.sending
                ? AppStrings.of(context).messages.discoveryPageSavingYourChoice
                : AppStrings.of(context)
                      .messages
                      .discoveryPagePreparingEncounters,
          ),
        ],
        if (c.notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                DiscoveryStrings(AppStrings.of(context)).notice(c.notice),
              ),
            ),
          ),
        if (c.failure case final failure?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                DiscoveryStrings(AppStrings.of(context)).failure(failure),
              ),
            ),
          ),
        if (c.locationIssue case final issue?) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              DiscoveryStrings(AppStrings.of(context)).location(issue),
            ),
          ),
          if (issue == LocationIssue.deniedForever ||
              issue == LocationIssue.disabled)
            OutlinedButton(
              onPressed: enabled
                  ? () async {
                      final opened = await c.location.openSettings(
                        services: issue == LocationIssue.disabled,
                      );
                      if (!opened && mounted) {
                        setState(() {
                          _message = AppStrings.of(context)
                              .messages
                              .discoveryPageOpenYourDeviceSLocationSettings;
                        });
                      }
                    }
                  : null,
              child: Text(
                AppStrings.of(context).messages.discoveryPageOpenSettings,
              ),
            ),
        ],
        if (_message != null) Text(_message!),
        if (c.retrySeconds > 0)
          Text(
            AppStrings.of(context).messages
                .appStringsTryAgainInS(c.retrySeconds),
          ),
        if (!showFeed)
          OutlinedButton(
            onPressed: enabled
                ? (c.ready &&
                          !c.exhausted &&
                          c.pending == null &&
                          c.failure == null
                      ? c.loadMore
                      : c.refresh)
                : null,
            child: Text(
              AppStrings.of(context).messages.discoveryPageRefreshEncounters,
            ),
          ),
        if (c.ready && !showFeed)
          TextButton(
            onPressed: enabled ? _locate : null,
            child: Text(
              AppStrings.of(context).messages.discoveryPageRefreshMyLocation,
            ),
          ),
        if (c.encounter case final encounter?)
          TextButton.icon(
            onPressed: !c.busy ? () => _showEncounter(encounter) : null,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              AppStrings.of(context).messages
                  .discoveryPageYourMatchWith(encounter.profile.firstname),
            ),
          ),
        TextButton(
          onPressed: () => _open(ConsentsPage(session: c.session)),
          child: Text(
            AppStrings.of(context).messages.appStringsYourChoicesAndPrivacy,
          ),
        ),
        TextButton(
          onPressed: c.session.logout,
          child: Text(AppStrings.of(context).messages.appStringsSignOut),
        ),
      ];
      return HistaeScaffold(
        appBar: AppBar(
          title: const HistaeWordmark(),
          actions: [
            IconButton(
              tooltip: AppStrings.of(context)
                  .messages
                  .discoveryPageYourPreferences,
              onPressed: enabled
                  ? () => _repair(DiscoveryAction.preferences)
                  : null,
              icon: const Icon(Icons.tune),
            ),
            PopupMenuButton<String>(
              tooltip: AppStrings.of(context)
                  .messages
                  .discoveryPageDiscoveryOptions,
              onSelected: (value) {
                if (value == 'refresh') unawaited(c.refresh());
                if (value == 'location') unawaited(_locate());
                if (value == 'block') unawaited(_block());
                if (value == 'report') unawaited(_report());
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  enabled: enabled,
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .discoveryPageRefreshProfiles,
                  ),
                ),
                PopupMenuItem(
                  value: 'location',
                  enabled: enabled,
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .discoveryPageRefreshMyLocation,
                  ),
                ),
                if (profile != null)
                  PopupMenuItem(
                    value: 'report',
                    enabled: enabled,
                    child: Text(
                      AppStrings.of(context)
                          .messages
                          .discoveryPageReportThisProfile,
                    ),
                  ),
                if (profile != null)
                  PopupMenuItem(
                    value: 'block',
                    enabled: enabled,
                    child: Text(
                      AppStrings.of(context)
                          .messages
                          .discoveryPageBlockThisProfile372,
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: showFeed
              ? Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: FeedProfileCard(
                          key: ValueKey(profile.id),
                          profile: profile,
                          enabled:
                              c.canChoose &&
                              widget.visibility?.saving != true &&
                              widget.visibility?.uncertain != true,
                          onLike: () => _choose(SwipeDecision.like),
                          onPass: () => _choose(SwipeDecision.pass),
                        ),
                      ),
                    ),
                    if (c.notice != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            DiscoveryStrings(AppStrings.of(context))
                                .notice(c.notice),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_message!),
                        ),
                      ),
                    if (c.encounter case final encounter?)
                      TextButton(
                        onPressed: () => _showEncounter(encounter),
                        child: Text(
                          AppStrings.of(context).messages
                              .discoveryPageYourMatchWith(
                                encounter.profile.firstname,
                              ),
                        ),
                      ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: statusBody,
                ),
        ),
      );
    },
  );
}
