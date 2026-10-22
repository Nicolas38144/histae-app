import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

/// A route background matching the site's quiet, two-corner ambient light.
/// Scaffold retains keyboard avoidance, semantics and navigation behavior.
class HistaeScaffold extends StatelessWidget {
  const HistaeScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.extendBody = false,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.1, -1.1),
            radius: 1.25,
            colors: [
              HistaeTokens.lavender.withValues(alpha: dark ? 0.1 : 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.25, 1.25),
              radius: 1,
              colors: [
                HistaeTokens.coral.withValues(alpha: dark ? 0.05 : 0.04),
                Colors.transparent,
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: extendBody,
            appBar: appBar == null
                ? null
                : PreferredSize(
                    preferredSize: appBar!.preferredSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      child: appBar!,
                    ),
                  ),
            body: body,
            bottomNavigationBar: bottomNavigationBar,
          ),
        ),
      ),
    );
  }
}
