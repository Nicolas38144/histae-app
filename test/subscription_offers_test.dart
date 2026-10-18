import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/billing/data/billing_models.dart';
import 'package:histae_app/features/billing/presentation/subscription_plans.dart';
import 'package:histae_app/features/catalog/application/catalog_controller.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/catalog/data/plan_catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/catalog_fixture.dart';

void main() {
  test('catalogue links three offers to two entitlement plans', () {
    final catalog = PlanCatalog.fromJson(catalogJson());
    expect(catalog.plans.length, 2);
    expect(catalog.offers.map((offer) => offer.displayName), [
      'Free',
      'Premium Mensuel',
      'Premium Annuel',
    ]);
    expect(catalog.offers[1].billingPeriod, BillingPeriod.monthly);
    expect(catalog.offers[2].billingPeriod, BillingPeriod.annual);
    expect(catalog.offers[1].planCode, catalog.offers[2].planCode);
    expect(catalog.offers[1].priceCents, 1234);
    expect(catalog.offers[2].priceCents, 9876);
  });

  test('rejects a plans-only response instead of reconstructing offers', () {
    final json = catalogJson()..remove('offers');
    expect(() => PlanCatalog.fromJson(json), throwsA(isA<ApiFailure>()));
    json['plans'] = <dynamic>[];
    expect(() => PlanCatalog.fromJson(json), throwsA(isA<ApiFailure>()));
  });

  test('explicitly empty offers stay empty without reconstructing them', () {
    final explicit = catalogJson()..['offers'] = <dynamic>[];
    expect(PlanCatalog.fromJson(explicit).offers, isEmpty);
    explicit['plans'] = <dynamic>[];
    expect(PlanCatalog.fromJson(explicit).offers, isEmpty);
  });

  for (final value in <Object?>[null, <String, Object?>{}, 'invalid']) {
    test('rejects malformed offers: $value', () {
      final json = catalogJson()..['offers'] = value;
      expect(() => PlanCatalog.fromJson(json), throwsA(isA<ApiFailure>()));
    });
  }

  for (final invalid in [
    'missing_plan',
    'duplicate',
    'wrong_period',
    'missing_price',
  ]) {
    test('rejects inconsistent offer: $invalid', () {
      final json = catalogJson();
      final offers = json['offers'] as List<dynamic>;
      final offer = offers[2] as Map<String, dynamic>;
      switch (invalid) {
        case 'missing_plan':
          json['plans'] = <dynamic>[];
        case 'duplicate':
          offers.add(Map<String, dynamic>.from(offer));
        case 'wrong_period':
          offer['billing_period'] = 'monthly';
        case 'missing_price':
          offer.remove('price_cents');
      }
      expect(() => PlanCatalog.fromJson(json), throwsA(isA<ApiFailure>()));
    });
  }

  testWidgets('each Premium card selects its period and server price', (
    tester,
  ) async {
    final repository = CatalogRepository(
      ApiClient(
        origin: Uri.parse('https://api.example'),
        client: MockClient((_) async => http.Response(catalogFixture(), 200)),
      ),
    );
    final controller = CatalogController(repository);
    addTearDown(controller.dispose);
    addTearDown(repository.close);
    await controller.load();
    final chosen = <SubscriptionOffer>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SubscriptionPlans(
              catalog: controller,
              paymentsAvailable: true,
              canSubscribe: true,
              hasPending: false,
              canAct: true,
              onChoose: (offer) async {
                chosen.add(offer);
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Premium Mensuel'), findsOneWidget);
    expect(find.text('Premium Annuel'), findsOneWidget);
    expect(find.textContaining('Période d’essai'), findsNothing);
    expect(find.textContaining('éligibilité'), findsNothing);
    await tester.scrollUntilVisible(find.text('Choisir Premium Mensuel'), 250);
    await tester.tap(find.text('Choisir Premium Mensuel'));
    await tester.scrollUntilVisible(find.text('Choisir Premium Annuel'), 250);
    await tester.tap(find.text('Choisir Premium Annuel'));
    expect(chosen.map((offer) => offer.billingPeriod), [
      BillingPeriod.monthly,
      BillingPeriod.annual,
    ]);
    expect(chosen.map((offer) => offer.priceCents), [1234, 9876]);
    expect(tester.takeException(), isNull);
  });
}
