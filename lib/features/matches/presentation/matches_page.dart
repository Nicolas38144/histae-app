import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../continuation/presentation/continuation_balance_card.dart';
import '../../continuation/presentation/credits_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../application/matches_controller.dart';
import 'chat_page.dart';
import 'match_preview_card.dart';
import 'matches_strings.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({
    super.key,
    required this.controller,
    this.initialMatchId,
    this.onInitialMatchHandled,
    this.notificationFlow = false,
  });
  final MatchesController controller;
  final String? initialMatchId;
  final VoidCallback? onInitialMatchHandled;
  final bool notificationFlow;
  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> with WidgetsBindingObserver {
  MatchesController get c => widget.controller;
  late final _key = c.session.resourceKey;
  bool _opening = false;
  bool _creditsOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    final initialMatchId = widget.initialMatchId;
    widget.onInitialMatchHandled?.call();
    await c.activate();
    if (mounted && initialMatchId != null && c.accessible) {
      await _open(initialMatchId);
    }
    if (mounted &&
        c.session.resourceKey == _key &&
        c.active &&
        ModalRoute.of(context)?.isCurrent == true) {
      await c.continuation.activate();
    }
  }

  Future<void> _open(String id) async {
    if (_opening) return;
    _opening = true;
    try {
      await c.openChat(id);
      if (!mounted || !c.accessible || c.session.resourceKey != _key) return;
      if (c.selected?.id != id || c.selected?.historyAllowed != true) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(controller: c, matchId: id),
        ),
      );
      if (mounted && c.active) await _refresh();
    } finally {
      _opening = false;
    }
  }

  Future<void> _refresh() async {
    c.continuation.suspend();
    await c.refresh();
    if (mounted && c.active && c.session.resourceKey == _key) {
      await c.continuation.activate();
    }
  }

  Future<void> _openCredits() async {
    if (_opening) return;
    _opening = true;
    _creditsOpen = true;
    c.continuation.suspend();
    c.suspend();
    try {
      final route = MaterialPageRoute<void>(
        builder: (_) => CreditsPage(controller: c.continuation),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      _creditsOpen = false;
      _opening = false;
      if (mounted && c.session.resourceKey == _key) await _resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_creditsOpen) return; // CreditsPage owns native ad/consent lifecycle.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      c.suspend();
      c.continuation.suspend();
    }
    if (state == AppLifecycleState.resumed) unawaited(_resume());
  }

  Future<void> _resume() async {
    if (_creditsOpen) return;
    if (!widget.notificationFlow &&
        PushScope.maybeOf(context)?.coversMainFlow == true) {
      return;
    }
    await c.session.synchronize();
    if (mounted && c.session.resourceKey == _key) {
      await c.activate();
      if (mounted && c.active && ModalRoute.of(context)?.isCurrent == true) {
        await c.continuation.activate();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.suspend(notify: false);
    c.continuation.suspend(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.continuation]),
    builder: (context, _) {
      if (!c.accessible || c.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      return HistaeScaffold(
        appBar: AppBar(
          title: const Text('Vos rencontres'),
          actions: [
            IconButton(
              tooltip: 'Vos crédits',
              onPressed: _openCredits,
              icon: const Icon(Icons.account_balance_wallet_outlined),
            ),
            IconButton(
              tooltip: 'Actualiser les rencontres',
              onPressed: c.listLoading || c.retrySeconds > 0 ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                ContinuationBalanceCard(
                  controller: c.continuation,
                  onVideos: _openCredits,
                ),
                const SizedBox(height: 24),
                const EditorialCard(
                  eyebrow: 'PRENDRE LE TEMPS',
                  title: 'Les mots\ncontinuent.',
                  body: 'Un intérêt réciproque, puis un espace pour faire connaissance.',
                ),
                const SizedBox(height: 16),
                if (!c.realtimeConnected)
                  const Text(
                    'Actualisation en reprise. Vous pouvez relire vos rencontres manuellement.',
                  ),
                if (c.listLoading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Chargement des rencontres',
                  ),
                if (c.notice == 'ended')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Cette rencontre est terminée.'),
                  ),
                if (c.failure case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(MatchesStrings.failure(error)),
                    ),
                  ),
                if (!c.listLoading && c.items.isEmpty && c.failure == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aucune rencontre pour le moment. Elles apparaîtront après un intérêt réciproque.',
                    ),
                  ),
                for (final match in c.items)
                  MatchPreviewCard(
                    match: match,
                    ownerId: c.ownerId,
                    onTap: _opening ? null : () => _open(match.id),
                  ),
                if (c.retrySeconds > 0)
                  Text('Nouvel essai possible dans ${c.retrySeconds} s'),
                if (c.listCursor != null)
                  OutlinedButton(
                    onPressed: c.listLoading || c.retrySeconds > 0
                        ? null
                        : c.loadMore,
                    child: const Text('Voir les rencontres suivantes'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
