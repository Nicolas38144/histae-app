import '../../../core/models/public_profile_answer.dart';
import '../../../core/network/json_fields.dart';

export '../../../core/models/public_profile_answer.dart';
export '../../../core/network/json_fields.dart' show wireTime;

enum DiscoveryAction {
  profile('profile'),
  sex('sex'),
  preferences('preferences'),
  sensitiveConsent('sensitive_data_consent'),
  locationConsent('location_consent'),
  freshPresence('fresh_presence'),
  resumeDiscovery('resume_discovery');

  const DiscoveryAction(this.wireName);
  final String wireName;
  static DiscoveryAction parse(Object? value) =>
      values.firstWhere((a) => a.wireName == value, orElse: invalidResponse);
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
      invalidResponse();
    }
    return DiscoveryStatus(ready, List.unmodifiable(actions), expires);
  }
  final bool ready;
  final List<DiscoveryAction> requiredActions;
  final DateTime? presenceExpiresAt;
}

class FeedProfile {
  FeedProfile(
    this.id,
    this.firstname,
    this.age,
    this.sex,
    this.bio,
    this.distance,
    List<String> traits,
    List<PublicProfileAnswer> answers,
  ) : traits = List.unmodifiable(traits),
      answers = List.unmodifiable(answers);

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
      invalidResponse();
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
        jsonField<List<dynamic>>(
          j,
          'profile_answers',
        ).map(PublicProfileAnswer.fromJson),
      ),
    );
  }
  final String id, firstname, sex;
  final int age;
  final String? bio;
  final double distance;
  final List<String> traits;
  final List<PublicProfileAnswer> answers;
}

class FeedPage {
  FeedPage(List<FeedProfile> profiles, this.nextCursor)
    : profiles = List.unmodifiable(profiles);

  factory FeedPage.fromJson(Object? value) {
    final j = jsonObject(value);
    final cursor = optionalText(j, 'next_cursor');
    if (cursor != null && (cursor.isEmpty || cursor.length > 512)) {
      invalidResponse();
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
      invalidResponse();
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
      invalidResponse();
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
// Compatibility with the original public feed model name.

typedef FeedAnswer = PublicProfileAnswer;
