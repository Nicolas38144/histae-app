import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/core/config/app_config.dart';

void main() {
  test(
    'uses the API host supplied by the user with exactly one /api prefix',
    () {
      final config = AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: AppConfig.defaultApiBaseUrl,
        isDebug: false,
      );
      expect(
        config.apiOrigin.resolve('/api/plans').toString(),
        'https://api.histae.com/api/plans',
      );
    },
  );
  test('keeps an origin without duplicating /api', () {
    final config = AppConfig.fromValues(
      environment: 'development',
      apiBaseUrl: 'http://10.0.2.2:8080/',
      isDebug: true,
    );
    expect(
      config.apiOrigin.resolve('/api/plans').toString(),
      'http://10.0.2.2:8080/api/plans',
    );
  });

  for (final origin in [
    '',
    'localhost:8080',
    'https://api.example/api',
    'https://api.example?token=private',
    'https://api.example#fragment',
    'https://user:private@api.example',
    'file:///tmp/api',
  ]) {
    test('rejects missing, non-HTTP or non-origin configuration: $origin', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          apiBaseUrl: origin,
          isDebug: true,
        ),
        throwsFormatException,
      );
    });
  }
  test('rejects an unknown environment', () {
    expect(
      () => AppConfig.fromValues(
        environment: 'prod',
        apiBaseUrl: 'https://api.example',
        isDebug: true,
      ),
      throwsFormatException,
    );
  });
  test('production and distributed builds require HTTPS', () {
    for (final env in ['development', 'staging', 'production']) {
      expect(
        () => AppConfig.fromValues(
          environment: env,
          apiBaseUrl: 'http://192.168.1.10:8080',
          isDebug: false,
        ),
        throwsFormatException,
      );
    }
    for (final env in ['staging', 'production']) {
      expect(
        () => AppConfig.fromValues(
          environment: env,
          apiBaseUrl: 'http://192.168.1.10:8080',
          isDebug: true,
        ),
        throwsFormatException,
      );
    }
    expect(
      AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'https://api.example',
        isDebug: false,
      ).environment,
      AppEnvironment.production,
    );
  });
}
