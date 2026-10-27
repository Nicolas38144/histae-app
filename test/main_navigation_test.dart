import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/main_navigation_bar.dart';
import 'package:histae_app/features/discovery/presentation/discovery_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:histae_app/features/profile/presentation/profile_page.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  testWidgets(
    'private tabs retain data without reads on navigation or focus and stay usable at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final reads = <String, int>{};
      final session = testSession((r) async {
        if (r.method == 'GET' && !r.url.path.endsWith('/events')) {
          reads.update(r.url.path, (count) => count + 1, ifAbsent: () => 1);
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      final discovery = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .controller;
      expect(discovery.active, isTrue);
      final initialReads = Map<String, int>.from(reads);
      expect(
        tester
            .widget<MainNavigationBar>(find.byType(MainNavigationBar))
            .selectedIndex,
        MainTab.discovery.index,
      );
      final profilePosition = tester.getCenter(
        find.byKey(const Key('main-tab-profile')),
      );
      final feedPosition = tester.getCenter(
        find.byKey(const Key('main-tab-discovery')),
      );
      final matchesPosition = tester.getCenter(
        find.byKey(const Key('main-tab-matches')),
      );
      expect(profilePosition.dx, lessThan(feedPosition.dx));
      expect(feedPosition.dx, lessThan(matchesPosition.dx));
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      final matches = tester
          .widget<MatchesPage>(find.byType(MatchesPage))
          .controller;
      expect(discovery.active, isTrue);
      expect(matches.active, isTrue);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      expect(matches.active, isTrue);
      expect(find.text('Mon profil'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(matches.active, isTrue);
      expect(discovery.active, isTrue);

      await tester.tap(find.byKey(const Key('main-tab-discovery')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DiscoveryPage>(find.byType(DiscoveryPage)).controller,
        same(discovery),
      );
      expect(discovery.active, isTrue);
      expect(matches.active, isTrue);
      for (final tab in ['discovery', 'matches', 'profile']) {
        final size = tester.getSize(find.byKey(Key('main-tab-$tab')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(reads, initialReads);
      // The same visible profile refresh control still performs a real read.
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actualiser mon profil'));
      await tester.pumpAndSettle();
      expect(reads['/api/users/me'], initialReads['/api/users/me']! + 1);
      expect(tester.takeException(), isNull);
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationBar), findsNothing);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(find.byType(MatchesPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'horizontal swipes preserve tab data and scroll state without feed choices or extra reads',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reads = <String, int>{};
      var choices = 0;
      final session = testSession((r) async {
        if (r.method == 'GET' && !r.url.path.endsWith('/events')) {
          reads.update(r.url.path, (count) => count + 1, ifAbsent: () => 1);
        }
        if (r.url.path == '/api/swipes') choices++;
        if (r.url.path == '/api/feed') {
          return jsonResponse({
            'profiles': [
              candidateJson(
                candidateOne,
                bio: List.filled(
                  8,
                  'Je peux passer des heures à discuter de nos lectures, des '
                  'endroits où nous aimerions retourner et des petits moments '
                  'qui ont marqué notre semaine.',
                ).join('\n\n'),
              ),
              candidateJson(candidateTwo),
            ],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      await tester.pumpWidget(HistaeApp(sessionController: session));
      await tester.pumpAndSettle();
      final initialReads = Map<String, int>.from(reads);
      final discovery = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .controller;
      final initialProfile = discovery.current?.id;
      final profile = tester
          .widget<ProfilePage>(find.byType(ProfilePage, skipOffstage: false))
          .controller;
      final matches = tester
          .widget<MatchesPage>(find.byType(MatchesPage, skipOffstage: false))
          .controller;
      expect(profile.profile, isNotNull);
      expect(matches.active, isTrue);
      final pages = find.byKey(const Key('main-tab-pages'));

      void selected(MainTab tab) => expect(
        tester
            .widget<MainNavigationBar>(find.byType(MainNavigationBar))
            .selectedIndex,
        tab.index,
      );

      Future<void> swipe(double dx) async {
        await tester.timedDrag(
          pages,
          Offset(dx, 0),
          const Duration(milliseconds: 350),
        );
        await tester.pumpAndSettle();
      }

      // An initially sideways drift must yield to vertical profile reading.
      final feedScroll = find.descendant(
        of: find.byKey(const Key('feed-profile-scroll')),
        matching: find.byType(Scrollable),
      );
      final reading = await tester.startGesture(tester.getCenter(pages));
      await reading.moveBy(const Offset(-28, -12));
      await tester.pump();
      await reading.moveBy(const Offset(-10, -180));
      await tester.pump();
      await reading.moveBy(const Offset(6, -120));
      await tester.pump();
      await reading.up();
      await tester.pumpAndSettle();
      selected(MainTab.discovery);
      expect(
        tester.state<ScrollableState>(feedScroll).position.pixels,
        greaterThan(0),
      );
      expect(discovery.current?.id, initialProfile);
      expect(choices, 0);

      final shortDrag = await tester.startGesture(tester.getCenter(pages));
      await shortDrag.moveBy(const Offset(30, 0));
      await tester.pump();
      await shortDrag.up();
      await tester.pumpAndSettle();
      selected(MainTab.discovery);

      await swipe(-300);
      selected(MainTab.matches);
      expect(find.byType(MatchesPage), findsOneWidget);
      await swipe(-300);
      selected(MainTab.matches);
      await swipe(300);
      selected(MainTab.discovery);
      expect(discovery.current?.id, initialProfile);
      await swipe(300);
      selected(MainTab.profile);
      expect(
        tester.widget<ProfilePage>(find.byType(ProfilePage)).controller,
        same(profile),
      );
      await swipe(300);
      selected(MainTab.profile);
      final profileScroll = find.descendant(
        of: find.byType(ProfilePage),
        matching: find.byType(Scrollable),
      );
      await tester.drag(profileScroll, const Offset(0, -280));
      await tester.pumpAndSettle();
      final scrollPosition = tester
          .state<ScrollableState>(profileScroll)
          .position
          .pixels;
      expect(scrollPosition, greaterThan(0));
      selected(MainTab.profile);
      await swipe(-300);
      selected(MainTab.discovery);
      await swipe(300);
      selected(MainTab.profile);
      expect(
        tester.state<ScrollableState>(profileScroll).position.pixels,
        closeTo(scrollPosition, 0.1),
      );
      // Tapping across both pages must leave the bar and pager in agreement.
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      selected(MainTab.matches);
      expect(
        tester.widget<MatchesPage>(find.byType(MatchesPage)).controller,
        same(matches),
      );
      expect(discovery.current?.id, initialProfile);
      expect(choices, 0);
      expect(reads, initialReads);
      expect(tester.takeException(), isNull);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pump();
      selected(MainTab.profile);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(reads, initialReads);

      // Session teardown must also remove both pages of an unfinished swipe.
      final gesture = await tester.startGesture(tester.getCenter(pages));
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();
      await session.logout();
      await tester.pumpAndSettle();
      await gesture.up();
      expect(find.byType(MainNavigationBar), findsNothing);
      expect(find.byType(DiscoveryPage, skipOffstage: false), findsNothing);
      expect(find.byType(ProfilePage, skipOffstage: false), findsNothing);
      expect(find.byType(MatchesPage, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mutual encounter opens an authorized chat in the matches tab', (
    tester,
  ) async {
    var matched = false;
    final session = testSession((r) async {
      if (r.url.path == '/api/swipes') {
        matched = true;
        return jsonResponse({
          'decision': 'like',
          'matched': true,
          'match': {...matchJson(candidateOne), 'id': testMatch},
        }, 201);
      }
      if (!matched && r.url.path == '/api/matches/me') {
        return jsonResponse({'matches': <Object?>[], 'next_cursor': null});
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
    await tester.drag(find.byType(ChatPage), const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    final chatContext = tester.element(find.byType(ChatPage));
    expect(ModalRoute.of(chatContext)?.isFirst, isFalse);
    expect(discovery.active, isTrue);
    final chat = tester.widget<ChatPage>(find.byType(ChatPage)).controller;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(chat.active, isTrue);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(chat.active, isTrue);
    expect(find.byType(ChatPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MatchesPage), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(
      tester
          .widget<MainNavigationBar>(find.byType(MainNavigationBar))
          .selectedIndex,
      MainTab.matches.index,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
