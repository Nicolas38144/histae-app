import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';

/// Occupies the same footer as a confirmed receipt, without changing its height.
class MessageSendingIndicator extends StatefulWidget {
  const MessageSendingIndicator({super.key, required this.active});

  final bool active;

  @override
  State<MessageSendingIndicator> createState() =>
      _MessageSendingIndicatorState();
}

class _MessageSendingIndicatorState extends State<MessageSendingIndicator>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _motion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MessageSendingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() {
    final state = WidgetsBinding.instance.lifecycleState;
    _motion =
        widget.active &&
        (state == null || state == AppLifecycleState.resumed) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motion) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.of(context).messages.chatPageSending,
    excludeSemantics: true,
    child: AnimatedBuilder(
      animation: _wave,
      builder: (context, _) => SizedBox(
        width: 24,
        height: 16,
        child: Row(
          children: [
            for (var index = 0; index < 3; index++)
              SizedBox(
                width: 8,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _motion
                          ? -2 *
                                math.max(
                                  0,
                                  math.sin(
                                    (_wave.value - index / 5) * 2 * math.pi,
                                  ),
                                )
                          : 0,
                    ),
                    child: SizedBox.square(
                      dimension: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
