import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/widgets/histae_button.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/data/notification_models.dart';

class NotificationOverlay extends StatelessWidget {
  const NotificationOverlay({
    super.key,
    required this.controller,
    required this.child,
  });
  final PushController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final push = controller;
    if (push == null) return child;
    return ListenableBuilder(
      listenable: push,
      builder: (context, _) => Column(
        children: [
          if (push.foreground case final intent? when push.active)
            _ForegroundNotification(
              kind: intent.kind,
              onOpen: push.openForeground,
              onDismiss: push.dismiss,
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The banner renders local copy; authorization and navigation stay outside it.
class _ForegroundNotification extends StatelessWidget {
  const _ForegroundNotification({
    required this.kind,
    required this.onOpen,
    required this.onDismiss,
  });

  final PushKind kind;
  final VoidCallback onOpen, onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kind == PushKind.matchExpiring
                    ? text.matchesInactivityWarning
                    : text.notificationOverlayAHistaeUpdateIsAvailable,
              ),
              Wrap(
                spacing: 12,
                children: [
                  HistaeButton.text(
                    onPressed: onOpen,
                    child: Text(text.viewNotification),
                  ),
                  HistaeButton.text(
                    onPressed: onDismiss,
                    child: Text(text.notificationOverlayLater),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
