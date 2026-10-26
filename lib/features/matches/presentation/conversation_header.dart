import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/match_models.dart';
import 'matches_strings.dart';

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.match,
    required this.compact,
    required this.loading,
    required this.onDecisions,
  });
  final UserMatch match;
  final bool compact, loading;
  final Future<void> Function() onDecisions;

  Future<void> _details(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      titleTextStyle: Theme.of(dialogContext).textTheme.titleMedium
          ?.copyWith(color: Theme.of(dialogContext).colorScheme.onSurface),
      title: Text(MatchesStrings(AppStrings.of(context)).status(match.status)),
      content: Text(MatchesStrings(AppStrings.of(context)).stateBody(match)),
      actions: [
        HistaeButton.text(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppStrings.of(context).messages.conversationHeaderClose),
        ),
      ],
    ),
  );

  String _action(BuildContext context) =>
      match.status == MatchStatus.awaitingContinuation
      ? AppStrings.of(context).messages.conversationHeaderChooseWhatComesNext
      : match.photosRevealed
      ? AppStrings.of(context).messages.photoRevealManage
      : match.myRevealed
      ? AppStrings.of(context).messages.photoRevealWaitingAction
      : AppStrings.of(context).messages.photoRevealShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = IconButton(
      tooltip: AppStrings.of(context)
          .messages
          .conversationHeaderConversationStatus,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  MatchesStrings(AppStrings.of(context)).status(match.status),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              info,
            ],
          ),
          if (!compact)
            Align(
              alignment: Alignment.centerLeft,
              child: HistaeButton.textIcon(
                onPressed: onDecisions,
                icon: Icon(
                  match.photosRevealed
                      ? Icons.photo_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(_action(context)),
              ),
            ),
          if (loading)
            LinearProgressIndicator(
              semanticsLabel: AppStrings.of(context)
                  .messages
                  .conversationHeaderSyncingConversation,
            ),
        ],
      ),
    );
  }
}
