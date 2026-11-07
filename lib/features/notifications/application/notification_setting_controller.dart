import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/read_snapshots.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';

/// Shared lifecycle for account choices and a conversation's mute editor.
/// Writes are partial/idempotent. An uncertain write is followed by a fresh read.
final class NotificationSettingController<T> extends ChangeNotifier {
  NotificationSettingController({required this.session, required this.read})
    : _key = session.resourceKey {
    session.addListener(_sessionChanged);
  }
  final AuthenticatedSession session;
  final Future<T> Function(RequestCancellation, ReadPolicy) read;
  final String _key;
  RequestCancellation _scope = RequestCancellation();
  bool _disposed = false, _active = true;
  int _epoch = 0;
  bool busy = false;
  T? value;
  ApiFailure? failure;
  late final _ticker = RetryTicker(
    remaining: () => retrySeconds,
    onTick: _notify,
  );

  bool get accessible =>
      !_disposed &&
      session.resourceKey == _key &&
      session.phase == SessionPhase.ready;
  bool get active => accessible && _active;
  int get retrySeconds => retrySecondsUntil(failure?.retryAt);
  bool _alive(int epoch) => active && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (!accessible) {
      _epoch++;
      _scope.cancel();
      busy = false;
      value = null;
      failure = null;
      _notify();
    } else if (_active && _scope.isCancelled) {
      _scope = RequestCancellation();
      unawaited(load(policy: ReadPolicy.refresh));
    }
  }

  void suspend() {
    _active = false;
    _epoch++;
    _scope.cancel();
    busy = false;
  }

  Future<void> resume() async {
    if (!accessible || _active) return;
    _active = true;
    _scope = RequestCancellation();
    await load(policy: ReadPolicy.refresh);
  }

  void _failed(ApiFailure e) {
    failure = e;
    if (retrySeconds > 0) _ticker.restart();
    if (e.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  Future<void> load({ReadPolicy policy = ReadPolicy.cached}) async {
    if (!active || busy || retrySeconds > 0) return;
    final epoch = _epoch;
    busy = true;
    failure = null;
    _notify();
    try {
      final next = await read(_scope, policy);
      if (_alive(epoch)) value = next;
    } on ApiFailure catch (e) {
      if (_alive(epoch)) _failed(e);
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> change(Future<T> Function(RequestCancellation) write) async {
    if (!active || busy || value == null || retrySeconds > 0) return;
    final epoch = _epoch;
    busy = true;
    failure = null;
    _notify();
    try {
      final next = await write(_scope);
      if (_alive(epoch)) value = next;
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        // Never leave a toggle claiming success, or reuse a pre-write snapshot.
        value = null;
        _failed(e);
        if (retrySeconds == 0 && e.kind != ApiFailureKind.cancelled) {
          try {
            final actual = await read(_scope, ReadPolicy.refresh);
            if (_alive(epoch)) value = actual;
          } on ApiFailure catch (readError) {
            if (_alive(epoch)) _failed(readError);
          }
        }
      }
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    suspend();
    _ticker.cancel();
    value = null;
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
