import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../async/serial_executor.dart';
import 'api_language.dart';

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

/// Device selection, with an optional account preference supplied by the app.
class LocaleController extends ChangeNotifier {
  LocaleController({this.store});
  static const supportedLanguages = ['fr', 'en', 'es', 'it'];
  final LocalePreferenceStore? store;
  final _queue = SerialExecutor();
  String? _language = 'fr';
  bool _disposed = false;
  bool _saving = false;
  bool _saveFailed = false;
  bool _hasPreference = false;

  // The application supplies an account adapter; core never imports a feature.
  Future<void> Function(ApiLanguage)? onSelected;

  bool get hasPreference => _hasPreference;

  ApiLanguage get apiLanguage =>
      ApiLanguage.tryParse(
        _language ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      ) ?? ApiLanguage.fr;

  void systemLocaleChanged() {
    if (!_disposed && _language == null) notifyListeners();
  }

  void useAccountLanguage(ApiLanguage? language) {
    if (_disposed || _hasPreference) return;
    final next = (language ?? ApiLanguage.fr).code;
    if (_language == next) return;
    _language = next;
    notifyListeners();
  }

  void accountSyncFailed() {
    if (_disposed) return;
    _saveFailed = true;
    notifyListeners();
  }

  String? get language => _language;

  Locale? get locale => _language == null ? null : Locale(_language!);

  bool get saving => _saving;

  bool get saveFailed => _saveFailed;

  Future<void> restore() async {
    try {
      final saved = await store?.read();
      if (_disposed) return;
      _hasPreference = saved == 'system' || supportedLanguages.contains(saved);
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

  Future<void> select(String? language) {
    final persistAccount = onSelected;
    return _queue.run(() async {
      if (_disposed ||
          (language != null && !supportedLanguages.contains(language))) {
        return;
      }
      _saving = true;
      _saveFailed = false;
      notifyListeners();
      try {
        await store?.write(language ?? 'system');
        if (_disposed) return;
        _hasPreference = true;
        _language = language;
        // Local selection remains usable if the account write fails.
        notifyListeners();
        await persistAccount?.call(apiLanguage);
      } catch (_) {
        if (!_disposed) _saveFailed = true;
      } finally {
        if (!_disposed) {
          _saving = false;
          notifyListeners();
        }
      }
    });
  }

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
