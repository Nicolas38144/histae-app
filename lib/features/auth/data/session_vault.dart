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
// A single secure entry is replaced before/after refresh. A rotating entry has
// no reusable token: a crash or lost response must never replay its predecessor.

class SessionRecord {
  const SessionRecord(this.origin, this.phase, [this.refreshToken]);
  final String origin;
  final String phase;
  final String? refreshToken;

  static SessionRecord? decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['origin'] is! String ||
          value['phase'] is! String ||
          (value['phase'] == 'ready' && value['refresh_token'] is! String)) {
        throw const FormatException();
      }
      return SessionRecord(
        value['origin'] as String,
        value['phase'] as String,
        value['refresh_token'] as String?,
      );
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.sessionUncertain);
    }
  }

  String encode() => jsonEncode({
    'origin': origin,
    'phase': phase,
    if (refreshToken != null) 'refresh_token': refreshToken,
  });
}
