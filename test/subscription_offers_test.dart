import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/catalog/data/plan_catalog.dart';

import 'support/catalog_fixture.dart';

void main() {
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
}
