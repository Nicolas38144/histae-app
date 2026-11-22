import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../data/casework_entry.dart';
import 'casework_strings.dart';

class SupportRequestForm extends StatelessWidget {
  const SupportRequestForm({
    super.key,
    required this.category,
    required this.onCategoryChanged,
    required this.composer,
  });

  final String category;
  final ValueChanged<String?>? onCategoryChanged;
  final Widget composer;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialCard(
          title: text.supportNewRequest,
          body: text.caseworkSupportHelp,
        ),
        const SizedBox(height: HistaeTokens.textSpacing),
        DropdownButtonFormField<String>(
          initialValue: category,
          isExpanded: true,
          decoration: InputDecoration(labelText: text.caseworkCategory),
          items: [
            for (final value in [
              'login',
              'billing',
              'appeal',
              'privacy',
              'other',
            ])
              DropdownMenuItem(
                value: value,
                child: Text(caseworkValueLabel(text, value)),
              ),
          ],
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: HistaeTokens.contentSpacing),
        composer,
      ],
    );
  }
}

class SupportRequestCard extends StatelessWidget {
  const SupportRequestCard({super.key, required this.entry});

  final CaseworkEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: HistaeTokens.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: HistaeTokens.textSpacing,
              runSpacing: HistaeTokens.labelSpacing,
              children: [
                Text(
                  caseworkValueLabel(text, entry.topic),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  caseworkValueLabel(text, entry.status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (entry.createdAt case final date?) ...[
              const SizedBox(height: HistaeTokens.labelSpacing),
              Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(date.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (entry.body.isNotEmpty) ...[
              const SizedBox(height: HistaeTokens.textSpacing),
              SelectableText(entry.body),
            ],
            if (entry.response case final response?
                when response.isNotEmpty) ...[
              const Divider(height: HistaeTokens.sectionSpacing),
              Text(text.caseworkTeam, style: theme.textTheme.titleSmall),
              const SizedBox(height: HistaeTokens.labelSpacing),
              SelectableText(response),
            ],
          ],
        ),
      ),
    );
  }
}
