import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/continuation_controller.dart';
import '../application/rewarded_video_controller.dart';
import 'continuation_strings.dart';
import 'credits_balance_panel.dart';
import 'reward_video_card.dart';
import 'rewarded_video_scope.dart';

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key, required this.controller});
  final ContinuationController controller;

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> with WidgetsBindingObserver {
  ContinuationController get c => widget.controller;
  late final _key = c.access.session.resourceKey;
  RewardedVideoController? _video;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _video ??= RewardedVideoController(c, RewardedVideoScope.maybeOf(context));
  }

  Future<void> _start() async {
    await c.activate();
    if (mounted && c.accessible) {
      _video?.resume();
      c.rewards.activate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _video?.foreground =
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.detached;
    // Native consent/video screens may temporarily take the Activity away.
    // Keep their attempt alive; page/session invalidation still discards it.
    if (_video?.nativeOverlay == true) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    } else if (state != AppLifecycleState.inactive) {
      _video?.suspend();
      c.suspend();
    }
  }

  Future<void> _resume() async {
    if (mounted && c.access.session.resourceKey == _key) await _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    c.suspend(notify: false);
    super.dispose();
  }

  Future<void> _refresh() async {
    await c.refreshQuota();
    if (c.rewards.intent != null) await c.rewards.refresh();
  }

  Future<void> _cancelReward() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.of(context).messages.creditsPageCancelThisRequest,
        ),
        content: Text(
          AppStrings.of(context)
              .messages
              .creditsPageCancellationPreventsAnyLaterValidationEven,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).messages.creditsPageKeep),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.of(context).messages.creditsPageCancelRequest,
            ),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await c.rewards.cancel(completedVideoWarningAccepted: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.rewards, _video!]),
    builder: (context, _) {
      if (!c.accessible || c.access.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final q = c.quota, video = _video!, theme = Theme.of(context);
      final fresh = q != null && c.quotaReadAt != null;
      return PopScope(
        canPop: !video.busy,
        child: HistaeScaffold(
          appBar: AppBar(
            title: Text(AppStrings.of(context).messages.creditsPageYourCredits),
            actions: [
              IconButton(
                onPressed: c.loading || video.busy || c.retrySeconds > 0
                    ? null
                    : _refresh,
                tooltip: AppStrings.of(context)
                    .messages
                    .creditsPageRefreshMyCredits,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: video.busy ? () async {} : _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  Text(
                    AppStrings.of(context).messages.creditsPageTimeToContinue,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .creditsPageTheNextChapterStartsHere,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .creditsPageCreditsForTheConnectionsYouWant,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (c.loading) ...[
                    LinearProgressIndicator(
                      semanticsLabel: AppStrings.of(context)
                          .messages
                          .creditsPageCheckingYourCredits,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (fresh) ...[
                    CreditsBalancePanel(quota: q),
                    if (!q.premium) ...[
                      const SizedBox(height: 16),
                      CreditsWeekPanel(quota: q),
                    ],
                  ] else if (!c.loading)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 32),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.of(context)
                                  .messages
                                  .creditsPageYourBalanceStillNeedsChecking,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c.failure == null
                                  ? AppStrings.of(context)
                                        .messages
                                        .creditsPageRefreshYourCreditsToViewYour
                                  : ContinuationStrings(AppStrings.of(context))
                                        .failure(c.failure!),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: c.retrySeconds > 0 ? null : _refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                c.retrySeconds > 0
                                    ? AppStrings.of(context).messages
                                          .continuationBalanceCardTryAgainInS(
                                            c.retrySeconds,
                                          )
                                    : AppStrings.of(context)
                                          .messages
                                          .creditsPageRefreshMyCredits,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (fresh && !q.premium) ...[
                    const SizedBox(height: 16),
                    RewardVideoCard(
                      credits: c,
                      video: video,
                      onCancel: _cancelReward,
                    ),
                    const SizedBox(height: 16),
                    CreditsExplanation(quota: q),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .creditsPageAMatchContinuesTogetherEachPerson,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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
