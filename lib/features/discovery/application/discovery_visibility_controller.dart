import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../data/discovery_visibility_repository.dart';

/// Server-owned visibility; no local preference can hide a profile remotely.
class DiscoveryVisibilityController extends ChangeNotifier {
  DiscoveryVisibilityController(AuthenticatedSession session)
    : this.withRepository(DiscoveryVisibilityRepository(session));

  DiscoveryVisibilityController.withRepository(this.repository) {
    _key = session.resourceKey;
    session.addListener(_sessionChanged);
  }
  final DiscoveryVisibilityRepository repository;

  AuthenticatedSession get session => repository.session;
  late String _key;
  RequestCancellation _scope = RequestCancellation();
  int _epoch = 0;
  bool _disposed = false;
  bool _loading = false, _saving = false, _uncertain = false;
  bool? _paused;
  ApiFailure? _failure;

  bool get loading => _loading;

  bool get saving => _saving;

  bool get uncertain => _uncertain;

  bool? get paused => _paused;

  ApiFailure? get failure => _failure;
  DateTime? _retryAt;
  late final RetryTicker _ticker = RetryTicker(
    remaining: () => retrySeconds,
    onTick: _notify,
  );

  bool get accessible => !_disposed && session.phase == SessionPhase.ready;

  int get retrySeconds => retrySecondsUntil(_retryAt);

  bool get canChange =>
      accessible &&
      _paused != null &&
      !_loading &&
      !_saving &&
      !_uncertain &&
      _failure == null &&
      retrySeconds == 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_key == session.resourceKey && accessible) return;
    _key = session.resourceKey;
    _epoch++;
    _scope.cancel();
    _scope = RequestCancellation();
    _paused = null;
    _failure = null;
    _loading = _saving = _uncertain = false;
    _retryAt = null;
    _ticker.cancel();
    _notify();
  }

  bool _alive(int epoch) => accessible && epoch == _epoch;

  void _failed(ApiFailure error) {
    _failure = error;
    _retryAt = error.retryAt;
    if (retrySeconds > 0) _ticker.restart();
  }

  Future<void> load() async {
    if (!accessible || _loading || _saving || retrySeconds > 0) return;
    final epoch = _epoch;
    _loading = true;
    _notify();
    try {
      final result = await repository.read(_scope);
      if (!_alive(epoch)) return;
      _paused = result;
      _failure = null;
      _uncertain = false;
    } on ApiFailure catch (error) {
      if (_alive(epoch)) _failed(error);
    } finally {
      if (_alive(epoch)) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> setPaused(bool value) async {
    if (!canChange) throw const ApiFailure(ApiFailureKind.conflict);
    final epoch = _epoch;
    _saving = true;
    _failure = null;
    _notify();
    try {
      final result = await repository.setPaused(value, _scope);
      if (!_alive(epoch)) throw const ApiFailure(ApiFailureKind.cancelled);
      if (result != value) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      _paused = result;
    } on ApiFailure catch (error) {
      if (_alive(epoch)) {
        _failed(error);
        _uncertain = const [
          ApiFailureKind.network,
          ApiFailureKind.timeout,
          ApiFailureKind.server,
          ApiFailureKind.unavailable,
          ApiFailureKind.invalidResponse,
        ].contains(error.kind);
      }
      rethrow;
    } finally {
      if (_alive(epoch)) {
        _saving = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _scope.cancel();
    _ticker.cancel();
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
