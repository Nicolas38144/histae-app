import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/profile_models.dart';
import 'billing_models.dart';

/// Persist intent BEFORE the first POST. No hosted URL, provider/customer ID,
/// amount, payment detail or entitlement is persisted on the device.
class CheckoutAttempt {
  const CheckoutAttempt(this.origin, this.owner, this.key, this.period);
  factory CheckoutAttempt.create(
    String origin,
    String owner,
    BillingPeriod period,
  ) => CheckoutAttempt(origin, owner, newUuidV4(), period);
  final String origin, owner, key;
  final BillingPeriod period;
  String encode() => jsonEncode({
    'origin': origin,
    'owner': owner,
    'key': key,
    'period': period.name,
  });
  static CheckoutAttempt? decode(String? raw) {
    if (raw == null || raw == '{}') return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final owner = serverId(j, 'owner'), key = serverId(j, 'key');
      if (!RegExp(r'^[0-9a-fA-F-]{14}4[0-9a-fA-F]{3}-[89abAB]').hasMatch(key)) {
        throw const FormatException();
      }
      final origin = j['origin'] as String;
      if (!Uri.parse(origin).hasAuthority) throw const FormatException();
      return CheckoutAttempt(
        origin,
        owner,
        key,
        BillingPeriod.values.byName(j['period'] as String),
      );
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }

  @override
  String toString() => 'CheckoutAttempt(redacted)';
}

abstract interface class CheckoutVault {
  Future<CheckoutAttempt?> read();
  Future<void> write(CheckoutAttempt? attempt);
}

class SecureCheckoutVault implements CheckoutVault {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _key = 'histae.checkout.v1';
  @override
  Future<CheckoutAttempt?> read() async {
    try {
      return CheckoutAttempt.decode(await _storage.read(key: _key));
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }

  @override
  Future<void> write(CheckoutAttempt? attempt) async {
    try {
      final value = attempt?.encode() ?? '{}';
      await _storage.write(key: _key, value: value);
      if (await _storage.read(key: _key) != value) {
        throw const FormatException();
      }
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }
}
