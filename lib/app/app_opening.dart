import 'dart:ui' show FontVariation, lerpDouble;

import 'package:flutter/material.dart';

import '../core/theme/histae_tokens.dart';
import '../core/widgets/histae_brand_symbol.dart';

/// A one-shot presentation above the live navigator. Session restoration and
/// incoming navigation continue while the opening hides their first frames.
class AppOpening extends StatefulWidget {
  const AppOpening({required this.child, super.key});

  final Widget child;

  @override
  State<AppOpening> createState() => _AppOpeningState();
}

class _AppOpeningState extends State<AppOpening>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1480),
  )..addStatusListener(_statusChanged);
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _finished = true;
    } else if (!_started && !_finished) {
      _started = true;
      _animation.forward();
    }
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_finished) {
      setState(() => _finished = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_finished &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      _animation.stop();
      setState(() => _finished = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: !_finished,
        child: ExcludeSemantics(
          excluding: !_finished,
          child: IgnorePointer(ignoring: !_finished, child: widget.child),
        ),
      ),
      if (!_finished)
        Positioned.fill(
          key: const Key('app-opening'),
          child: Semantics(
            label: 'Histae',
            excludeSemantics: true,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final progress = _animation.value;
                final separation = const Interval(
                  0.1,
                  0.68,
                  curve: Curves.easeInOutCubic,
                ).transform(progress);
                final symbol = const Interval(
                  0.52,
                  0.78,
                  curve: Curves.easeOut,
                ).transform(progress);
                final fade = 1 - const Interval(0.86, 1).transform(progress);
                return Opacity(
                  opacity: fade,
                  child: ColoredBox(
                    color: HistaeTokens.night,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 360,
                            height: 230,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: symbol,
                                  child: const HistaeBrandSymbol(size: 72),
                                ),
                                const SizedBox(height: 20),
                                CustomPaint(
                                  size: const Size(360, 110),
                                  painter: _OpeningName(separation),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ],
  );
}

class _OpeningName extends CustomPainter {
  const _OpeningName(this.separation);

  final double separation;

  @override
  void paint(Canvas canvas, Size size) {
    const style = TextStyle(
      fontFamily: HistaeTokens.serif,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('opsz', 40)],
      fontSize: 88,
      letterSpacing: -2,
      color: HistaeTokens.ink,
    );
    TextPainter text(String value, {Color? color}) => TextPainter(
      text: TextSpan(
        text: value,
        style: style.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final h = text('H');
    final middle = text('istae');
    final dot = text('.', color: HistaeTokens.coral);
    try {
      final compact = h.width + dot.width;
      final expanded = compact + middle.width;
      final hX = lerpDouble(
        (size.width - compact) / 2,
        (size.width - expanded) / 2,
        separation,
      )!;
      final y = (size.height - h.height) / 2;
      final gap = middle.width * separation;
      h.paint(canvas, Offset(hX, y));
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(hX + h.width, 0, gap, size.height));
      middle.paint(canvas, Offset(hX + h.width, y));
      canvas.restore();
      dot.paint(canvas, Offset(hX + h.width + gap, y));
    } finally {
      h.dispose();
      middle.dispose();
      dot.dispose();
    }
  }

  @override
  bool shouldRepaint(_OpeningName oldDelegate) =>
      oldDelegate.separation != separation;
}
