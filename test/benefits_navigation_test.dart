import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/presentation/subscription_page.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/continuation/presentation/credits_page.dart';
import 'package:histae_app/features/discovery/presentation/discovery_page.dart';
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/billing_fixture.dart';
import 'support/catalog_fixture.dart';
import 'support/continuation_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  testWidgets(
    'feed shortcuts suspend discovery, open scoped benefits and survive large text without making a payment or reward intent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var mutations = 0;
      final session = testSession((r) async {
        if (r.method == 'POST' &&
            (r.url.path.endsWith('/checkout') ||
                r.url.path.endsWith('/advertising-rewards'))) {
          mutations++;
        }
        if (r.url.path == '/api/users/me/subscription') {
          return jsonResponse(subscriptionJson());
        }
        return defaultContinuationResponse(r);
      });
      await session.establish(testTokens);
      final billing = BillingController(
        BillingRepository(session),
        testBillingConfig,
        MemoryCheckoutVault(),
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
      final discovery = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .controller;
      await tester.tap(find.byKey(const Key('open-premium')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionPage), findsOneWidget);
      expect(discovery.active, isFalse);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(discovery.active, isTrue);
      await tester.tap(find.byKey(const Key('open-videos')));
      await tester.pumpAndSettle();
      expect(find.byType(CreditsPage), findsOneWidget);
      expect(discovery.active, isFalse);
      await tester.scrollUntilVisible(find.text('Regarder une vidéo'), 160);
      final watch = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Regarder une vidéo'),
      );
      expect(watch.onPressed, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('main-tab-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-videos')));
      await tester.pumpAndSettle();
      expect(find.byType(CreditsPage), findsOneWidget);
      expect(mutations, 0);
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.byType(CreditsPage), findsNothing);
      expect(find.byType(DiscoveryPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
