import 'dart:async';

import '../../../core/network/api_failure.dart';

/// Owns the bounded network retry policy; the caller checks access before sending.
final class MessageRetryScheduler {
  MessageRetryScheduler({required this.onRetry});
  final void Function() onRetry;
  static const _delays = [2, 5, 10, 20];
  Timer? _timer;
  int _attempt = 0;

  bool get isActive => _timer?.isActive == true;

  static bool isRecoverable(ApiFailure? error) => switch (error?.kind) {
    ApiFailureKind.network ||
    ApiFailureKind.timeout ||
    ApiFailureKind.server ||
    ApiFailureKind.unavailable ||
    ApiFailureKind.cancelled => true,
    _ => false,
  };

  void schedule() {
    cancel();
    if (_attempt >= _delays.length) return;
    _timer = Timer(Duration(seconds: _delays[_attempt++]), onRetry);
  }

  void cancel() => _timer?.cancel();

  void reset() {
    cancel();
    _attempt = 0;
  }
}
