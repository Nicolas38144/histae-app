import 'package:flutter/material.dart';

// A scrolling choice dialog keeps long labels readable with large text.
class PrivacyChoice<T> extends StatelessWidget {
  const PrivacyChoice({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label),
      const SizedBox(height: 8),
      OutlinedButton(
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
      const SizedBox(height: 12),
    ],
  );
}
