import '../../../core/network/json_fields.dart';

enum NotificationCategory {
  messages('messages'),
  newMatches('new_matches'),
  continuations('continuations'),
  photos('photos'),
  reminders('reminders'),
  accountSecurity('account_security');

  const NotificationCategory(this.key);
  final String key;
}

final class NotificationPreferences {
  NotificationPreferences.fromJson(Object? value) : this._(jsonObject(value));
  NotificationPreferences._(Map<String, dynamic> json)
    : categories = Map.unmodifiable({
        for (final category in NotificationCategory.values)
          category: jsonField<bool>(json, category.key),
      }),
      discreet = jsonField<bool>(json, 'discreet');

  final Map<NotificationCategory, bool> categories;
  final bool discreet;
}

final class ConversationMute {
  ConversationMute.fromJson(Object? value) : this._(jsonObject(value));
  ConversationMute._(Map<String, dynamic> json)
    : muted = jsonField<bool>(json, 'muted'),
      until = json['muted_until'] == null
          ? null
          : wireTime(json['muted_until']) {
    if (!muted && until != null) invalidResponse();
  }

  final bool muted;
  final DateTime? until;

  bool isMutedAt(DateTime now) =>
      muted && (until == null || until!.isAfter(now));
}
