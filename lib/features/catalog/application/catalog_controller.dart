import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/retry_after.dart';
import '../data/catalog_repository.dart';
import '../data/plan_catalog.dart';
import '../data/subscription_plan.dart';

enum CatalogStatus { idle, loading, ready, empty, failure }

class CatalogController extends ChangeNotifier {
  CatalogController(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final CatalogRepository _repository;
  final DateTime Function() _now;
  CatalogStatus status = CatalogStatus.idle;
  List<SubscriptionPlan> plans = const [];
  List<SubscriptionOffer> offers = const [];
  ApiFailure? failure;
  RequestCancellation? _pending;
  late final RetryTicker _cooldown = RetryTicker(
    remaining: () => retrySeconds,
    onTick: () {
      if (!_disposed) notifyListeners();
    },
  );
  bool _disposed = false;

  int get retrySeconds => retrySecondsUntil(failure?.retryAt, now: _now());

  Future<void> load() async {
    if (_disposed || status == CatalogStatus.loading || retrySeconds > 0) {
      return;
    }
    _cooldown.cancel();
    final request = RequestCancellation();
    _pending = request;
    status = CatalogStatus.loading;
    failure = null;
    notifyListeners();
    try {
      final result = await _repository.load(request);
      if (_disposed || request.isCancelled) return;
      plans = result.plans;
      offers = result.offers;
      status = offers.isEmpty ? CatalogStatus.empty : CatalogStatus.ready;
    } on ApiFailure catch (error) {
      if (_disposed || request.isCancelled) return;
      failure = error;
      status = CatalogStatus.failure;
      if (retrySeconds > 0) {
        _cooldown.restart();
      }
    } finally {
      if (identical(_pending, request)) _pending = null;
      request.cancel();
    }
    if (!_disposed) notifyListeners();
  }

  void suspend() {
    if (status != CatalogStatus.loading) return;
    _pending?.cancel();
    _pending = null;
    status = CatalogStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _cooldown.cancel();
    super.dispose();
  }
}
