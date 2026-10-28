import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/reading_preferences.dart';

abstract interface class ReadingPreferencesStore {
  Future<ReadingPreferences> read();
  Future<void> write(ReadingPreferences preferences);
}

class SecureReadingPreferencesStore implements ReadingPreferencesStore {
  const SecureReadingPreferencesStore();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _key = 'histae.reading_preferences.v1';

  @override
  Future<ReadingPreferences> read() async =>
      ReadingPreferences.decode(await _storage.read(key: _key));

  @override
  Future<void> write(ReadingPreferences preferences) =>
      _storage.write(key: _key, value: preferences.encode());
}
