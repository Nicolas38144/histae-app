import 'billing_config.dart';
import 'public_env.dart';
import 'push_config.dart';
import 'support_config.dart';

enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig._(
    this.environment,
    this.apiOrigin,
    this.admobAndroidAppId,
    this.admobIosAppId,
    this.admobAndroidRewardedAdUnit,
    this.admobIosRewardedAdUnit,
    this.push,
    this.billing,
    this.support,
  );

  factory AppConfig.fromDotEnv(String source, {required bool isDebug}) {
    final values = parsePublicEnv(
      source,
      allowedKeys: {
        'APP_ENV',
        'API_BASE_URL',
        'ADMOB_ANDROID_APP_ID',
        'ADMOB_IOS_APP_ID',
        'ADMOB_ANDROID_REWARDED_AD_UNIT',
        'ADMOB_IOS_REWARDED_AD_UNIT',
        ...PushConfig.keys,
        ...BillingConfig.keys,
        'SUPPORT_EMAIL',
        'SUPPORT_WEBSITE_URL',
      },
    );
    return AppConfig.fromValues(
      environment: values['APP_ENV'] ?? '',
      apiBaseUrl: values['API_BASE_URL'] ?? '',
      isDebug: isDebug,
      admobAndroidAppId: values['ADMOB_ANDROID_APP_ID'] ?? '',
      admobIosAppId: values['ADMOB_IOS_APP_ID'] ?? '',
      admobAndroidRewardedAdUnit:
          values['ADMOB_ANDROID_REWARDED_AD_UNIT'] ?? '',
      admobIosRewardedAdUnit: values['ADMOB_IOS_REWARDED_AD_UNIT'] ?? '',
      push: PushConfig.fromValues(values),
      billing: BillingConfig.fromValues(values),
      support: SupportConfig.fromValues(values),
    );
  }

  factory AppConfig.fromValues({
    required String environment,
    required String apiBaseUrl,
    required bool isDebug,
    String admobAndroidAppId = '',
    String admobIosAppId = '',
    String admobAndroidRewardedAdUnit = '',
    String admobIosRewardedAdUnit = '',
    PushConfig push = const PushConfig(),
    BillingConfig billing = const BillingConfig(),
    SupportConfig support = const SupportConfig(),
  }) {
    final env = AppEnvironment.values.where((e) => e.name == environment);
    final uri = Uri.tryParse(apiBaseUrl);
    if (env.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Invalid API origin or environment');
    }
    if (uri.scheme == 'http' &&
        (!isDebug || env.single != AppEnvironment.development)) {
      throw const FormatException('HTTPS required');
    }
    String? appId(String value) {
      if (value.isEmpty) return null;
      if (!RegExp(r'^ca-app-pub-\d{16}~\d{10}$').hasMatch(value)) {
        throw const FormatException(
          'Invalid public advertising application ID',
        );
      }
      return value;
    }

    String? adUnit(String value) {
      if (value.isEmpty) return null;
      if (!RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(value)) {
        throw const FormatException('Invalid public rewarded ad unit');
      }
      return value;
    }

    return AppConfig._(
      env.single,
      uri.replace(path: ''),
      appId(admobAndroidAppId),
      appId(admobIosAppId),
      adUnit(admobAndroidRewardedAdUnit),
      adUnit(admobIosRewardedAdUnit),
      push,
      billing,
      support,
    );
  }
  final AppEnvironment environment;
  // Origin only; repositories supply full paths including /api.
  final Uri apiOrigin;
  final PushConfig push;
  final BillingConfig billing;
  final SupportConfig support;
  // Public IDs also read by native builds. Empty fields disable playback.
  final String? admobAndroidAppId, admobIosAppId;
  // The API's intent remains authoritative; these never replace its ad_unit.
  final String? admobAndroidRewardedAdUnit, admobIosRewardedAdUnit;
}
