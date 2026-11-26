import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_content.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';
import 'package:histae_app/features/profile/presentation/profile_feed_preview_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/photo_crop_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  testWidgets(
    'owner preview reuses its private photo until it changes or the session ends',
    (tester) async {
      var downloads = 0;
      var photoUrl = 'https://storage.example/private-owner-photo';
      final bytes = (await tester.runAsync(() => syntheticCropSource()))!;
      final session = testSession(
        (r) async => r.url.path == '/api/users/me'
            ? jsonResponse(ownerJson(photo: photoUrl))
            : defaultProfileResponse(r),
      );
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final c = ProfileController(ProfileRepository(session));
      addTearDown(c.dispose);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          locale: const Locale('fr'),
          localizationsDelegates: AppMessages.localizationsDelegates,
          supportedLocales: AppMessages.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileFeedPreviewPage(
                      controller: c,
                      photoClient: () => MockClient((r) async {
                        downloads++;
                        expect(r.url.toString(), photoUrl);
                        expect(r.headers['authorization'], isNull);
                        expect(r.followRedirects, false);
                        return http.Response.bytes(bytes, 200);
                      }),
                    ),
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      );
      final openPreview = find.text('Open preview');
      await tester.tap(openPreview);
      await tester.pumpAndSettle();
      final photo = find.byType(Image);
      expect(downloads, 1);
      final originalImage = tester.widget<Image>(photo).image;
      expect(
        find.descendant(
          of: find.byType(FeedProfileContent),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      final notice = find.textContaining('Votre photo reste absente du feed.');
      expect(notice, findsOneWidget);
      expect(
        tester.widget<Text>(notice).style,
        Theme.of(tester.element(notice)).textTheme.bodySmall,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(photo, findsNothing);
      c.photoReadAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      await tester.tap(openPreview);
      await tester.pumpAndSettle();
      expect(downloads, 1);
      expect(tester.widget<Image>(photo).image, same(originalImage));

      photoUrl = 'https://storage.example/replaced-owner-photo';
      await c.refreshPhotoPreview();
      await tester.pumpAndSettle();
      expect(downloads, 2);
      final replacementImage = tester.widget<Image>(photo).image;
      expect(replacementImage, isNot(same(originalImage)));

      await session.logout();
      await tester.pumpAndSettle();
      expect(photo, findsNothing);
      expect(
        c.ownerPreviewPhotos.owns(
          ProfileController.ownerPreviewPhotoKey,
          replacementImage,
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('photo URL renewal coalesces reads and preserves unrelated profile sections', () async {
    final response = Completer<http.Response>();
    var renewing = false;
    final reads = <String>[];
    final session = testSession((r) async {
      if (renewing) reads.add(r.url.path);
      if (renewing && r.url.path == '/api/users/me') return response.future;
      return defaultProfileResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = ProfileController(ProfileRepository(session));
    addTearDown(c.dispose);
    await c.load();
    final preferences = c.preferences;
    renewing = true;
    final first = c.refreshPhotoPreview(), second = c.refreshPhotoPreview();
    await pumpEventQueue();
    response.complete(
      jsonResponse(ownerJson(photo: 'https://storage.example/renewed-photo')),
    );
    await Future.wait([first, second]);
    expect(reads, ['/api/users/me']);
    expect(c.profile?.photo, 'https://storage.example/renewed-photo');
    expect(c.preferences, same(preferences));
    expect(c.loading, false);
  });
}
