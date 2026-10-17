import '../../../core/network/json_fields.dart';

class TokenPair {
  const TokenPair(this.accessToken, this.refreshToken);
  factory TokenPair.fromJson(Object? value) {
    final json = jsonObject(value);
    return TokenPair(
      jsonString(json, 'access_token'),
      jsonString(json, 'refresh_token'),
    );
  }
  final String accessToken, refreshToken;
  @override
  String toString() => 'TokenPair(redacted)';
}

class MobileIdentity {
  const MobileIdentity(this.userId, this.onboardingComplete);
  factory MobileIdentity.fromJson(Object? value) {
    final json = jsonObject(value);
    return MobileIdentity(
      jsonString(json, 'user_id'),
      jsonField<bool>(json, 'onboarding_complete'),
    );
  }
  final String userId;
  final bool onboardingComplete;
}
