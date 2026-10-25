import 'package:flutter/material.dart';

/// Slides the previous profile up and brings the next one in from below.
class FeedProfileTransition extends StatelessWidget {
  const FeedProfileTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final profile in [...previous, ?current])
            ExcludeFocus(
              key: profile.key,
              excluding: profile != current,
              child: ExcludeSemantics(
                excluding: profile != current,
                child: IgnorePointer(
                  ignoring: profile != current,
                  child: TickerMode(
                    enabled: profile == current,
                    child: profile,
                  ),
                ),
              ),
            ),
        ],
      ),
      transitionBuilder: (profile, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, profile.key == child.key ? 1 : -1),
          end: Offset.zero,
        ).animate(animation),
        child: profile,
      ),
      child: child,
    ),
  );
}
