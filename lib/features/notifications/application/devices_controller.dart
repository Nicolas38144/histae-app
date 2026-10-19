import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../data/device_repository.dart';
import '../data/notification_models.dart';

class DevicesController extends ChangeNotifier {
  DevicesController(this.repository) {
    _key = session.resourceKey;
    session.addListener(_changed);
  }
  final DeviceRepository repository;

  AuthenticatedSession get session => repository.session;
  late final String _key;
  RequestCancellation _scope = RequestCancellation();
  bool _disposed = false, _active = true;
  int _epoch = 0;
  late final RetryTicker _timer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  final _devices = <PushDevice>[];
  bool loading = false, removing = false;
  String? pendingRemoval, notice;
  ApiFailure? failure;

  List<PushDevice> get devices => List.unmodifiable(_devices);

  bool get accessible =>
      !_disposed &&
      session.phase == SessionPhase.ready &&
      session.resourceKey == _key;

  bool get active => accessible && _active;

  int get retrySeconds => retrySecondsUntil(failure?.retryAt);

  bool _alive(int epoch) => active && epoch == _epoch;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _error(ApiFailure e) {
    failure = e;
    _timer.cancel();
    if (retrySeconds > 0) {
      _timer.restart();
    }
    if (e.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  void _changed() {
    if (!accessible) {
      suspend();
      _devices.clear();
      pendingRemoval = null;
      notice = null;
      failure = null;
      _notify();
    }
  }

  void suspend() {
    _active = false;
    _epoch++;
    _scope.cancel();
    loading = false;
    removing = false;
  }

  Future<void> resume() async {
    await session.synchronize();
    if (!accessible) return;
    _active = true;
    _scope = RequestCancellation();
    await load();
  }

  Future<void> load() async {
    if (!active || loading || removing || retrySeconds > 0) return;
    final epoch = _epoch;
    loading = true;
    failure = null;
    _notify();
    try {
      final result = await repository.list(_scope);
      if (!_alive(epoch)) return;
      final ids = <String>{};
      _devices
        ..clear()
        ..addAll(result.where((d) => ids.add(d.id)));
      if (pendingRemoval != null &&
          !_devices.any((d) => d.id == pendingRemoval)) {
        pendingRemoval = null;
        notice = 'device_removed';
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) _error(e);
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> remove(String id) async {
    if (!active ||
        loading ||
        removing ||
        retrySeconds > 0 ||
        (pendingRemoval != null && pendingRemoval != id)) {
      return false;
    }
    final epoch = _epoch;
    pendingRemoval = id;
    removing = true;
    failure = null;
    notice = null;
    _notify();
    ApiFailure? error;
    try {
      await repository.remove(id, _scope);
      if (!_alive(epoch)) return false;
      pendingRemoval = null;
      _devices.removeWhere((d) => d.id == id);
      notice = 'device_removed';
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        if (e.code == 'device_not_found') {
          pendingRemoval = null;
          notice = 'device_removed';
        } else {
          error = e;
          _error(e);
        }
      }
    } finally {
      if (_alive(epoch)) {
        removing = false;
        await load();
        if (_alive(epoch) && error != null) {
          failure = error;
          _notify();
        }
      }
    }
    return _alive(epoch) && pendingRemoval == null;
  }

  @override
  void dispose() {
    _disposed = true;
    suspend();
    _timer.cancel();
    session.removeListener(_changed);
    _devices.clear();
    super.dispose();
  }
}
