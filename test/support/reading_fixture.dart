import 'dart:async';

import 'package:histae_app/features/reading/data/reading_preferences_store.dart';
import 'package:histae_app/features/reading/domain/reading_preferences.dart';

class TestReadingStore implements ReadingPreferencesStore {
  ReadingPreferences value = const ReadingPreferences();
  Completer<ReadingPreferences>? pendingRead;
  bool failWrite = false;

  @override
  Future<ReadingPreferences> read() async =>
      pendingRead == null ? value : await pendingRead!.future;

  @override
  Future<void> write(ReadingPreferences preferences) async {
    if (failWrite) throw StateError('Unavailable test storage');
    value = preferences;
  }
}
