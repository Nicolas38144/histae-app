import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/catalog/data/catalog_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig? config;
  try {
    config = AppConfig.fromValues(
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      ),
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: AppConfig.defaultApiBaseUrl,
      ),
      isDebug: kDebugMode,
    );
  } on FormatException {
    // Do not log invalid configuration: it might contain credentials.
  }
  runApp(
    HistaeApp(
      catalogRepository: config == null
          ? null
          : CatalogRepository(ApiClient(origin: config.apiOrigin)),
    ),
  );
}
