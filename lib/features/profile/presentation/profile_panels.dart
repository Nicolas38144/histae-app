import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/profile_models.dart';
import 'profile_strings.dart';

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    required this.action,
    required this.onPressed,
    this.count,
  });
  final String title, action;
  final String? count;
  final IconData icon;
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: colors.primary, size: 22),
                ),
                if (count != null)
                  Text(
                    count!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: HistaeButton.textIcon(
                onPressed: onPressed,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileAnswersPreview extends StatelessWidget {
  const ProfileAnswersPreview({
    super.key,
    required this.answers,
    required this.unavailable,
  });
  final List<ProfileAnswer> answers;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    if (unavailable) {
      return Text(
        AppStrings.of(context)
            .messages
            .profilePanelsYourAnswersCouldNotBeRefreshed,
      );
    }
    if (answers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.of(context)
                .messages
                .profilePanelsLittleDetailsMakeGreatConversations,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context)
                .messages
                .profilePanelsChooseUpToThreeQuestionsTo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    final ordered = answers.toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
          Text(
            AppStrings.of(context).messages.profilePanels(
              (i + 1).toString().padLeft(2, '0'),
              ordered[i].question,
            ),
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 8),
          Text(ordered[i].answer, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          ProfileModerationLabel(moderation: ordered[i].moderation),
        ],
      ],
    );
  }
}

class ProfileModerationLabel extends StatelessWidget {
  const ProfileModerationLabel({super.key, required this.moderation});
  final Moderation? moderation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      ProfileStrings(AppStrings.of(context)).moderation(moderation),
      style: theme.textTheme.bodySmall?.copyWith(
        color: moderation?.status == 'rejected'
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class ProfileDetailTile extends StatelessWidget {
  const ProfileDetailTile({
    super.key,
    required this.title,
    required this.summary,
    required this.action,
    required this.icon,
    required this.onTap,
    this.details,
  });
  final String title, summary, action;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: colors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (details != null) ...[const SizedBox(height: 12), details!],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: HistaeButton.textIcon(
                onPressed: onTap,
                label: Text(action),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
