import 'dart:async';

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

final class _PendingRead {
  _PendingRead(this.cancellation, Set<Object> tags) : tags = {...tags};
  final RequestCancellation? cancellation;
  final Set<Object> tags;
  final result = Completer<Object?>();
}

/// Repository-owned, typed snapshots. Only validated models enter this cache.
/// Policy is explicit; refreshes and writes never depend on a widget's Zone.
final class ReadSnapshots {
  final _values = <Object, _Snapshot<Object?>>{};
  final _pending = <Object, _PendingRead>{};
  String? _scope;

  DateTime? readAt(Object key) => _values[key]?.readAt;

  void clear() {
    _values.clear();
    _pending.clear();
  }

  void invalidate(Set<Object> tags) {
    _values.removeWhere((_, value) => value.tags.any(tags.contains));
    _pending.removeWhere((_, value) => value.tags.any(tags.contains));
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
    final current = _pending[key];
    // Share only requests with the same cancellation owner. Closing one route
    // must never abort a different route's independent read.
    if (current != null && identical(current.cancellation, cancellation)) {
      current.tags.addAll(tags);
      return await current.result.future as T;
    }
    // A failed refresh must not leave a previously successful view reusable.
    _values.remove(key);
    final pending = _PendingRead(cancellation, tags);
    _pending[key] = pending;
    unawaited(_fetch(key, pending, fetch));
    return await pending.result.future as T;
  }

  Future<void> _fetch<T>(
    Object key,
    _PendingRead pending,
    Future<T> Function() fetch,
  ) async {
    try {
      final result = await fetch();
      if (identical(_pending[key], pending) &&
          pending.cancellation?.isCancelled != true) {
        _values[key] = _Snapshot(
          result,
          DateTime.now().toUtc(),
          Set.unmodifiable(pending.tags),
        );
        while (_values.length > 128) {
          _values.remove(_values.keys.first);
        }
      }
      pending.result.complete(result);
    } catch (error, stack) {
      pending.result.completeError(error, stack);
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }
}
