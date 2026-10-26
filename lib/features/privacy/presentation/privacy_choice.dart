import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';

// A scrolling choice dialog keeps long labels readable with large text.

class PrivacyChoice<T> extends StatelessWidget {
  const PrivacyChoice({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    this.descriptions,
    this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> choices;
  final Map<T, String>? descriptions;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label),
      const SizedBox(height: 8),
      HistaeButton.outlined(
        onPressed: onChanged == null
            ? null
            : () async {
                final selected = await showDialog<T>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: Text(label),
                    children: [
                      for (final entry in choices.entries)
                        SimpleDialogOption(
                          onPressed: () => Navigator.of(context).pop(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(entry.value),
                          ),
                        ),
                    ],
                  ),
                );
                if (context.mounted && selected != null) {
                  onChanged?.call(selected);
                }
              },
        child: Row(
          children: [
            Expanded(child: Text(choices[value]!, softWrap: true)),
            const SizedBox(width: 12),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
      if (descriptions?[value] case final description?)
        IconTheme.merge(
          data: const IconThemeData(size: 18),
          child: ExpansionTile(
            key: ValueKey(value),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            shape: const Border(),
            collapsedShape: const Border(),
            dense: true,
            iconColor: Theme.of(context).colorScheme.primary,
            collapsedIconColor: Theme.of(context).colorScheme.primary,
            title: Text(
              AppStrings.of(context).messages.privacyRightExplanationTitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
    ],
  );
}
