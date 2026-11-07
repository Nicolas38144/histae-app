import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../privacy/presentation/privacy_strings.dart' show privacyDate;
import '../application/notification_setting_controller.dart';
import '../data/notification_preferences.dart';
import '../data/notification_preferences_repository.dart';
import 'notification_setting_view.dart';

Future<void> showConversationNotifications(
  BuildContext context, {
  required NotificationPreferencesRepository repository,
  required String matchId,
  required DateTime Function() now,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ConversationNotificationSheet(
      repository: repository,
      matchId: matchId,
      now: now,
    ),
  );
}

class ConversationNotificationSheet extends StatelessWidget {
  const ConversationNotificationSheet({
    super.key,
    required this.repository,
    required this.matchId,
    required this.now,
  });
  final NotificationPreferencesRepository repository;
  final String matchId;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) =>
      NotificationSettingView<ConversationMute>(
        create: () => NotificationSettingController(
          session: repository.session,
          read: (scope, policy) =>
              repository.conversation(matchId, scope, policy: policy),
        ),
        builder: (context, c) {
          final strings = AppStrings.of(context);
          final text = strings.messages;
          final current = c.value;
          final muted = current?.isMutedAt(now()) == true;
          final enabled = c.active && !c.busy && c.retrySeconds == 0;
          void save({required bool mute, DateTime? until}) => unawaited(
            c.change(
              (scope) =>
                  repository.mute(matchId, scope, muted: mute, until: until),
            ),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.notificationConversationTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(text.notificationConversationDescription),
                if (current != null) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      !muted
                          ? text.notificationConversationActive
                          : current.until == null
                          ? text.notificationMutedIndefinitely
                          : text.notificationMutedUntil(
                              privacyDate(strings, current.until!),
                            ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  HistaeButton.outlinedIcon(
                    key: const Key('conversation-unmute'),
                    onPressed: enabled && muted
                        ? () => save(mute: false)
                        : null,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(text.notificationUnmute),
                  ),
                  const SizedBox(height: 12),
                  HistaeButton.outlined(
                    key: const Key('conversation-mute-hour'),
                    onPressed: enabled
                        ? () => save(
                            mute: true,
                            until: now().add(const Duration(hours: 1)),
                          )
                        : null,
                    child: Text(text.notificationMuteHour),
                  ),
                  const SizedBox(height: 12),
                  HistaeButton.outlined(
                    key: const Key('conversation-mute-tomorrow'),
                    onPressed: enabled
                        ? () {
                            final local = now().toLocal();
                            save(
                              mute: true,
                              until: DateTime(
                                local.year,
                                local.month,
                                local.day + 1,
                              ),
                            );
                          }
                        : null,
                    child: Text(text.notificationMuteTomorrow),
                  ),
                  const SizedBox(height: 12),
                  HistaeButton.outlined(
                    key: const Key('conversation-mute-indefinite'),
                    onPressed: enabled && !(muted && current.until == null)
                        ? () => save(mute: true)
                        : null,
                    child: Text(text.notificationMuteIndefinitely),
                  ),
                ],
                NotificationSettingStatus(controller: c),
                const SizedBox(height: 16),
                HistaeButton.text(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(text.notificationSettingsClose),
                ),
              ],
            ),
          );
        },
      );
}
