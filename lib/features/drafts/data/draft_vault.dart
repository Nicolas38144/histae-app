import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One encrypted, device-only document; it contains no biography or credentials.
abstract interface class DraftVault {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureDraftVault implements DraftVault {
  const SecureDraftVault();
  static const _key = 'histae.private_drafts.v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? value) async {
    if (value == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: value);
    }
    if (await read() != value) throw const FormatException();
  }
}

/// Explicitly injected by tests and previews; production uses SecureDraftVault.
class MemoryDraftVault implements DraftVault {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}
