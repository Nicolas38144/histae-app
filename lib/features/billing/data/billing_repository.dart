import '../../../core/network/api_client.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/application/session_controller.dart';
import 'billing_models.dart';
import 'checkout_vault.dart';

class BillingRepository {
  BillingRepository(this.session);
  final SessionController session;
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
      body: {'billing_period': attempt.period.name},
    ),
  );
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
