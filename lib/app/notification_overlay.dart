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
  Widget build(BuildContext context) => controller == null
      ? child
      : ListenableBuilder(
          listenable: controller!,
          builder: (context, _) => Column(
            children: [
              if (controller!.foreground != null && controller!.active)
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            controller!.foreground!.kind == PushKind.matchExpiring
                                ? AppStrings.of(context).messages.matchesInactivityWarning
                                : AppStrings.of(context).messages.notificationOverlayAHistaeUpdateIsAvailable,
                          ),
                          Wrap(
                            spacing: 12,
                            children: [
                              HistaeButton.text(
                                onPressed: controller!.openForeground,
                                child: Text(
                                  AppStrings.of(context)
                                      .messages
                                      .viewNotification,
                                ),
                              ),
                              HistaeButton.text(
                                onPressed: controller!.dismiss,
                                child: Text(
                                  AppStrings.of(context)
                                      .messages
                                      .notificationOverlayLater,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        );
}
