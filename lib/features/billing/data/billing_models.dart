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
        ![null, 'stripe'].contains(provider) ||
        ![
          null,
          'incomplete',
          'incomplete_expired',
          'trialing',
          'active',
          'past_due',
          'canceled',
          'unpaid',
          'paused',
        ].contains(status) ||
        ![null, 'monthly', 'annual'].contains(period)) {
      _invalid();
    }
    billingPeriod = period == null ? null : BillingPeriod.values.byName(period);
    accessGranted = jsonField<bool>(j, 'access_granted');
    cancelAtPeriodEnd = jsonField<bool>(j, 'cancel_at_period_end');
    portalAvailable = jsonField<bool>(j, 'customer_portal_available');
    DateTime? date(String key) {
      if (!j.containsKey(key)) _invalid();
      return j[key] == null ? null : wireTime(j[key]);
    }

    periodStart = date('current_period_starts_at');
    periodEnd = date('current_period_ends_at');
    trialEnd = date('trial_ends_at');
    canceledAt = date('canceled_at');
    // The server supplies the effective plan. Never derive access from status
    // alone (past_due may still have access; active may have no known period).
    if (accessGranted != (plan == 'premium')) _invalid();
  }
  late final String plan;
  late final String? provider, status;
  late final BillingPeriod? billingPeriod;
  late final bool accessGranted, cancelAtPeriodEnd, portalAvailable;
  late final DateTime? periodStart, periodEnd, trialEnd, canceledAt;
}

String? _nullable(Map<String, dynamic> j, String key) {
  if (!j.containsKey(key)) _invalid();
  return j[key] == null ? null : jsonString(j, key);
}

Never _invalid() => throw const ApiFailure(ApiFailureKind.invalidResponse);

Uri stripeUrl(Object? raw, {required bool portal}) {
  if (raw is! String || raw.length > 8192) _invalid();
  final u = Uri.tryParse(raw);
  if (u == null ||
      u.scheme != 'https' ||
      u.userInfo.isNotEmpty ||
      u.hasFragment ||
      (u.hasPort && u.port != 443) ||
      u.host != (portal ? 'billing.stripe.com' : 'checkout.stripe.com') ||
      u.path.isEmpty ||
      u.path == '/') {
    _invalid();
  }
  return u;
}

class CheckoutLink {
  CheckoutLink.fromJson(Object? value) {
    final j = jsonObject(value);
    jsonString(j, 'session_id'); // Not stored or used as entitlement proof.
    url = stripeUrl(j['url'], portal: false);
    expiresAt = wireTime(j['expires_at']);
  }
  late final Uri url;
  late final DateTime expiresAt;

  @override
  String toString() => 'CheckoutLink(redacted)';
}
