import '../../../core/l10n/api_language.dart';
import '../../../core/network/json_fields.dart';

class PushDevice {
  PushDevice.fromJson(Object? value) : this._(jsonObject(value));

  PushDevice._(Map<String, dynamic> j)
    : id = serverId(j, 'id'),
      sessionId = j['session_id'] == null ? null : serverId(j, 'session_id'),
      platform = jsonString(j, 'platform'),
      version = optionalText(j, 'app_version'),
      language = j['language'] == null
          ? null
          : ApiLanguage.tryParse(j['language']) ?? invalidResponse(),
      createdAt = wireTime(j['created_at']),
      lastUsedAt = j['last_used_at'] == null
          ? null
          : wireTime(j['last_used_at']) {
    if (!['android', 'ios'].contains(platform)) invalidResponse();
  }
  final String id, platform;
  final String? sessionId, version;
  final ApiLanguage? language;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}

enum PushKind {
  newMatch,
  newMessage,
  billingPaymentFailed,
  subscriptionTrialEnding,
}

class PushIntent {
  const PushIntent(this.id, this.kind, this.matchId);

  static PushIntent? parse(Map<String, dynamic> data) {
    try {
      final id = serverId(data, 'notification_id');
      final kind = switch (data['type']) {
        'new_match' => PushKind.newMatch,
        'new_message' => PushKind.newMessage,
        'billing_payment_failed' => PushKind.billingPaymentFailed,
        'subscription_trial_ending' => PushKind.subscriptionTrialEnding,
        _ => null,
      };
      if (kind == null) return null;
      final match = [PushKind.newMatch, PushKind.newMessage].contains(kind)
          ? serverId(data, 'match_id')
          : null;
      // Ignore all remote display text, links, senders and non-contract fields.
      return PushIntent(id, kind, match);
    } catch (_) {
      return null;
    }
  }

  final String id;
  final PushKind kind;
  final String? matchId;

  @override
  String toString() => 'PushIntent(redacted)';
}

class DeviceRegistration {
  DeviceRegistration(this.token, this.platform, this.version, {this.language}) {
    if (token.trim().length < 20 ||
        token.length > 4096 ||
        !['android', 'ios'].contains(platform) ||
        (version?.length ?? 0) > 50) {
      invalidResponse();
    }
  }
  final String token, platform;
  final String? version;
  final ApiLanguage? language;

  Map<String, Object?> get body => {
    'push_token': token,
    'platform': platform,
    'app_version': ?version,
    'language': language?.code,
  };

  @override
  String toString() => 'DeviceRegistration(redacted)';
}
