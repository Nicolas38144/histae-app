import 'dart:convert';

import '../../../core/network/json_fields.dart';
import '../../../core/text/whitespace.dart';

enum DataRight {
  access,
  erasure,
  portability,
  rectification,
  restriction,
  objection,
}

enum RightStatus { pending, inProgress, completed, rejected }

enum ReportReason { inappropriateContent, fakeProfile, harassment, spam, other }

extension ReportWire on ReportReason {
  String get wire => switch (this) {
    ReportReason.inappropriateContent => 'inappropriate_content',
    ReportReason.fakeProfile => 'fake_profile',
    ReportReason.harassment => 'harassment',
    ReportReason.spam => 'spam',
    ReportReason.other => 'other',
  };
}

class MobileSession {
  const MobileSession(
    this.id,
    this.createdAt,
    this.refreshedAt,
    this.expiresAt,
    this.current,
  );
  factory MobileSession.fromJson(Object? value) {
    final j = jsonObject(value), id = serverId(jsonObject(value), 'id');
    if (!RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89abAB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$',
    ).hasMatch(id)) {
      invalidResponse();
    }
    return MobileSession(
      id,
      wireTime(j['created_at']),
      wireTime(j['last_refreshed_at']),
      wireTime(j['expires_at']),
      jsonField<bool>(j, 'current'),
    );
  }
  final String id;
  final DateTime createdAt, refreshedAt, expiresAt;
  final bool current;
}

class SessionPage {
  SessionPage(Map<String, dynamic> j)
    : items = List.unmodifiable(
        jsonField<List<dynamic>>(j, 'sessions').map(MobileSession.fromJson),
      ),
      cursor = pageCursor(j);
  final List<MobileSession> items;
  final String? cursor;
}

class BlockedPerson {
  BlockedPerson.fromJson(Object? value) : this._(jsonObject(value));
  BlockedPerson._(Map<String, dynamic> j)
    : id = serverId(j, 'user_id'),
      firstname = optionalText(j, 'firstname'),
      blockedAt = wireTime(j['blocked_at']);
  final String id;
  final String? firstname;
  final DateTime blockedAt;
  // The API always returns photo:null. No image field is retained or fetched.
}

class RightsRequest {
  const RightsRequest(
    this.id,
    this.type,
    this.status,
    this.requestedAt,
    this.completedAt,
  );
  factory RightsRequest.fromJson(Object? value, String owner) {
    final j = jsonObject(value);
    if (serverId(j, 'user_id') != owner) invalidResponse();
    final type = DataRight.values.where((t) => t.name == j['type']).firstOrNull;
    final status = switch (j['status']) {
      'pending' => RightStatus.pending,
      'in_progress' => RightStatus.inProgress,
      'completed' => RightStatus.completed,
      'rejected' => RightStatus.rejected,
      _ => invalidResponse(),
    };
    if (type == null) invalidResponse();
    return RightsRequest(
      serverId(j, 'id'),
      type,
      status,
      wireTime(j['requested_at']),
      j['completed_at'] == null ? null : wireTime(j['completed_at']),
    );
  }
  final String id;
  final DataRight type;
  final RightStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  bool get open =>
      status == RightStatus.pending || status == RightStatus.inProgress;
}

class DeletionTicket {
  DeletionTicket.fromJson(Object? value) : this._(jsonObject(value));
  DeletionTicket._(Map<String, dynamic> j)
    : value = jsonString(j, 'confirmation_token'),
      expiresAt = wireTime(j['expires_at']) {
    if (!RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89abAB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}:[A-Za-z0-9_-]{43}$',
    ).hasMatch(value)) {
      invalidResponse();
    }
  }
  final String value;
  final DateTime expiresAt;
  @override
  String toString() => 'DeletionTicket(redacted)';
}

class ReportIntent {
  ReportIntent(this.target, this.matchId, this.reason, String description)
    : description = trimOuterWhitespace(description) {
    serverId({'id': target}, 'id');
    if (matchId != null) serverId({'id': matchId}, 'id');
  }
  final String target;
  final String? matchId;
  final ReportReason reason;
  final String description;
  Map<String, Object?> get body => {
    'reported_user_id': target,
    'match_id': ?matchId,
    'reason': reason.wire,
    if (description.isNotEmpty) 'description': description,
  };
  @override
  String toString() => 'ReportIntent(redacted)';
}

String? validateReport(String value) => utf8.encode(value).length > 2000
    ? 'Votre description est trop longue. Raccourcissez-la avant de l’envoyer.'
    : null;
