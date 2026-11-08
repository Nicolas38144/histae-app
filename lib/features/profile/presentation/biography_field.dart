import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../data/profile_models.dart';

/// Keeps text and composition intact while making the API byte limit visible.
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
          final colors = Theme.of(context).colorScheme;
          final reached = biographyByteLength(value.text) >= biographyByteLimit;
          return Semantics(
            hint: reached ? text.biographyLimitReached : null,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: reached ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, emphasis, _) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: HistaeTokens.coral.withValues(
                        alpha: .16 * emphasis,
                      ),
                      blurRadius: 14 * emphasis,
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  onChanged: onChanged,
                  minLines: minLines,
                  maxLines: maxLines,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: text.identityEditorAFewWordsAboutYou,
                    alignLabelWithHint: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Color.lerp(
                          colors.outline,
                          HistaeTokens.coral,
                          emphasis,
                        )!,
                        width: 1 + emphasis,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Color.lerp(
                          colors.primary,
                          HistaeTokens.coral,
                          emphasis,
                        )!,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
