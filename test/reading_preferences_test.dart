import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';
import 'package:histae_app/features/reading/application/reading_controller.dart';
import 'package:histae_app/features/reading/domain/reading_preferences.dart';

import 'support/auth_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/reading_fixture.dart';

void main() {
  test('late restore cannot overwrite choices; reopening restores the final choice and reset', () async {
    final store = TestReadingStore()
      ..pendingRead = Completer<ReadingPreferences>();
    final controller = ReadingController(store: store);
    addTearDown(controller.dispose);
    final loading = controller.load();
    final size = controller.setTextSize(ReadingTextSize.large);
    final spacing = controller.setLineSpacing(ReadingLineSpacing.relaxed);
    store.pendingRead!.complete(const ReadingPreferences());
    await Future.wait([loading, size, spacing]);
    expect(controller.preferences.fontSize, 22);
    expect(controller.preferences.lineHeight, 1.8);
    store.pendingRead = null;
    final reopened = ReadingController(store: store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.preferences, controller.preferences);
    await reopened.reset();
    expect(store.value, const ReadingPreferences());
  });

  test('failed saves retain the visible choice and allow retrying the same selection', () async {
    final store = TestReadingStore()..failWrite = true;
    final controller = ReadingController(store: store);
    addTearDown(controller.dispose);
    await controller.setTextSize(ReadingTextSize.comfortable);
    expect(controller.preferences.fontSize, 20);
    expect(controller.saveFailed, isTrue);
    store.failWrite = false;
    await controller.setTextSize(ReadingTextSize.comfortable);
    expect(controller.saveFailed, isFalse);
    expect(store.value, controller.preferences);
  });

  testWidgets(
    'reading choices update the same feed without network reads or consuming its reading delay',
    (tester) async {
      final requests = <String>[];
      final session = testSession((request) async {
        requests.add('${request.method} ${request.url.path}');
        return defaultDiscoveryResponse(request);
      });
      await session.establish(testTokens);
      final store = TestReadingStore();
      final reading = ReadingController(store: store);
      await tester.pumpWidget(
        HistaeApp(sessionController: session, readingController: reading),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final before = List<String>.of(requests);
      await tester.tap(find.byKey(const Key('feed-reading-settings')));
      await tester.pumpAndSettle();
      final delay = tester
          .widget<FractionallySizedBox>(
            find.byKey(const Key('feed-reading-fill')),
          )
          .widthFactor;
      expect(delay, lessThan(1));
      expect(
        tester.widget<FeedProfileCard>(find.byType(FeedProfileCard)).active,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('reading-size-large')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('reading-spacing-relaxed')),
      );
      await tester.tap(find.byKey(const Key('reading-spacing-relaxed')));
      await tester.pump(const Duration(seconds: 10));
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const Key('feed-reading-fill')),
            )
            .widthFactor,
        delay,
      );
      await tester.tap(find.byKey(const Key('reading-close')));
      await tester.pump();
      final bio = tester.widget<Text>(find.byKey(const Key('feed-biography')));
      expect(bio.style!.fontSize, 22);
      expect(bio.style!.height, 1.8);
      expect(find.text('Léa, 27'), findsOneWidget);
      expect(requests, before);
      expect(store.value, reading.preferences);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
