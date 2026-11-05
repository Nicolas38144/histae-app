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

enum PushDestination { match, subscription, requests, sessions }

enum PushKind {
  newMatch,
  newMessage,
  matchExpiring,
  billingPaymentFailed,
  continuationRequested,
  conversationContinued,
  photosRevealed,
  firstPeriodEnding,
  dataRequestReplied,
  newSession;

  PushDestination get destination => switch (this) {
    PushKind.newMatch ||
    PushKind.newMessage ||
    PushKind.matchExpiring ||
    PushKind.continuationRequested ||
    PushKind.conversationContinued ||
    PushKind.photosRevealed ||
    PushKind.firstPeriodEnding => PushDestination.match,
    PushKind.billingPaymentFailed => PushDestination.subscription,
    PushKind.dataRequestReplied => PushDestination.requests,
    PushKind.newSession => PushDestination.sessions,
  };

  bool get opensMatch => destination == PushDestination.match;
}

class PushIntent {
  const PushIntent(this.id, this.kind, this.matchId, {this.requestId});

  static PushIntent? parse(Map<String, dynamic> data) {
    try {
      final id = serverId(data, 'notification_id');
      final kind = switch (data['type']) {
        'new_match' => PushKind.newMatch,
        'new_message' => PushKind.newMessage,
        'match_expiring' => PushKind.matchExpiring,
        'billing_payment_failed' => PushKind.billingPaymentFailed,
        'continuation_requested' => PushKind.continuationRequested,
        'conversation_continued' => PushKind.conversationContinued,
        'photos_revealed' => PushKind.photosRevealed,
        'first_period_ending' => PushKind.firstPeriodEnding,
        'data_request_replied' => PushKind.dataRequestReplied,
        'new_session' => PushKind.newSession,
        _ => null,
      };
      if (kind == null) return null;
      final match = kind.opensMatch ? serverId(data, 'match_id') : null;
      final request = kind == PushKind.dataRequestReplied
          ? serverId(data, 'request_id')
          : null;
      // Ignore all remote display text, links, senders and non-contract fields.
      return PushIntent(id, kind, match, requestId: request);
    } catch (_) {
      return null;
    }
  }

  final String id;
  final PushKind kind;
  final String? matchId;
  final String? requestId;

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
