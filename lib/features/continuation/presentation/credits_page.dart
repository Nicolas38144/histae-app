import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/continuation_controller.dart';
import '../data/continuation_models.dart';
import 'continuation_strings.dart';

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key, required this.controller});
  final ContinuationController controller;
  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> with WidgetsBindingObserver {
  ContinuationController get c => widget.controller;
  late final _key = c.access.session.resourceKey;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    await c.activate();
    if (mounted && c.accessible) c.rewards.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    } else {
      c.suspend();
    }
  }

  Future<void> _resume() async {
    await c.access.session.synchronize();
    if (mounted && c.access.session.resourceKey == _key) await _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.suspend(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.rewards]),
    builder: (context, _) {
      if (!c.accessible || c.access.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final q = c.quota, reward = c.rewards;
      return HistaeScaffold(
        appBar: AppBar(title: const Text('Vos crédits')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await c.activate();
              if (reward.intent != null) await reward.refresh();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const EditorialCard(
                  eyebrow: 'LE TEMPS DE CONTINUER',
                  title: 'À votre rythme.',
                  body: 'Vos crédits servent à choisir de poursuivre une rencontre. Chacun confirme son propre choix.',
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Regarder une vidéo'),
                ),
                const SizedBox(height: 8),
                Text(
                  q?.premium == true
                      ? 'Votre formule Premium n’utilise pas de vidéos récompensées.'
                      : 'Les vidéos récompensées ne sont pas encore disponibles dans cette version. Vos crédits gratuits restent accessibles.',
                ),
                const SizedBox(height: 24),
                if (c.loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Lecture de vos crédits',
                  ),
                if (c.failure case final error?)
                  Text(ContinuationStrings.failure(error)),
                if (q != null) ...[
                  Text(
                    q.premium ? 'Votre formule Premium' : 'Votre formule Free',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (c.quotaReadAt == null)
                    const Text(
                      'Ce solde doit être actualisé avant toute décision.',
                    ),
                  if (q.premium)
                    const Text(
                      'Aucun crédit nécessaire pour votre accord de continuation. Le choix de chaque personne reste indépendant.',
                    )
                  else ...[
                    _count('Nouvelles continuations disponibles', q.remaining!),
                    _count('Crédits gratuits disponibles', q.freeRemaining),
                    _count('Allocation gratuite hebdomadaire', q.weeklyCredits),
                    _count('Continuations confirmées cette semaine', q.used),
                    _count('Plafond hebdomadaire', q.weeklyLimit!),
                    _count(
                      'Crédits publicitaires disponibles',
                      q.advertisingRemaining,
                    ),
                  ],
                  _count('Crédits réservés', q.reserved),
                  _count(
                    'Stock publicitaire total, réservations incluses',
                    q.advertisingBalance,
                  ),
                  _count('Capacité du stock publicitaire', q.stockLimit),
                  const SizedBox(height: 16),
                  const Text(
                    'Les crédits gratuits sont renouvelés chaque lundi à 00 h UTC, sans cumul. Le stock publicitaire est conservé. Une réservation peut rester rattachée à la semaine de votre accord ; le serveur tient compte des réservations et du plafond dans le solde disponible.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Un crédit réservé n’est débité qu’après deux accords valides. Un crédit déjà débité n’est pas remboursé à la clôture.',
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: c.loading || c.retrySeconds > 0
                      ? null
                      : c.activate,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    c.retrySeconds > 0
                        ? 'Réessayer dans ${c.retrySeconds} s'
                        : 'Actualiser mes crédits',
                  ),
                ),
                const EditorialDivider(),
                Text(
                  'Une vidéo, si vous le souhaitez',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Le crédit est ajouté uniquement après validation de la récompense par le serveur. Le suivi reste accessible si une validation est en attente.',
                ),
                if (c.catalogFailure case final error?)
                  Text(ContinuationStrings.failure(error)),
                if (reward.intent case final intent?) ...[
                  const SizedBox(height: 20),
                  Text(switch (intent.status) {
                    RewardStatus.pending =>
                      'Récompense en cours de validation par le serveur.',
                    RewardStatus.credited =>
                      'Récompense validée. Votre solde a été relu.',
                    RewardStatus.expired => 'La période de visionnage est terminée. Une validation tardive reste possible si la vidéo a été terminée à temps.',
                    RewardStatus.cancelled => 'Cette demande a été annulée.',
                  }),
                  if (reward.failure case final error?)
                    Text(ContinuationStrings.failure(error)),
                  TextButton(
                    onPressed: reward.busy || reward.waiting
                        ? null
                        : reward.refresh,
                    child: const Text('Vérifier la récompense'),
                  ),
                  if (intent.status != RewardStatus.credited &&
                      intent.status != RewardStatus.cancelled)
                    TextButton(
                      onPressed: reward.busy || reward.waiting
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Annuler cette demande ?'),
                                  content: const Text(
                                    'L’annulation empêchera toute validation ultérieure, même si une vidéo déjà terminée est encore en cours de vérification.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Conserver'),
                                    ),
                                    HistaeButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Annuler la demande'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await reward.cancel(
                                  completedVideoWarningAccepted: true,
                                );
                              }
                            },
                      child: const Text('Annuler la demande de récompense'),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _count(String label, int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text('$label : $count'),
  );
}
