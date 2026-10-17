import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/session_controller.dart';
import '../data/device_repository.dart';
import '../data/notification_models.dart';
import '../data/push_gateway.dart';
import '../data/push_vault.dart';

class PushController extends ChangeNotifier {
  PushController(
    this.repository,
    this.gateway,
    this.vault, {
    Future<String?> Function()? appVersion,
  }) : _appVersion =
           appVersion ??
           (() async {
             final p = await PackageInfo.fromPlatform();
             return '${p.version}+${p.buildNumber}';
           }) {
    session.addListener(_sessionChanged);
  }
  final DeviceRepository repository;
  final PushGateway gateway;
  final PushVault vault;
  final Future<String?> Function() _appVersion;
  SessionController get session => repository.session;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _presented = <String>{};
  final _opened = <String>[];
  final _obsolete = <String>{};
  RequestCancellation _scope = RequestCancellation();
  Future<void> _tail = Future<void>.value();
  Future<void>? _start;
  Future<void>? _gatewayPreparation;
  PushRecord? _saved;
  String? _key, _restoredKey, _latestRegistration;
  int _epoch = 0;
  bool _disposed = false, _started = false, _foreground = true;
  bool enabled = false, busy = false, coversMainFlow = false;
  PushPermission permission = PushPermission.unavailable;
  String? deviceId, notice;
  DeviceRegistration? pending;
  ApiFailure? failure;
  PushIntent? foreground, pendingOpen;
  String? _pendingOwner;
  Timer? _timer;
  bool get configured => gateway.configured;
  bool get stopping => _saved?.optedIn == false;
  bool get accessible =>
      !_disposed &&
      session.phase == SessionPhase.ready &&
      session.identity != null;
  bool get active => accessible && _foreground;
  int get retrySeconds {
    final ms = failure?.retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  String get _origin => session.repository.api.origin.toString();
  bool _alive(int epoch) => active && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _error(Object error) {
    failure = error is ApiFailure
        ? error
        : const ApiFailure(
            ApiFailureKind.unavailable,
            code: 'push_unavailable',
          );
    _timer?.cancel();
    if (retrySeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (retrySeconds == 0) t.cancel();
        _notify();
      });
    }
    if (failure?.kind == ApiFailureKind.consentRequired) {
      unawaited(session.synchronize());
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final task = _tail.then((_) async {
      if (!_disposed) await action();
    });
    _tail = task.catchError((Object error) {
      if (!_disposed) {
        _error(error);
        _notify();
      }
    });
    return _tail;
  }

  Future<void> start() => _start ??= _initialize();
  Future<void> _initialize() async {
    try {
      _saved = await vault.read();
    } catch (e) {
      _error(e);
    }
    try {
      await _prepareGateway();
    } catch (e) {
      _error(e);
    }
    if (_disposed) return;
    _started = true;
    _sessionChanged();
    _notify();
  }

  Future<void> _prepareGateway() {
    if (!configured || _subscriptions.isNotEmpty) return Future<void>.value();
    if (_gatewayPreparation case final pending?) return pending;
    final task = _connectGateway();
    _gatewayPreparation = task;
    return task.whenComplete(() {
      if (identical(_gatewayPreparation, task)) _gatewayPreparation = null;
    });
  }

  Future<void> _connectGateway() async {
    await gateway.initialize().timeout(const Duration(seconds: 20));
    if (_disposed) return;
    _subscriptions.add(
      gateway.registrations.listen(
        _registrationChanged,
        onError: (Object _) {
          if (enabled) {
            _error(
              const ApiFailure(
                ApiFailureKind.unavailable,
                code: 'push_unavailable',
              ),
            );
            _notify();
          }
        },
      ),
    );
    _subscriptions.add(
      gateway.received.listen(_receive, onError: (Object _) {}),
    );
    _subscriptions.add(gateway.opened.listen(_open, onError: (Object _) {}));
    final first = await gateway.initial();
    if (first != null) _open(first);
  }

