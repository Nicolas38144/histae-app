import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/core/network/read_snapshots.dart';
import 'package:histae_app/core/network/request_cancellation.dart';

void main() {
  test(
    'view snapshots reuse JSON, while refresh remains fresh and replaces it',
    () async {
      final cache = ReadSnapshots();
      var reads = 0;
      Future<Object?> read() => cache.read(
        scope: 'owner:fr',
        key: '/profile',
        fetch: () async => {
          'revision': ++reads,
          'tags': ['books'],
        },
      );
      final first = await ReadSnapshots.forView(read) as Map;
      (first['tags'] as List).clear();
      expect(await ReadSnapshots.forView(read), {
        'revision': 1,
        'tags': ['books'],
      });
      expect(reads, 1);
      expect(await read(), {
        'revision': 2,
        'tags': ['books'],
      });
      expect(await ReadSnapshots.forView(read), {
        'revision': 2,
        'tags': ['books'],
      });
      expect(reads, 2);
    },
  );

  test(
    'owner, consent and language scopes cannot reuse private data',
    () async {
      final cache = ReadSnapshots();
      var reads = 0;
      Future<Object?> read(String scope) => ReadSnapshots.forView(
        () => cache.read(
          scope: scope,
          key: '/profile',
          fetch: () async => ++reads,
        ),
      );
      expect(await read('owner1:consent1:fr'), 1);
      expect(await read('owner1:consent1:fr'), 1);
      expect(await read('owner1:consent1:en'), 2);
      expect(await read('owner1:consent2:en'), 3);
      expect(await read('owner2:consent2:en'), 4);
      expect(await read('owner1:consent1:fr'), 5);
    },
  );

  test('reopening a view preserves the original photo read time', () async {
    final cache = ReadSnapshots();
    Future<Object?> read() => cache.read(
      scope: 'owner',
      key: '/profile',
      fetch: () async => {'photo': 'https://storage.example/temporary'},
    );
    await read();
    final first = await ReadSnapshots.forView(() async {
      await read();
      return ReadSnapshots.reusedAt('/profile');
    });
    expect(first, isNotNull);
    final second = await ReadSnapshots.forView(() async {
      await read();
      return ReadSnapshots.reusedAt('/profile');
    });
    expect(second, first);
    expect(ReadSnapshots.reusedAt('/profile'), isNull);
  });

  test('invalidation rejects late fills; failures and cancellation are never snapshots', () async {
    final cache = ReadSnapshots();
    final response = Completer<Object?>();
    final old = cache.read(
      scope: 'owner',
      key: '/matches/1',
      fetch: () => response.future,
    );
    cache.clear(prefix: '/matches/');
    response.complete({'old': true});
    await old;
    expect(
      await ReadSnapshots.forView(
        () => cache.read(
          scope: 'owner',
          key: '/matches/1',
          fetch: () async => {'old': false},
        ),
      ),
      {'old': false},
    );
    final cancelled = RequestCancellation()..cancel();
    await expectLater(
      ReadSnapshots.forView(
        () => cache.read(
          scope: 'owner',
          key: '/matches/1',
          cancellation: cancelled,
          fetch: () async => fail('cancelled read reached server'),
        ),
      ),
      throwsA(isA<ApiFailure>()),
    );
    // A failed manual refresh cannot make an old success reappear on reopen.
    await cache.read(scope: 'owner', key: '/failure', fetch: () async => 'old');
    await expectLater(
      cache.read(
        scope: 'owner',
        key: '/failure',
        fetch: () async => throw const ApiFailure(ApiFailureKind.network),
      ),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      ReadSnapshots.forView(
        () => cache.read(
          scope: 'owner',
          key: '/failure',
          fetch: () async => throw const ApiFailure(ApiFailureKind.network),
        ),
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      await ReadSnapshots.forView(
        () => cache.read(
          scope: 'owner',
          key: '/failure',
          fetch: () async => 'retried',
        ),
      ),
      'retried',
    );
  });
}
