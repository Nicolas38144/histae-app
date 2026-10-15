import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../data/catalog_repository.dart';
import '../data/subscription_plan.dart';

enum CatalogStatus { idle, loading, ready, empty, failure }

class CatalogController extends ChangeNotifier {
  CatalogController(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final CatalogRepository _repository;
  final DateTime Function() _now;
  CatalogStatus status = CatalogStatus.idle;
  List<SubscriptionPlan> plans = const [];
  ApiFailure? failure;
  RequestCancellation? _pending;
  Timer? _cooldown;
  bool _disposed = false;

  int get retrySeconds {
    final deadline = failure?.retryAt;
    if (deadline == null) return 0;
    final milliseconds = deadline.difference(_now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  Future<void> load() async {
    if (_disposed || status == CatalogStatus.loading || retrySeconds > 0) {
      return;
    }
    _cooldown?.cancel();
    final request = RequestCancellation();
    _pending = request;
    status = CatalogStatus.loading;
    failure = null;
    notifyListeners();
    try {
      final result = await _repository.load(request);
      if (_disposed || request.isCancelled) return;
      plans = result;
      status = plans.isEmpty ? CatalogStatus.empty : CatalogStatus.ready;
    } on ApiFailure catch (error) {
      if (_disposed || request.isCancelled) return;
      failure = error;
      status = CatalogStatus.failure;
      if (retrySeconds > 0) {
        _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (retrySeconds == 0) timer.cancel();
          notifyListeners();
        });
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
    _cooldown?.cancel();
    super.dispose();
  }
}
