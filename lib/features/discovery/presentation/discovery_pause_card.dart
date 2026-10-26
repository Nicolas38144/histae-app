import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/histae_button.dart';
import '../application/discovery_visibility_controller.dart';

class DiscoveryPauseCard extends StatelessWidget {
  const DiscoveryPauseCard({super.key, required this.controller});
  final DiscoveryVisibilityController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.paused != null && !c.uncertain)
                SwitchListTile(
                  key: const Key('discovery-paused'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    AppStrings.of(context).messages.discoveryPauseCardPauseMode,
                  ),
                  value: c.paused!,
                  onChanged: c.canChange
                      ? (value) async {
                          try {
                            await c.setPaused(value);
                          } on ApiFailure {
                            // The controller displays failure without inventing success.
                          }
                        }
                      : null,
                )
              else
                Text(
                  AppStrings.of(context).messages.discoveryPauseCardPauseMode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Text(
                c.uncertain
                    ? AppStrings.of(context)
                          .messages
                          .discoveryPauseCardYourVisibilityStillNeedsCheckingRefresh
                    : c.paused == true
                    ? AppStrings.of(context)
                          .messages
                          .discoveryPauseCardYourProfileIsHiddenFromNew
                    : c.paused == false
                    ? AppStrings.of(context)
                          .messages
                          .discoveryPauseCardTakeABreakFromNewEncounters
                    : c.loading
                    ? AppStrings.of(context)
                          .messages
                          .discoveryPauseCardCheckingYourVisibility
                    : AppStrings.of(context)
                          .messages
                          .discoveryPauseCardYourVisibilityCannotBeCheckedRight,
              ),
              if (c.loading || c.saving) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  semanticsLabel: AppStrings.of(context)
                      .messages
                      .discoveryPauseCardRefreshingYourVisibility,
                ),
              ],
              if (c.failure != null) ...[
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context)
                      .messages
                      .discoveryPauseCardVisibilityCouldNotBeConfirmed,
                ),
                HistaeButton.text(
                  onPressed: c.loading || c.saving || c.retrySeconds > 0
                      ? null
                      : c.load,
                  child: Text(
                    c.retrySeconds > 0
                        ? AppStrings.of(context).messages
                              .discoveryPauseCardTryAgainInS(c.retrySeconds)
                        : AppStrings.of(context)
                              .messages
                              .discoveryPauseCardRefreshMyVisibility,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
