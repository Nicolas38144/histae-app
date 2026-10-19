import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await bootstrap();
  final locale = LocaleController(store: const SecureLocalePreferenceStore());
  await locale.restore();
  runApp(
    HistaeApp(
      localeController: locale,
      catalogRepository: dependencies.catalog,
      sessionController: dependencies.session,
      pushController: dependencies.push,
      billingController: dependencies.billing,
      rewardedVideoGateway: dependencies.videos,
    ),
  );
}
