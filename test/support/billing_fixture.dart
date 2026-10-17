import 'package:histae_app/core/config/billing_config.dart';
import 'package:histae_app/features/billing/data/billing_gateway.dart';
import 'package:histae_app/features/billing/data/checkout_vault.dart';

final testBillingConfig = BillingConfig.fromValues({
  'BILLING_ENABLED': 'true',
  'BILLING_DISTRIBUTION': 'android_external',
  'BILLING_SUCCESS_URL':
      'https://return.example/success?session_id={CHECKOUT_SESSION_ID}',
  'BILLING_CANCEL_URL': 'https://return.example/cancel',
  'BILLING_PORTAL_RETURN_URL': 'https://return.example/account',
});
Map<String, Object?> subscriptionJson({
  bool access = false,
  String? status,
  bool cancel = false,
  bool portal = false,
}) => {
  'plan': access ? 'premium' : 'free',
  'provider': status == null ? null : 'stripe',
  'status': status,
  'access_granted': access,
  'billing_period': status == null ? null : 'monthly',
  'cancel_at_period_end': cancel,
  'current_period_starts_at': status == null ? null : '2026-10-01T00:00:00Z',
  'current_period_ends_at': status == null ? null : '2099-11-01T00:00:00Z',
  'trial_ends_at': status == 'trialing' ? '2099-10-25T00:00:00Z' : null,
  'canceled_at': status == 'canceled' ? '2026-10-15T00:00:00Z' : null,
  'customer_portal_available': portal,
};
Map<String, Object?> checkoutJson({String? url}) => {
  'session_id': 'cs_test_synthetic',
  'url': url ?? 'https://checkout.stripe.com/c/pay/synthetic',
  'expires_at': '2099-10-17T10:00:00Z',
};

class MemoryCheckoutVault implements CheckoutVault {
  String? raw;
  bool fail = false;
  @override
  Future<CheckoutAttempt?> read() async => CheckoutAttempt.decode(raw);
  @override
  Future<void> write(CheckoutAttempt? attempt) async {
    if (fail) throw StateError('Synthetic locked storage');
    raw = attempt?.encode() ?? '{}';
  }
}

class FakeBillingGateway implements BillingGateway {
  final opened = <Uri>[];
  bool accepted = true;
  @override
  Future<bool> open(Uri url, {required bool portal}) async {
    opened.add(url);
    return accepted;
  }
}
