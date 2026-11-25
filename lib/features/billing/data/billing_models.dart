import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';

enum BillingPeriod { monthly, annual }

class SubscriptionState {
  SubscriptionState.fromJson(Object? value) {
    final j = jsonObject(value);
    plan = jsonString(j, 'plan');
    provider = _nullable(j, 'provider');
    status = _nullable(j, 'status');
    final period = _nullable(j, 'billing_period');
    if (!['free', 'premium'].contains(plan) ||
        ![null, 'app_store', 'google_play'].contains(provider) ||
        ![
          null,
          'active',
          'past_due',
          'canceled',
          'paused',
          'pending',
          'grace_period',
          'on_hold',
          'expired',
          'revoked',
        ].contains(status) ||
        ![null, 'monthly', 'annual'].contains(period)) {
      _invalid();
    }
    billingPeriod = period == null ? null : BillingPeriod.values.byName(period);
    accessGranted = jsonField<bool>(j, 'access_granted');
    cancelAtPeriodEnd = jsonField<bool>(j, 'cancel_at_period_end');
    DateTime? date(String key) {
      if (!j.containsKey(key)) _invalid();
      return j[key] == null ? null : wireTime(j[key]);
    }

    periodStart = date('current_period_starts_at');
    periodEnd = date('current_period_ends_at');
    canceledAt = date('canceled_at');
    // The server supplies the effective plan. Never derive access from status
    // alone (past_due may still have access; active may have no known period).
    if (accessGranted != (plan == 'premium')) _invalid();
  }
  late final String plan;
  late final String? provider, status;
  late final BillingPeriod? billingPeriod;
  late final bool accessGranted, cancelAtPeriodEnd;
  late final DateTime? periodStart, periodEnd, canceledAt;
}

String? _nullable(Map<String, dynamic> j, String key) {
  if (!j.containsKey(key)) _invalid();
  return j[key] == null ? null : jsonString(j, key);
}

Never _invalid() => throw const ApiFailure(ApiFailureKind.invalidResponse);
