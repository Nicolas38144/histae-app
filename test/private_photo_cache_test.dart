import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/media/private_photo_cache.dart';
import 'package:histae_app/core/widgets/private_photo.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final pixels = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jLZkAAAAASUVORK5CYII=',
  );
  const url = 'https://photos.example/portrait?X-Amz-Signature=one';

  testWidgets(
    'hidden thumbnails reuse authorized pixels without refreshing an expired URL; backgrounding purges them',
    (tester) async {
      final cache = PrivatePhotoCache();
      addTearDown(cache.dispose);
      var visible = true, downloads = 0, refreshes = 0;
      var readAt = DateTime.now().toUtc();
      Widget photo() => MaterialApp(
        home: TickerMode(
          enabled: visible,
          child: PrivatePhoto(
            url: url,
            readAt: readAt,
            allowed: true,
            decodeWidth: 144,
            memoryCache: cache,
            cacheKey: 'match',
            refreshAccess: () async {
              refreshes++;
            },
            photoClient: () => MockClient((_) async {
              downloads++;
              return http.Response.bytes(pixels, 200);
            }),
            builder: (_, image, _, _) =>
                image == null ? const SizedBox() : Image(image: image),
          ),
        ),
      );
      await tester.pumpWidget(photo());
      await tester.pumpAndSettle();
      final original = tester.widget<Image>(find.byType(Image)).image;
      visible = false;
      await tester.pumpWidget(photo());
      expect(find.byType(Image), findsNothing);
      readAt = readAt.subtract(const Duration(minutes: 2));
      visible = true;
      await tester.pumpWidget(photo());
      expect(tester.widget<Image>(find.byType(Image)).image, same(original));
      expect(downloads, 1);
      expect(refreshes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(cache.lookup('match', url, 144), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'one thumbnail download serves concurrent views and late cancelled bytes cannot refill it',
    (tester) async {
      final cache = PrivatePhotoCache();
      addTearDown(cache.dispose);
      final response = Completer<http.Response>();
      var downloads = 0;
      Future<ImageProvider> load() => cache.load(
        key: 'match',
        url: url,
        width: 144,
        photoClient: () => MockClient((request) {
          downloads++;
          expectSync(request.followRedirects, isFalse);
          expectSync(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('authorization')),
          );
          return response.future;
        }),
      );
      final first = load(), second = load();
      await tester.pump();
      expect(downloads, 1);
      response.complete(http.Response.bytes(pixels, 200));
      final images = await Future.wait([first, second]);
      expect(images.first, same(images.last));
      final lateResponse = Completer<http.Response>();
      final pending = cache.load(
        key: 'late',
        url: url,
        width: 144,
        photoClient: () => MockClient((_) => lateResponse.future),
      );
      final failure = expectLater(pending, throwsA(anything));
      cache.clear();
      lateResponse.complete(http.Response.bytes(pixels, 200));
      await failure;
      expect(cache.lookup('match', url, 144), isNull);
      expect(cache.lookup('late', url, 144), isNull);
    },
  );

  testWidgets(
    'LRU, resource changes and server grants bound thumbnail retention',
    (tester) async {
      final cache = PrivatePhotoCache(maxEntries: 2);
      addTearDown(cache.dispose);
      Future<ImageProvider> load(String key) => cache.load(
        key: key,
        url: url,
        width: 144,
        photoClient: () =>
            MockClient((_) async => http.Response.bytes(pixels, 200)),
      );
      final a = await load('a');
      await load('b');
      expect(cache.lookup('a', url, 144), same(a));
      await load('c');
      expect(cache.lookup('b', url, 144), isNull);
      expect(cache.lookup('a', '$url&versionId=replaced', 144), isNull);
      cache.retainAuthorized({
        'c': 'https://photos.example/portrait?X-Amz-Signature=renewed',
      });
      expect(cache.lookup('c', url, 144), isNotNull);
      cache.retainAuthorized({});
      expect(cache.lookup('c', url, 144), isNull);
    },
  );
}
