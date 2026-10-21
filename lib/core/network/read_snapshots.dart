import 'dart:async';
import 'dart:convert';

import 'api_failure.dart';
import 'request_cancellation.dart';

/// Only initial view reads opt in. Refreshes, events and mutation verification
/// always go to the server. Snapshots live in memory for one session only.
final class ReadSnapshots {
  static final _viewKey = Object();
  static Future<T> forView<T>(Future<T> Function() read) =>
      runZoned(read, zoneValues: {_viewKey: <String, DateTime>{}});

  /// Reusing a view must never extend a signed photo URL's lifetime.
  static DateTime? reusedAt(String path) =>
      (Zone.current[_viewKey] as Map<String, DateTime>?)?[path];

  final _values = <String, (String, DateTime)>{};
  final _pending = <String, Object>{};
  String? _scope;
  int _revision = 0;

  void clear({String? prefix}) {
    _revision++;
    if (prefix == null) {
      _values.clear();
    } else {
      _values.removeWhere((key, _) => key.startsWith(prefix));
    }
  }

  Future<Object?> read({
    required String scope,
    required String key,
    required Future<Object?> Function() fetch,
    RequestCancellation? cancellation,
  }) async {
    if (_scope != scope) {
      clear();
      _scope = scope;
    }
    if (cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (Zone.current[_viewKey] case final Map<String, DateTime> reused) {
      if (_values[key] case final value?) {
        reused[Uri.parse(key).path] = value.$2;
        return jsonDecode(value.$1);
      }
    }
    // A failed refresh must not leave a previously successful view reusable.
    _values.remove(key);
    final pending = Object();
    _pending[key] = pending;
    final revision = _revision;
    try {
      final result = await fetch();
      if (revision == _revision &&
          identical(_pending[key], pending) &&
          cancellation?.isCancelled != true) {
        _values[key] = (jsonEncode(result), DateTime.now().toUtc());
        while (_values.length > 128) {
          _values.remove(_values.keys.first);
        }
      }
      return result;
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }
}
