import 'api_failure.dart';
import 'request_cancellation.dart';

enum ReadPolicy { cached, refresh }

enum DataResource {
  profile,
  preferences,
  traits,
  selectedTraits,
  questions,
  answers,
  matches,
  messages,
  devices,
  sessions,
  blocks,
  rights,
  plans,
}

final class _Snapshot<T> {
  _Snapshot(this.value, this.readAt, this.tags);
  final T value;
  final DateTime readAt;
  final Set<Object> tags;
}

/// Repository-owned, typed snapshots. Only validated models enter this cache.
/// Policy is explicit; refreshes and writes never depend on a widget's Zone.
final class ReadSnapshots {
  final _values = <Object, _Snapshot<Object?>>{};
  final _pending = <Object, (Object, Set<Object>)>{};
  String? _scope;

  DateTime? readAt(Object key) => _values[key]?.readAt;

  void clear() {
    _values.clear();
    _pending.clear();
  }

  void invalidate(Set<Object> tags) {
    _values.removeWhere((_, value) => value.tags.any(tags.contains));
    _pending.removeWhere((_, value) => value.$2.any(tags.contains));
  }

  Future<T> mutate<T>(Set<Object> tags, Future<T> Function() write) async {
    invalidate(tags);
    try {
      return await write();
    } finally {
      // Lost responses also make earlier snapshots unsuitable for reuse.
      invalidate(tags);
    }
  }

  Future<T> read<T>({
    required String scope,
    required Object key,
    required Future<T> Function() fetch,
    ReadPolicy policy = ReadPolicy.refresh,
    Set<Object> tags = const {},
    RequestCancellation? cancellation,
  }) async {
    if (_scope != scope) {
      clear();
      _scope = scope;
    }
    if (cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    final value = _values[key];
    if (policy == ReadPolicy.cached && value != null) {
      return value.value as T;
    }
    // A failed refresh must not leave a previously successful view reusable.
    _values.remove(key);
    final pending = Object();
    _pending[key] = (pending, Set.unmodifiable(tags));
    try {
      final result = await fetch();
      if (identical(_pending[key]?.$1, pending) &&
          cancellation?.isCancelled != true) {
        _values[key] = _Snapshot(
          result,
          DateTime.now().toUtc(),
          Set.unmodifiable(tags),
        );
        while (_values.length > 128) {
          _values.remove(_values.keys.first);
        }
      }
      return result;
    } finally {
      if (identical(_pending[key]?.$1, pending)) _pending.remove(key);
    }
  }
}
