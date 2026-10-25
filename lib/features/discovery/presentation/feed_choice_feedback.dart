import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../application/discovery_controller.dart';
import '../data/discovery_models.dart';

/// Shows a brief symbol for confirmed choices without moving the feed layout.
class FeedChoiceFeedback extends StatefulWidget {
  const FeedChoiceFeedback({
    super.key,
    required this.feedback,
    required this.active,
    required this.child,
  });

  final DiscoveryChoiceFeedback? feedback;
  final bool active;
  final Widget child;

  @override
  State<FeedChoiceFeedback> createState() => _FeedChoiceFeedbackState();
}

class _FeedChoiceFeedbackState extends State<FeedChoiceFeedback>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 650),
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void didUpdateWidget(FeedChoiceFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || widget.feedback == null) {
      _animation.value = 1;
    } else if (widget.feedback != oldWidget.feedback) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      final feedback = widget.feedback;
      final progress = _animation.value;
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      final opacity = reducedMotion
          ? 1.0
          : const Interval(0, 0.15).transform(progress) *
                (1 - const Interval(0.6, 1).transform(progress));
      return Stack(
        fit: StackFit.expand,
        children: [
          child!,
          if (widget.active && feedback != null && progress < 1)
            Center(
              child: IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  label: feedback.decision == SwipeDecision.like
                      ? AppStrings.of(context).messages.feedProfileCardLike
                      : AppStrings.of(context).messages.feedProfileCardPass,
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset:
                            !reducedMotion &&
                                feedback.decision == SwipeDecision.pass
                            ? Offset(0, -32 * progress)
                            : Offset.zero,
                        child: Transform.scale(
                          scale: reducedMotion
                              ? 1
                              : 0.75 +
                                    0.35 *
                                        Curves.easeOutCubic.transform(progress),
                          child: Container(
                            key: ValueKey(
                              'feed-choice-${feedback.decision.name}',
                            ),
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: HistaeTokens.actionGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: HistaeTokens.coral.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Icon(
                              feedback.decision == SwipeDecision.like
                                  ? Icons.favorite_rounded
                                  : Icons.keyboard_double_arrow_up_rounded,
                              size: 38,
                              color: HistaeTokens.night,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
