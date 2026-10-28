import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_empty_state.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/matches_controller.dart';
import '../data/match_models.dart';
import 'match_list_projection.dart';
import 'matches_strings.dart';

/// Reuses the owner's live snapshots and navigation; it owns only its search.
class ArchivedMatchesPage extends StatefulWidget {
  const ArchivedMatchesPage({
    super.key,
    required this.controller,
    required this.cardBuilder,
  });

  final MatchesController controller;
  final Widget Function(UserMatch match) cardBuilder;

  @override
  State<ArchivedMatchesPage> createState() => _ArchivedMatchesPageState();
}

class _ArchivedMatchesPageState extends State<ArchivedMatchesPage> {
  late final _key = widget.controller.session.resourceKey;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.accessible || c.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final text = AppStrings.of(context).messages;
      final now = c.serverNow;
      final list = MatchListProjection(
        c.items.where((match) => match.isArchivedAt(now)),
        now: now,
        search: _search.text,
      );
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(text.matchesArchivedTitle),
          actions: [
            IconButton(
              tooltip: text.discoveryPageRefreshEncounters,
              onPressed: c.listLoading || c.retrySeconds > 0 ? null : c.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (list.hasMatches)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: TextField(
                    key: const Key('archives-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: text.matchesSearchLabel,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: text.matchesSearchClear,
                              onPressed: () => setState(_search.clear),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              SizedBox(
                height: 3,
                child: c.listLoading ? const LinearProgressIndicator() : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: c.refresh,
                  child: ListView(
                    key: const Key('archived-matches-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (c.failure case final error?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              MatchesStrings(AppStrings.of(context))
                                  .failure(error),
                            ),
                          ),
                        ),
                      if (!list.hasMatches &&
                          !c.listLoading &&
                          c.failure == null)
                        HistaeEmptyState(title: text.matchesArchivesEmpty),
                      if (list.query.isNotEmpty &&
                          !list.hasResults &&
                          !c.listLoading)
                        Text(text.matchesSearchEmpty),
                      if (list.query.isNotEmpty && c.listCursor != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(text.matchesSearchLoadedOnly),
                        ),
                      for (final match in list.archived)
                        widget.cardBuilder(match),
                      if (c.retrySeconds > 0)
                        Text(text.appStringsTryAgainInS(c.retrySeconds)),
                      if (c.listCursor != null)
                        HistaeButton.outlined(
                          onPressed: c.listLoading || c.retrySeconds > 0
                              ? null
                              : c.loadMore,
                          child: Text(text.matchesPageViewMoreMatches),
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
