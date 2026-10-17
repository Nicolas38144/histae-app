import 'package:flutter/material.dart';

import '../data/billing_models.dart';
import 'billing_strings.dart';

class SubscriptionSummary extends StatelessWidget {
  const SubscriptionSummary({super.key, required this.state});
  final SubscriptionState state;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.plan == 'premium' ? 'Histae Premium' : 'Histae Gratuit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(BillingStrings.status(state.status)),
          Text(
            state.accessGranted
                ? 'Accès Premium confirmé lors de la dernière vérification.'
                : 'Votre accès actuel correspond à la formule gratuite.',
          ),
          if (state.billingPeriod != null)
            Text(
              state.billingPeriod == BillingPeriod.monthly
                  ? 'Rythme mensuel'
                  : 'Rythme annuel',
            ),
          if (state.trialEnd != null)
            Text('Fin de l’essai : ${BillingStrings.date(state.trialEnd!)}'),
          if (state.periodStart != null)
            Text(
              'Début de période : ${BillingStrings.date(state.periodStart!)}',
            ),
          if (state.periodEnd != null)
            Text('Fin de période : ${BillingStrings.date(state.periodEnd!)}'),
          if (state.cancelAtPeriodEnd)
            const Text('Résiliation prévue à la fin de la période en cours.'),
          if (state.canceledAt != null)
            Text(
              'Résiliation enregistrée le ${BillingStrings.date(state.canceledAt!)}',
            ),
          if (state.status == 'past_due')
            const Text(
              'Votre paiement demande une régularisation. Les droits affichés sont ceux confirmés par Histae.',
            ),
        ],
      ),
    ),
  );
}
