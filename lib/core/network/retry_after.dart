import 'dart:async';

int retrySecondsUntil(DateTime? deadline, {DateTime? now}) {
  final ms = deadline?.difference(now ?? DateTime.now()).inMilliseconds ?? 0;
  return ms <= 0 ? 0 : (ms / 1000).ceil();
}

/// Drives countdown presentation only. Never retries an HTTP operation and
/// leaves each feature in control of how it retains its server deadline.
class RetryTicker {
  RetryTicker({required this.remaining, required this.onTick});
  final int Function() remaining;
  final void Function() onTick;
  Timer? _timer;
  void restart() {
    cancel();
    if (remaining() <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining() <= 0) cancel();
      onTick();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
