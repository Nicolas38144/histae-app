import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/billing_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../matches/data/realtime_client.dart';
import '../data/billing_gateway.dart';
import '../data/billing_models.dart';
import '../data/billing_repository.dart';

class BillingController extends ChangeNotifier {
  BillingController(
    this.repository,
    this.config,
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
    if (config.available) {
      _purchases = gateway.updates.listen(
        _updates,
        onError: (Object _) {
          _fail(
            const ApiFailure(
              ApiFailureKind.unavailable,
              code: 'store_unavailable',
            ),
          );
        },
      );
    }
    session.addListener(_changed);
    _changed();
  }
  final BillingRepository repository;
  final BillingConfig config;
  final BillingGateway gateway;
  AuthenticatedSession get session => repository.session;
  late final RealtimeClient _realtime;
  StreamSubscription<List<StorePurchase>>? _purchases;
  Timer? _expiry;
  final _queue = <String, StorePurchase>{};
  String? _owner, _resource;
  int _epoch = 0;
  bool _disposed = false,
      _active = false,
      _processing = false,
      _invalidated = false;
  bool loading = false, busy = false, fresh = false, purchasePending = false;
  bool restored = true, storeAvailable = false;
  SubscriptionState? subscription;
  List<StoreOffer> offers = [];
  ApiFailure? failure;
  String? notice;
  RequestCancellation _scope = RequestCancellation();
  late final RetryTicker _timer = RetryTicker(
    remaining: () => retrySeconds,
    onTick: _notify,
  );
  bool get accessible =>
      !_disposed &&
      session.phase == SessionPhase.ready &&
      session.identity?.userId == _owner &&
      session.resourceKey == _resource;
  bool get active => accessible && _active;
  bool get paymentsAvailable => config.available && storeAvailable;
  int get retrySeconds => retrySecondsUntil(failure?.retryAt);
  bool _alive(int epoch) => accessible && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(ApiFailure value) {
    if (_disposed) return;
    failure = value;
    if (retrySeconds > 0) _timer.restart();
    _notify();
  }

  void _changed() {
    if (_disposed) return;
    if (_owner != session.identity?.userId ||
        _resource != session.resourceKey ||
        !session.hasSession) {
      _epoch++;
      _scope.cancel();
      _scope = RequestCancellation();
      _realtime.stop();
      _expiry?.cancel();
      _queue.clear();
      subscription = null;
      offers = [];
      failure = null;
      notice = null;
      purchasePending = false;
      storeAvailable = false;
      fresh = false;
      loading = false;
      busy = false;
      _owner = session.identity?.userId;
      _resource = session.resourceKey;
    }
    if (session.phase != SessionPhase.ready) _realtime.stop();
    _notify();
  }

  Future<void> activate({bool refresh = false}) async {
    if (_disposed) return;
    _changed();
    _active = true;
    if (!accessible) return;
    if (_scope.isCancelled) _scope = RequestCancellation();
    if (refresh || subscription == null || !fresh) await load();
    if (active) _realtime.start();
  }

  void suspend() {
    _active = false;
    _realtime.stop();
  }

  Future<void> resume() async {
    await activate(refresh: true);
    await _drain();
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
      _expiry?.cancel();
      final end = result.periodEnd;
      if (result.accessGranted && end != null) {
        final delay = end.difference(DateTime.now().toUtc());
        if (delay > Duration.zero) {
          _expiry = Timer(delay, () {
            fresh = false;
            _notify();
            if (active) unawaited(load());
          });
        } else {
          fresh = false;
        }
      }
      if (config.available && await gateway.available()) {
        final products = await repository.products(gateway.provider, _scope);
        final available = await gateway.products(products);
        if (!_alive(epoch)) return;
        offers = available;
        storeAvailable = available.isNotEmpty;
      }
    } on ApiFailure catch (error) {
      if (_alive(epoch)) _fail(error);
    } catch (_) {
      if (_alive(epoch)) _fail(const ApiFailure(ApiFailureKind.unavailable));
    } finally {
      if (_alive(epoch)) {
        loading = false;
        _notify();
        if (_invalidated) {
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
        purchasePending ||
        retrySeconds > 0 ||
        subscription?.accessGranted != false) {
      return;
    }
    if (_queue.isNotEmpty) {
      await _drain();
      return;
    }
    final epoch = _epoch;
    busy = true;
    failure = null;
    notice = null;
    _notify();
    try {
      final intent = await repository.intent(gateway.provider, _scope);
      if (!_alive(epoch)) return;
      final offer = offers
          .where((offer) => offer.product.period == period)
          .firstOrNull;
      if (offer == null ||
          !intent.products.any(
            (product) =>
                product.period == period &&
                product.productId == offer.product.productId &&
                product.basePlanId == offer.product.basePlanId,
          )) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      purchasePending = true;
      if (intent.provider != gateway.provider) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final accepted = await gateway.buy(offer, intent.binding);
      if (!_alive(epoch)) return;
      if (!accepted) {
        purchasePending = false;
        throw const ApiFailure(
          ApiFailureKind.unavailable,
          code: 'store_unavailable',
        );
      }
    } on ApiFailure catch (error) {
      if (_alive(epoch)) {
        purchasePending = false;
        _fail(error);
      }
    } catch (_) {
      if (_alive(epoch)) {
        purchasePending = false;
        _fail(const ApiFailure(ApiFailureKind.unavailable));
      }
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
        if (_invalidated) {
          _invalidated = false;
          unawaited(load());
        }
      }
    }
  }

