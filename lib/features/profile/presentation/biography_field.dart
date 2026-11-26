import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/text/text_limit_input_formatter.dart';
import '../../../core/widgets/text_limit_highlight.dart';
import '../data/profile_models.dart';

/// Keeps text and composition intact while showing when a limit is reached.
class BiographyField extends StatelessWidget {
  const BiographyField({
    super.key,
    required this.controller,
    this.onChanged,
    this.enabled = true,
    this.minLines,
    this.maxLines = 5,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final text = AppStrings.of(context).messages;
          return TextLimitHighlight(
            reached: biographyTextLimit.reached(value.text),
            limitHint: text.biographyLimitReached,
            decoration: InputDecoration(
              labelText: text.identityEditorAFewWordsAboutYou,
              alignLabelWithHint: true,
              helperText: value.text.trim().isEmpty ? text.bioRequired : null,
              helperMaxLines: 3,
            ),
            builder: (decoration) => TextField(
              controller: controller,
              inputFormatters: const [
                TextLimitInputFormatter(biographyTextLimit),
              ],
              enabled: enabled,
              onChanged: onChanged,
              minLines: minLines,
              maxLines: maxLines,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
            ),
          );
        },
      );
}
