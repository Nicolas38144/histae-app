import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../data/device_repository.dart';
import '../data/notification_models.dart';

class DevicesController extends ChangeNotifier {
  DevicesController(this.repository) {
    _key = session.resourceKey;
    session.addListener(_changed);
  }
  final DeviceRepository repository;
  SessionController get session => repository.session;
  late final String _key;
  RequestCancellation _scope = RequestCancellation();
  bool _disposed = false, _active = true;
  int _epoch = 0;
  Timer? _timer;
  final devices = <PushDevice>[];
  bool loading = false, removing = false;
  String? pendingRemoval, notice;
  ApiFailure? failure;
  bool get accessible =>
      !_disposed &&
      session.phase == SessionPhase.ready &&
      session.resourceKey == _key;
  bool get active => accessible && _active;
  int get retrySeconds {
    final ms = failure?.retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool _alive(int epoch) => active && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _error(ApiFailure e) {
    failure = e;
    _timer?.cancel();
    if (retrySeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (retrySeconds == 0) t.cancel();
        _notify();
      });
    }
    if (e.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  void _changed() {
    if (!accessible) {
      suspend();
      devices.clear();
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
      devices
        ..clear()
        ..addAll(result.where((d) => ids.add(d.id)));
      if (pendingRemoval != null &&
          !devices.any((d) => d.id == pendingRemoval)) {
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
      devices.removeWhere((d) => d.id == id);
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
    _timer?.cancel();
    session.removeListener(_changed);
    devices.clear();
    super.dispose();
  }
}
