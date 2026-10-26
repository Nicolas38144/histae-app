import 'dart:convert';

import '../../../core/models/client_message.dart';
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

extension DataRightDetails on DataRight {
  bool get requiresDetails => switch (this) {
    DataRight.rectification => true,
    _ => false,
  };
}

class RightsRequestIntent {
  factory RightsRequestIntent(DataRight type, String? details) {
    final normalized = trimOuterWhitespace(details ?? '');
    return RightsRequestIntent._(type, normalized.isEmpty ? null : normalized);
  }
  const RightsRequestIntent._(this.type, this.details);

  static const maxDetailsLength = 2000;
  final DataRight type;
  final String? details;

  bool get valid =>
      type != DataRight.restriction &&
      type != DataRight.objection &&
      (!type.requiresDetails || (details?.isNotEmpty ?? false)) &&
      (details == null ||
          (details!.runes.length <= maxDetailsLength &&
              !RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]')
                  .hasMatch(details!)));
}

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
    this.completedAt, {
    this.details,
    this.response,
  });

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
      details: optionalText(j, 'details'),
      response: optionalText(j, 'response'),
    );
  }
  final String id;
  final DataRight type;
  final RightStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? details;
  final String? response;

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

ClientMessage? validateReport(String value) =>
    utf8.encode(value).length > 2000 ? ClientMessage.reportTooLong : null;
