import '../../../core/network/api_client.dart';
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
  final String accessToken;
  final String refreshToken;
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

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;

  Future<void> sendOtp(
    String phone,
    String key,
    RequestCancellation cancellation,
  ) async {
    await api.requestJson(
      'POST',
      '/api/auth/otp/send',
      body: {'phone_number': phone},
      idempotencyKey: key,
      expectedStatus: 202,
      cancellation: cancellation,
    );
  }

  Future<TokenPair> verifyOtp(
    String phone,
    String otp,
    RequestCancellation cancellation,
  ) async => TokenPair.fromJson(
    await api.requestJson(
      'POST',
      '/api/auth/otp/verify',
      body: {'phone_number': phone, 'otp': otp},
      expectedStatus: 200,
      cancellation: cancellation,
    ),
  );

  Future<TokenPair> refresh(String refreshToken) async => TokenPair.fromJson(
    await api.requestJson(
      'POST',
      '/api/auth/refresh',
      body: {'refresh_token': refreshToken},
      expectedStatus: 200,
    ),
  );

  Future<void> logout(TokenPair tokens) async {
    await api.requestJson(
      'POST',
      '/api/auth/logout',
      body: {'refresh_token': tokens.refreshToken},
      bearer: tokens.accessToken,
      expectedStatus: 204,
    );
  }
}

String? normalizeFrenchPhone(String input) {
  final phone = input.trim().replaceAll(RegExp(r'[ .()\-]'), '');
  return RegExp(r'^\+33[1-9][0-9]{8}$').hasMatch(phone) ? phone : null;
}
