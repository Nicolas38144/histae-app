import 'dart:io';

import 'package:histae_app/core/config/app_config.dart';
import 'package:histae_app/core/network/api_client.dart';
import 'package:histae_app/core/network/api_failure.dart';
import 'package:histae_app/features/catalog/data/catalog_repository.dart';

// Explicit, read-only integration check. Never executed by the unit test suite.
Future<void> main() async {
  final AppConfig config;
  try {
    config = AppConfig.fromDotEnv(
      await File('.env').readAsString(),
      isDebug: false,
    );
  } catch (_) {
    stderr.writeln('Configuration .env absente ou invalide.');
    exitCode = 1;
    return;
  }
  final repository = CatalogRepository(ApiClient(origin: config.apiOrigin));
  try {
    final catalog = await repository.load(RequestCancellation());
    stdout.writeln(
      'Catalogue public lu et décodé : ${catalog.offers.length} offres, ${catalog.plans.length} niveaux de droits.',
    );
  } on ApiFailure catch (error) {
    stderr.writeln('Échec du catalogue : ${error.kind.name}.');
    exitCode = 1;
  } finally {
    repository.close();
  }
}
