import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/match_models.dart';
import 'matches_strings.dart';
import 'message_bubble.dart';
import 'message_sending_indicator.dart';

/// A submitted intention is visible immediately, without inventing a receipt.
class PendingMessageTile extends StatelessWidget {
  const PendingMessageTile({
    super.key,
    required this.intent,
    required this.maxWidth,
    required this.active,
    this.failure,
    this.onRetry,
  });

  final MessageIntent intent;
  final double maxWidth;
  final bool active;
  final ApiFailure? failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MessageBubble.pending(content: intent.content),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: failure == null
                      ? MessageSendingIndicator(
                          key: ValueKey('message-sending-${intent.key}'),
                          active: active,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              MatchesStrings(AppStrings.of(context))
                                  .failure(failure!),
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.end,
                            ),
                            HistaeButton.text(
                              onPressed: onRetry,
                              child: Text(
                                AppStrings.of(context)
                                    .messages
                                    .appStringsTryAgain,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
