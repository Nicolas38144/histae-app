import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../catalog/application/catalog_controller.dart';
import '../../catalog/data/plan_catalog.dart';
import '../../catalog/presentation/plan_card.dart';

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
  final Future<void> Function(SubscriptionOffer offer) onChoose;
  @override
  Widget build(BuildContext context) {
    if (catalog.status == CatalogStatus.loading ||
        catalog.status == CatalogStatus.idle) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Chargement des formules',
      );
    }
    if (catalog.failure != null || catalog.offers.isEmpty) {
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
        for (final offer in catalog.offers)
          PlanCard(
            plan: catalog.plans.firstWhere(
              (plan) => plan.code == offer.planCode,
            ),
            offer: offer,
            action:
                offer.billingPeriod != null &&
                    paymentsAvailable &&
                    canSubscribe &&
                    hasPending == false
                ? HistaeButton(
                    onPressed: canAct ? () => onChoose(offer) : null,
                    child: Text('Choisir ${offer.displayName}'),
                  )
                : null,
          ),
      ],
    );
  }
}
