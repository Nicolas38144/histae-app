import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/store_update_gateway.dart';

class StoreUpdateController extends ChangeNotifier {
  StoreUpdateController(this.gateway);
  final StoreUpdateGateway gateway;
  StoreUpdate? update;
  bool checking = false, opening = false, openFailed = false;
  bool _disposed = false, _active = true;
  int _epoch = 0;
  Timer? _timer;
  Future<void>? _check;

  bool get blocked => update != null;

  Future<void> check() {
    if (_disposed || !_active) return Future.value();
    if (_check case final pending?) return pending;
    final epoch = _epoch;
    checking = true;
    notifyListeners();
    final task = _read(epoch);
    _check = task;
    return task.whenComplete(() {
      if (identical(_check, task)) _check = null;
    });
  }

  Future<void> _read(int epoch) async {
    try {
      final result = await gateway.check().timeout(const Duration(seconds: 12));
      if (!_disposed && _active && epoch == _epoch) update = result;
    } catch (_) {
      // An unknown/unreachable store never creates a block. A confirmed block
      // stays until the same store confirms it is no longer applicable.
    } finally {
      if (!_disposed && epoch == _epoch) {
        checking = false;
        notifyListeners();
        _arm();
      }
    }
  }

  void _arm() {
    _timer?.cancel();
    if (_active && !_disposed) {
      _timer = Timer(const Duration(minutes: 15), () => unawaited(check()));
    }
  }

  void setActive(bool value) {
    if (_active == value || _disposed) return;
    _active = value;
    _timer?.cancel();
    if (!value) {
      _epoch++;
      _check = null;
      checking = false;
    } else {
      unawaited(check());
    }
  }

  Future<void> openStore() async {
    final offer = update;
    if (_disposed || opening || offer == null) return;
    opening = true;
    openFailed = false;
    notifyListeners();
    try {
      final opened = await gateway
          .open(offer)
          .timeout(const Duration(seconds: 10));
      if (!_disposed) openFailed = !opened;
    } catch (_) {
      if (!_disposed) openFailed = true;
    } finally {
      if (!_disposed) {
        opening = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    gateway.dispose();
    super.dispose();
  }
}
