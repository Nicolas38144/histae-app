import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

enum _ActionStyle { primary, outlined, text }

/// Shared action spacing and Material interaction for all branded buttons.
class HistaeButton extends StatelessWidget {
  const HistaeButton({super.key, required this.onPressed, required this.child})
    : icon = null,
      _actionStyle = _ActionStyle.primary;

  const HistaeButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
  }) : child = label,
       _actionStyle = _ActionStyle.primary;

  const HistaeButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
  }) : icon = null,
       _actionStyle = _ActionStyle.outlined;

  const HistaeButton.outlinedIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
  }) : child = label,
       _actionStyle = _ActionStyle.outlined;

  const HistaeButton.text({
    super.key,
    required this.onPressed,
    required this.child,
  }) : icon = null,
       _actionStyle = _ActionStyle.text;

  const HistaeButton.textIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
  }) : child = label,
       _actionStyle = _ActionStyle.text;

  final _ActionStyle _actionStyle;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final Widget action;
    switch (_actionStyle) {
      case _ActionStyle.primary:
        action = _primary(context);
      case _ActionStyle.outlined:
        action = icon == null
            ? OutlinedButton(onPressed: onPressed, child: child)
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: icon!,
                label: child,
              );
      case _ActionStyle.text:
        action = icon == null
            ? TextButton(onPressed: onPressed, child: child)
            : TextButton.icon(onPressed: onPressed, icon: icon!, label: child);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: HistaeTokens.actionSpacing / 2,
      ),
      child: action,
    );
  }

  Widget _primary(BuildContext context) {
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
