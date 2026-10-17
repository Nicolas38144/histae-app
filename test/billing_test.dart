import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/config/app_config.dart';
import 'package:histae_app/core/config/billing_config.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/billing/application/billing_controller.dart';
import 'package:histae_app/features/billing/data/billing_models.dart';
import 'package:histae_app/features/billing/data/billing_repository.dart';
import 'package:histae_app/features/billing/data/checkout_vault.dart';
import 'package:histae_app/features/matches/data/realtime_client.dart';
import 'package:http/http.dart' as http;

import 'support/auth_fixture.dart';
import 'support/billing_fixture.dart';
import 'support/matches_fixture.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('public deployment gate is default off, Android external only and requires complete HTTPS return configuration', () {
    expect(
      AppConfig.fromDotEnv(
        'APP_ENV=production\nAPI_BASE_URL=https://api.example',
        isDebug: false,
      ).billing.available,
      isFalse,
    );
    expect(testBillingConfig.available, isTrue);
    expect(testBillingConfig.allows(TargetPlatform.iOS), isFalse);
    expect(
      testBillingConfig.allows(TargetPlatform.android, web: true),
      isFalse,
    );
    expect(
      () => BillingConfig.fromValues({'BILLING_ENABLED': 'true'}),
      throwsFormatException,
    );
    expect(
      () => BillingConfig.fromValues({
        'BILLING_CANCEL_URL': 'http://return.example',
      }),
      throwsFormatException,
    );
    expect(
      () => AppConfig.fromDotEnv(
        'APP_ENV=production\nAPI_BASE_URL=https://api.example\nSTRIPE_SECRET_KEY=secret',
        isDebug: false,
      ),
      throwsFormatException,
    );
  });
  test('access comes from effective API plan, never from status or launch; dates and nullable provider support administrative access', () {
    expect(
      SubscriptionState.fromJson(subscriptionJson(status: 'active'))
          .accessGranted,
      isFalse,
    );
    expect(
      SubscriptionState.fromJson(
        subscriptionJson(access: true, status: 'past_due'),
      ).accessGranted,
      isTrue,
    );
    expect(
      SubscriptionState.fromJson(subscriptionJson(access: true)).provider,
      isNull,
    );
    expect(
      SubscriptionState.fromJson(subscriptionJson(status: 'canceled'))
          .canceledAt,
      isNotNull,
    );
    expect(
      () => SubscriptionState.fromJson({
        ...subscriptionJson(),
        'plan': 'premium',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => SubscriptionState.fromJson({
        ...subscriptionJson(),
        'trial_ends_at': '2026-10-20',
      }),
      throwsA(isA<ApiFailure>()),
    );
    for (final url in [
      'https://checkout.stripe.com.evil.example/c/pay/x',
      'https://user@checkout.stripe.com/c/pay/x',
      'http://checkout.stripe.com/c/pay/x',
      'https://checkout.stripe.com:444/c/pay/x',
      'histae://success',
    ]) {
      expect(
        () => CheckoutLink.fromJson(checkoutJson(url: url)),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test('disabled billing permits authenticated subscription reads but sends no checkout or portal POST', () async {
    final calls = <http.Request>[];
    final session = testSession((r) async {
      calls.add(r);
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(subscriptionJson(portal: true));
      }
      return defaultAuthResponse(r, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = BillingController(
      BillingRepository(session),
      const BillingConfig(),
      MemoryCheckoutVault(),
      FakeBillingGateway(),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    expect(c.fresh, isTrue);
    await c.checkout(BillingPeriod.monthly);
    await c.portal();
    expect(
      calls.where(
        (r) => r.url.path.contains('/subscription') && r.method == 'POST',
      ),
      isEmpty,
    );
    expect(
      calls.last.headers['Authorization'],
      'Bearer ${testTokens.accessToken}',
    );
  });
  test('durable immutable intent prevents double taps, survives lost response and restart, and only GET confirms access', () async {
    final posts = <http.Request>[];
    final response = Completer<http.Response>();
    var premium = false;
    final vault = MemoryCheckoutVault(), browser = FakeBillingGateway();
    final session = testSession((r) async {
      if (r.url.path.endsWith('/checkout')) {
        expect(vault.raw, isNotNull);
        posts.add(r);
        if (posts.length == 1) return response.future;
        return jsonResponse(checkoutJson(), 201);
      }
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(
          subscriptionJson(
            access: premium,
            status: premium ? 'trialing' : null,
          ),
        );
      }
      return defaultAuthResponse(r, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    BillingController make() => BillingController(
      BillingRepository(session),
      testBillingConfig,
      vault,
      browser,
      realtime: QuietRealtime(session),
    );
    var c = make();
    await c.activate();
    final first = c.checkout(BillingPeriod.monthly);
    await Future<void>.delayed(Duration.zero);
    await c.checkout(BillingPeriod.annual);
    expect(posts, hasLength(1));
    response.completeError(const SocketException('Synthetic response lost'));
    await first;
    final key = c.pending!.key;
    expect(jsonDecode(posts.single.body), {'billing_period': 'monthly'});
    expect(vault.raw, isNot(contains('stripe')));
    c.dispose();
    c = make();
    addTearDown(c.dispose);
    await c.activate();
    expect(c.pending!.key, key);
    await c.checkout(BillingPeriod.annual);
    expect(posts, hasLength(1));
    await c.checkout(BillingPeriod.monthly);
    expect(posts.last.headers['Idempotency-Key'], key);
    expect(browser.opened, hasLength(1));
    expect(c.subscription!.accessGranted, isFalse);
    c.suspend();
    premium = true;
    await c.resume();
    expect(c.subscription!.accessGranted, isTrue);
    expect(c.pending, isNull);
    expect(vault.raw, '{}');
  });
  test('secure storage failure blocks POST and invalid hosted URL never opens a browser; explicit retry retains key', () async {
    var count = 0;
    final vault = MemoryCheckoutVault(), browser = FakeBillingGateway();
    final session = testSession((r) async {
      if (r.url.path.endsWith('/checkout')) {
        count++;
        return jsonResponse(
          checkoutJson(url: 'https://untrusted.example/pay'),
          201,
        );
      }
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(subscriptionJson());
      }
      return defaultAuthResponse(r, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = BillingController(
      BillingRepository(session),
      testBillingConfig,
      vault,
      browser,
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    vault.fail = true;
    await c.checkout(BillingPeriod.annual);
    expect(count, 0);
    final key = c.pending!.key;
    vault.fail = false;
    await c.checkout(BillingPeriod.annual);
    expect(c.pending!.key, key);
    expect(c.failure!.kind, ApiFailureKind.invalidResponse);
    expect(browser.opened, isEmpty);
  });
  test('server consumed key requires entitlement reread before another intent; Retry-After blocks every billing mutation', () async {
    final posts = <http.Request>[];
    var consumed = true;
    final session = testSession((r) async {
      if (r.url.path.endsWith('/checkout')) {
        posts.add(r);
        return consumed
            ? apiError(409, 'idempotency_key_consumed')
            : apiError(429, 'billing_rate_limit_exceeded', retryAfter: '60');
      }
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(subscriptionJson(portal: true));
      }
      return defaultAuthResponse(r, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = BillingController(
      BillingRepository(session),
      testBillingConfig,
      MemoryCheckoutVault(),
      FakeBillingGateway(),
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.checkout(BillingPeriod.monthly);
    expect(c.pending, isNull);
    expect(c.notice, 'attempt_closed');
    consumed = false;
    await c.checkout(BillingPeriod.annual);
    expect(
      posts[0].headers['Idempotency-Key'],
      isNot(posts[1].headers['Idempotency-Key']),
    );
    expect(c.retrySeconds, greaterThan(0));
    await c.checkout(BillingPeriod.annual);
    await c.portal();
    expect(posts, hasLength(2));
  });
  test('logout purges subscription and intent, ignores late checkout, and never restores another owner intent', () async {
    final response = Completer<http.Response>();
    final vault = MemoryCheckoutVault(), browser = FakeBillingGateway();
    final session = testSession((r) async {
      if (r.url.path.endsWith('/checkout')) return response.future;
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(subscriptionJson());
      }
      return defaultAuthResponse(r, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final c = BillingController(
      BillingRepository(session),
      testBillingConfig,
      vault,
      browser,
      realtime: QuietRealtime(session),
    );
    addTearDown(c.dispose);
    await c.activate();
    final task = c.checkout(BillingPeriod.monthly);
    await Future<void>.delayed(Duration.zero);
    await session.logout();
    response.complete(jsonResponse(checkoutJson(), 201));
    await task;
    await Future<void>.delayed(Duration.zero);
    expect(c.pending, isNull);
    expect(c.subscription, isNull);
    expect(vault.raw, '{}');
    expect(browser.opened, isEmpty);
    vault.raw = CheckoutAttempt.create(
      'https://api.example',
      '22222222-2222-4222-8222-222222222222',
      BillingPeriod.annual,
    ).encode();
    await session.establish(testTokens);
    await c.activate();
    expect(c.pending, isNull);
    expect(vault.raw, '{}');
  });
  test('subscription events invalidate and reread status; portal uses no body or amount and does not grant access', () async {
    final calls = <http.Request>[];
    var state = subscriptionJson(
      status: 'past_due',
      access: true,
      portal: true,
    );
    final session = testSession((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/portal')) {
        return jsonResponse({
          'url': 'https://billing.stripe.com/p/session/synthetic',
        }, 201);
      }
      if (r.url.path == '/api/users/me/subscription') {
        return jsonResponse(state);
      }
      return defaultAuthResponse(r, complete: true);
    });
    addTearDown(session.dispose);
    await session.establish(testTokens);
    final realtime = QuietRealtime(session), browser = FakeBillingGateway();
    final c = BillingController(
      BillingRepository(session),
      testBillingConfig,
      MemoryCheckoutVault(),
      browser,
      realtime: realtime,
    );
    addTearDown(c.dispose);
    await c.activate();
    await c.portal();
    expect(calls.last.body, isEmpty);
    expect(browser.opened.single.host, 'billing.stripe.com');
    state = subscriptionJson(status: 'canceled', portal: true);
    realtime.emit(const MobileSignal('subscription.updated'));
    await Future<void>.delayed(Duration.zero);
    expect(c.subscription!.accessGranted, isFalse);
    expect(c.subscription!.status, 'canceled');
  });
}
