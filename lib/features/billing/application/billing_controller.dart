import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async/serial_executor.dart';
import '../../../core/config/billing_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../matches/data/realtime_client.dart';
import '../data/billing_gateway.dart';
import '../data/billing_models.dart';
import '../data/billing_repository.dart';
import '../data/checkout_vault.dart';

class BillingController extends ChangeNotifier {
  BillingController(
    this.repository,
    this.config,
    this.vault,
    this.gateway, {
    RealtimeClient? realtime,
  }) {
    _realtime = realtime ?? RealtimeClient(session);
    _realtime.onSignal = (signal) {
      if (signal.type == 'subscription.updated' || signal.type == 'connected') {
        fresh = false;
        if (busy || loading) {
          _invalidated = true;
        } else {
          unawaited(load());
        }
      }
    };
    session.addListener(_changed);
    _changed();
  }
  final BillingRepository repository;
  final BillingConfig config;
  final CheckoutVault vault;
  final BillingGateway gateway;

  AuthenticatedSession get session => repository.session;
  late final RealtimeClient _realtime;
  String? _owner, _key;
  bool _disposed = false, _active = false, restored = false;
  bool loading = false, busy = false, fresh = false;
  bool _invalidated = false;
  int _epoch = 0;
  RequestCancellation _scope = RequestCancellation();
  final _storage = SerialExecutor();
  Future<void>? _restore;
  Timer? _expiry;
  late final RetryTicker _timer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  SubscriptionState? subscription;
  CheckoutAttempt? pending;
  ApiFailure? failure;
  String? notice;

  bool get accessible =>
      !_disposed &&
      session.phase == SessionPhase.ready &&
      session.resourceKey == _key &&
      session.identity?.userId == _owner;

  bool get active => accessible && _active && restored;

  bool get paymentsAvailable => config.available;

  int get retrySeconds => retrySecondsUntil(failure?.retryAt);

  bool _alive(int epoch) => active && epoch == _epoch;

  void _notify() {
    if (!_disposed) notifyListeners();
  }
  // Serialize every storage operation, including logout and owner changes, so
  // a late write cannot resurrect an old owner's pending intent.

