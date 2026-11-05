import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'preference_field.dart';

/// A bounded integer preference with equivalent touch, button and keyboard input.
class PreferenceSlider extends StatelessWidget {
  const PreferenceSlider({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  }) : assert(minimum <= value && value <= maximum);

  final String label, valueLabel;
  final int value, minimum, maximum;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context).messages;
    final colors = Theme.of(context).colorScheme;
    final change = onChanged;
    Widget stepButton({
      required String key,
      required String tooltip,
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      final foreground = onPressed == null
          ? colors.onSurface.withValues(alpha: 0.22)
          : colors.onSurfaceVariant;
      return IconButton(
        key: Key(key),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
        ),
        icon: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: foreground.withValues(
                alpha: onPressed == null ? 0.1 : 0.35,
              ),
              width: 0.7,
            ),
          ),
          child: SizedBox.square(dimension: 30, child: Icon(icon, size: 18)),
        ),
      );
    }

    return PreferenceField(
      label: label,
      valueLabel: valueLabel,
      child: Row(
        children: [
          stepButton(
            key: 'decrease',
            tooltip: copy.registrationDecrease(label),
            onPressed: change != null && value > minimum
                ? () => change(value - 1)
                : null,
            icon: Icons.remove,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.outlineVariant,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  disabledThumbRadius: 5,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                trackShape: const RoundedRectSliderTrackShape(),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: value.toDouble(),
                min: minimum.toDouble(),
                max: maximum.toDouble(),
                divisions: maximum > minimum ? maximum - minimum : null,
                label: valueLabel,
                semanticFormatterCallback: (_) => valueLabel,
                onChanged: change != null && maximum > minimum
                    ? (next) => change(next.round())
                    : null,
              ),
            ),
          ),
          stepButton(
            key: 'increase',
            tooltip: copy.registrationIncrease(label),
            onPressed: change != null && value < maximum
                ? () => change(value + 1)
                : null,
            icon: Icons.add,
          ),
        ],
      ),
    );
  }
}
