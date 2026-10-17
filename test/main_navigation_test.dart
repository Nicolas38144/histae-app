import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/main_navigation_bar.dart';
import 'package:histae_app/features/discovery/presentation/discovery_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';

import 'support/auth_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  testWidgets(
    'private tabs share one root, suspend hidden resources and stay usable at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session = testSession((r) async => defaultMatchesResponse(r));
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      final discovery = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .controller;
      expect(discovery.active, isTrue);
      expect(
        tester
            .widget<MainNavigationBar>(find.byType(MainNavigationBar))
            .selectedIndex,
        0,
      );
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      final matches = tester
          .widget<MatchesPage>(find.byType(MatchesPage))
          .controller;
      expect(discovery.active, isFalse);
      expect(matches.active, isTrue);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      expect(matches.active, isFalse);
      expect(find.text('Votre espace Histae'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(matches.active, isFalse);
      expect(discovery.active, isFalse);

      await tester.tap(find.byKey(const Key('main-tab-discovery')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DiscoveryPage>(find.byType(DiscoveryPage)).controller,
        same(discovery),
      );
      expect(discovery.active, isTrue);
      expect(matches.active, isFalse);
      for (final tab in ['discovery', 'matches', 'profile']) {
        final size = tester.getSize(find.byKey(Key('main-tab-$tab')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationBar), findsNothing);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(MatchesPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mutual encounter opens an authorized chat in the matches tab', (
    tester,
  ) async {
    final session = testSession((r) async {
      if (r.url.path == '/api/swipes') {
        return jsonResponse({
          'decision': 'like',
          'matched': true,
          'match': {...matchJson(candidateOne), 'id': testMatch},
        }, 201);
      }
      return defaultMatchesResponse(r);
    });
    await session.establish(testTokens);
    await tester.pumpWidget(HistaeApp(sessionController: session));
    await tester.pumpAndSettle();
    final discovery = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .controller;
    await tester.tap(find.text('Léa, 27'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Léa, 27'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ouvrir la conversation'), 180);
    await tester.tap(find.text('Ouvrir la conversation'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(
      tester.widget<ChatPage>(find.byType(ChatPage)).controller.accessible,
      isTrue,
    );
    expect(find.byTooltip('Actualiser la conversation'), findsOneWidget);
    final chatContext = tester.element(find.byType(ChatPage));
    expect(ModalRoute.of(chatContext)?.isFirst, isFalse);
    expect(discovery.active, isFalse);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MatchesPage), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
