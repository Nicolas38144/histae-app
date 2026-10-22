import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_empty_state.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../continuation/presentation/continuation_balance_card.dart';
import '../../continuation/presentation/credits_page.dart';
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

class _MatchesPageState extends State<MatchesPage> {
  MatchesController get c => widget.controller;
  late final _key = c.session.resourceKey;
  bool _opening = false;
  int _overviewLoads = 1;

  bool get _loading =>
      _overviewLoads > 0 || c.listLoading || c.continuation.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start().whenComplete(_endOverview));
    });
  }

  @override
  void didUpdateWidget(covariant MatchesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.initialMatchId;
    if (id != null && id != oldWidget.initialMatchId) {
      widget.onInitialMatchHandled?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_open(id));
      });
    }
  }

  Future<void> _start() async {
    final initialMatchId = widget.initialMatchId;
    widget.onInitialMatchHandled?.call();
    await c.activate(refresh: widget.notificationFlow);
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
    } finally {
      _opening = false;
      if (mounted) await c.continuation.activate();
    }
  }

  void _endOverview() {
    if (mounted) setState(() => _overviewLoads--);
  }

  Future<void> _withOverview(Future<void> Function() read) async {
    if (!mounted) return;
    setState(() => _overviewLoads++);
    try {
      await read();
    } finally {
      _endOverview();
    }
  }

  Future<void> _refresh() async {
    if (_overviewLoads > 0) return;
    await _withOverview(() async {
      c.continuation.suspend();
      await c.refresh();
      if (mounted && c.active && c.session.resourceKey == _key) {
        await c.continuation.refreshQuota();
      }
    });
  }

  Future<void> _openCredits() async {
    if (_opening) return;
    _opening = true;
    try {
      final route = MaterialPageRoute<void>(
        builder: (_) => CreditsPage(controller: c.continuation),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      _opening = false;
      if (mounted) await c.continuation.activate();
    }
  }

  @override
  void dispose() {
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
          title: Text(AppStrings.of(context).messages.matchesPageYourMatches),
          actions: [
            IconButton(
              tooltip: AppStrings.of(context).messages.creditsPageYourCredits,
              onPressed: _openCredits,
              icon: const Icon(Icons.account_balance_wallet_outlined),
            ),
            IconButton(
              tooltip: AppStrings.of(context)
                  .messages
                  .discoveryPageRefreshEncounters,
              onPressed: _loading || c.retrySeconds > 0 ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 3,
                child: _loading
                    ? LinearProgressIndicator(
                        key: Key('matches-loading'),
                        semanticsLabel: AppStrings.of(context)
                            .messages
                            .matchesPageRefreshingMatchesAndCredits,
                      )
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (!_loading && c.items.isEmpty && c.failure == null)
                        HistaeEmptyState(
                          key: const Key('matches-empty'),
                          title: AppStrings.of(context)
                              .messages
                              .matchesEmptyTitle,
                          body: AppStrings.of(context)
                              .messages
                              .matchesPageNoMatchesYetTheyWillAppear,
                        )
                      else
                        EditorialCard(
                          eyebrow: AppStrings.of(context)
                              .messages
                              .discoveryPageTakeYourTime,
                          title: AppStrings.of(context)
                              .messages
                              .matchesPageWordsContinue,
                          body: AppStrings.of(context)
                              .messages
                              .matchesPageMutualInterestThenASpaceTo,
                        ),
                      const SizedBox(height: 16),
                      ContinuationBalanceCard(
                        controller: c.continuation,
                        onOpenCredits: _openCredits,
                        loading: _overviewLoads > 0,
                      ),
                      const SizedBox(height: 16),
                      if (!c.realtimeConnected)
                        Text(
                          AppStrings.of(context)
                              .messages
                              .matchesPageReconnectingUpdatesYouCanRefreshYour,
                        ),
                      if (c.notice == 'ended')
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            AppStrings.of(context)
                                .messages
                                .matchesPageThisMatchHasEnded,
                          ),
                        ),
                      if (c.failure case final error?)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              MatchesStrings(AppStrings.of(context))
                                  .failure(error),
                            ),
                          ),
                        ),
                      for (final match in c.items)
                        MatchPreviewCard(
                          match: match,
                          ownerId: c.ownerId,
                          onTap: _opening ? null : () => _open(match.id),
                        ),
                      if (c.retrySeconds > 0)
                        Text(
                          AppStrings.of(context).messages
                              .appStringsTryAgainInS(c.retrySeconds),
                        ),
                      if (c.listCursor != null)
                        OutlinedButton(
                          onPressed: c.listLoading || c.retrySeconds > 0
                              ? null
                              : c.loadMore,
                          child: Text(
                            AppStrings.of(context)
                                .messages
                                .matchesPageViewMoreMatches,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
