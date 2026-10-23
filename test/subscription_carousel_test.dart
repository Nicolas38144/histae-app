import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/l10n/generated/app_messages.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/features/billing/data/billing_gateway.dart';
import 'package:histae_app/features/billing/data/billing_models.dart';
import 'package:histae_app/features/billing/data/store_models.dart';
import 'package:histae_app/features/billing/presentation/subscription_plans.dart';
import 'package:histae_app/features/catalog/application/catalog_controller.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/catalog/data/plan_catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/catalog_fixture.dart';

const storeOffers = [
  StoreOffer(
    StoreProduct(period: BillingPeriod.monthly, productId: 'monthly'),
    '7,50 EUR',
  ),
  StoreOffer(
    StoreProduct(period: BillingPeriod.annual, productId: 'annual'),
    '72,00 EUR',
  ),
];

Widget subject(
  CatalogController catalog, {
  String locale = 'fr',
  double scale = 1,
  bool reduceMotion = false,
  Future<void> Function(SubscriptionOffer)? choose,
}) => MaterialApp(
  key: ValueKey(locale),
  locale: Locale(locale),
  localizationsDelegates: AppMessages.localizationsDelegates,
  supportedLocales: AppMessages.supportedLocales,
  theme: histaeTheme(Brightness.dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduceMotion,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SubscriptionPlans(
          catalog: catalog,
          paymentsAvailable: true,
          canSubscribe: true,
          hasPending: false,
          canAct: true,
          storeOffers: storeOffers,
          onChoose: choose ?? (_) async {},
        ),
      ],
    ),
  ),
);

void main() {
  Future<CatalogController> catalogue({VoidCallback? onRead}) async {
    final repository = CatalogRepository(
      ApiClient(
        origin: Uri.parse('https://api.example'),
        client: MockClient((_) async {
          onRead?.call();
          return http.Response(catalogFixture(), 200);
        }),
      ),
    );
    addTearDown(repository.close);
    final controller = CatalogController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  testWidgets(
    'starts monthly and compares offers without a reread or purchase',
    (tester) async {
      var reads = 0;
      final choices = <BillingPeriod?>[];
      final catalog = await catalogue(onRead: () => reads++);
      await tester.pumpWidget(
        subject(
          catalog,
          choose: (offer) async => choices.add(offer.billingPeriod),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offre 2 sur 3'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('plan-selector-premium_monthly')),
            )
            .selected,
        isTrue,
      );
      expect(find.text('7,50 EUR par mois'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('subscription-plan-pages')),
        const Offset(650, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offre 1 sur 3'), findsOneWidget);
      await tester.pumpWidget(
        subject(
          catalog,
          choose: (offer) async => choices.add(offer.billingPeriod),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offre 1 sur 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-selector-premium_annual')));
      await tester.pumpAndSettle();
      expect(find.text('Offre 3 sur 3'), findsOneWidget);
      expect(choices, isEmpty);
      final action = find.text('Choisir Premium Annuel');
      await tester.ensureVisible(action);
      await tester.tap(action);
      expect(choices, [BillingPeriod.annual]);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cards resize for large text without clipping in all four locales',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = await catalogue();
      for (final locale in ['fr', 'en', 'es', 'it']) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            subject(
              catalog,
              locale: locale,
              scale: scale,
              reduceMotion: scale == 2,
            ),
          );
          await tester.pumpAndSettle();
          final selector = find.byKey(
            const Key('plan-selector-premium_annual'),
          );
          await tester.ensureVisible(selector);
          await tester.tap(selector);
          await tester.pumpAndSettle();
          expect(
            tester
                .getSize(find.byKey(const Key('subscription-plan-pages')))
                .height,
            closeTo(
              tester
                  .getSize(find.byKey(const Key('plan-offer-premium_annual')))
                  .height,
              0.1,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
