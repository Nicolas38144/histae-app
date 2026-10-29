import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A prose answer whose final sentence is a link, with natural line wrapping.
class LinkedHelpAnswer extends StatefulWidget {
  const LinkedHelpAnswer({
    super.key,
    required this.body,
    required this.linkLabel,
    required this.onOpenLink,
  });

  final String body;
  final String linkLabel;
  final VoidCallback? onOpenLink;

  @override
  State<LinkedHelpAnswer> createState() => _LinkedHelpAnswerState();
}

class _LinkedHelpAnswerState extends State<LinkedHelpAnswer> {
  final _recognizer = TapGestureRecognizer();
  bool _focusVisible = false;

  @override
  void initState() {
    super.initState();
    _recognizer.onTap = widget.onOpenLink;
  }

  @override
  void didUpdateWidget(LinkedHelpAnswer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recognizer.onTap = widget.onOpenLink;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusableActionDetector(
      enabled: widget.onOpenLink != null,
      onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onOpenLink?.call();
            return null;
          },
        ),
      },
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${widget.body} '),
            TextSpan(
              text: widget.linkLabel,
              recognizer: _recognizer,
              style: TextStyle(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
                decorationThickness: _focusVisible ? 2 : 1,
              ),
            ),
          ],
        ),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
