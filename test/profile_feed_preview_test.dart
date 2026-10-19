import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_content.dart';
import 'package:histae_app/features/profile/presentation/profile_feed_preview_page.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/profile_fixture.dart';

void main() {
  testWidgets(
    'owner preview shares the feed layout, exposes approved text only and cannot swipe',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <String>[];
      var unavailable = false;
      final session = testSession((r) async {
        if (r.method != 'GET' && !r.url.path.startsWith('/api/auth/')) {
          writes.add(r.url.path);
        }
        if (r.url.path == '/api/users/me') {
          return jsonResponse({
            ...ownerJson(
              bio: 'Ma bio encore en validation.',
              photo: 'https://storage.example/private-photo',
            ),
            'moderation': {
              'bio': {'status': 'pending', 'reasons': <Object?>[]},
              'photo': {'status': 'approved', 'reasons': <Object?>[]},
            },
          });
        }
        if (r.url.path == '/api/users/me/profile-answers') {
          if (unavailable) return apiError(503, 'service_unavailable');
          return jsonResponse({
            'answers': [
              {
                ...answerJson(questionTwo, 'Seconde réponse publique.', 1),
                'moderation_status': 'approved',
              },
              {
                ...answerJson(questionOne, 'Première réponse publique.', 0),
                'moderation_status': 'approved',
              },
              answerJson(
                '66666666-6666-4666-8666-666666666666',
                'Réponse encore privée.',
                2,
              ),
            ],
          });
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-feed-preview')));
      await tester.pumpAndSettle();
      final page = find.byType(ProfileFeedPreviewPage);
      expect(page, findsOneWidget);
      final content = tester.widget<FeedProfileContent>(
        find.descendant(of: page, matching: find.byType(FeedProfileContent)),
      );
      expect(content.firstname, 'Camille');
      expect(content.bio, isNull);
      expect(content.traits, ['Curieux']);
      expect(content.answers.map((a) => a.answer), [
        'Première réponse publique.',
        'Seconde réponse publique.',
      ]);
      expect(content.distanceLabel, 'Distance selon la personne');
      expect(
        find.descendant(of: page, matching: find.byType(Image)),
        findsNothing,
      );
      expect(find.text('Ma bio encore en validation.'), findsNothing);
      expect(find.text('Réponse encore privée.'), findsNothing);
      expect(find.text('J’aime'), findsNothing);
      expect(find.text('Passer'), findsNothing);
      await tester.tap(find.textContaining('Camille,'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.textContaining('Camille,'));
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);

      unavailable = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await refresh;
      await tester.pumpAndSettle();
      expect(find.byType(FeedProfileContent), findsNothing);
      expect(
        find.textContaining('Votre aperçu ne peut pas être affiché.'),
        findsOneWidget,
      );
      await session.logout();
      await tester.pumpAndSettle();
      expect(page, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
