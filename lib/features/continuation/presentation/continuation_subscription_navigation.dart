import 'package:flutter/material.dart';

import '../../billing/presentation/billing_scope.dart';
import '../../billing/presentation/subscription_page.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../application/continuation_controller.dart';

/// Reuses the session billing controller and only refreshes changed entitlements.
Future<void> openContinuationSubscription(
  BuildContext context, {
  required ContinuationController credits,
  CatalogRepository? catalog,
}) async {
  final billing = BillingScope.maybeOf(context);
  final key = credits.access.session.resourceKey;
  credits.suspend();
  final route = MaterialPageRoute<void>(
    builder: (_) => billing == null
        ? CatalogPage(repository: catalog)
        : SubscriptionPage(controller: billing, catalog: catalog),
  );
  await Navigator.of(context).push(route);
  await route.completed;
  if (!context.mounted || credits.access.session.resourceKey != key) return;
  await credits.activate();
  if (billing?.subscription != null &&
      billing!.fresh &&
      billing.subscription!.accessGranted != credits.quota?.premium) {
    await credits.loadQuota();
  }
}
