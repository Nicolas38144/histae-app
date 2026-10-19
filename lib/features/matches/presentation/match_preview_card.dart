import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/match_models.dart';
import 'matches_strings.dart';

class MatchPreviewCard extends StatelessWidget {
  const MatchPreviewCard({
    super.key,
    required this.match,
    required this.ownerId,
    required this.onTap,
  });
  final UserMatch match;
  final String ownerId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(HistaeTokens.panelRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: colors.primary,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.of(context).messages.encounterPage(
                            match.partner.firstname,
                            match.partner.age,
                          ),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          MatchesStrings(AppStrings.of(context))
                              .status(match.status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              if (match.lastMessage case final last?) ...[
                const SizedBox(height: 16),
                Text(
                  AppStrings.of(context).messages.matchPreviewCard(
                    last.senderId == ownerId
                        ? AppStrings.of(context).messages.matchPreviewCardYou
                        : '',
                    last.content,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (match.unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    AppStrings.of(context).messages
                        .unreadMessages(match.unreadCount),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
