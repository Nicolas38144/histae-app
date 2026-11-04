import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_failure.dart';

abstract interface class SessionVault {
  Future<String?> read();

  Future<void> write(String value);
}

class SecureSessionVault implements SessionVault {
  SecureSessionVault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'histae.session.v1';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      await _storage.write(key: _key, value: value);
      if (await _storage.read(key: _key) != value) {
        throw const ApiFailure(ApiFailureKind.secureStorage);
      }
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }
}
// A refresh attempt is persisted atomically with its original credential and
// recovery key. Only that exact attempt can be resumed after a lost response.
// Legacy 'rotating' entries have no recovery material and still fail closed.

class SessionRecord {
  const SessionRecord(
    this.origin,
    this.phase, [
    this.refreshToken,
    this.attemptId,
  ]);
  final String origin;
  final String phase;
  final String? refreshToken;
  final String? attemptId;

  static SessionRecord? decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['origin'] is! String ||
          value['phase'] is! String ||
          (value['phase'] == 'ready' && value['refresh_token'] is! String) ||
          (value['phase'] == 'refreshing' &&
              (value['refresh_token'] is! String ||
                  value['attempt_id'] is! String ||
                  !RegExp(
                    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
                  ).hasMatch(value['attempt_id'] as String)))) {
        throw const FormatException();
      }
      return SessionRecord(
        value['origin'] as String,
        value['phase'] as String,
        value['refresh_token'] as String?,
        value['attempt_id'] as String?,
      );
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.sessionUncertain);
    }
  }

  String encode() => jsonEncode({
    'origin': origin,
    'phase': phase,
    if (refreshToken != null) 'refresh_token': refreshToken,
    if (attemptId != null) 'attempt_id': attemptId,
  });
}
