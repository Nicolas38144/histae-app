import '../../../core/network/json_fields.dart';

class OtpSendReceipt {
  const OtpSendReceipt({required this.resendAfter});

  factory OtpSendReceipt.fromJson(Object? value) {
    final json = jsonObject(value);
    // Older API versions did not return the server's resend deadline.
    final seconds = json['resend_after_seconds'] ?? 60;
    if (seconds is! int || seconds < 0 || seconds > 3600) invalidResponse();
    return OtpSendReceipt(resendAfter: Duration(seconds: seconds));
  }

  final Duration resendAfter;
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
