import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/store_update_controller.dart';

/// Covers every navigator route without discarding drafts or session state.
class StoreUpdateGate extends StatelessWidget {
  const StoreUpdateGate({
    super.key,
    required this.controller,
    required this.child,
  });
  final StoreUpdateController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final updates = controller;
    if (updates == null) return child;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: updates.blocked,
            child: ExcludeSemantics(
              excluding: updates.blocked,
              child: IgnorePointer(ignoring: updates.blocked, child: child),
            ),
          ),
          if (updates.blocked)
            Positioned.fill(child: _UpdatePage(controller: updates)),
        ],
      ),
    );
  }
}

class _UpdatePage extends StatelessWidget {
  const _UpdatePage({required this.controller});
  final StoreUpdateController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    final theme = Theme.of(context);
    return HistaeScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    text.storeUpdateTitle,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(text.storeUpdateBody),
                  const SizedBox(height: 28),
                  HistaeButton.icon(
                    key: const Key('store-update-open'),
                    onPressed: controller.opening ? null : controller.openStore,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(text.storeUpdateOpen),
                  ),
                  const SizedBox(height: 12),
                  HistaeButton.text(
                    onPressed: controller.checking ? null : controller.check,
                    child: Text(text.storeUpdateCheck),
                  ),
                  if (controller.openFailed) ...[
                    const SizedBox(height: 12),
                    Text(
                      text.storeUpdateOpenFailed,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
