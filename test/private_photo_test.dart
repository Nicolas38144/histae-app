import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/widgets/private_photo.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final pixels = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jLZkAAAAASUVORK5CYII=',
  );

  testWidgets(
    'signature renewal retains pixels; object replacement and access loss purge them',
    (tester) async {
      var url = 'https://photos.example/portrait-1?X-Amz-Signature=one';
      var readAt = DateTime.now().toUtc();
      var allowed = true, downloads = 0;
      Widget photo() => MaterialApp(
        home: PrivatePhoto(
          url: url,
          readAt: readAt,
          allowed: allowed,
          decodeWidth: 144,
          photoClient: () => MockClient((_) async {
            downloads++;
            return http.Response.bytes(pixels, 200);
          }),
          builder: (context, image, loading, failed) =>
              image == null ? const SizedBox() : Image(image: image),
        ),
      );
      await tester.pumpWidget(photo());
      await tester.pumpAndSettle();
      final original = tester.widget<Image>(find.byType(Image)).image;
      expect(downloads, 1);
      url = 'https://photos.example/portrait-1?X-Amz-Signature=two';
      await tester.pumpWidget(photo());
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, same(original));
      expect(downloads, 1);
      readAt = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      await tester.pumpWidget(photo());
      expect(find.byType(Image), findsOneWidget);
      readAt = DateTime.now().toUtc();
      url = 'https://photos.example/portrait-2?X-Amz-Signature=three';
      await tester.pumpWidget(photo());
      await tester.pumpAndSettle();
      expect(downloads, 2);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isNot(same(original)),
      );
      allowed = false;
      await tester.pumpWidget(photo());
      expect(find.byType(Image), findsNothing);
    },
  );

  for (final stale in [true, false]) {
    testWidgets(
      'a ${stale ? 'stale' : 'rejected'} URL is refreshed once before retrying storage',
      (tester) async {
        var readAt = DateTime.now().toUtc().subtract(
          stale ? const Duration(minutes: 2) : Duration.zero,
        );
        var signature = 'old', refreshes = 0, downloads = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return PrivatePhoto(
                  url:
                      'https://photos.example/portrait?X-Amz-Signature=$signature',
                  readAt: readAt,
                  allowed: true,
                  decodeWidth: 144,
                  refreshAccess: () async {
                    refreshes++;
                    update(() {
                      readAt = DateTime.now().toUtc();
                      signature = 'fresh';
                    });
                  },
                  photoClient: () => MockClient((request) async {
                    downloads++;
                    if (request.url.queryParameters['X-Amz-Signature'] ==
                        'old') {
                      return http.Response('', 403);
                    }
                    return http.Response.bytes(pixels, 200);
                  }),
                  builder: (context, image, loading, failed) =>
                      image != null ? Image(image: image) : const SizedBox(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(downloads, stale ? 1 : 2);
        expect(find.byType(Image), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );
  }

  testWidgets(
    'failed refresh has no loop and sends no expired URL to storage',
    (tester) async {
      var refreshes = 0, downloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PrivatePhoto(
            url: 'https://photos.example/portrait',
            readAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
            allowed: true,
            decodeWidth: 144,
            refreshAccess: () async {
              refreshes++;
            },
            photoClient: () => MockClient((_) async {
              downloads++;
              return http.Response('', 403);
            }),
            builder: (context, image, loading, failed) =>
                Text(failed ? 'failed' : 'loading'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(downloads, 0);
      expect(find.text('failed'), findsOneWidget);
    },
  );
}
