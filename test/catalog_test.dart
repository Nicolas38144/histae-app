import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/catalog/application/catalog_controller.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';
import 'package:histae_app/features/catalog/data/subscription_plan.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/catalog_fixture.dart';

void main() {
  CatalogRepository repository(
    Future<http.Response> Function(http.Request) handle, {
    DateTime Function()? now,
  }) {
    final repository = CatalogRepository(
      ApiClient(
        origin: Uri.parse('https://api.example'),
        client: MockClient(handle),
        now: now,
      ),
    );
    addTearDown(repository.close);
    return repository;
  }

  test(
    'decodes Rust optional fields, nullable labels and arbitrary feature_value',
    () async {
      final repo = repository(
        (_) async => http.Response(catalogFixture(), 200),
      );
      final catalog = await repo.load(RequestCancellation());
      final plans = catalog.plans;
      expect(catalog.offers.map((offer) => offer.code), [
        'free',
        'premium_monthly',
        'premium_annual',
      ]);
      expect(catalog.offers.last.priceCents, 9876);
      expect(plans.map((p) => p.code), ['free', 'premium']);
      expect(plans.first.weeklyIncludedCredits, 3);
      expect(plans.first.weeklyContinuationLimit, 6);
      expect(plans.first.features.single.value, {'enabled': true});
      final premium = plans.last;
      expect(premium.weeklyIncludedCredits, isNull);
      expect(premium.weeklyContinuationLimit, isNull);
      expect(premium.monthlyPriceCents, 1234);
      expect(premium.annualPriceCents, 9876);
      expect(premium.features.single.displayName, isNull);
      expect(premium.features.single.value, true);
      expect(() => plans.clear(), throwsUnsupportedError);
      expect(() => catalog.offers.clear(), throwsUnsupportedError);
    },
  );
  test(
    'plans-only response is rejected without reconstructing offers or retrying',
    () async {
      var calls = 0;
      final controller = CatalogController(
        repository((_) async {
          calls++;
          return http.Response(
            jsonEncode(catalogJson()..remove('offers')),
            200,
          );
        }),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.status, CatalogStatus.failure);
      expect(controller.offers, isEmpty);
      expect(controller.failure?.kind, ApiFailureKind.invalidResponse);
      expect(calls, 1);
    },
  );
  test('retains server changes without deriving quotas from a plan code', () {
    final json = (catalogJson()['plans'] as List).first as Map<String, dynamic>;
    json['weekly_included_credits'] = 2;
    json['weekly_continuation_limit'] = 5;
    json['advertising_credit_stock_limit'] = 8;
    json['rewarded_advertising_enabled'] = true;
    final plan = SubscriptionPlan.fromJson(json);
    expect(plan.weeklyIncludedCredits, 2);
    expect(plan.weeklyContinuationLimit, 5);
    expect(plan.advertisingCreditStockLimit, 8);
    expect(plan.rewardedAdvertisingEnabled, isTrue);
  });
  for (final field in [
    'monthly_price_cents',
    'ads_removed',
    'rewarded_advertising_enabled',
    'features',
  ]) {
    test('rejects missing required field $field without silently guessing', () {
      final json =
          (catalogJson()['plans'] as List).first as Map<String, dynamic>;
      json.remove(field);
      expect(() => SubscriptionPlan.fromJson(json), throwsFormatException);
    });
  }
  test('rejects wrong numeric types and malformed envelopes', () async {
    final json = (catalogJson()['plans'] as List).first as Map<String, dynamic>;
    json['monthly_price_cents'] = 12.34;
    expect(() => SubscriptionPlan.fromJson(json), throwsFormatException);
    for (final body in ['[]', '{}', '{"plans":[{}]}']) {
      final repo = repository((_) async => http.Response(body, 200));
      await expectLater(
        repo.load(RequestCancellation()),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });
  test(
    'loading is single-flight and publishes ready and empty states',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final controller = CatalogController(
        repository((_) {
          calls++;
          return response.future;
        }),
      );
      addTearDown(controller.dispose);
      final pending = controller.load();
      expect(controller.status, CatalogStatus.loading);
      await controller.load();
      response.complete(http.Response(catalogFixture(), 200));
      await pending;
      expect(calls, 1);
      expect(controller.status, CatalogStatus.ready);
      final empty = CatalogController(
        repository((_) async => http.Response('{"plans":[],"offers":[]}', 200)),
      );
      addTearDown(empty.dispose);
      await empty.load();
      expect(empty.status, CatalogStatus.empty);
    },
  );
  test(
    'manual retry respects deadline without automatic network retries',
    () async {
      var now = DateTime.utc(2026, 10, 15);
      var calls = 0;
      final controller = CatalogController(
        repository((_) async {
          calls++;
          return calls == 1
              ? http.Response(
                  '{"error":{"code":"rate_limit_exceeded"}}',
                  429,
                  headers: {'retry-after': '2'},
                )
              : http.Response('{"plans":[],"offers":[]}', 200);
        }, now: () => now),
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.status, CatalogStatus.failure);
      expect(controller.retrySeconds, 2);
      await controller.load();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 2));
      expect(calls, 1);
      await controller.load();
      expect(calls, 2);
      expect(controller.status, CatalogStatus.empty);
    },
  );
  test(
    'late responses after suspension never overwrite a newer request',
    () async {
      final first = Completer<http.Response>();
      var calls = 0;
      final controller = CatalogController(
        repository((_) async {
          calls++;
          return calls == 1
              ? first.future
              : http.Response('{"plans":[],"offers":[]}', 200);
        }),
      );
      addTearDown(controller.dispose);
      final old = controller.load();
      controller.suspend();
      expect(controller.status, CatalogStatus.idle);
      await controller.load();
      first.complete(http.Response(catalogFixture(), 200));
      await old;
      expect(controller.status, CatalogStatus.empty);
      expect(controller.plans, isEmpty);
    },
  );
  test('dispose ignores a late successful response', () async {
    final response = Completer<http.Response>();
    final controller = CatalogController(repository((_) => response.future));
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });
    final loading = controller.load();
    controller.dispose();
    response.complete(http.Response(jsonEncode({'plans': <Object?>[]}), 200));
    await loading;
    expect(notifications, 1);
  });
}
