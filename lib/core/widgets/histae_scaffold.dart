import 'package:flutter/material.dart';

/// A solid route background using the app's theme surface.
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
    return Scaffold(
      backgroundColor: colors.surface,
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
    );
  }
}
