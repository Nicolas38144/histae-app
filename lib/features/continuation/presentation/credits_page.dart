import 'dart:async';

import 'package:flutter/material.dart';

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
    await c.access.session.synchronize();
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
    await c.activate();
    if (c.rewards.intent != null) await c.rewards.refresh();
  }

  Future<void> _cancelReward() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette demande ?'),
        content: const Text(
          'L’annulation empêchera toute validation ultérieure, même si une vidéo déjà terminée est encore en cours de vérification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver'),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la demande'),
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
            title: const Text('Vos crédits'),
            actions: [
              IconButton(
                onPressed: c.loading || video.busy || c.retrySeconds > 0
                    ? null
                    : _refresh,
                tooltip: 'Actualiser mes crédits',
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
                    'LE TEMPS DE CONTINUER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La suite commence\nici.',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Des crédits pour les rencontres que vous avez envie de poursuivre.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (c.loading) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Lecture de vos crédits',
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
                              'Votre solde reste à vérifier',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c.failure == null
                                  ? 'Actualisez vos crédits pour retrouver votre solde.'
                                  : ContinuationStrings.failure(c.failure!),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: c.retrySeconds > 0 ? null : _refresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                c.retrySeconds > 0
                                    ? 'Réessayer dans ${c.retrySeconds} s'
                                    : 'Actualiser mes crédits',
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
                    'Une rencontre se poursuit à deux. Chacun confirme son propre choix.',
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
