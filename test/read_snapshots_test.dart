import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/core/network/read_snapshots.dart';
import 'package:histae_app/core/network/request_cancellation.dart';

void main() {
  test('explicit cached reads retain immutable values and their original timestamp', () async {
    final cache = ReadSnapshots();
    var reads = 0;
    Future<List<int>> read(ReadPolicy policy) => cache.read(
      scope: 'owner:fr',
      key: DataResource.profile,
      policy: policy,
      fetch: () async => List.unmodifiable([++reads]),
    );
    final first = await read(ReadPolicy.cached);
    final timestamp = cache.readAt(DataResource.profile);
    expect(() => first.clear(), throwsUnsupportedError);
    expect(await read(ReadPolicy.cached), [1]);
    expect(cache.readAt(DataResource.profile), timestamp);
    expect(reads, 1);
    expect(await read(ReadPolicy.refresh), [2]);
    expect(await read(ReadPolicy.cached), [2]);
    expect(reads, 2);
  });

  test(
    'owner, consent and language changes isolate private snapshots',
    () async {
      final cache = ReadSnapshots();
      var reads = 0;
      Future<int> read(String scope) => cache.read(
        scope: scope,
        key: DataResource.profile,
        policy: ReadPolicy.cached,
        fetch: () async => ++reads,
      );
      expect(await read('owner1:consent1:fr'), 1);
      expect(await read('owner1:consent1:fr'), 1);
      expect(await read('owner1:consent1:en'), 2);
      expect(await read('owner1:consent2:en'), 3);
      expect(await read('owner2:consent2:en'), 4);
      expect(await read('owner1:consent1:fr'), 5);
    },
  );

  test('targeted invalidation rejects late fills without discarding unrelated in-flight reads', () async {
    final cache = ReadSnapshots();
    final old = Completer<int>(), device = Completer<int>();
    Future<int> read(Object key, Future<int> Function() fetch) => cache.read(
      scope: 'owner',
      key: key,
      tags: {key},
      policy: ReadPolicy.cached,
      fetch: fetch,
    );
    final oldRead = read(DataResource.messages, () => old.future);
    final deviceRead = read(DataResource.devices, () => device.future);
    cache.invalidate({DataResource.messages});
    old.complete(1);
    device.complete(2);
    await Future.wait([oldRead, deviceRead]);
    expect(await read(DataResource.messages, () async => 3), 3);
    expect(
      await read(
        DataResource.devices,
        () async => fail('unrelated device snapshot was invalidated'),
      ),
      2,
    );
  });

  test('failed refreshes, cancelled requests and uncertain writes cannot resurrect snapshots', () async {
    final cache = ReadSnapshots();
    Future<int> read({
      ReadPolicy policy = ReadPolicy.cached,
      RequestCancellation? cancellation,
      bool failRead = false,
    }) => cache.read(
      scope: 'owner',
      key: DataResource.profile,
      tags: {DataResource.profile},
      policy: policy,
      cancellation: cancellation,
      fetch: () async {
        if (failRead) throw const ApiFailure(ApiFailureKind.network);
        return 1;
      },
    );
    await read();
    await expectLater(
      read(cancellation: RequestCancellation()..cancel()),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      read(policy: ReadPolicy.refresh, failRead: true),
      throwsA(isA<ApiFailure>()),
    );
    expect(cache.readAt(DataResource.profile), isNull);
    await read();
    final late = Completer<int>();
    await expectLater(
      cache.mutate({DataResource.profile}, () async {
        final pending = cache.read(
          scope: 'owner',
          key: DataResource.profile,
          tags: {DataResource.profile},
          fetch: () => late.future,
        );
        unawaited(pending);
        throw const ApiFailure(ApiFailureKind.network);
      }),
      throwsA(isA<ApiFailure>()),
    );
    late.complete(9);
    await Future<void>.delayed(Duration.zero);
    expect(cache.readAt(DataResource.profile), isNull);
    expect(await read(), 1);
    cache.clear();
    expect(cache.readAt(DataResource.profile), isNull);
  });
}
