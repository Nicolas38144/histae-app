import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/config/support_config.dart';
import 'package:histae_app/features/continuation/application/continuation_controller.dart';
import 'package:histae_app/features/continuation/domain/weekly_renewal.dart';
import 'package:histae_app/features/discovery/application/discovery_controller.dart';
import 'package:histae_app/features/discovery/data/discovery_repository.dart';
import 'package:histae_app/features/discovery/presentation/discovery_page.dart';
import 'package:histae_app/features/discovery/presentation/feed_profile_card.dart';
import 'package:histae_app/features/help/application/help_controller.dart';
import 'package:histae_app/features/help/data/feed_guide_store.dart';
import 'package:histae_app/features/help/presentation/help_page.dart';
import 'package:histae_app/features/help/presentation/help_scope.dart';
import 'package:histae_app/features/matches/application/matches_controller.dart';
import 'package:histae_app/features/matches/data/matches_repository.dart';
import 'package:histae_app/features/matches/presentation/match_preview_card.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:histae_app/features/profile/application/profile_controller.dart';
import 'package:histae_app/features/profile/data/profile_repository.dart';

import 'support/auth_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/discovery_fixture.dart';
import 'support/matches_fixture.dart';

class _GuideStore implements FeedGuideStore {
  bool seen = false;
  @override
  Future<bool> read() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

void main() {
  test('support standards only use an optional public HTTPS origin', () {
    final support = SupportConfig.fromValues({
      'SUPPORT_EMAIL': 'support@example.test',
      'SUPPORT_WEBSITE_URL': 'https://example.test',
    });
    expect(support.websiteOrigin, Uri.parse('https://example.test'));
    expect(SupportConfig.fromValues({}).websiteOrigin, isNull);
    for (final invalid in [
      'http://example.test',
      'https://user@example.test',
      'https://example.test/private',
      'https://example.test?token=secret',
      'https://example.test/#private',
    ]) {
      expect(
        () => SupportConfig.fromValues({'SUPPORT_WEBSITE_URL': invalid}),
        throwsFormatException,
      );
    }
  });

  testWidgets(
    'Monday invalidates last week quota without a navigation request',
    (tester) async {
      var now = DateTime.utc(2026, 11, 1, 23, 59, 59);
      var reads = 0;
      final session = testSession((r) async {
        if (r.url.path.endsWith('/continuation-quota')) {
          reads++;
          return jsonResponse(quotaJson(remaining: reads == 1 ? 0 : 2));
        }
        return defaultContinuationResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final access = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      addTearDown(access.dispose);
      final credits = ContinuationController(access, now: () => now);
      try {
        await credits.activate();
        expect(credits.quotaReadAt, isNotNull);
        now = DateTime.utc(2026, 11, 2);
        await tester.pump(const Duration(seconds: 1));
        expect(credits.quotaReadAt, isNull);
        expect(credits.quota!.remaining, 0);
        await credits.activate();
        expect(reads, 1);
        await credits.refreshQuota();
        expect(reads, 2);
        expect(credits.quotaReadAt, isNotNull);
        expect(credits.quota!.remaining, 2);
      } finally {
        credits.dispose();
      }
    },
  );

  test('renewal stays on Monday midnight UTC across local offsets and year changes', () {
    expect(
      nextWeeklyRenewal(DateTime.parse('2026-11-01T23:59:59Z')),
      DateTime.parse('2026-11-02T00:00:00Z'),
    );
    expect(
      nextWeeklyRenewal(DateTime.parse('2026-11-02T01:00:00+01:00')),
      DateTime.parse('2026-11-09T00:00:00Z'),
    );
    expect(
      nextWeeklyRenewal(DateTime.parse('2026-12-31T23:00:00-03:00')),
      DateTime.parse('2027-01-04T00:00:00Z'),
    );
  });

  testWidgets(
    'name search ignores accents and clears without a network request',
    (tester) async {
      var reads = 0;
      final session = testSession((r) async {
        reads++;
        if (r.url.path == '/api/matches/me') {
          final second = publicMatchJson(id: secondMatch);
          (second['other_user'] as Map<String, dynamic>)['firstname'] =
              'Camille';
          return jsonResponse({
            'matches': [publicMatchJson(), second],
            'next_cursor': null,
          });
        }
        return defaultContinuationResponse(r);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final matches = MatchesController(
        MatchesRepository(session),
        realtime: QuietRealtime(session),
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: histaeTheme(Brightness.dark),
            home: MatchesPage(controller: matches),
          ),
        );
        await tester.pumpAndSettle();
        final before = reads;
        expect(find.text('Archivage et suppression'), findsNothing);
        await tester.enterText(find.byKey(const Key('matches-search')), 'lea');
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsOneWidget);
        expect(
          tester
              .widget<MatchPreviewCard>(find.byType(MatchPreviewCard))
              .match
              .partner
              .firstname,
          'Léa',
        );
        await tester.enterText(
          find.byKey(const Key('matches-search')),
          'le\u0301a',
        );
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('matches-search')),
          'Introuvable',
        );
        await tester.pumpAndSettle();
        expect(find.byType(MatchPreviewCard), findsNothing);
        expect(
          find.textContaining('Aucun match ne correspond'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Effacer la recherche'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('open-credits')), findsOneWidget);
        expect(reads, before);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        matches.dispose();
      }
    },
  );

  testWidgets(
    'the first-feed guide pauses reading and remains available from help',
    (tester) async {
      final session = testSession((r) async => defaultDiscoveryResponse(r));
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final discovery = DiscoveryController(
        DiscoveryRepository(session),
        TestLocationSource(),
      );
      addTearDown(discovery.dispose);
      final profile = ProfileController(ProfileRepository(session));
      addTearDown(profile.dispose);
      final store = _GuideStore();
      final help = HelpController(
        SupportConfig.fromValues({
          'SUPPORT_EMAIL': 'support@example.test',
          'SUPPORT_WEBSITE_URL': 'https://example.test',
        }),
        store: store,
      );
      addTearDown(help.dispose);
      await help.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          builder: (_, child) => HelpScope(controller: help, child: child!),
          home: DiscoveryPage(controller: discovery, profile: profile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-mini-guide')), findsOneWidget);
      expect(
        tester.widget<FeedProfileCard>(find.byType(FeedProfileCard)).active,
        isFalse,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('feed-guide-done')),
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('feed-mini-guide')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feed-guide-done')));
      await tester.pumpAndSettle();
      expect(store.seen, isTrue);
      expect(find.byKey(const Key('feed-mini-guide')), findsNothing);
      expect(
        tester.widget<FeedProfileCard>(find.byType(FeedProfileCard)).active,
        isTrue,
      );
      final context = tester.element(find.byType(DiscoveryPage));
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const HelpPage()));
      await tester.pumpAndSettle();
      final helpScroller = find
          .descendant(
            of: find.byType(HelpPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('help-child-safety')),
        200,
        scrollable: helpScroller,
      );
      expect(
        find.byKey(const Key('help-child-safety-standards')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('help-child-safety')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('help-child-safety-standards')),
        200,
        scrollable: helpScroller,
      );
      expect(
        find.textContaining('Consultez nos normes de sécurité des enfants.'),
        findsOneWidget,
      );
      final linkedAnswer = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('help-child-safety-standards')),
          matching: find.byType(Text),
        ),
      );
      final bodyStyle = histaeTheme(Brightness.dark).textTheme.bodyMedium!;
      final answerSpan = linkedAnswer.textSpan! as TextSpan;
      expect(linkedAnswer.style?.fontSize, bodyStyle.fontSize);
      expect(answerSpan.children!.whereType<WidgetSpan>(), isEmpty);
      final linkSpan = answerSpan.children!.last as TextSpan;
      expect(linkSpan.style?.fontSize, isNull);
      expect(
        linkSpan.style?.decorationColor,
        histaeTheme(Brightness.dark).colorScheme.primary,
      );
      expect(linkSpan.recognizer, isNotNull);
      await tester.scrollUntilVisible(
        find.text('support@example.test'),
        200,
        scrollable: helpScroller,
      );
      await tester.pumpAndSettle();
      expect(find.text('support@example.test'), findsOneWidget);
      expect(find.text('Contacter le support'), findsOneWidget);
      expect(find.text('E-mail à venir.'), findsNothing);
      tester.state<ScrollableState>(helpScroller).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('help-feed-guide')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-mini-guide')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
