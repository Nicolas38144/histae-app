import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/session_vault.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/data/billing_gateway.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/billing/data/checkout_vault.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/data/device_repository.dart';
import '../features/notifications/data/push_gateway.dart';
import '../features/notifications/data/push_vault.dart';

/// The composition root. Feature widgets receive scoped dependencies instead
/// of reaching into a global locator. HistaeApp owns their disposal.
class AppDependencies {
  const AppDependencies({this.catalog, this.session, this.push, this.billing});
  factory AppDependencies.fromConfig(AppConfig config) {
    final session = SessionController(
      AuthRepository(ApiClient(origin: config.apiOrigin)),
      SecureSessionVault(),
    );
    return AppDependencies(
      catalog: CatalogRepository(ApiClient(origin: config.apiOrigin)),
      session: session,
      push: PushController(
        DeviceRepository(session),
        FirebasePushGateway(config.push),
        SecurePushVault(),
      ),
      billing: BillingController(
        BillingRepository(session),
        config.billing,
        SecureCheckoutVault(),
        ExternalBillingGateway(),
      ),
    );
  }
  final CatalogRepository? catalog;
  final SessionController? session;
  final PushController? push;
  final BillingController? billing;
}
