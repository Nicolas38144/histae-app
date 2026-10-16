import '../../../core/network/json_fields.dart';
import '../../profile/data/profile_models.dart';

DateTime wireTime(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    invalidProfile();
  }
  return DateTime.tryParse(value)?.toUtc() ?? invalidProfile();
}

enum DiscoveryAction {
  profile('profile'),
  sex('sex'),
  preferences('preferences'),
  sensitiveConsent('sensitive_data_consent'),
  locationConsent('location_consent'),
  freshPresence('fresh_presence');

  const DiscoveryAction(this.wireName);
  final String wireName;
  static DiscoveryAction parse(Object? value) =>
      values.firstWhere((a) => a.wireName == value, orElse: invalidProfile);
}

class DiscoveryStatus {
  const DiscoveryStatus(
    this.ready,
    this.requiredActions,
    this.presenceExpiresAt,
  );
  factory DiscoveryStatus.fromJson(Object? value) {
    final j = jsonObject(value);
    final ready = jsonField<bool>(j, 'ready');
    final actions = jsonField<List<dynamic>>(
      j,
      'required_actions',
    ).map(DiscoveryAction.parse).toList();
    final expires = j['presence_expires_at'] == null
        ? null
        : wireTime(j['presence_expires_at']);
    if (ready != actions.isEmpty ||
        actions.toSet().length != actions.length ||
        (ready && expires == null)) {
      invalidProfile();
    }
    return DiscoveryStatus(ready, List.unmodifiable(actions), expires);
  }
  final bool ready;
  final List<DiscoveryAction> requiredActions;
  final DateTime? presenceExpiresAt;
}

class FeedAnswer {
  const FeedAnswer(this.questionId, this.question, this.answer, this.position);
  factory FeedAnswer.fromJson(Object? value) {
    final j = jsonObject(value);
    jsonString(j, 'code');
    return FeedAnswer(
      serverId(j, 'question_id'),
      jsonString(j, 'question'),
      jsonString(j, 'answer'),
      jsonField<int>(j, 'position'),
    );
  }
  final String questionId, question, answer;
  final int position;
}

class FeedProfile {
  const FeedProfile(
    this.id,
    this.firstname,
    this.age,
    this.sex,
    this.bio,
    this.distance,
    this.traits,
    this.answers,
  );
  factory FeedProfile.fromJson(Object? value) {
    final j = jsonObject(value);
    final age = jsonField<int>(j, 'age');
    final distance = jsonField<num>(j, 'distance_km').toDouble();
    final sex = jsonString(j, 'sex');
    final traits = jsonField<List<dynamic>>(j, 'traits');
    if (age < 18 ||
        !distance.isFinite ||
        distance < 0 ||
        !['male', 'female', 'other'].contains(sex) ||
        traits.any((t) => t is! String)) {
      invalidProfile();
    }
    // Deliberately no photo, signed URL, coordinates or fabricated city field.
    return FeedProfile(
      serverId(j, 'user_id'),
      jsonString(j, 'firstname'),
      age,
      sex,
      optionalText(j, 'bio'),
      distance,
      List<String>.unmodifiable(traits),
      List.unmodifiable(
        jsonField<List<dynamic>>(j, 'profile_answers').map(FeedAnswer.fromJson),
      ),
    );
  }
  final String id, firstname, sex;
  final int age;
  final String? bio;
  final double distance;
  final List<String> traits;
  final List<FeedAnswer> answers;
}

class FeedPage {
  const FeedPage(this.profiles, this.nextCursor);
  factory FeedPage.fromJson(Object? value) {
    final j = jsonObject(value);
    final cursor = optionalText(j, 'next_cursor');
    if (cursor != null && (cursor.isEmpty || cursor.length > 512)) {
      invalidProfile();
    }
    return FeedPage(
      List.unmodifiable(
        jsonField<List<dynamic>>(j, 'profiles').map(FeedProfile.fromJson),
      ),
      cursor,
    );
  }
  final List<FeedProfile> profiles;
  final String? nextCursor;
}

enum SwipeDecision { like, pass }

enum PendingAction { like, pass, block }

class PendingChoice {
  const PendingChoice(this.profile, this.action);
  final FeedProfile profile;
  final PendingAction action;
}

class ReceivedMatch {
  const ReceivedMatch(this.id, this.status, this.createdAt, this.expiresAt);
  factory ReceivedMatch.fromJson(Object? value, String owner, String target) {
    final j = jsonObject(value);
    final members = {serverId(j, 'user1_id'), serverId(j, 'user2_id')};
    final status = jsonString(j, 'status');
    if (members.length != 2 ||
        !members.contains(owner) ||
        !members.contains(target) ||
        ![
          'active',
          'awaiting_continuation',
          'confirmed',
          'expired',
          'ended',
        ].contains(status)) {
      invalidProfile();
    }
    return ReceivedMatch(
      serverId(j, 'id'),
      status,
      wireTime(j['created_at']),
      wireTime(j['expires_at']),
    );
  }
  final String id, status;
  final DateTime createdAt, expiresAt;
}

class SwipeResult {
  const SwipeResult(this.decision, this.match);
  factory SwipeResult.fromJson(
    Object? value,
    String owner,
    PendingChoice intent,
  ) {
    final j = jsonObject(value);
    final decision = jsonString(j, 'decision');
    final matched = jsonField<bool>(j, 'matched');
    if (decision != intent.action.name ||
        matched != (j['match'] != null) ||
        (matched && decision != 'like')) {
      invalidProfile();
    }
    return SwipeResult(
      SwipeDecision.values.byName(decision),
      matched
          ? ReceivedMatch.fromJson(j['match'], owner, intent.profile.id)
          : null,
    );
  }
  final SwipeDecision decision;
  final ReceivedMatch? match;
}
