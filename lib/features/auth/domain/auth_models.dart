import '../../../core/network/json_fields.dart';

class OtpSendReceipt {
  const OtpSendReceipt({required this.resendAfter, required this.challengeId});

  factory OtpSendReceipt.fromJson(Object? value) {
    final json = jsonObject(value);
    final seconds = jsonField<int>(json, 'resend_after_seconds');
    final challengeId = jsonString(json, 'challenge_id');
    if (seconds < 0 || seconds > 3600 || !isUuidV4(challengeId)) {
      invalidResponse();
    }
    return OtpSendReceipt(
      resendAfter: Duration(seconds: seconds),
      challengeId: challengeId,
    );
  }

  final Duration resendAfter;
  final String challengeId;
}

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