  void _sessionChanged() {
    if (!_started || _disposed) return;
    final newKey = session.resourceKey;
    // Bootstrap and refresh have not yet established an account owner. Keep
    // the sealed preference until identity is verified or restoration fails.
    if (_key == null &&
        !accessible &&
        [
          SessionPhase.restoring,
          SessionPhase.synchronizing,
        ].contains(session.phase)) {
      return;
    }
    if (!accessible || (_key != null && _key != newKey)) {
      final temporary =
          session.hasSession &&
          session.phase == SessionPhase.unavailable &&
          (_key == newKey || _key == null);
      _epoch++;
      _scope.cancel();
      _scope = RequestCancellation();
      busy = false;
      foreground = null;
      coversMainFlow = false;
      if (temporary) _restoredKey = null;
      if (!temporary) {
        failure = null;
        notice = null;
        permission = PushPermission.unavailable;
        _timer?.cancel();
        enabled = false;
        deviceId = null;
        pending = null;
        pendingOpen = null;
        _pendingOwner = null;
        _latestRegistration = null;
        _opened.clear();
        _presented.clear();
        _obsolete.clear();
        _saved = null;
        _restoredKey = null;
        unawaited(
          _enqueue(() async {
            try {
              await vault.write(null);
            } finally {
              if (configured) await gateway.disable();
            }
          }),
        );
      }
      _key = null;
      _notify();
      if (!accessible) return;
    }
    _key = newKey;
    if (_restoredKey == newKey) return;
    _restoredKey = newKey;
    final epoch = _epoch;
    unawaited(
      _enqueue(() async {
        if (_alive(epoch)) await _restore(epoch);
      }),
    );
  }

  Future<void> _restore(int epoch) async {
    final saved = await vault.read();
    if (!_alive(epoch)) return;
    _saved = saved;
    if (saved == null) {
      pendingOpen = null;
      return;
    }
    if (saved.origin != _origin || saved.owner != session.identity!.userId) {
      await vault.write(null);
      if (configured) await gateway.disable();
      _saved = null;
      pendingOpen = null;
      return;
    }
    if (!configured || !saved.optedIn) {
      deviceId = saved.deviceId;
      await _disable(epoch);
      return;
    }
    if (saved.deviceId == null) {
      await gateway.disable();
      await vault.write(null);
      _saved = null;
      pendingOpen = null;
      return;
    }
    _opened
      ..clear()
      ..addAll(saved.opened);
    if (pendingOpen != null && _opened.contains(pendingOpen!.id)) {
      pendingOpen = null;
      _pendingOwner = null;
    }
    final devices = await repository.list(_scope);
    if (!_alive(epoch)) return;
    if (!devices.any((d) => d.id == saved.deviceId)) {
      await vault.write(null);
      await gateway.disable();
      _saved = null;
      pendingOpen = null;
      notice = 'removed_elsewhere';
      _notify();
      return;
    }
    deviceId = saved.deviceId;
    enabled = true;
    permission = await gateway.permission();
    if (!_alive(epoch)) return;
    if (![
      PushPermission.authorized,
      PushPermission.provisional,
    ].contains(permission)) {
      await _disable(epoch);
      return;
    }
    await _newRegistration(epoch);
  }

  Future<void> _persist(int epoch, {String? id}) async {
    if (!_alive(epoch)) return;
    final record = PushRecord(
      _origin,
      session.identity!.userId,
      deviceId: id ?? deviceId,
      opened: List.of(_opened),
    );
    await vault.write(record);
    if (_alive(epoch)) _saved = record;
  }

