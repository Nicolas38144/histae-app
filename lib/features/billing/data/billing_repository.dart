import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';
import 'billing_models.dart';
import 'checkout_vault.dart';

abstract interface class BillingRepository {
  factory BillingRepository(AuthenticatedSession session) =
      ApiBillingRepository;

  AuthenticatedSession get session;

  Future<SubscriptionState> load(RequestCancellation scope);

  Future<CheckoutLink> checkout(
    CheckoutAttempt attempt,
    RequestCancellation scope,
  );

  Future<Uri> portal(RequestCancellation scope);
}

final class ApiBillingRepository implements BillingRepository {
  ApiBillingRepository(this.session);
  @override
  final AuthenticatedSession session;

  @override
  Future<SubscriptionState> load(RequestCancellation scope) async =>
      SubscriptionState.fromJson(
        await session.request(
          'GET',
          '/api/users/me/subscription',
          expectedStatus: 200,
          replayAfterRefresh: true,
          cancellation: scope,
        ),
      );

  @override
  Future<CheckoutLink> checkout(
    CheckoutAttempt attempt,
    RequestCancellation scope,
  ) async => CheckoutLink.fromJson(
    await session.request(
      'POST',
      '/api/users/me/subscription/checkout',
      expectedStatus: 201,
      replayAfterRefresh: true,
      cancellation: scope,
      idempotencyKey: attempt.key,
      language: attempt.language,
      body: {'billing_period': attempt.period.name},
    ),
  );

  @override
  Future<Uri> portal(RequestCancellation scope) async => stripeUrl(
    jsonObject(
      await session.request(
        'POST',
        '/api/users/me/subscription/portal',
        expectedStatus: 201,
        replayAfterRefresh: true,
        cancellation: scope,
      ),
    )['url'],
    portal: true,
  );
}