  void _updates(List<StorePurchase> updates) {
    if (_disposed) return;
    for (final purchase in updates) {
      if (purchase.status == StorePurchaseStatus.pending) {
        purchasePending = true;
        continue;
      }
      if (purchase.status == StorePurchaseStatus.error ||
          purchase.status == StorePurchaseStatus.canceled) {
        purchasePending = false;
        if (purchase.status == StorePurchaseStatus.error) {
          _fail(
            const ApiFailure(
              ApiFailureKind.unavailable,
              code: 'store_purchase_failed',
            ),
          );
        }
        continue;
      }
      if (purchase.status == StorePurchaseStatus.purchased ||
          purchase.status == StorePurchaseStatus.restored) {
        try {
          _queue[gateway.reference(purchase)] = purchase;
        } on ApiFailure catch (error) {
          _fail(error);
        }
      }
    }
    _notify();
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_processing || !accessible || retrySeconds > 0 || _queue.isEmpty) {
      return;
    }
    _processing = true;
    final epoch = _epoch;
    try {
      for (final reference in _queue.keys.toList()) {
        if (!_alive(epoch)) return;
        final purchase = _queue[reference]!;
        try {
          await repository.verify(gateway.provider, reference, _scope);
          if (!_alive(epoch)) return;
          if (purchase.pendingCompletePurchase) {
            await gateway.complete(purchase);
          }
          if (!_alive(epoch)) return;
          _queue.remove(reference);
          purchasePending = false;
          notice = 'confirmed';
          fresh = false;
        } on ApiFailure catch (error) {
          if (_alive(epoch)) _fail(error);
          break;
        } catch (_) {
          if (_alive(epoch)) {
            _fail(const ApiFailure(ApiFailureKind.unavailable));
          }
          break;
        }
      }
    } finally {
      _processing = false;
      if (_alive(epoch)) {
        _notify();
        if (!busy && !loading && active && _queue.isEmpty) await load();
      }
    }
  }

  Future<void> restorePurchases() async {
    if (!active || busy || !config.available || retrySeconds > 0) return;
    final epoch = _epoch;
    busy = true;
    failure = null;
    _notify();
    try {
      await gateway.restore();
    } catch (_) {
      if (_alive(epoch)) _fail(const ApiFailure(ApiFailureKind.unavailable));
    } finally {
      if (_alive(epoch)) {
        busy = false;
        _notify();
      }
    }
    await _drain();
  }

  Future<void> portal() async {
    final provider = subscription?.provider;
    if (!active ||
        busy ||
        loading ||
        !fresh ||
        provider == null ||
        provider == 'stripe') {
      return;
    }
    final epoch = _epoch;
    busy = true;
    _notify();
    try {
      final opened = await gateway.manage(provider);
      if (_alive(epoch) && !opened) {
        _fail(const ApiFailure(ApiFailureKind.unavailable));
      }
    } catch (_) {
      if (_alive(epoch)) _fail(const ApiFailure(ApiFailureKind.unavailable));
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
    _expiry?.cancel();
    _scope.cancel();
    _timer.cancel();
    session.removeListener(_changed);
    unawaited(_purchases?.cancel());
    _realtime.dispose();
    _queue.clear();
    subscription = null;
    offers = [];
    super.dispose();
  }
}
