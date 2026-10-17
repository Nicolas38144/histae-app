import 'push_config.dart';

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
  );
  factory AppConfig.fromDotEnv(String source, {required bool isDebug}) {
    final values = <String, String>{};
    for (final raw in source.replaceFirst('\uFEFF', '').split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator < 1) {
        throw const FormatException('Invalid public configuration');
      }
      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (![
            'APP_ENV',
            'API_BASE_URL',
            'ADMOB_ANDROID_APP_ID',
            'ADMOB_IOS_APP_ID',
            'ADMOB_ANDROID_REWARDED_AD_UNIT',
            'ADMOB_IOS_REWARDED_AD_UNIT',
            ...PushConfig.keys,
          ].contains(key) ||
          values.containsKey(key)) {
        throw const FormatException('Invalid public configuration');
      }
      if (value.startsWith('"') || value.startsWith("'")) {
        if (value.length < 2 || !value.endsWith(value[0])) {
          throw const FormatException('Invalid public configuration');
        }
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }
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
    );
  }

  final AppEnvironment environment;
  // Origin only; repositories supply full paths including /api.
  final Uri apiOrigin;
  final PushConfig push;
  // Public IDs reserved for a future native SDK installation. Empty fields do
  // not enable videos, initialize advertising, or provide an ad unit fallback.
  final String? admobAndroidAppId, admobIosAppId;
  // Reserved public configuration for the future SDK. The API's intent remains
  // authoritative; these values never replace a missing server ad_unit.
  final String? admobAndroidRewardedAdUnit, admobIosRewardedAdUnit;
}
