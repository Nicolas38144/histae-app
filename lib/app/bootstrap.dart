import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/config/app_config.dart';
import '../core/l10n/locale_controller.dart';
import '../features/privacy/data/private_export_store.dart';
import 'app_dependencies.dart';

Future<AppDependencies> bootstrap({LocaleController? locale}) async {
  try {
    await PrivateExportStore().clean();
  } catch (_) {
    // The privacy hub exposes cleanup failure and permits a later retry.
  }
  LicenseRegistry.addLicense(() async* {
    for (final font in [
      ('Inter', 'assets/fonts/inter/OFL.txt'),
      ('Source Serif 4', 'assets/fonts/source_serif_4/OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        font.$1,
      ], await rootBundle.loadString(font.$2));
    }
  });
  try {
    return AppDependencies.fromConfig(
      AppConfig.fromDotEnv(
        await rootBundle.loadString('.env'),
        isDebug: kDebugMode,
      ),
      locale: locale,
    );
  } on FormatException {
    // Invalid configuration may contain secrets: never log its source.
    return const AppDependencies();
  } on FlutterError {
    // Missing assets have no fallback host or credentials.
    return const AppDependencies();
  }
}
