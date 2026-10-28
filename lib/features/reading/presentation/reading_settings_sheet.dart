import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/reading_controller.dart';
import '../domain/reading_preferences.dart';
import 'reading_scope.dart';

Future<void> showReadingSettings(BuildContext context) async {
  final controller = ReadingScope.maybeOf(context);
  if (controller == null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ReadingSettingsSheet(controller: controller),
  );
}

class ReadingSettingsSheet extends StatelessWidget {
  const ReadingSettingsSheet({super.key, required this.controller});
  final ReadingController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final text = AppStrings.of(context).messages;
      final theme = Theme.of(context);
      final preferences = controller.preferences;
      return FractionallySizedBox(
        heightFactor: .88,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.readingTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      key: const Key('reading-close'),
                      tooltip: text.readingClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('reading-settings-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(text.readingIntro),
                      const SizedBox(height: 24),
                      Text(
                        text.readingTextSize,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final size in ReadingTextSize.values)
                            ChoiceChip(
                              key: Key('reading-size-${size.name}'),
                              label: Text(switch (size) {
                                ReadingTextSize.standard =>
                                  text.readingSizeStandard,
                                ReadingTextSize.comfortable =>
                                  text.readingSizeComfortable,
                                ReadingTextSize.large => text.readingSizeLarge,
                              }),
                              selected: preferences.textSize == size,
                              onSelected: (_) =>
                                  unawaited(controller.setTextSize(size)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        text.readingLineSpacing,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final spacing in ReadingLineSpacing.values)
                            ChoiceChip(
                              key: Key('reading-spacing-${spacing.name}'),
                              label: Text(switch (spacing) {
                                ReadingLineSpacing.standard =>
                                  text.readingSpacingStandard,
                                ReadingLineSpacing.relaxed =>
                                  text.readingSpacingRelaxed,
                                ReadingLineSpacing.spacious =>
                                  text.readingSpacingSpacious,
                              }),
                              selected: preferences.lineSpacing == spacing,
                              onSelected: (_) =>
                                  unawaited(controller.setLineSpacing(spacing)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        text.readingPreview,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          text.readingPreviewText,
                          key: const Key('reading-preview-text'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: preferences.fontSize,
                            height: preferences.lineHeight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        text.readingSystemScale,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (controller.saveFailed) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(text.readingSaveFailed),
                        ),
                      ],
                      const SizedBox(height: 12),
                      HistaeButton.text(
                        key: const Key('reading-reset'),
                        onPressed:
                            preferences != const ReadingPreferences() ||
                                controller.saveFailed
                            ? () => unawaited(controller.reset())
                            : null,
                        child: Text(text.readingReset),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
