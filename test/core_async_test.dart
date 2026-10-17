import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/async/serial_executor.dart';
import 'package:histae_app/core/network/retry_after.dart';

void main() {
  test('serialized storage failure reaches its caller and does not bypass or poison the next operation', () async {
    final executor = SerialExecutor();
    final release = Completer<void>();
    final events = <String>[];
    final first = executor.run<void>(() async {
      events.add('write');
      await release.future;
      throw StateError('Synthetic failed write');
    });
    final failure = expectLater(first, throwsStateError);
    final next = executor.run(() async {
      events.add('clear');
      return 'cleared';
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, ['write']);
    release.complete();
    await failure;
    expect(await next, 'cleared');
    expect(events, ['write', 'clear']);
  });

  testWidgets(
    'retry countdown expires, rounds partial seconds up and stops notifying after cancellation',
    (tester) async {
      final now = DateTime.utc(2026, 10, 17);
      expect(
        retrySecondsUntil(now.add(const Duration(milliseconds: 1)), now: now),
        1,
      );
      expect(
        retrySecondsUntil(now.subtract(const Duration(seconds: 1)), now: now),
        0,
      );
      var remaining = 2, ticks = 0;
      final ticker = RetryTicker(
        remaining: () => remaining,
        onTick: () => ticks++,
      );
      ticker.restart();
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, 1);
      remaining = 0;
      await tester.pump(const Duration(seconds: 1));
      expect(ticks, 2);
      await tester.pump(const Duration(seconds: 5));
      expect(ticks, 2);
      remaining = 3;
      ticker.restart();
      ticker.cancel();
      await tester.pump(const Duration(seconds: 5));
      expect(ticks, 2);
    },
  );
}
