import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/l10n/locale_controller.dart';
import 'package:histae_app/features/discovery/presentation/discovery_status_sections.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/match_photo_avatar.dart';
import 'package:histae_app/features/profile/presentation/photo_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/photo_crop_fixture.dart';
import 'support/profile_fixture.dart';
import 'support/scrolling.dart';

void main() {
  testWidgets(
    'the photo step follows upload and removal on return to the feed',
    (tester) async {
      const photo = 'https://storage.example/owner?signature=synthetic';
      var hasPhoto = false, statusReads = 0, uploads = 0, feedReads = 0;
      bool? previousApproval;
      final session = testSession((r) async {
        switch (r.url.path) {
          case '/api/users/me/discovery-status':
            statusReads++;
            return jsonResponse(
              previousApproval ?? hasPhoto
                  ? discoveryStatusJson()
                  : {
                      'ready': false,
                      'required_actions': ['photo'],
                      'presence_expires_at': null,
                    },
            );
          case '/api/users/me':
            return jsonResponse(ownerJson(photo: hasPhoto ? photo : null));
          case '/api/users/me/photo':
            previousApproval = hasPhoto;
            hasPhoto = r.method == 'PUT';
            if (hasPhoto) uploads++;
          case '/api/feed':
            feedReads++;
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      final locale = LocaleController();
      await locale.select('fr');
      await tester.pumpWidget(
        HistaeApp(sessionController: session, localeController: locale),
      );
      await tester.pumpAndSettle();
      final initialReads = statusReads;
      expect(feedReads, 0);
      expect(find.text('Un visage, pour plus tard'), findsOneWidget);
      final action = find.descendant(
        of: find.widgetWithText(
          DiscoveryReadinessCard,
          'Un visage, pour plus tard',
        ),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(PhotoPage), findsOneWidget);
      final save = find.text('Enregistrer ma photo');
      expect(save, findsNothing);
      final bytes = (await tester.runAsync(syntheticCropSource))!;
      tester
          .widget<PhotoPage>(find.byType(PhotoPage))
          .controller
          .setPhoto(bytes);
      await tester.pumpAndSettle();

      Future<void> tapVisible(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          175,
          scrollable: verticalScrollables.first,
        );
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tapVisible(save);
      expect(uploads, 1);
      expect(statusReads, initialReads);
      previousApproval = null;
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(FeedProfileCard), findsOneWidget);
      expect(feedReads, 1);

      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tapVisible(find.text('Gérer ma photo'));
      await tapVisible(find.text('Retirer ma photo'));
      await tester.tap(find.text('Retirer la photo'));
      await tester.pumpAndSettle();
      expect(hasPhoto, isFalse);
      expect(statusReads, initialReads + 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      previousApproval = null;
      await tester.tap(find.byKey(const Key('main-tab-discovery')));
      await tester.pumpAndSettle();
      expect(find.text('Un visage, pour plus tard'), findsOneWidget);
      expect(find.byType(FeedProfileCard), findsNothing);
      expect(feedReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('withdrawal hides photos immediately and a lost response never replays a grant', () async {
    var mine = true;
    var fail = true;
    final writes = <String>[];
    final session = testSession((r) async {
      if (r.url.path == '/api/matches/me') {
        final item = publicMatchJson();
        return jsonResponse({
          'matches': [
            {
              ...item,
              'my_revealed': mine,
              'photos_revealed': mine,
              'other_user': {
                ...item['other_user'] as Map,
                'photo': 'https://photos.example/synthetic',
              },
            },
          ],
          'next_cursor': null,
        });
      }
      if (r.url.path.endsWith('/reveal')) {
        writes.add(r.method);
        expect(r.body, isEmpty);
        if (fail) throw http.ClientException('synthetic interruption');
        mine = false;
        return jsonResponse({'photos_revealed': false});
      }
      return defaultContinuationResponse(r);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final matches = MatchesController(
      MatchesRepository(session),
      realtime: QuietRealtime(session),
    );
    addTearDown(matches.dispose);
    await matches.activate();
    await matches.openChat(testMatch);
    final c = matches.continuation;
    await c.activate();
    final withdrawing = c.withdrawReveal();
    expect(matches.photosBlocked(testMatch), isTrue);
    await withdrawing;
    expect(c.pendingWithdrawal, isTrue);
    expect(c.canReveal, isFalse);
    expect(matches.photosBlocked(testMatch), isTrue);
    await c.reveal();
    expect(writes, ['DELETE']);
    c.suspend();
    await c.activate();
    fail = false;
    await c.withdrawReveal();
    expect(writes, ['DELETE', 'DELETE']);
    expect(c.pendingWithdrawal, isFalse);
    expect(c.myRevealed, isFalse);
    expect(matches.selected!.photosRevealed, isFalse);
    expect(matches.selected!.partner.photo, isNull);
    expect(matches.messages, isNotEmpty);
  });

  testWidgets(
    'thumbnail downloads only after authorization and discards late bytes after withdrawal',
    (tester) async {
      var allowed = false, requests = 0;
      final response = Completer<http.Response>();
      final readAt = DateTime.now().toUtc();
      Widget avatar() => MaterialApp(
        home: MatchPhotoAvatar(
          url: 'https://photos.example/synthetic',
          readAt: readAt,
          allowed: allowed,
          photoClient: () => MockClient((r) {
            requests++;
            expect(
              r.headers.keys.map((v) => v.toLowerCase()),
              isNot(contains('authorization')),
            );
            expect(r.followRedirects, isFalse);
            return response.future;
          }),
        ),
      );
      await tester.pumpWidget(avatar());
      await tester.pump();
      expect(requests, 0);
      allowed = true;
      await tester.pumpWidget(avatar());
      await tester.pump();
      expect(requests, 1);
      allowed = false;
      await tester.pumpWidget(avatar());
      response.complete(
        http.Response.bytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jLZkAAAAASUVORK5CYII=',
          ),
          200,
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
