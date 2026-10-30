import '../../../core/models/client_message.dart';
import '../../../core/models/public_profile_answer.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/text/whitespace.dart';
import '../../profile/data/profile_models.dart';
import '../domain/match_lifecycle.dart';

export '../../../core/network/json_fields.dart' show pageCursor;
export '../domain/match_lifecycle.dart' show MatchStatus;

MatchStatus parseMatchStatus(String value) => switch (value) {
  'active' => MatchStatus.active,
  'awaiting_continuation' => MatchStatus.awaitingContinuation,
  'confirmed' => MatchStatus.confirmed,
  'expired' => MatchStatus.expired,
  'ended' => MatchStatus.ended,
  _ => invalidResponse(),
};

class ChatMessage {
  const ChatMessage(
    this.id,
    this.matchId,
    this.senderId,
    this.content,
    this.createdAt,
    this.readAt,
  );

  factory ChatMessage.fromJson(
    Object? value,
    String matchId,
    Set<String> members, {
    bool summary = false,
  }) {
    final j = jsonObject(value);
    final sender = serverId(j, 'sender_id');
    if (!members.contains(sender) ||
        (!summary && serverId(j, 'match_id') != matchId)) {
      invalidResponse();
    }
    return ChatMessage(
      serverId(j, 'id'),
      matchId,
      sender,
      jsonString(j, 'content'),
      wireTime(j['created_at']),
      j['read_at'] == null ? null : wireTime(j['read_at']),
    );
  }
  final String id, matchId, senderId, content;
  final DateTime createdAt;
  final DateTime? readAt;
}

class MatchPartner {
  MatchPartner(
    this.id,
    this.firstname,
    this.age,
    this.sex,
    this.bio,
    List<String> traits,
    List<PublicProfileAnswer> answers, {
    this.photo,
  }) : traits = List.unmodifiable(traits),
       answers = List.unmodifiable(answers);

  factory MatchPartner.fromJson(
    Object? value,
    String owner, {
    bool photosAllowed = false,
  }) {
    final j = jsonObject(value);
    final id = serverId(j, 'user_id');
    final age = jsonField<int>(j, 'age');
    final sex = optionalText(j, 'sex');
    final traits = jsonField<List<dynamic>>(j, 'traits');
    if (id == owner ||
        age < 18 ||
        (sex != null && !['female', 'male', 'other'].contains(sex)) ||
        traits.any((t) => t is! String)) {
      invalidResponse();
    }
    final photo = photosAllowed ? optionalText(j, 'photo') : null;
    if (photo != null && !validPhotoUrl(photo)) invalidResponse();
    return MatchPartner(
      id,
      jsonString(j, 'firstname'),
      age,
      sex,
      optionalText(j, 'bio'),
      List<String>.unmodifiable(traits),
      List.unmodifiable(
        jsonField<List<dynamic>>(
          j,
          'profile_answers',
        ).map(PublicProfileAnswer.fromJson),
      ),
      photo: photo,
    );
  }
  final String id, firstname;
  final int age;
  final String? sex, bio;
  final String? photo;
  final List<String> traits;
  final List<PublicProfileAnswer> answers;
}

class UserMatch {
  const UserMatch(
    this.id,
    this.status,
    this.expiresAt,
    this.createdAt,
    this.partner,
    this.myRevealed,
    this.photosRevealed,
    this.myContinued,
    this.unreadCount,
    this.lastMessage, {
    this.archived = false,
    this.inactivityExpiresAt,
  });

  factory UserMatch.fromJson(Object? value, String owner) {
    final j = jsonObject(value);
    final id = serverId(j, 'id');
    final status = parseMatchStatus(jsonString(j, 'status'));
    final revealed = jsonField<bool>(j, 'photos_revealed');
    final partner = MatchPartner.fromJson(
      j['other_user'],
      owner,
      photosAllowed:
          revealed &&
          status != MatchStatus.ended &&
          status != MatchStatus.expired,
    );
    final unread = jsonField<int>(j, 'unread_count');
    if (unread < 0) invalidResponse();
    return UserMatch(
      id,
      status,
      wireTime(j['expires_at']),
      wireTime(j['created_at']),
      partner,
      jsonField<bool>(j, 'my_revealed'),
      revealed,
      jsonField<bool>(j, 'my_continued'),
      unread,
      j['last_message'] == null ||
              status == MatchStatus.expired ||
              status == MatchStatus.ended
          ? null
          : ChatMessage.fromJson(j['last_message'], id, {
              owner,
              partner.id,
            }, summary: true),
      archived: j['archived'] == null ? false : jsonField<bool>(j, 'archived'),
      inactivityExpiresAt: j['inactivity_expires_at'] == null
          ? null
          : wireTime(j['inactivity_expires_at']),
    );
  }
  final String id;
  final MatchStatus status;
  final DateTime expiresAt, createdAt;
  final MatchPartner partner;
  final bool myRevealed, photosRevealed, myContinued;
  final int unreadCount;
  final ChatMessage? lastMessage;
  final bool archived;
  final DateTime? inactivityExpiresAt;

  MatchLifecycle get lifecycle => MatchLifecycle(
    status: status,
    expiresAt: expiresAt,
    inactivityExpiresAt: inactivityExpiresAt,
    archived: archived,
  );

  bool isInactivityExpiredAt(DateTime now) =>
      lifecycle.isInactivityExpiredAt(now);

  bool isArchivedAt(DateTime now) => lifecycle.isArchivedAt(now);

  bool get historyAllowed => lifecycle.historyAllowed;

  bool get sendAllowed => lifecycle.sendAllowed;
}

class MatchPage {
  MatchPage(List<UserMatch> items, this.cursor)
    : items = List.unmodifiable(items);
  final List<UserMatch> items;
  final String? cursor;
}

class MessagePage {
  MessagePage(List<ChatMessage> items, this.cursor)
    : items = List.unmodifiable(items);
  final List<ChatMessage> items;
  final String? cursor;
}

String trimMessage(String value) => trimOuterWhitespace(value);

const messageCharacterLimit = 2000;

ClientMessage? validateMessage(String value) {
  final content = trimMessage(value);
  if (content.isEmpty) return ClientMessage.messageEmpty;
  if (content.runes.length > messageCharacterLimit) {
    return ClientMessage.messageTooLong;
  }
  return null;
}

class MessageIntent {
  MessageIntent(this.matchId, String content)
    : content = trimMessage(content),
      key = newUuidV4();
  final String matchId, content, key;

  @override
  String toString() => 'MessageIntent(redacted)';
}
