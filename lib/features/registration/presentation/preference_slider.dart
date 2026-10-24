import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';

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
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context).messages;
    final colors = Theme.of(context).colorScheme;
    final buttonStyle = IconButton.styleFrom(
      disabledForegroundColor: colors.onSurface.withValues(alpha: 0.28),
      disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.06),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(valueLabel, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                key: const Key('decrease'),
                tooltip: copy.registrationDecrease(label),
                style: buttonStyle,
                onPressed: value > minimum ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context)
                      .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
                  child: Slider(
                    value: value.toDouble(),
                    min: minimum.toDouble(),
                    max: maximum.toDouble(),
                    divisions: maximum > minimum ? maximum - minimum : null,
                    label: valueLabel,
                    semanticFormatterCallback: (_) => valueLabel,
                    onChanged: maximum > minimum
                        ? (next) => onChanged(next.round())
                        : null,
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const Key('increase'),
                tooltip: copy.registrationIncrease(label),
                style: buttonStyle,
                onPressed: value < maximum ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
