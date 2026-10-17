import '../../../core/network/api_client.dart';

import '../domain/auth_models.dart';
export '../domain/auth_models.dart';

abstract interface class AuthRepository {
  factory AuthRepository(ApiClient api) = ApiAuthRepository;
  ApiClient get api;
  Future<void> sendOtp(
    String phone,
    String key,
    RequestCancellation cancellation,
  );
  Future<TokenPair> verifyOtp(
    String phone,
    String otp,
    RequestCancellation cancellation,
  );
  Future<TokenPair> refresh(String refreshToken);
  Future<void> logout(TokenPair tokens);
}

final class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api);
  @override
  final ApiClient api;

  @override
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

  @override
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

  @override
  Future<TokenPair> refresh(String refreshToken) async => TokenPair.fromJson(
    await api.requestJson(
      'POST',
      '/api/auth/refresh',
      body: {'refresh_token': refreshToken},
      expectedStatus: 200,
    ),
  );

  @override
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
