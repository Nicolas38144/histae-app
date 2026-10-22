import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/presentation/subscription_page.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/matches/presentation/matches_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/billing_fixture.dart';
import 'support/catalog_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';

Future<void> mountBenefits(
  WidgetTester tester, {
  required bool Function() premium,
  Map<String, dynamic> Function()? quota,
  bool Function()? quotaUnavailable,
  Future<http.Response> Function()? readQuota,
  void Function(http.Request)? inspect,
}) async {
  final session = testSession((r) async {
    inspect?.call(r);
    if (r.url.path == '/api/users/me/subscription') {
      return jsonResponse(subscriptionJson(access: premium()));
    }
    if (r.url.path == '/api/users/me/continuation-quota') {
      if (readQuota != null) return readQuota();
      return quotaUnavailable?.call() == true
          ? apiError(503, 'service_unavailable')
          : jsonResponse(quota?.call() ?? quotaJson(premium: premium()));
    }
    return defaultContinuationResponse(r);
  });
  await session.establish(testTokens);
  final billing = BillingController(
    BillingRepository(session),
    testBillingConfig,
    FakeBillingGateway(),
    realtime: QuietRealtime(session),
  );
  final catalog = CatalogRepository(
    ApiClient(
      origin: Uri.parse('https://api.example'),
      client: MockClient((_) async => jsonResponse(catalogJson())),
    ),
  );
  await tester.pumpWidget(
    HistaeApp(
      sessionController: session,
      billingController: billing,
      catalogRepository: catalog,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> revealSubscription(WidgetTester tester) async {
  final entry = find.byKey(const Key('profile-subscription'));
  await tester.scrollUntilVisible(
    entry,
    240,
    maxScrolls: 80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Profile keeps its confirmed subscription label while refreshing and applies new results',
    (tester) async {
      Completer<http.Response>? pending;
      await mountBenefits(
        tester,
        premium: () => false,
        readQuota: () =>
            pending?.future ?? Future.value(jsonResponse(quotaJson())),
      );
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await revealSubscription(tester);
      expect(find.text(testUser), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);

      Future<void> refreshWith(
        http.Response response, {
        required String during,
        required String after,
      }) async {
        pending = Completer<http.Response>();
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(during), findsOneWidget);
        expect(
          find.text(during == 'Premium' ? 'Mon abonnement' : 'Premium'),
          findsNothing,
        );
        pending!.complete(response);
        await refresh;
        await tester.pumpAndSettle();
        expect(find.text(after), findsOneWidget);
      }

      await refreshWith(
        jsonResponse(quotaJson(premium: true)),
        during: 'Premium',
        after: 'Mon abonnement',
      );
      await refreshWith(
        jsonResponse(quotaJson()),
        during: 'Mon abonnement',
        after: 'Premium',
      );
      await refreshWith(
        apiError(503, 'service_unavailable'),
        during: 'Premium',
        after: 'Mon abonnement',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Free gets a full feed, a profile upgrade and exact available balances with videos in matches at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var mutations = 0, quotaReads = 0, free = 2, ads = 1;
      await mountBenefits(
        tester,
        premium: () => false,
        quota: () => {
          ...quotaJson(remaining: 0),
          'free_remaining': free,
          'advertising_remaining': ads,
          'advertising_balance': 3,
          'reserved': 2,
        },
        inspect: (r) {
          if (r.url.path.endsWith('/continuation-quota')) quotaReads++;
          if (r.method == 'POST' &&
              (r.url.path.endsWith('/checkout') ||
                  r.url.path.endsWith('/advertising-rewards'))) {
            mutations++;
          }
        },
      );
      expect(quotaReads, 1);
      expect(find.byKey(const Key('profile-subscription')), findsNothing);
      expect(find.byKey(const Key('open-videos')), findsNothing);
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await revealSubscription(tester);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.byKey(const Key('open-videos')), findsNothing);
      await tester.tap(find.byKey(const Key('profile-subscription')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionPage), findsOneWidget);
      expect(find.text(testUser), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('free-credits-remaining')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('free-credits-remaining')))
            .data,
        '2',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('ad-credits-remaining'))).data,
        '1',
      );
      expect(find.byKey(const Key('open-videos')), findsOneWidget);
      await tester.ensureVisible(find.text('Voir mes crédits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir mes crédits'));
      await tester.pumpAndSettle();
      expect(find.byType(CreditsPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Regarder une vid\u00e9o'),
        160,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Regarder une vid\u00e9o'),
            )
            .onPressed,
        isNull,
      );
      free = 0;
      ads = 2;
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // Returning alone keeps the balance; only a manual refresh reads it.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('free-credits-remaining')))
            .data,
        '2',
      );
      await tester.tap(find.byTooltip('Actualiser les rencontres'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('free-credits-remaining')))
            .data,
        '0',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('ad-credits-remaining'))).data,
        '2',
      );
      expect(mutations, 0);
      final session = tester
          .widget<MatchesPage>(find.byType(MatchesPage))
          .controller
          .session;
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(MatchesPage), findsNothing);
      expect(find.byType(CreditsPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Premium hides videos and a refreshed plan or unavailable quota never invents balances',
    (tester) async {
      var premium = true, unavailable = false;
      await mountBenefits(
        tester,
        premium: () => premium,
        quotaUnavailable: () => unavailable,
      );
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await revealSubscription(tester);
      expect(find.text('Mon abonnement'), findsOneWidget);
      expect(find.text('Premium'), findsNothing);
      expect(find.byKey(const Key('open-videos')), findsNothing);
      await tester.tap(find.byKey(const Key('profile-subscription')));
      await tester.pumpAndSettle();
      premium = false;
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Mon abonnement'), findsOneWidget);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Premium'), findsOneWidget);
      premium = true;
      await tester.tap(find.byKey(const Key('main-tab-matches')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actualiser les rencontres'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vos continuations ne n\u00e9cessitent aucun cr\u00e9dit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('open-videos')), findsNothing);
      expect(find.byKey(const Key('free-credits-remaining')), findsNothing);
      await tester.tap(find.byTooltip('Vos crédits'));
      await tester.pumpAndSettle();
      expect(find.text('Regarder une vidéo'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      premium = false;
      unavailable = true;
      await tester.tap(find.byTooltip('Actualiser les rencontres'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('free-credits-remaining')), findsNothing);
      expect(find.byKey(const Key('open-videos')), findsNothing);
      expect(
        find.text(
          'Votre solde ne peut pas \u00eatre v\u00e9rifi\u00e9 pour le moment.',
        ),
        findsOneWidget,
      );
      unavailable = false;
      await tester.tap(find.text('Actualiser les cr\u00e9dits'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-videos')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('free-credits-remaining')))
            .data,
        '1',
      );
      premium = true;
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await revealSubscription(tester);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Mon abonnement'), findsOneWidget);
      expect(find.text('Premium'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
