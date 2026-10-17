import 'package:flutter/material.dart';

import '../features/notifications/application/push_controller.dart';

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
                          const Text('Une mise à jour Histae est disponible.'),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: controller!.openForeground,
                                child: const Text('Consulter'),
                              ),
                              TextButton(
                                onPressed: controller!.dismiss,
                                child: const Text('Plus tard'),
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
