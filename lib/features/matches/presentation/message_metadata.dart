import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/match_models.dart';
import 'matches_strings.dart';

/// Keeps receipts secondary to the message and uses only server-confirmed state.
class MessageMetadata extends StatelessWidget {
  const MessageMetadata({super.key, required this.message, required this.own});

  final ChatMessage message;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
    );
    final read = message.readAt != null;
    final status = read
        ? strings.messages.chatPageRead
        : strings.messages.chatPageSent;
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(MatchesStrings(strings).date(message.createdAt), style: style),
        if (own)
          Tooltip(
            message: status,
            excludeFromSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    read ? Icons.done_all_rounded : Icons.check_rounded,
                    size: 13,
                    color: read
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Text(status, style: style),
              ],
            ),
          ),
      ],
    );
  }
}
