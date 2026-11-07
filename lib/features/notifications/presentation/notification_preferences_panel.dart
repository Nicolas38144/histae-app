import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../application/notification_setting_controller.dart';
import '../data/notification_preferences.dart';
import '../data/notification_preferences_repository.dart';
import 'notification_setting_view.dart';

class NotificationPreferencesPanel extends StatelessWidget {
  const NotificationPreferencesPanel({super.key, required this.repository});
  final NotificationPreferencesRepository repository;

  @override
  Widget build(BuildContext context) =>
      NotificationSettingView<NotificationPreferences>(
        key: ValueKey(repository.session.resourceKey),
        create: () => NotificationSettingController(
          session: repository.session,
          read: (scope, policy) => repository.account(scope, policy: policy),
        ),
        builder: (context, c) {
          final text = AppStrings.of(context).messages;
          final value = c.value;
          final enabled = c.active && !c.busy && c.retrySeconds == 0;
          final labels = {
            NotificationCategory.messages: (
              text.notificationMessages,
              text.notificationMessagesDescription,
            ),
            NotificationCategory.newMatches: (
              text.notificationNewMatches,
              text.notificationNewMatchesDescription,
            ),
            NotificationCategory.continuations: (
              text.notificationContinuations,
              text.notificationContinuationsDescription,
            ),
            NotificationCategory.photos: (
              text.notificationPhotos,
              text.notificationPhotosDescription,
            ),
            NotificationCategory.reminders: (
              text.notificationReminders,
              text.notificationRemindersDescription,
            ),
            NotificationCategory.accountSecurity: (
              text.notificationAccountSecurity,
              text.notificationAccountSecurityDescription,
            ),
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text.notificationPreferencesTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(text.notificationPreferencesDescription),
              const SizedBox(height: 12),
              if (value != null) ...[
                for (final category in NotificationCategory.values) ...[
                  SwitchListTile.adaptive(
                    key: ValueKey('notification-${category.key}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(labels[category]!.$1),
                    subtitle: Text(labels[category]!.$2),
                    value: value.categories[category]!,
                    onChanged: enabled
                        ? (next) => unawaited(
                            c.change(
                              (scope) => repository.changeAccount({
                                category.key: next,
                              }, scope),
                            ),
                          )
                        : null,
                  ),
                  const Divider(height: 20),
                ],
                SwitchListTile.adaptive(
                  key: const Key('notification-discreet'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(text.notificationDiscreet),
                  subtitle: Text(text.notificationDiscreetDescription),
                  value: value.discreet,
                  onChanged: enabled
                      ? (next) => unawaited(
                          c.change(
                            (scope) => repository.changeAccount({
                              'discreet': next,
                            }, scope),
                          ),
                        )
                      : null,
                ),
              ],
              NotificationSettingStatus(controller: c),
            ],
          );
        },
      );
}
