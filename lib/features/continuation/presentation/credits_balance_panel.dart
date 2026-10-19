import 'package:flutter/material.dart';

import '../data/continuation_models.dart';

class CreditsBalancePanel extends StatelessWidget {
  const CreditsBalancePanel({super.key, required this.quota});
  final ContinuationQuota quota;

  @override
  Widget build(BuildContext context) {
    final q = quota, theme = Theme.of(context), colors = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.primary.withValues(alpha: .3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: .65),
            colors.surfaceContainerLow,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'VOTRE SOLDE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  q.premium ? 'Premium' : 'Histae Free',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (q.premium) ...[
            Icon(Icons.all_inclusive_rounded, size: 52, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              'Le temps de vous découvrir.',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Vos continuations ne nécessitent aucun crédit. Chacun reste libre de poursuivre la rencontre.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Semantics(
              label: '${q.remaining} nouvelles continuations disponibles',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    '${q.remaining}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 76,
                      height: 1,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.remaining == 1
                        ? 'continuation disponible'
                        : 'continuations disponibles',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Flex(
              direction: largeText ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: largeText ? 0 : 1,
                  child: _Balance(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Gratuits',
                    count: q.freeRemaining,
                    color: colors.primary,
                  ),
                ),
                SizedBox(width: largeText ? 0 : 12, height: largeText ? 12 : 0),
                Flexible(
                  flex: largeText ? 0 : 1,
                  child: _Balance(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Vidéos',
                    count: q.advertisingRemaining,
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Soldes disponibles, hors crédits réservés.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: theme.textTheme.headlineMedium?.copyWith(color: color),
          ),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class CreditsWeekPanel extends StatelessWidget {
  const CreditsWeekPanel({super.key, required this.quota});
  final ContinuationQuota quota;
  @override
  Widget build(BuildContext context) {
    final q = quota, theme = Theme.of(context), colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cette semaine', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '${q.used} / ${q.weeklyLimit} continuations confirmées',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: q.weeklyLimit == 0
                  ? 0
                  : (q.used / q.weeklyLimit!).clamp(0, 1),
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
              semanticsLabel:
                  'Continuations confirmées cette semaine : ${q.used} sur ${q.weeklyLimit}',
            ),
            const SizedBox(height: 14),
            Text(
              '${q.weeklyCredits} crédits gratuits renouvelés le lundi à 00 h UTC.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (q.remaining == 0) ...[
              const SizedBox(height: 10),
              const Text(
                'Aucune nouvelle continuation disponible actuellement. Le solde tient compte du plafond de la semaine et des réservations.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CreditsExplanation extends StatelessWidget {
  const CreditsExplanation({super.key, required this.quota});
  final ContinuationQuota quota;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: const Text('Comprendre mes crédits'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${quota.reserved} crédit${quota.reserved == 1 ? '' : 's'} réservé${quota.reserved == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Un crédit est réservé lorsque vous choisissez de continuer. Il est débité une fois les deux accords confirmés. Un crédit déjà débité n’est pas remboursé à la clôture.',
            ),
            const SizedBox(height: 16),
            Text(
              'Réserve vidéo : ${quota.advertisingBalance} / ${quota.stockLimit}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Les crédits vidéo sont conservés, réservations comprises. Les crédits gratuits sont renouvelés chaque semaine, sans cumul. Une réservation peut rester rattachée à la semaine de votre accord.',
            ),
          ],
        ),
      ],
    ),
  );
}
