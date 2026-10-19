import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../async/serial_executor.dart';

abstract interface class LocalePreferenceStore {
  Future<String?> read();

  Future<void> write(String language);
}

class SecureLocalePreferenceStore implements LocalePreferenceStore {
  const SecureLocalePreferenceStore();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _key = 'histae.interface_language';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String language) async {
    await _storage.write(key: _key, value: language);
    if (await _storage.read(key: _key) != language) {
      throw const FormatException();
    }
  }
}

/// Device preference, independent of the account and of server-owned content.
class LocaleController extends ChangeNotifier {
  LocaleController({this.store});
  static const supportedLanguages = ['fr', 'en', 'es', 'it'];
  final LocalePreferenceStore? store;
  final _queue = SerialExecutor();
  String? _language = 'fr';
  bool _disposed = false;
  bool _saving = false;
  bool _saveFailed = false;

  String? get language => _language;

  Locale? get locale => _language == null ? null : Locale(_language!);

  bool get saving => _saving;

  bool get saveFailed => _saveFailed;

  Future<void> restore() async {
    try {
      final saved = await store?.read();
      if (_disposed) return;
      _language = saved == 'system'
          ? null
          : supportedLanguages.contains(saved)
          ? saved
          : 'fr';
    } catch (_) {
      if (!_disposed) _saveFailed = true;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> select(String? language) => _queue.run(() async {
    if (_disposed ||
        (language != null && !supportedLanguages.contains(language))) {
      return;
    }
    _saving = true;
    _saveFailed = false;
    notifyListeners();
    try {
      await store?.write(language ?? 'system');
      if (!_disposed) _language = language;
    } catch (_) {
      if (!_disposed) _saveFailed = true;
    } finally {
      if (!_disposed) {
        _saving = false;
        notifyListeners();
      }
    }
  });

  static Locale resolve(Locale? requested, Iterable<Locale> supported) =>
      supported.firstWhere(
        (locale) => locale.languageCode == requested?.languageCode,
        orElse: () => const Locale('fr'),
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}
