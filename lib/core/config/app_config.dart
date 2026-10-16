enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig._(this.environment, this.apiOrigin);
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
      if (!['APP_ENV', 'API_BASE_URL'].contains(key) ||
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
    );
  }

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
