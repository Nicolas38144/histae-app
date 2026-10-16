import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/session_vault.dart';
import 'features/auth/application/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'DM Serif Display',
    ], await rootBundle.loadString('assets/fonts/dm_serif_display/OFL.txt'));
  });
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
      sessionController: config == null
          ? null
          : SessionController(
              AuthRepository(ApiClient(origin: config.apiOrigin)),
              SecureSessionVault(),
            ),
    ),
  );
}
