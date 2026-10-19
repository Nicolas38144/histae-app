import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';

/// Server-owned visibility; no local preference can hide a profile remotely.
class DiscoveryVisibilityController extends ChangeNotifier {
  DiscoveryVisibilityController(this.session) {
    _key = session.resourceKey;
    session.addListener(_sessionChanged);
  }

  final AuthenticatedSession session;
  late String _key;
  RequestCancellation _scope = RequestCancellation();
  int _epoch = 0;
  bool _disposed = false;
  bool loading = false, saving = false, uncertain = false;
  bool? paused;
  ApiFailure? failure;
  DateTime? _retryAt;
  late final RetryTicker _ticker = RetryTicker(
    remaining: () => retrySeconds,
    onTick: _notify,
  );

  bool get accessible => !_disposed && session.phase == SessionPhase.ready;
  int get retrySeconds => retrySecondsUntil(_retryAt);
  bool get canChange =>
      accessible &&
      paused != null &&
      !loading &&
      !saving &&
      !uncertain &&
      failure == null &&
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
    paused = null;
    failure = null;
    loading = saving = uncertain = false;
    _retryAt = null;
    _ticker.cancel();
    _notify();
  }

  bool _alive(int epoch) => accessible && epoch == _epoch;

  void _failed(ApiFailure error) {
    failure = error;
    _retryAt = error.retryAt;
    if (retrySeconds > 0) _ticker.restart();
  }

  Future<bool> _request(String method, {bool? value}) async => jsonField<bool>(
    jsonObject(
      await session.request(
        method,
        '/api/users/me/discovery-settings',
        body: value == null ? null : {'paused': value},
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: _scope,
      ),
    ),
    'paused',
  );

  Future<void> load() async {
    if (!accessible || loading || saving || retrySeconds > 0) return;
    final epoch = _epoch;
    loading = true;
    _notify();
    try {
      final result = await _request('GET');
      if (!_alive(epoch)) return;
      paused = result;
      failure = null;
      uncertain = false;
    } on ApiFailure catch (error) {
      if (_alive(epoch)) _failed(error);
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> setPaused(bool value) async {
    if (!canChange) throw const ApiFailure(ApiFailureKind.conflict);
    final epoch = _epoch;
    saving = true;
    failure = null;
    _notify();
    try {
      final result = await _request('PATCH', value: value);
      if (!_alive(epoch)) throw const ApiFailure(ApiFailureKind.cancelled);
      if (result != value) invalidResponse();
      paused = result;
    } on ApiFailure catch (error) {
      if (_alive(epoch)) {
        _failed(error);
        uncertain = const [
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
        saving = false;
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
