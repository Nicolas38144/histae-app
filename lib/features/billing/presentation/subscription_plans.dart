import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/subscription_plan.dart';
import '../../catalog/presentation/plan_card.dart';
import '../data/billing_models.dart';

class SubscriptionPlans extends StatelessWidget {
  const SubscriptionPlans({
    super.key,
    required this.catalog,
    required this.paymentsAvailable,
    required this.canSubscribe,
    required this.hasPending,
    required this.canAct,
    required this.onChoose,
  });
  final CatalogController catalog;
  final bool paymentsAvailable, canSubscribe, hasPending, canAct;
  final Future<void> Function(SubscriptionPlan plan, BillingPeriod period)
  onChoose;
  @override
  Widget build(BuildContext context) {
    if (catalog.status == CatalogStatus.loading ||
        catalog.status == CatalogStatus.idle) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Chargement des formules',
      );
    }
    if (catalog.failure != null || catalog.plans.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            catalog.failure == null
                ? 'Aucune formule disponible.'
                : 'Les formules ne sont pas disponibles pour le moment.',
          ),
          OutlinedButton(
            onPressed: catalog.retrySeconds > 0 ? null : catalog.load,
            child: Text(
              catalog.retrySeconds > 0
                  ? AppStrings.of(context).retryIn(catalog.retrySeconds)
                  : 'Actualiser les formules',
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final plan in catalog.plans)
          PlanCard(
            plan: plan,
            action:
                plan.code == 'premium' &&
                    paymentsAvailable &&
                    canSubscribe &&
                    hasPending == false
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: canAct
                            ? () => onChoose(plan, BillingPeriod.monthly)
                            : null,
                        child: const Text('Choisir le rythme mensuel'),
                      ),
                      OutlinedButton(
                        onPressed: canAct
                            ? () => onChoose(plan, BillingPeriod.annual)
                            : null,
                        child: const Text('Choisir le rythme annuel'),
                      ),
                    ],
                  )
                : null,
          ),
      ],
    );
  }
}
