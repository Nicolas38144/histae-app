class PlanFeature {
  const PlanFeature({
    required this.code,
    required this.displayName,
    required this.description,
    required this.value,
  });

  factory PlanFeature.fromJson(Object? value) {
    final json = _object(value);
    return PlanFeature(
      code: _field<String>(json, 'code'),
      displayName: _nullableString(json, 'display_name'),
      description: _nullableString(json, 'description'),
      value: json['feature_value'],
    );
  }
  final String code;
  final String? displayName;
  final String? description;
  final Object? value;
}

class SubscriptionPlan {
  SubscriptionPlan({
    required this.code,
    required this.displayName,
    required this.monthlyPriceCents,
    required this.annualPriceCents,
    required this.currency,
    required this.weeklyContinuationLimit,
    required this.weeklyIncludedCredits,
    required this.advertisingCreditStockLimit,
    required this.adsRemoved,
    required this.rewardedAdvertisingEnabled,
    required List<PlanFeature> features,
  }) : features = List.unmodifiable(features);

  factory SubscriptionPlan.fromJson(Object? value) {
    final json = _object(value);
    final features = _field<List<dynamic>>(json, 'features');
    return SubscriptionPlan(
      code: _field<String>(json, 'code'),
      displayName: _field<String>(json, 'display_name'),
      monthlyPriceCents: _nonNegativeInt(json, 'monthly_price_cents'),
      annualPriceCents: _nonNegativeInt(json, 'annual_price_cents'),
      currency: _field<String>(json, 'currency'),
      weeklyContinuationLimit: _optionalInt(json, 'weekly_continuation_limit'),
      weeklyIncludedCredits: _optionalInt(json, 'weekly_included_credits'),
      advertisingCreditStockLimit: _nonNegativeInt(
        json,
        'advertising_credit_stock_limit',
      ),
      adsRemoved: _field<bool>(json, 'ads_removed'),
      rewardedAdvertisingEnabled: _field<bool>(
        json,
        'rewarded_advertising_enabled',
      ),
      features: List.unmodifiable(features.map(PlanFeature.fromJson)),
    );
  }
  final String code;
  final String displayName;
  final int monthlyPriceCents;
  final int annualPriceCents;
  final String currency;
  // Rust omits these fields when None; other fields are required.
  final int? weeklyContinuationLimit;
  final int? weeklyIncludedCredits;
  final int advertisingCreditStockLimit;
  final bool adsRemoved;
  final bool rewardedAdvertisingEnabled;
  final List<PlanFeature> features;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

T _field<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! T) throw const FormatException('Invalid catalog field');
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw const FormatException('Missing catalog field');
  }
  return json[key] == null ? null : _field<String>(json, key);
}

int _nonNegativeInt(Map<String, dynamic> json, String key) {
  final value = _field<int>(json, key);
  if (value < 0) throw const FormatException('Invalid catalog integer');
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _nonNegativeInt(json, key);
