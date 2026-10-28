import 'package:flutter/foundation.dart';

import '../../../core/async/serial_executor.dart';
import '../data/reading_preferences_store.dart';
import '../domain/reading_preferences.dart';

class ReadingController extends ChangeNotifier {
  ReadingController({this.store});

  final ReadingPreferencesStore? store;
  final _operations = SerialExecutor();
  ReadingPreferences _preferences = const ReadingPreferences();
  ReadingPreferences get preferences => _preferences;
  bool _saveFailed = false;
  bool get saveFailed => _saveFailed;
  bool _disposed = false;
  int _revision = 0;
  Future<void>? _load;

  Future<void> load() => _load ??= _restore();

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final restored = await _operations.run(
        () async => await store?.read() ?? const ReadingPreferences(),
      );
      if (_disposed || revision != _revision) return;
      _preferences = restored;
      notifyListeners();
    } catch (_) {
      // Unavailable storage must not prevent reading or changing preferences.
    }
  }

  Future<void> setTextSize(ReadingTextSize size) =>
      _save(_preferences.copyWith(textSize: size));

  Future<void> setLineSpacing(ReadingLineSpacing spacing) =>
      _save(_preferences.copyWith(lineSpacing: spacing));

  Future<void> reset() => _save(const ReadingPreferences());

  Future<void> _save(ReadingPreferences next) async {
    if (_disposed || (next == _preferences && !saveFailed)) return;
    final revision = ++_revision;
    _preferences = next;
    _saveFailed = false;
    notifyListeners();
    try {
      // Rapid choices stay ordered on disk; a late restore never wins over them.
      await _operations.run(() async => await store?.write(next));
    } catch (_) {
      if (!_disposed && revision == _revision) {
        _saveFailed = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
