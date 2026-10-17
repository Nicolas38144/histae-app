import 'package:flutter/material.dart';

import '../data/match_models.dart';
import 'matches_strings.dart';

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.match,
    required this.compact,
    required this.connected,
    required this.loading,
    required this.onDecisions,
  });
  final UserMatch match;
  final bool compact, connected, loading;
  final Future<void> Function() onDecisions;

  Future<void> _details(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      titleTextStyle: Theme.of(dialogContext).textTheme.titleMedium
          ?.copyWith(color: Theme.of(dialogContext).colorScheme.onSurface),
      title: Text(MatchesStrings.status(match.status)),
      content: Text(
        '${MatchesStrings.stateBody(match)}${connected ? '' : '\n\nConnexion en reprise. Vous pouvez actualiser la conversation manuellement.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );

  String get _action => match.status == MatchStatus.awaitingContinuation
      ? 'Choisir la suite'
      : 'Photos et continuation';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = IconButton(
      tooltip: 'État de la conversation',
      onPressed: () => _details(context),
      icon: Icon(
        Icons.info_outline_rounded,
        size: 21,
        color: theme.colorScheme.primary,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 10, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDecisions,
                    child: Text(
                      match.status == MatchStatus.awaitingContinuation
                          ? 'En pause'
                          : 'Vos choix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                info,
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    MatchesStrings.status(match.status),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                info,
              ],
            ),
            Text(
              MatchesStrings.stateBody(match),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onDecisions,
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: Text(_action),
              ),
            ),
            if (!connected)
              Text(
                'Connexion en reprise · actualisation manuelle disponible.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (loading)
            const LinearProgressIndicator(
              semanticsLabel: 'Synchronisation de la conversation',
            ),
        ],
      ),
    );
  }
}
