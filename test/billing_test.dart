import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/config/billing_config.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_gateway.dart';
import 'package:histae_app/features/billing/data/billing_models.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/data/store_models.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/billing_fixture.dart';
import 'support/matches_fixture.dart';

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('native billing is opt-in on Android and iOS only', () {
    expect(const BillingConfig().available, isFalse);
    expect(testBillingConfig.available, isTrue);
    expect(testBillingConfig.allows(TargetPlatform.iOS), isTrue);
    expect(
      testBillingConfig.allows(TargetPlatform.android, web: true),
      isFalse,
    );
    expect(testBillingConfig.allows(TargetPlatform.linux), isFalse);
  });
  test('effective access is never inferred from native status; invalid owner binding is rejected', () {
    for (final provider in ['stripe', 'app_store', 'google_play']) {
      expect(
        SubscriptionState.fromJson(
          subscriptionJson(status: 'active', provider: provider),
        ).accessGranted,
        isFalse,
      );
      expect(
        SubscriptionState.fromJson(
          subscriptionJson(status: 'active', provider: provider, access: true),
        ).accessGranted,
        isTrue,
      );
    }
    expect(
      () => StoreIntent.fromJson({
        ...storeIntentJson(),
        'account_binding': testUser,
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => SubscriptionState.fromJson({
        ...subscriptionJson(),
        'plan': 'premium',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('purchase requires intent, prevents double taps and verifies server before finishing', () async {
    final calls = <String>[];
    final verification = Completer<http.Response>();
    var premium = false;
    final session = testSession((r) async {
      calls.add(r.url.path);
      if (r.url.path.endsWith('/purchase-intents')) {
        return jsonResponse(storeIntentJson());
      }
      if (r.url.path.endsWith('/google-play/verify')) {
        return verification.future;
      }
      if (r.url.path == '/api/billing/store-products') {
        return jsonResponse(storeProductsJson());
      }
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(
          subscriptionJson(access: premium, status: premium ? 'active' : null),
        );
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
    await c.activate();
    expect(c.paymentsAvailable, isTrue);
    await c.checkout(BillingPeriod.monthly);
    await c.checkout(BillingPeriod.annual);
    expect(gateway.bought, hasLength(1));
    expect(c.subscription!.accessGranted, isFalse);
    gateway.stream.add([storePurchase()]);
    await flush();
    expect(gateway.completed, isEmpty);
    expect(calls, contains('/api/users/me/subscription/google-play/verify'));
    premium = true;
    verification.complete(http.Response('', 204));
    await flush();
    expect(gateway.completed, hasLength(1));
    expect(c.subscription!.accessGranted, isTrue);
    expect(
      calls.where(
        (path) => path.endsWith('/checkout') || path.endsWith('/portal'),
      ),
      isEmpty,
    );
  });
  test('unverified purchases stay unfinished; restore can retry without buying again', () async {
    var unavailable = true;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/google-play/verify')) {
        return unavailable
            ? apiError(503, 'store_unavailable')
            : http.Response('', 204);
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
    await c.activate();
    gateway.stream.add([storePurchase()]);
    await flush();
    expect(gateway.completed, isEmpty);
    expect(c.failure, isNotNull);
    unavailable = false;
    await c.restorePurchases();
    await flush();
    expect(gateway.completed, hasLength(1));
    expect(gateway.bought, isEmpty);
  });
  test('late verification after logout cannot finish purchase or restore old account state', () async {
    final verification = Completer<http.Response>();
    final session = testSession((r) async {
      if (r.url.path.endsWith('/google-play/verify')) {
        return verification.future;
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
    await c.activate();
    gateway.stream.add([storePurchase()]);
    await flush();
    await session.logout();
    verification.complete(http.Response('', 204));
    await flush();
    expect(gateway.completed, isEmpty);
    expect(c.subscription, isNull);
  });
  test(
    'pending and canceled purchases never call verification or finish',
    () async {
      final calls = <String>[];
      final session = testSession((r) async {
        calls.add(r.url.path);
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
      await c.activate();
      gateway.stream.add([storePurchase(status: StorePurchaseStatus.pending)]);
      await flush();
      expect(c.purchasePending, isTrue);
      gateway.stream.add([storePurchase(status: StorePurchaseStatus.canceled)]);
      await flush();
      expect(c.purchasePending, isFalse);
      expect(calls.where((path) => path.endsWith('/verify')), isEmpty);
      expect(gateway.completed, isEmpty);
    },
  );
}