  Future<void> enable() async {
    if (!active || !configured || busy || retrySeconds > 0) return;
    final epoch = _epoch;
    busy = true;
    _notify();
    await _enqueue(() async {
      if (!_alive(epoch)) return;
      busy = true;
      failure = null;
      notice = null;
      _notify();
      try {
        await _prepareGateway();
        if (!_alive(epoch)) return;
        permission = await gateway.permission(request: true);
        if (!_alive(epoch)) return;
        if (![
          PushPermission.authorized,
          PushPermission.provisional,
        ].contains(permission)) {
          if (enabled || pending != null) await _disable(epoch);
          notice = 'permission_denied';
          return;
        }
        await _persist(epoch);
        if (!_alive(epoch)) return;
        enabled = true;
        if (pending != null) {
          await _send(epoch);
        } else {
          await _newRegistration(epoch);
        }
      } catch (e) {
        if (_alive(epoch)) _error(e);
      } finally {
        if (_alive(epoch)) {
          busy = false;
          _notify();
        }
      }
    });
  }

  Future<void> _newRegistration(int epoch) async {
    if (!_alive(epoch) || !enabled || pending != null) return;
    final token = await gateway.registration();
    if (!_alive(epoch)) return;
    final version = await _appVersion();
    if (!_alive(epoch)) return;
    pending = DeviceRegistration(token, gateway.platform, version);
    await _send(epoch);
  }

  Future<void> _send(int epoch) async {
    final intent = pending;
    if (intent == null || !_alive(epoch)) return;
    final old = deviceId;
    final registered = await repository.register(intent, _scope);
    if (!_alive(epoch)) return;
    if (registered.platform != intent.platform) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    await _persist(epoch, id: registered.id);
    if (!_alive(epoch)) return;
    deviceId = registered.id;
    pending = null;
    failure = null;
    notice = 'registered';
    if (old != null && old != registered.id) _obsolete.add(old);
    await _cleanObsolete(epoch);
    if (_latestRegistration == intent.token) _latestRegistration = null;
    final latest = _latestRegistration;
    if (latest != null && _alive(epoch)) {
      _latestRegistration = null;
      pending = DeviceRegistration(latest, gateway.platform, intent.version);
      await _send(epoch);
    }
    _notify();
  }

  Future<void> _cleanObsolete(int epoch) async {
    for (final id in List.of(_obsolete)) {
      if (!_alive(epoch)) return;
      try {
        await repository.remove(id, _scope);
        _obsolete.remove(id);
      } on ApiFailure catch (e) {
        if (e.code == 'device_not_found') {
          _obsolete.remove(id);
        } else {
          rethrow;
        }
      }
    }
  }

  void _registrationChanged(String token) {
    if (!active || !enabled || !configured) return;
    _latestRegistration = token;
    if (busy || pending != null) return;
    final epoch = _epoch;
    unawaited(
      _enqueue(() async {
        if (!_alive(epoch) || !enabled || pending != null) return;
        final latest = _latestRegistration;
        _latestRegistration = null;
        if (latest == null) return;
        busy = true;
        _notify();
        try {
          final version = await _appVersion();
          if (!_alive(epoch)) return;
          pending = DeviceRegistration(latest, gateway.platform, version);
          await _send(epoch);
        } catch (e) {
          if (_alive(epoch)) _error(e);
        } finally {
          if (_alive(epoch)) {
            busy = false;
            _notify();
          }
        }
      }),
    );
  }

  Future<void> disable() async {
    if (!active || busy || (stopping && retrySeconds > 0)) return;
    final epoch = _epoch;
    busy = true;
    _notify();
    await _enqueue(() async {
      if (!_alive(epoch)) return;
      busy = true;
      _notify();
      try {
        await _disable(epoch);
      } catch (e) {
        if (_alive(epoch)) _error(e);
      } finally {
        if (_alive(epoch)) {
          busy = false;
          _notify();
        }
      }
    });
  }

