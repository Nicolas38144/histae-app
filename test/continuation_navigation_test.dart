import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/app_strings.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/features/continuation/presentation/continuation_page.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/matches/presentation/chat_page.dart';

import 'support/continuation_scenario.dart';
import 'support/matches_fixture.dart';

Future<void> mountChat(
  WidgetTester tester,
  ContinuationScenario scenario,
) async {
  await scenario.start();
  await tester.pumpWidget(
    MaterialApp(
      theme: histaeTheme(Brightness.dark),
      locale: const Locale('fr'),
      localizationsDelegates: AppMessages.localizationsDelegates,
      supportedLocales: AppMessages.supportedLocales,
      home: ChatPage(controller: scenario.matches, matchId: testMatch),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final premium in [false, true]) {
    testWidgets(
      'chat confirms the ${premium ? 'Premium' : 'credit'} cost and opens automatically after both agreements',
      (tester) async {
        final scenario = ContinuationScenario(premium: premium, remaining: 1);
        addTearDown(scenario.dispose);
        await mountChat(tester, scenario);
        final action = find.byKey(const Key('continue-conversation'));
        expect(find.text('Envoyer'), findsNothing);
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(find.byKey(const Key('chat-refresh')), findsNothing);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(scenario.costs, isEmpty);
        await tester.tap(
          find
              .text(
                premium
                    ? const AppStrings()
                          .messages
                          .continuationPageContinueWithoutCredits
                    : const AppStrings()
                          .messages
                          .continuationPageAcceptUpTo1Credit,
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(scenario.costs, [premium ? 0 : 1]);
        expect(find.text('En attente de sa réponse'), findsOneWidget);
        scenario.partnerContinues();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat-composer')), findsOneWidget);
        expect(find.text('Envoyer'), findsOneWidget);
        expect(action, findsNothing);

        await tester.tap(find.byKey(const Key('chat-options')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chat-decisions')));
        await tester.pumpAndSettle();
        expect(find.byType(ContinuationPage), findsOneWidget);
        expect(find.text('Continuer cette conversation'), findsNothing);
        expect(find.text('Voir mes crédits'), findsNothing);
        expect(find.byIcon(Icons.refresh), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        scenario.dispose();
      },
    );
  }

  testWidgets('without available credits chat opens Credits without spending', (
    tester,
  ) async {
    final scenario = ContinuationScenario(remaining: 0, advertising: 0);
    addTearDown(scenario.dispose);
    await mountChat(tester, scenario);
    await tester.tap(find.byKey(const Key('continue-conversation')));
    await tester.pumpAndSettle();
    expect(find.byType(CreditsPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(scenario.costs, isEmpty);
    expect(find.byType(RefreshIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.dispose();
  });

  testWidgets(
    'an uncertain continuation resumes its original cost despite the empty balance',
    (tester) async {
      final scenario = ContinuationScenario(loseFirstResponse: true);
      addTearDown(scenario.dispose);
      await mountChat(tester, scenario);
      final action = find.byKey(const Key('continue-conversation'));
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          const AppStrings().messages.continuationPageAcceptUpTo1Credit,
        ),
      );
      await tester.pumpAndSettle();
      expect(scenario.matches.continuation.pendingCost, 1);
      expect(scenario.matches.continuation.quota!.remaining, 0);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(scenario.costs, [1, 1]);
      expect(find.byType(CreditsPage), findsNothing);
      expect(scenario.matches.continuation.pendingCost, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      scenario.dispose();
    },
  );
}
