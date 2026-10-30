import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final locale = LocaleController(store: const SecureLocalePreferenceStore());
  await locale.restore();
  final dependencies = await bootstrap(locale: locale);
  await dependencies.reading?.load();
  runApp(
    HistaeApp(
      localeController: locale,
      catalogRepository: dependencies.catalog,
      sessionController: dependencies.session,
      pushController: dependencies.push,
      billingController: dependencies.billing,
      rewardedVideoGateway: dependencies.videos,
      repositories: dependencies.repositories,
      helpController: dependencies.help,
      readingController: dependencies.reading,
      updateController: dependencies.updates,
    ),
  );
}