  Future<void> _disable(int epoch) async {
    final id = deviceId;
    enabled = false;
    pending = null;
    _latestRegistration = null;
    foreground = null;
    pendingOpen = null;
    final tombstone = PushRecord(
      _origin,
      session.identity!.userId,
      deviceId: id,
      optedIn: false,
    );
    await vault.write(tombstone);
    _saved = tombstone;
    await gateway.disable();
    if (!_alive(epoch)) return;
    if (id != null) {
      if (retrySeconds > 0) throw failure!;
      try {
        await repository.remove(id, _scope);
      } on ApiFailure catch (e) {
        if (e.code != 'device_not_found') rethrow;
      }
    }
    if (_alive(epoch)) {
      await vault.write(null);
      if (!_alive(epoch)) return;
      _saved = null;
      deviceId = null;
      notice = 'disabled';
      _notify();
    }
  }

  Future<void> removed(String id) async {
    if (deviceId != id) return;
    await disable();
  }

  void suspend() {
    _foreground = false;
    _epoch++;
    _scope.cancel();
    _scope = RequestCancellation();
    busy = false;
    foreground = null;
    _notify();
  }

  Future<void> resume() async {
    _foreground = true;
    if (!accessible || !configured) return;
    final epoch = _epoch;
    await _enqueue(() async {
      if (!_alive(epoch) || !enabled || pending != null) return;
      try {
        permission = await gateway.permission();
        if (!_alive(epoch)) return;
        if (![
          PushPermission.authorized,
          PushPermission.provisional,
        ].contains(permission)) {
          await _disable(epoch);
          return;
        }
        final devices = await repository.list(_scope);
        if (!_alive(epoch)) return;
        if (deviceId != null && !devices.any((d) => d.id == deviceId)) {
          await _disable(epoch);
          notice = 'removed_elsewhere';
          return;
        }
        await _cleanObsolete(epoch);
        if (deviceId == null && pending == null) await _newRegistration(epoch);
      } catch (e) {
        if (_alive(epoch)) _error(e);
      } finally {
        _notify();
      }
    });
  }

  void _receive(PushIntent intent) {
    if (!active || !enabled || !configured || !_presented.add(intent.id)) {
      return;
    }
    if (_presented.length > 128) _presented.remove(_presented.first);
    foreground = intent;
    _notify();
  }

  void dismiss() {
    foreground = null;
    _notify();
  }

  void openForeground() {
    final intent = foreground;
    foreground = null;
    if (intent != null) _open(intent);
    _notify();
  }

  void _open(PushIntent intent) {
    if (!configured || _opened.contains(intent.id)) return;
    final savedOwner = _saved?.origin == _origin && _saved?.optedIn == true
        ? _saved?.owner
        : null;
    final owner =
        accessible && (enabled || savedOwner == session.identity!.userId)
        ? session.identity!.userId
        : _key == null &&
              [
                SessionPhase.restoring,
                SessionPhase.synchronizing,
                SessionPhase.unavailable,
              ].contains(session.phase)
        ? savedOwner
        : null;
    if (owner == null) return;
    pendingOpen = intent;
    _pendingOwner = owner;
    _notify();
  }

  Future<PushIntent?> authorizeOpen() async {
    final intent = pendingOpen, epoch = _epoch;
    if (intent == null ||
        !active ||
        !enabled ||
        busy ||
        _opened.contains(intent.id) ||
        _pendingOwner != session.identity!.userId) {
      return null;
    }
    await session.synchronize();
    if (!_alive(epoch) ||
        !enabled ||
        pendingOpen != intent ||
        _pendingOwner != session.identity!.userId) {
      return null;
    }
    _opened.insert(0, intent.id);
    if (_opened.length > 64) _opened.removeLast();
    try {
      await _persist(epoch);
    } catch (e) {
      _error(e);
      pendingOpen = null;
      _notify();
      return null;
    }
    if (!_alive(epoch)) return null;
    pendingOpen = null;
    _pendingOwner = null;
    foreground = null;
    _notify();
    return intent;
  }

  void coverMainFlow(bool value) {
    coversMainFlow = value;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _scope.cancel();
    _timer?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    session.removeListener(_sessionChanged);
    pending = null;
    foreground = null;
    pendingOpen = null;
    super.dispose();
  }
}
