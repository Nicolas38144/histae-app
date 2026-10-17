import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/config/app_config.dart';
import '../features/privacy/data/private_export_store.dart';
import 'app_dependencies.dart';

Future<AppDependencies> bootstrap() async {
  try {
    await PrivateExportStore().clean();
  } catch (_) {
    // The privacy hub exposes cleanup failure and permits a later retry.
  }
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'DM Serif Display',
    ], await rootBundle.loadString('assets/fonts/dm_serif_display/OFL.txt'));
  });
  try {
    return AppDependencies.fromConfig(
      AppConfig.fromDotEnv(
        await rootBundle.loadString('.env'),
        isDebug: kDebugMode,
      ),
    );
  } on FormatException {
    // Invalid configuration may contain secrets: never log its source.
    return const AppDependencies();
  } on FlutterError {
    // Missing assets have no fallback host or credentials.
    return const AppDependencies();
  }
}
