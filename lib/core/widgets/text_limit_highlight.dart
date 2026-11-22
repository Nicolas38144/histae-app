import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

/// Adds limit feedback without changing the field's content or layout.
class TextLimitHighlight extends StatelessWidget {
  const TextLimitHighlight({
    super.key,
    required this.reached,
    required this.limitHint,
    required this.decoration,
    required this.builder,
  });

  final bool reached;
  final String limitHint;
  final InputDecoration decoration;
  final Widget Function(InputDecoration) builder;

  static const _radius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      hint: reached ? limitHint : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: reached ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, emphasis, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            boxShadow: [
              BoxShadow(
                color: HistaeTokens.coral.withValues(alpha: .16 * emphasis),
                blurRadius: 14 * emphasis,
              ),
            ],
          ),
          child: builder(
            decoration.copyWith(
              enabledBorder: OutlineInputBorder(
                borderRadius: _radius,
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
                borderRadius: _radius,
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
  }
}
