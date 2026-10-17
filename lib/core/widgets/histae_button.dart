import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

/// Keeps Material's input, focus and disabled behavior over the site's CTA.
class HistaeButton extends StatelessWidget {
  const HistaeButton({super.key, required this.onPressed, required this.child})
    : icon = null;
  const HistaeButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
  }) : child = label;

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.onSurface.withValues(alpha: 0.38)
            : HistaeTokens.night,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? const BorderSide(color: HistaeTokens.focus, width: 2)
            : BorderSide.none,
      ),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        gradient: onPressed == null ? null : HistaeTokens.actionGradient,
        color: onPressed == null ? colors.surfaceContainerHighest : null,
      ),
      child: icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: icon!,
              label: child,
            ),
    );
  }
}