  Future<T> _stored<T>(Future<T> Function() action) => _storage.run(action);

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
    if (_disposed) return;
    // Synchronizing is transient. A confirmed loss/revision/owner change purges
    // memory and queued work; temporary server unavailability retains intent.
    final changed =
        _key != null &&
        (session.resourceKey != _key ||
            !session.hasSession ||
            session.identity?.userId != _owner);
    if (changed) {
      suspend();
      subscription = null;
      pending = null;
      failure = null;
      notice = null;
      restored = false;
      _key = null;
      _owner = null;
      _restore = null;
      unawaited(_stored(() => vault.write(null)).catchError((Object _) {}));
      _notify();
    }
    if (session.phase != SessionPhase.ready) {
      _realtime.stop();
      fresh = false;
      _notify();
      return;
    }
    if (_key == null) {
      _key = session.resourceKey;
      _owner = session.identity!.userId;
      _restore = _restoreIntent(_epoch);
    }
  }

  Future<void> _restoreIntent(int epoch) async {
    try {
      final record = await _stored(vault.read);
      if (_disposed || epoch != _epoch || !accessible) return;
      if (record != null &&
          record.owner == _owner &&
          record.origin == session.apiOrigin.toString()) {
        pending = record;
      } else if (record != null) {
        await _stored(() => vault.write(null));
      }
      if (_disposed || epoch != _epoch || !accessible) return;
      restored = true;
    } on ApiFailure catch (e) {
      if (!_disposed && epoch == _epoch) _error(e);
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        _error(const ApiFailure(ApiFailureKind.secureStorage));
      }
    }
    _notify();
  }

  Future<void> activate() async {
    if (_disposed) return;
    _changed();
    final epoch = _epoch;
    // Await restoration before any POST or accepting a different period.
    await _restore;
    if (_disposed || epoch != _epoch || !accessible) return;
    if (!restored && accessible) {
      _restore = _restoreIntent(_epoch);
      await _restore;
    }
    if (_disposed || epoch != _epoch || !accessible || !restored) return;
    _active = true;
    if (_scope.isCancelled) _scope = RequestCancellation();
    await load();
    if (_alive(epoch)) _realtime.start();
  }

  void suspend() {
    _active = false;
    _epoch++;
    _scope.cancel();
    _realtime.stop();
    _expiry?.cancel();
    loading = false;
    busy = false;
    fresh = false;
    _invalidated = false;
  }

  Future<void> resume() async {
    final epoch = _epoch;
    await session.synchronize();
    if (_disposed || epoch != _epoch) return;
    await activate();
  }

  Future<void> load() async {
    if (!active || loading || busy || retrySeconds > 0) return;
    final epoch = _epoch;
    loading = true;
    fresh = false;
    failure = null;
    _notify();
    try {
      final result = await repository.load(_scope);
      if (!_alive(epoch)) return;
      subscription = result;
      fresh = true;
      if (result.accessGranted && pending != null) {
        await _stored(() => vault.write(null));
        if (!_alive(epoch)) return;
        pending = null;
        notice = 'confirmed';
      }
      _expiry?.cancel();
      final end = result.periodEnd;
      if (result.accessGranted && end != null) {
        final delay = end.difference(DateTime.now());
        if (delay > Duration.zero) {
          _expiry = Timer(delay, () {
            if (active) unawaited(load());
          });
        } else {
          // Do not grant cached access beyond an already passed period.
          fresh = false;
        }
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        fresh = false;
        _error(e);
      }
    } catch (_) {
      if (_alive(epoch)) {
        fresh = false;
        _error(const ApiFailure(ApiFailureKind.secureStorage));
      }
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
        if (_invalidated && retrySeconds == 0) {
          _invalidated = false;
          unawaited(load());
        }
      }
    }
  }

  Future<void> checkout(BillingPeriod period) async {
    if (!active ||
        busy ||
        loading ||
        !fresh ||
        !paymentsAvailable ||
        retrySeconds > 0 ||
        subscription == null ||
        subscription!.accessGranted ||
        (pending != null && pending!.period != period)) {
      return;
    }
    final epoch = _epoch;
    busy = true;
    failure = null;
    notice = null;
    pending ??= CheckoutAttempt.create(
      session.apiOrigin.toString(),
      _owner!,
      period,
      language: session.language,
    );
    final intent = pending!;
    _notify();
    var consumed = false;
    try {
      // Fail closed if the intent cannot be durably stored and verified.
      await _stored(() => vault.write(intent));
      if (!_alive(epoch)) return;
      final link = await repository.checkout(intent, _scope);
      if (!_alive(epoch)) return;
      if (!link.expiresAt.isAfter(DateTime.now())) {
        throw const ApiFailure(ApiFailureKind.expired);
      }
      notice = 'awaiting_confirmation';
      _notify();
      if (!await gateway.open(link.url, portal: false)) {
        throw const ApiFailure(
          ApiFailureKind.unavailable,
          code: 'browser_unavailable',
        );
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) {
        consumed = e.code == 'idempotency_key_consumed';
        _error(e);
      }
    } catch (_) {
      if (_alive(epoch)) _error(const ApiFailure(ApiFailureKind.secureStorage));
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
        // A consumed key is the server's definitive closed attempt. Re-read
        // entitlements before permitting a separately confirmed new purchase.
        if (consumed) {
          await load();
          if (_alive(epoch) && fresh) {
            try {
              await _stored(() => vault.write(null));
              if (_alive(epoch)) {
                pending = null;
                notice = 'attempt_closed';
              }
            } catch (_) {
              if (_alive(epoch)) {
                _error(const ApiFailure(ApiFailureKind.secureStorage));
              }
            }
            _notify();
          }
        }
        if (_invalidated && retrySeconds == 0) {
          _invalidated = false;
          unawaited(load());
        }
      }
    }
  }

  Future<void> portal() async {
    if (!active ||
        busy ||
        loading ||
        !fresh ||
        !paymentsAvailable ||
        retrySeconds > 0 ||
        subscription?.portalAvailable != true) {
      return;
    }
    final epoch = _epoch;
    busy = true;
    failure = null;
    _notify();
    try {
      final url = await repository.portal(_scope);
      if (!_alive(epoch)) return;
      notice = 'portal_opened';
      if (!await gateway.open(url, portal: true)) {
        throw const ApiFailure(
          ApiFailureKind.unavailable,
          code: 'browser_unavailable',
        );
      }
    } on ApiFailure catch (e) {
      if (_alive(epoch)) _error(e);
    } catch (_) {
      if (_alive(epoch)) _error(const ApiFailure(ApiFailureKind.unavailable));
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
        if (_invalidated && retrySeconds == 0) {
          _invalidated = false;
          unawaited(load());
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    suspend();
    _timer.cancel();
    session.removeListener(_changed);
    _realtime.dispose();
    subscription = null;
    pending = null;
    super.dispose();
  }
}
