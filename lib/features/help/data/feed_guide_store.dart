import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class FeedGuideStore {
  Future<bool> read();
  Future<void> markSeen();
}

class SecureFeedGuideStore implements FeedGuideStore {
  const SecureFeedGuideStore();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _key = 'histae.feed_guide.v1';

  @override
  Future<bool> read() async => await _storage.read(key: _key) == 'seen';

  @override
  Future<void> markSeen() => _storage.write(key: _key, value: 'seen');
}
