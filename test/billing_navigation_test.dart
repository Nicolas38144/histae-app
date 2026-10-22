import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/app.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/presentation/subscription_page.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/notifications/application/push_controller.dart';
import 'package:histae_app/features/notifications/data/device_repository.dart';
import 'package:histae_app/features/notifications/data/notification_models.dart';
import 'package:histae_app/features/notifications/data/push_vault.dart';
import 'package:http/testing.dart';

import 'support/auth_fixture.dart';
import 'support/billing_fixture.dart';
import 'support/catalog_fixture.dart';
import 'support/matches_fixture.dart';
import 'support/notifications_fixture.dart';

void main() {
  testWidgets(
    'native purchase requires explicit confirmation and uses the store price',
    (tester) async {
      var posts = 0;
      final session = testSession((r) async {
        if (r.url.path.endsWith('/purchase-intents')) {
          posts++;
          return jsonResponse(storeIntentJson());
        }
        if (r.url.path == '/api/billing/store-products') {
          return jsonResponse(storeProductsJson());
        }
        if (r.url.path == '/api/users/me/subscription') {
          return jsonResponse(subscriptionJson());
        }
        return defaultAuthResponse(r, complete: true);
      });
      addTearDown(session.dispose);
      await session.establish(testTokens);
      final gateway = FakeBillingGateway();
      addTearDown(gateway.stream.close);
      final c = BillingController(
        BillingRepository(session),
        testBillingConfig,
        gateway,
        realtime: QuietRealtime(session),
      );
      addTearDown(c.dispose);
      final plans = catalogJson();
      (plans['plans'] as List).firstWhere(
        (p) => p['code'] == 'premium',
      )['annual_price_cents'] = 12345;
      final annualOffer = (plans['offers'] as List).firstWhere(
        (p) => p['billing_period'] == 'annual',
      );
      annualOffer['price_cents'] = 12345;
      final annualChoice = 'Choisir ${annualOffer['display_name']}';
      final catalog = CatalogRepository(
        ApiClient(
          origin: Uri.parse('https://api.example'),
          client: MockClient((_) async => jsonResponse(plans)),
        ),
      );
      addTearDown(catalog.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: histaeTheme(Brightness.dark),
          home: SubscriptionPage(controller: c, catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(annualChoice), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text(annualChoice));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'48,00\sEUR')), findsWidgets);
      expect(posts, 0);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.tap(find.text(annualChoice));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer dans le store'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(gateway.bought, hasLength(1));
      expect(c.subscription!.accessGranted, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'billing notification opens subscription with authenticated re-read and ignores provider access claims and URLs',
    (tester) async {
      var reads = 0;
      final session = testSession((r) async {
        if (r.url.path == '/api/users/me/subscription') {
          reads++;
          return jsonResponse(subscriptionJson());
        }
        if (r.url.path == '/api/billing/store-products') {
          return jsonResponse(storeProductsJson());
        }
        return defaultNotificationsResponse(r);
      });
      await session.establish(testTokens);
      final vault = MemoryPushVault()
        ..record = const PushRecord(
          'https://api.example',
          testUser,
          deviceId: deviceOne,
        );
      final gateway = FakePushGateway()
        ..first = PushIntent.parse({
          'notification_id': notificationOne,
          'type': 'billing_payment_failed',
          'access_granted': true,
          'url': 'https://untrusted.example/success',
          'title': 'PRIVATE PROVIDER CONTENT',
        });
      final push = PushController(
        DeviceRepository(session),
        gateway,
        vault,
        appVersion: () async => '1.0',
      );
      final c = BillingController(
        BillingRepository(session),
        testBillingConfig,
        FakeBillingGateway(),
        realtime: QuietRealtime(session),
      );
      await tester.pumpWidget(
        HistaeApp(
          sessionController: session,
          pushController: push,
          billingController: c,
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, greaterThan(0));
      expect(find.byType(SubscriptionPage), findsOneWidget);
      expect(find.text('Histae Gratuit'), findsOneWidget);
      expect(find.textContaining('PRIVATE PROVIDER'), findsNothing);
      expect(c.subscription!.accessGranted, isFalse);
      await tester.pumpWidget(const SizedBox());
      await gateway.close();
    },
  );
}
