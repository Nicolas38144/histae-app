import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_fields.dart';
import '../../auth/domain/authenticated_session.dart';
import 'billing_models.dart';
import 'store_models.dart';

abstract interface class BillingRepository {
  factory BillingRepository(AuthenticatedSession session) =
      ApiBillingRepository;
  AuthenticatedSession get session;
  Future<SubscriptionState> load(RequestCancellation scope);
  Future<List<StoreProduct>> products(
    StoreProvider provider,
    RequestCancellation scope,
  );
  Future<StoreIntent> intent(StoreProvider provider, RequestCancellation scope);
  Future<void> verify(
    StoreProvider provider,
    String reference,
    RequestCancellation scope,
  );
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
  Future<List<StoreProduct>> products(
    StoreProvider provider,
    RequestCancellation scope,
  ) async {
    final json = jsonObject(
      await session.request(
        'GET',
        '/api/billing/store-products',
        query: {'provider': provider.wire},
        expectedStatus: 200,
        replayAfterRefresh: true,
        cancellation: scope,
      ),
    );
    final offers = json['offers'];
    if (offers is! List) throw const ApiFailure(ApiFailureKind.invalidResponse);
    return offers.map(StoreProduct.fromJson).toList(growable: false);
  }

  @override
  Future<StoreIntent> intent(
    StoreProvider provider,
    RequestCancellation scope,
  ) async => StoreIntent.fromJson(
    await session.request(
      'POST',
      '/api/users/me/subscription/purchase-intents',
      expectedStatus: 200,
      replayAfterRefresh: true,
      cancellation: scope,
      body: {'provider': provider.wire},
    ),
  );
  @override
  Future<void> verify(
    StoreProvider provider,
    String reference,
    RequestCancellation scope,
  ) async {
    await session.request(
      'POST',
      '/api/users/me/subscription/${provider == StoreProvider.appStore ? 'apple' : 'google-play'}/verify',
      expectedStatus: 204,
      replayAfterRefresh: true,
      cancellation: scope,
      body: {'reference': reference},
    );
  }
}
