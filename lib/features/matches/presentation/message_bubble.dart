import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/match_models.dart';
import 'matches_strings.dart';
import 'message_metadata.dart';

/// A selectable message with a temporary date that does not shift the history.
class MessageBubble extends StatefulWidget {
  const MessageBubble({super.key, required this.message, required this.own});

  final ChatMessage message;
  final bool own;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with WidgetsBindingObserver {
  final _date = OverlayPortalController();
  final _anchor = LayerLink();
  ScrollPosition? _scroll;
  Timer? _dismissal;
  bool _routeVisible = true;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_hideDate);
      _scroll = scroll;
      _scroll?.addListener(_hideDate);
    }
    if (!_routeVisible) _hideAfterBuild();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) _hideAfterBuild();
  }

  void _hideAfterBuild() {
    _dismissal?.cancel();
    if (_date.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hideDate();
      });
    }
  }

  void _showDate() {
    if (!_routeVisible || !_foreground) return;
    _dismissal?.cancel();
    _date.show();
    _dismissal = Timer(const Duration(seconds: 3), _hideDate);
  }

  void _hideDate() {
    _dismissal?.cancel();
    _dismissal = null;
    if (_date.isShowing) _date.hide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hideDate();
  }

  @override
  void dispose() {
    _dismissal?.cancel();
    _scroll?.removeListener(_hideDate);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return OverlayPortal(
      controller: _date,
      overlayChildBuilder: (context) {
        if (!_routeVisible || !_foreground) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _anchor,
            showWhenUnlinked: false,
            targetAnchor: widget.own ? Alignment.topRight : Alignment.topLeft,
            followerAnchor: widget.own
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            offset: const Offset(0, -6),
            child: IgnorePointer(
              child: Material(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      MatchesStrings(AppStrings.of(context))
                          .date(widget.message.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _anchor,
        child: TapRegion(
          onTapOutside: (_) => _hideDate(),
          child: Semantics(
            onTapHint: AppStrings.of(context).messages.messageShowDate,
            child: GestureDetector(
              onTap: _showDate,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.own
                      ? colors.primaryContainer
                      : colors.surfaceContainerLow,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(widget.own ? 20 : 6),
                    bottomRight: Radius.circular(widget.own ? 6 : 20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      widget.message.content,
                      onTap: _showDate,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.own
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                    if (widget.own) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MessageMetadata(message: widget.message),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
