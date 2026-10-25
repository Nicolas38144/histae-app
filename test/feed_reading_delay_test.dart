import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/discovery/data/discovery_models.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_transition.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/discovery_fixture.dart';

FeedProfile _profile(String id) => FeedProfile.fromJson({
  ...candidateJson(id, bio: null),
  'traits': <Object?>[],
  'profile_answers': <Object?>[],
});

void main() {
  testWidgets('all choices wait three seconds and each profile starts locked', (
    tester,
  ) async {
    var likes = 0, passes = 0;
    Future<void> show(String id) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedProfileCard(
            profile: _profile(id),
            enabled: true,
            onLike: () => likes++,
            onPass: () => passes++,
          ),
        ),
      ),
    );
    bool canPass() =>
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Passer'),
            )
            .onPressed !=
        null;

    await show(candidateOne);
    expect(canPass(), isFalse);
    expect(
      tester
          .widget<FractionallySizedBox>(
            find.byKey(const Key('feed-reading-fill')),
          )
          .widthFactor,
      0,
    );
    await tester.tap(find.text('Léa, 27'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Léa, 27'));
    await tester.drag(
      find.byKey(const Key('feed-profile-scroll')),
      const Offset(0, -240),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(likes, 0);
    expect(passes, 0);
    expect(canPass(), isFalse);

    await tester.pump(const Duration(seconds: 3));
    expect(canPass(), isTrue);
    expect(
      tester
          .widget<FractionallySizedBox>(
            find.byKey(const Key('feed-reading-fill')),
          )
          .widthFactor,
      1,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Passer'));
    await tester.pumpAndSettle();
    expect(passes, 1);

    // Same widget state, different candidate: no inherited unlocked state.
    await show(candidateTwo);
    await tester.pump();
    expect(canPass(), isFalse);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(canPass(), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(canPass(), isTrue);
    await tester.tap(find.text('Léa, 27'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Léa, 27'));
    await tester.pumpAndSettle();
    expect(likes, 1);
  });

  testWidgets('hidden feed and background time do not consume the delay', (
    tester,
  ) async {
    Future<void> show({required bool active}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedProfileCard(
            profile: _profile(candidateOne),
            enabled: true,
            active: active,
            onLike: () {},
            onPass: () {},
          ),
        ),
      ),
    );
    bool canPass() =>
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Passer'),
            )
            .onPressed !=
        null;

    await show(active: false);
    await tester.pump(const Duration(seconds: 10));
    expect(canPass(), isFalse);
    await show(active: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 10));
    expect(canPass(), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(canPass(), isTrue);
  });

  testWidgets(
    'double tap likes once and immediately displays the next profile',
    (tester) async {
      var likes = 0;
      final session = testSession((request) async {
        if (request.url.path == '/api/swipes') {
          likes++;
          return jsonResponse({'decision': 'like', 'matched': false}, 201);
        }
        return defaultContinuationResponse(request);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      expect(find.text('Léa, 27'), findsOneWidget);
      final scroll = find.byKey(const Key('feed-profile-scroll'));
      await tester.drag(scroll, const Offset(0, -1400));
      await tester.pumpAndSettle();
      final previousOffset = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;
      final point = tester.getCenter(scroll);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(point);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final slides = tester.widgetList<SlideTransition>(
        find.descendant(
          of: find.byType(FeedProfileTransition),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slides.any((slide) => slide.position.value.dy < 0), isTrue);
      expect(slides.any((slide) => slide.position.value.dy > 0), isTrue);
      expect(find.byKey(const Key('feed-choice-like')), findsOneWidget);
      final outgoingPosition = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey(candidateOne)),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(outgoingPosition.pixels, previousOffset);
      await tester.pumpAndSettle();
      expect(likes, 1);
      expect(find.byKey(const Key('feed-choice-like')), findsNothing);
      expect(find.text('Camille, 27'), findsOneWidget);
      expect(find.text('Léa, 27'), findsNothing);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
