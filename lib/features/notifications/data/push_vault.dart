import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_failure.dart';
import '../../profile/data/profile_models.dart';

class PushRecord {
  const PushRecord(
    this.origin,
    this.owner, {
    this.deviceId,
    this.opened = const [],
    this.optedIn = true,
  });
  final String origin, owner;
  final String? deviceId;
  final List<String> opened;
  final bool optedIn;

  String encode() => jsonEncode({
    'origin': origin,
    'owner': owner,
    'device_id': deviceId,
    'opted_in': optedIn,
    'opened': opened.take(64).toList(),
  });

  static PushRecord? decode(String? raw) {
    if (raw == null || raw == '{}') return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final owner = serverId(j, 'owner');
      final origin = j['origin'] as String;
      final id = j['device_id'] == null ? null : serverId(j, 'device_id');
      final ids = (j['opened'] as List)
          .map((v) => serverId({'id': v}, 'id'))
          .toList();
      if (ids.length > 64 || !Uri.parse(origin).hasAuthority) {
        throw const FormatException();
      }
      if (j['opted_in'] is! bool) throw const FormatException();
      return PushRecord(
        origin,
        owner,
        deviceId: id,
        opened: ids,
        optedIn: j['opted_in'] as bool,
      );
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }
}

abstract interface class PushVault {
  Future<PushRecord?> read();

  Future<void> write(PushRecord? record);
}

class SecurePushVault implements PushVault {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _key = 'histae.push.v1';

  @override
  Future<PushRecord?> read() async {
    try {
      return PushRecord.decode(await _storage.read(key: _key));
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }

  @override
  Future<void> write(PushRecord? record) async {
    try {
      final value = record?.encode() ?? '{}';
      await _storage.write(key: _key, value: value);
      if (await _storage.read(key: _key) != value) {
        throw const FormatException();
      }
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.secureStorage);
    }
  }
}
