import 'dart:convert';

import '../../../core/l10n/api_language.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/text/whitespace.dart';

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

enum PushDestination { match, subscription, requests, support, sessions }

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
  supportCaseUpdated,
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
    PushKind.supportCaseUpdated => PushDestination.support,
    PushKind.newSession => PushDestination.sessions,
  };

  bool get opensMatch => destination == PushDestination.match;
}

class PushIntent {
  const PushIntent(
    this.id,
    this.kind,
    this.matchId, {
    this.requestId,
    this.supportCaseId,
    this.openRequestThread = false,
  });

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
        'support_case_updated' => PushKind.supportCaseUpdated,
        'new_session' => PushKind.newSession,
        _ => null,
      };
      if (kind == null) return null;
      final match = kind.opensMatch ? serverId(data, 'match_id') : null;
      final request = kind == PushKind.dataRequestReplied
          ? serverId(data, 'request_id')
          : null;
      final support = kind == PushKind.supportCaseUpdated
          ? serverId(data, 'support_case_id')
          : null;
      final message = request != null && data['request_message_id'] != null
          ? serverId(data, 'request_message_id')
          : null;
      // Ignore all remote display text, links, senders and non-contract fields.
      return PushIntent(
        id,
        kind,
        match,
        requestId: request,
        supportCaseId: support,
        openRequestThread:
            request != null &&
            (message != null || data['request_event'] == 'export_ready'),
      );
    } catch (_) {
      return null;
    }
  }

  final String id;
  final PushKind kind;
  final String? matchId;
  final String? requestId;
  final String? supportCaseId;
  final bool openRequestThread;

  @override
  String toString() => 'PushIntent(redacted)';
}

class DeviceRegistration {
  DeviceRegistration(
    String token,
    this.platform,
    String? version, {
    this.language,
  }) : token = trimOuterWhitespace(token),
       version = version == null ? null : trimOuterWhitespace(version) {
    final tokenLength = utf8.encode(this.token).length;
    final controls = RegExp(r'[\x00-\x1F\x7F-\x9F]');
    final appVersion = this.version ?? '';
    if (tokenLength < 20 ||
        tokenLength > 2048 ||
        controls.hasMatch(this.token) ||
        !['android', 'ios'].contains(platform) ||
        utf8.encode(appVersion).length > 50 ||
        controls.hasMatch(appVersion)) {
      invalidResponse();
    }
  }
  final String token, platform;
  final String? version;
  final ApiLanguage? language;

  Map<String, Object?> get body => {
    'push_token': token,
    'platform': platform,
    if (version case final value? when value.isNotEmpty) 'app_version': value,
    'language': language?.code,
  };

  @override
  String toString() => 'DeviceRegistration(redacted)';
}
