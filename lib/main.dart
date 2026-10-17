import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await bootstrap();
  runApp(
    HistaeApp(
      catalogRepository: dependencies.catalog,
      sessionController: dependencies.session,
      pushController: dependencies.push,
      billingController: dependencies.billing,
    ),
  );
}
