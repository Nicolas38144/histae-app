import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_empty_state.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../../core/widgets/histae_wordmark.dart';
import '../../consents/presentation/consents_page.dart';
import '../../help/application/help_controller.dart';
import '../../help/presentation/feed_guide.dart';
import '../../help/presentation/help_scope.dart';
import '../../privacy/presentation/privacy_hub_page.dart';
import '../../privacy/presentation/report_page.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/presentation/photo_page.dart';
import '../../profile/presentation/profile_editors.dart';
import '../../reading/presentation/reading_settings_sheet.dart';
import '../application/discovery_controller.dart';
import '../application/discovery_visibility_controller.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';
import 'discovery_status_sections.dart';
import 'discovery_strings.dart';
import 'encounter_page.dart';
import 'feed_choice_feedback.dart';
import 'feed_profile_card.dart';
import 'feed_profile_transition.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({
    super.key,
    required this.controller,
    required this.profile,
    this.openMatches,
    this.visibility,
    this.visible = true,
  });
  final DiscoveryController controller;
  final ProfileController profile;
  final Future<void> Function([String? id])? openMatches;
  final DiscoveryVisibilityController? visibility;
  final bool visible;

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  DiscoveryController get c => widget.controller;
  late final _key = c.session.resourceKey;
  String? _message;
  bool _opening = false;
  HelpController? _help;
  bool _guideScheduled = false, _guideOpen = false;
  bool _readingOpen = false;
  ModalRoute<dynamic>? _route;
  bool _profileRefreshScheduled = false, _pullRefreshing = false;

  bool get _canPresentProfileRefresh =>
      mounted && widget.visible && !_opening && _route?.isCurrent == true;

  void _scheduleProfileRefresh() {
    if (_profileRefreshScheduled ||
        !_canPresentProfileRefresh ||
        !c.canRefreshProfile(widget.profile)) {
      return;
    }
    _profileRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await c.refreshAfterProfileEdit(
          widget.profile,
          isVisible: () => _canPresentProfileRefresh,
        );
      } finally {
        if (mounted) setState(() => _profileRefreshScheduled = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _help = HelpScope.maybeOf(context);
    _route = ModalRoute.of(context);
  }

  void _offerGuide(bool showFeed) {
    final help = _help;
    if (!showFeed ||
        !widget.visible ||
        _opening ||
        _readingOpen ||
        c.busy ||
        _guideScheduled ||
        help == null ||
        !help.loaded ||
        help.seen ||
        help.showing) {
      return;
    }
    _guideScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !widget.visible ||
          _readingOpen ||
          !c.accessible ||
          c.session.resourceKey != _key ||
          help.seen ||
          help.showing ||
          c.busy ||
          !c.ready ||
          c.current == null ||
          ModalRoute.of(context)?.isCurrent != true) {
        _guideScheduled = false;
        return;
      }
      setState(() => _guideOpen = true);
      try {
        await showFeedGuide(context);
      } finally {
        if (mounted) {
          setState(() {
            _guideOpen = false;
            _guideScheduled = false;
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Visibility is shared with Profile; do not notify an already mounted
    // sibling while PageView is constructing this page during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(c.activate());
      if (widget.visibility case final visibility?) {
        unawaited(visibility.ensureLoaded());
      }
    });
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

  Future<void> _openReading() async {
    if (_readingOpen || _guideOpen) return;
    setState(() => _readingOpen = true);
    try {
      await showReadingSettings(context);
    } finally {
      if (mounted) setState(() => _readingOpen = false);
    }
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
    setState(() {
      _opening = true;
      _message = null;
    });
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
      final sections = switch (action) {
        DiscoveryAction.preferences => ['preferences'],
        DiscoveryAction.traits => ['traits', 'selectedTraits'],
        DiscoveryAction.conversationStarters => ['questions', 'answers'],
        _ => ['profile'],
      };
      if (profile.loading ||
          sections.any(profile.errors.containsKey) ||
          profile.uncertain) {
        setState(() {
          _message = AppStrings.of(context)
              .messages
              .discoveryPageYourProfileCouldNotBeRefreshed;
        });
        return;
      }
      await _open(switch (action) {
        DiscoveryAction.photo => PhotoPage(controller: profile),
        DiscoveryAction.preferences => PreferencesEditor(controller: profile),
        DiscoveryAction.traits => TraitsEditor(controller: profile),
        DiscoveryAction.biography => IdentityEditor(controller: profile),
        DiscoveryAction.conversationStarters => AnswersEditor(
          controller: profile,
        ),
        DiscoveryAction.sex when profile.profile != null => PrivacyHubPage(
          session: c.session,
        ),
        _ => IdentityEditor(controller: profile),
      });
    } finally {
      if (mounted) setState(() => _opening = false);
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

  Future<void> _refreshFromPull() async {
    setState(() => _pullRefreshing = true);
    try {
      await c.refresh();
    } finally {
      if (mounted) setState(() => _pullRefreshing = false);
    }
  }

  Future<void> _openLocationSettings() async {
    final opened = await c.location.openSettings(
      services: c.locationIssue == LocationIssue.disabled,
    );
    if (!opened && mounted) {
      setState(() {
        _message = AppStrings.of(context)
            .messages
            .discoveryPageOpenYourDeviceSLocationSettings;
      });
    }
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
    listenable: Listenable.merge([c, widget.profile, widget.visibility, _help]),
    builder: (context, _) {
      if (!c.accessible || c.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final detailsChanged = c.needsProfileRefresh(widget.profile);
      if (detailsChanged) _scheduleProfileRefresh();
      final ready = !detailsChanged && c.ready;
      final profile = detailsChanged ? null : c.current;
      final required = c.requiredActions;
      final text = AppStrings.of(context).messages;
      final showFeedStatus =
          ready && profile == null && !c.loading && c.failure == null;
      final showExhaustedState = showFeedStatus && c.exhausted;
      final emptyState = HistaeEmptyState(
        title: text.discoveryPageAQuietMomentForNow,
        body: text.discoveryPageYouHaveSeenTheAvailableProfiles,
      );
      final showFeed =
          ready &&
          !_pullRefreshing &&
          !c.locating &&
          c.locationIssue == null &&
          profile != null &&
          (c.pending == null || (c.sending && !c.uncertain)) &&
          c.failure == null;
      final enabled =
          !detailsChanged && !_pullRefreshing && !c.busy && c.retrySeconds == 0;
      _offerGuide(showFeed);
      final locationInCard =
          !detailsChanged &&
          !ready &&
          required.contains(DiscoveryAction.freshPresence);
      final locationFeedback = c.locationIssue == null
          ? null
          : DiscoveryLocationFeedback(
              issue: c.locationIssue!,
              onOpenSettings: enabled ? _openLocationSettings : null,
            );
      final statusBody = <Widget>[
        if (!detailsChanged && c.status == null && !c.busy && c.failure == null)
          Text(
            AppStrings.of(context)
                .messages
                .discoveryStringsThisPageHasExpiredRefreshProfiles,
          ),
        if (!detailsChanged && !ready && c.status != null) ...[
          DiscoveryReadinessIntro(
            paused: required.contains(DiscoveryAction.resumeDiscovery),
          ),
          for (final action in required)
            DiscoveryReadinessCard(
              action: action,
              sensitiveAllowed: widget.profile.sensitiveAllowed,
              onRepair: enabled && !_opening ? () => _repair(action) : null,
              feedback: action == DiscoveryAction.freshPresence
                  ? locationFeedback
                  : null,
            ),
        ],
        if (showExhaustedState)
          emptyState
        else if (showFeedStatus)
          EditorialCard(
            title: text.discoveryPageJustAMoment,
            body: text.discoveryPageTheSearchCanContinueLoadMore,
          ),
        if (c.pending case final intent?)
          DiscoveryPendingChoiceCard(
            intent: intent,
            uncertain: c.uncertain,
            onResume: enabled && c.canResume ? _retry : null,
          ),
        if (c.busy || (detailsChanged && c.retrySeconds == 0)) ...[
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
        if (!locationInCard && locationFeedback != null) locationFeedback,
        if (_message != null) Text(_message!),
        if (c.retrySeconds > 0)
          Text(
            AppStrings.of(context).messages
                .appStringsTryAgainInS(c.retrySeconds),
          ),
        if (!showFeed && !showExhaustedState && !c.loading)
          HistaeButton.outlined(
            onPressed: enabled
                ? (c.ready &&
                          !c.exhausted &&
                          c.pending == null &&
                          c.failure == null
                      ? c.loadMore
                      : c.refresh)
                : null,
            child: Text(
              c.failure != null && c.pending == null
                  ? text.appStringsTryAgain
                  : text.discoveryPageRefreshFeed,
            ),
          ),
        if (c.encounter case final encounter?)
          HistaeButton.textIcon(
            onPressed: !c.busy ? () => _showEncounter(encounter) : null,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              AppStrings.of(context).messages
                  .discoveryPageYourMatchWith(encounter.profile.firstname),
            ),
          ),
      ];
      return HistaeScaffold(
        appBar: AppBar(
          title: const HistaeWordmark(),
          actions: [
            if (showFeed)
              IconButton(
                key: const Key('feed-reading-settings'),
                tooltip: AppStrings.of(context).messages.readingTitle,
                onPressed: enabled && !_guideOpen ? _openReading : null,
                icon: SizedBox(
                  width: 26,
                  height: 26,
                  child: FittedBox(
                    child: Text(
                      AppStrings.of(context).messages.readingButtonLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
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
                  child: Text(text.discoveryPageRefreshFeed),
                ),
                PopupMenuItem(
                  value: 'location',
                  enabled: enabled,
                  child: Text(text.discoveryPageRefreshMyLocation),
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
          child: FeedChoiceFeedback(
            feedback: c.choiceFeedback,
            active: widget.visible,
            child: showFeed
                ? Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: FeedProfileTransition(
                            child: FeedProfileCard(
                              key: ValueKey(profile.id),
                              profile: profile,
                              active:
                                  widget.visible &&
                                  !_guideOpen &&
                                  !_readingOpen,
                              enabled:
                                  c.canChoose &&
                                  widget.visibility?.saving != true &&
                                  widget.visibility?.uncertain != true,
                              onLike: () => _choose(SwipeDecision.like),
                              onPass: () => _choose(SwipeDecision.pass),
                            ),
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
                        HistaeButton.text(
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
                : RefreshIndicator(
                    onRefresh: _refreshFromPull,
                    semanticsLabel: text.discoveryPageRefreshFeed,
                    notificationPredicate: (notification) =>
                        showExhaustedState &&
                        enabled &&
                        defaultScrollNotificationPredicate(notification),
                    child: ListView(
                      physics: showExhaustedState || _pullRefreshing
                          ? const AlwaysScrollableScrollPhysics()
                          : null,
                      padding: HistaeTokens.pagePadding,
                      children: _pullRefreshing ? [emptyState] : statusBody,
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
