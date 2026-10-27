import '../core/config/app_config.dart';
import '../core/l10n/locale_controller.dart';
import '../core/network/api_client.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/session_vault.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/billing/data/native_billing_gateway.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/continuation/data/rewarded_video_gateway.dart';
import '../features/drafts/data/draft_vault.dart';
import '../features/help/application/help_controller.dart';
import '../features/help/data/feed_guide_store.dart';
import '../features/notifications/application/push_controller.dart';
import '../features/notifications/data/device_repository.dart';
import '../features/notifications/data/push_gateway.dart';
import '../features/notifications/data/push_vault.dart';
import 'session_repositories.dart';

/// The composition root. Feature widgets receive scoped dependencies instead
/// of reaching into a global locator. HistaeApp owns their disposal.
class AppDependencies {
  const AppDependencies({
    this.catalog,
    this.session,
    this.push,
    this.billing,
    this.videos,
    this.repositories,
    this.help,
  });

  factory AppDependencies.fromConfig(
    AppConfig config, {
    LocaleController? locale,
  }) {
    ApiClient client() => ApiClient(
      origin: config.apiOrigin,
      language: locale == null ? null : () => locale.apiLanguage,
    );
    final session = SessionController(
      AuthRepository(client()),
      SecureSessionVault(),
      languageChanges: locale,
    );
    final devices = DeviceRepository(session);
    final repositories = SessionRepositories(
      session,
      devices: devices,
      draftVault: const SecureDraftVault(),
    );
    return AppDependencies(
      help: HelpController(config.support, store: const SecureFeedGuideStore()),
      repositories: repositories,
      catalog: CatalogRepository(client(), languageChanges: locale),
      session: session,
      videos: AdmobRewardedVideoGateway(config),
      push: PushController(
        devices,
        FirebasePushGateway(config.push),
        SecurePushVault(),
        language: locale == null ? null : () => locale.apiLanguage,
        languageChanges: locale,
      ),
      billing: BillingController(
        BillingRepository(session),
        config.billing,
        NativeBillingGateway(),
        realtime: repositories.realtime.channel(),
      ),
    );
  }
  final CatalogRepository? catalog;
  final SessionController? session;
  final PushController? push;
  final BillingController? billing;
  final SessionRepositories? repositories;
  final RewardedVideoGateway? videos;
  final HelpController? help;
}
