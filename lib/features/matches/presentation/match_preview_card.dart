import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/match_models.dart';
import 'match_photo_avatar.dart';
import 'matches_strings.dart';

class MatchPreviewCard extends StatelessWidget {
  const MatchPreviewCard({
    super.key,
    required this.match,
    required this.ownerId,
    required this.onTap,
    this.photoReadAt,
    this.photosAllowed = false,
    this.refreshPhotoAccess,
  });
  final UserMatch match;
  final String ownerId;
  final VoidCallback? onTap;
  final DateTime? photoReadAt;
  final bool photosAllowed;
  final Future<void> Function()? refreshPhotoAccess;

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
                  MatchPhotoAvatar(
                    key: ValueKey('$ownerId:${match.id}'),
                    url: match.partner.photo,
                    readAt: photoReadAt,
                    refreshAccess: refreshPhotoAccess,
                    allowed:
                        photosAllowed &&
                        match.historyAllowed &&
                        match.photosRevealed,
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
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Semantics(
                      label: AppStrings.of(context).messages
                          .unreadMessages(match.unreadCount),
                      child: ExcludeSemantics(
                        child: Container(
                          key: ValueKey('match-unread-${match.id}'),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${match.unreadCount}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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
