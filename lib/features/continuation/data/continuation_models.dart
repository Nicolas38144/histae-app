import '../../../core/network/json_fields.dart';

class ContinuationQuota {
  const ContinuationQuota(
    this.plan,
    this.used,
    this.weeklyLimit,
    this.remaining,
    this.weeklyCredits,
    this.freeRemaining,
    this.advertisingBalance,
    this.advertisingRemaining,
    this.reserved,
    this.stockLimit,
  );

  factory ContinuationQuota.fromJson(Object? value) {
    final j = jsonObject(value);
    int count(String key) {
      final n = jsonField<int>(j, key);
      if (n < 0) invalidResponse();
      return n;
    }

    final plan = jsonString(j, 'plan');
    if (!['free', 'premium'].contains(plan)) invalidResponse();
    final limit = j['weekly_limit'] == null ? null : count('weekly_limit');
    final remaining = j['remaining'] == null ? null : count('remaining');
    if (plan == 'free' && (limit == null || remaining == null)) {
      invalidResponse();
    }
    if (plan == 'premium' && (limit != null || remaining != null)) {
      invalidResponse();
    }
    return ContinuationQuota(
      plan,
      count('used'),
      limit,
      remaining,
      count('weekly_credits'),
      count('free_remaining'),
      count('advertising_balance'),
      count('advertising_remaining'),
      count('reserved'),
      count('advertising_stock_limit'),
    );
  }
  final String plan;
  final int used,
      weeklyCredits,
      freeRemaining,
      advertisingBalance,
      advertisingRemaining,
      reserved,
      stockLimit;
  final int? weeklyLimit, remaining;

  bool get premium => plan == 'premium';

  int get creditCost => premium ? 0 : 1;

  bool get canStart => premium || remaining! > 0;
}

enum RewardStatus { pending, credited, expired, cancelled }

class RewardIntent {
  const RewardIntent(
    this.id,
    this.adUnit,
    this.customData,
    this.expiresAt,
    this.status,
    this.credits,
  );

  factory RewardIntent.fromJson(Object? value) {
    final j = jsonObject(value), id = serverId(jsonObject(value), 'id');
    final custom = jsonString(j, 'custom_data'),
        unit = jsonString(j, 'ad_unit');
    final credits = jsonField<int>(j, 'reward_credits');
    if (custom != id ||
        !RegExp(r'^ca-app-pub-\d+/\d+$').hasMatch(unit) ||
        credits <= 0) {
      invalidResponse();
    }
    final status = switch (jsonString(j, 'status')) {
      'pending' => RewardStatus.pending,
      'credited' => RewardStatus.credited,
      'expired' => RewardStatus.expired,
      'cancelled' => RewardStatus.cancelled,
      _ => invalidResponse(),
    };
    return RewardIntent(
      id,
      unit,
      custom,
      wireTime(j['expires_at']),
      status,
      credits,
    );
  }
  final String id, adUnit, customData;
  final DateTime expiresAt;
  final RewardStatus status;
  final int credits;

  @override
  String toString() => 'RewardIntent(redacted)';
}

class ContinuationOffer {
  const ContinuationOffer(
    this.matchId,
    this.cost,
    this.plan,
    this.readRevision,
    this.createdAt,
    this.resourceKey,
  );
  final String matchId, plan, resourceKey;
  final int cost, readRevision;
  final DateTime createdAt;
}
