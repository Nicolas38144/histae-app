import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../discovery/data/discovery_models.dart' show FeedAnswer, wireTime;
import '../../profile/data/profile_models.dart';

enum MatchStatus { active, awaitingContinuation, confirmed, expired, ended }

MatchStatus parseMatchStatus(String value) => switch (value) {
  'active' => MatchStatus.active,
  'awaiting_continuation' => MatchStatus.awaitingContinuation,
  'confirmed' => MatchStatus.confirmed,
  'expired' => MatchStatus.expired,
  'ended' => MatchStatus.ended,
  _ => invalidProfile(),
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
      invalidProfile();
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
  const MatchPartner(
    this.id,
    this.firstname,
    this.age,
    this.sex,
    this.bio,
    this.traits,
    this.answers,
  );
  factory MatchPartner.fromJson(Object? value, String owner) {
    final j = jsonObject(value);
    final id = serverId(j, 'user_id');
    final age = jsonField<int>(j, 'age');
    final sex = optionalText(j, 'sex');
    final traits = jsonField<List<dynamic>>(j, 'traits');
    if (id == owner ||
        age < 18 ||
        (sex != null && !['female', 'male', 'other'].contains(sex)) ||
        traits.any((t) => t is! String)) {
      invalidProfile();
    }
    // Partner photos remain unused in L5. L6 will gate their separate view on
    // the server's mutual revelation flag; never prefetch a signed partner URL.
    return MatchPartner(
      id,
      jsonString(j, 'firstname'),
      age,
      sex,
      optionalText(j, 'bio'),
      List<String>.unmodifiable(traits),
      List.unmodifiable(
        jsonField<List<dynamic>>(j, 'profile_answers').map(FeedAnswer.fromJson),
      ),
    );
  }
  final String id, firstname;
  final int age;
  final String? sex, bio;
  final List<String> traits;
  final List<FeedAnswer> answers;
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
    this.lastMessage,
  );
  factory UserMatch.fromJson(Object? value, String owner) {
    final j = jsonObject(value);
    final id = serverId(j, 'id');
    final partner = MatchPartner.fromJson(j['other_user'], owner);
    final status = parseMatchStatus(jsonString(j, 'status'));
    final unread = jsonField<int>(j, 'unread_count');
    if (unread < 0) invalidProfile();
    return UserMatch(
      id,
      status,
      wireTime(j['expires_at']),
      wireTime(j['created_at']),
      partner,
      jsonField<bool>(j, 'my_revealed'),
      jsonField<bool>(j, 'photos_revealed'),
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
    );
  }
  final String id;
  final MatchStatus status;
  final DateTime expiresAt, createdAt;
  final MatchPartner partner;
  final bool myRevealed, photosRevealed, myContinued;
  final int unreadCount;
  final ChatMessage? lastMessage;
  bool get historyAllowed =>
      status == MatchStatus.active ||
      status == MatchStatus.awaitingContinuation ||
      status == MatchStatus.confirmed;
  bool get sendAllowed =>
      status == MatchStatus.active || status == MatchStatus.confirmed;
}

class MatchPage {
  const MatchPage(this.items, this.cursor);
  final List<UserMatch> items;
  final String? cursor;
}

class MessagePage {
  const MessagePage(this.items, this.cursor);
  final List<ChatMessage> items;
  final String? cursor;
}

String? pageCursor(Map<String, dynamic> j) {
  final cursor = optionalText(j, 'next_cursor');
  if (cursor != null && (cursor.isEmpty || cursor.length > 512)) {
    invalidProfile();
  }
  return cursor;
}

// Same outer whitespace set as ECMAScript/Rust, not Dart's additional NEL.
final _edgeSpace = RegExp(
  r'^[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+|[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+$',
);
String trimMessage(String value) => value.replaceAll(_edgeSpace, '');
String? validateMessage(String value) {
  final content = trimMessage(value);
  if (content.isEmpty) return 'Écrivez quelques mots avant d’envoyer.';
  if (content.runes.length > 2000) {
    return 'Votre message dépasse 2 000 caractères.';
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
