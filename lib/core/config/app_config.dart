enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig._(this.environment, this.apiOrigin);
  static const defaultApiBaseUrl = 'https://api.histae.com';

  factory AppConfig.fromValues({
    required String environment,
    required String apiBaseUrl,
    required bool isDebug,
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
    return AppConfig._(env.single, uri.replace(path: ''));
  }

  final AppEnvironment environment;
  // Origin only; repositories supply full paths including /api.
  final Uri apiOrigin;
}
