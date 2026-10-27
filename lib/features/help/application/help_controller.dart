import 'package:flutter/foundation.dart';

import '../../../core/config/support_config.dart';
import '../data/feed_guide_store.dart';

class HelpController extends ChangeNotifier {
  HelpController(this.support, {required this.store});
  final SupportConfig support;
  final FeedGuideStore store;
  bool loaded = false, seen = false, showing = false, _disposed = false;
  Future<void>? _load;

  Future<void> load() => _load ??= _restore();

  Future<void> _restore() async {
    var restored = false;
    try {
      restored = await store.read();
    } catch (_) {
      /* In-memory fallback. */
    }
    if (_disposed) return;
    seen = seen || restored;
    loaded = true;
    notifyListeners();
  }

  Future<void> markSeen() async {
    if (_disposed) return;
    seen = true;
    notifyListeners();
    try {
      await store.markSeen();
    } catch (_) {
      /* Do not interrupt reading. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
