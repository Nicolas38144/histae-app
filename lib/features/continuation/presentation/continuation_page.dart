import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../matches/data/match_models.dart';
import '../../matches/presentation/matches_strings.dart';
import '../application/continuation_controller.dart';
import 'continuation_strings.dart';
import 'credits_page.dart';
import 'partner_photo_page.dart';

class ContinuationPage extends StatefulWidget {
  const ContinuationPage({
    super.key,
    required this.controller,
    required this.matchId,
  });
  final ContinuationController controller;
  final String matchId;
  @override
  State<ContinuationPage> createState() => _ContinuationPageState();
}

class _ContinuationPageState extends State<ContinuationPage>
    with WidgetsBindingObserver {
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
    await c.access.refresh();
    if (mounted && c.access.session.resourceKey == _key) await c.activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.suspend(notify: false);
    super.dispose();
  }

  Future<void> _continue() async {
    final offer = await c.prepareContinuation();
    if (!mounted || offer == null) return;
    final accepted = await confirmAction(
      context,
      'Poursuivre cette rencontre ?',
      offer.cost == 0
          ? 'Votre accord ne nécessite aucun crédit avec votre formule actuelle. Chacun fait son propre choix. La conversation reprend après deux accords valides.'
          : 'Vous acceptez un coût maximal de 1 crédit pour votre propre accord. Le serveur réserve ce crédit et le débite après deux accords valides. Une clôture ultérieure ne rembourse pas un crédit déjà débité.',
      action: offer.cost == 0
          ? 'Continuer sans crédit'
          : 'Accepter 1 crédit maximum',
    );
    if (accepted && mounted) await c.accept(offer);
  }

  Future<void> _reveal() async {
    if (await confirmAction(
          context,
          'Révéler vos photos ?',
          'Votre photo pourra être visible dans cette rencontre après un accord mutuel. Ce choix est indépendant de la continuation et ne rend pas votre photo visible dans le feed.',
          action: 'Donner mon accord',
        ) &&
        mounted) {
      await c.reveal();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.access]),
    builder: (context, _) {
      final m = c.match?.id == widget.matchId ? c.match : null;
      final allowed =
          c.accessible &&
          c.access.session.resourceKey == _key &&
          m?.historyAllowed == true;
      return HistaeScaffold(
        appBar: AppBar(title: const Text('Votre rencontre')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!allowed)
                const EditorialCard(
                  title: 'Cette rencontre\nn’est plus disponible.',
                  body: 'Revenez à vos rencontres pour relire leur état.',
                )
              else ...[
                EditorialCard(
                  eyebrow: m!.partner.firstname.toUpperCase(),
                  title: 'La suite\ns’écrit à deux.',
                  body: MatchesStrings.stateBody(m),
                ),
                if (c.loading || c.busy || !c.access.verified)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Actualisation de la rencontre',
                  ),
                if (c.failure case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(ContinuationStrings.failure(error)),
                  ),
                if (c.notice == 'cost_changed')
                  const Text(
                    'Le coût doit être relu et présenté à nouveau avant votre accord.',
                  ),
                const EditorialDivider(),
                Text(
                  'Se voir, à deux.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La révélation des photos demande un accord distinct de chaque personne. Votre formule ne remplace jamais ces accords.',
                ),
                if (c.myRevealed)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Votre accord de révélation est enregistré.'),
                  ),
                if (m.photosRevealed) ...[
                  const Text('La révélation mutuelle est confirmée.'),
                  if (m.partner.photo == null)
                    const Text('La photo n’est pas disponible actuellement.')
                  else
                    HistaeButton.icon(
                      onPressed: !c.access.verified
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PartnerPhotoPage(
                                  access: c.access,
                                  matchId: m.id,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Voir sa photo'),
                    ),
                ] else if (c.pendingReveal) ...[
                  const Text('Votre demande de révélation reste à confirmer.'),
                  OutlinedButton(
                    onPressed: c.canReveal ? c.reveal : null,
                    child: const Text('Reprendre le même accord de révélation'),
                  ),
                ] else if (!c.myRevealed)
                  OutlinedButton.icon(
                    onPressed: c.canReveal ? _reveal : null,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Choisir de révéler les photos'),
                  ),
                const EditorialDivider(),
                Text(
                  'Continuer cette conversation',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (m.status == MatchStatus.active)
                  Text(
                    'Votre période de décision s’ouvrira après les premiers échanges. Échéance actuelle : ${MatchesStrings.date(m.expiresAt)}.',
                  ),
                if (m.status == MatchStatus.confirmed)
                  const Text(
                    'Votre conversation est ouverte. Les conditions de continuation sont réunies.',
                  ),
                if (m.status == MatchStatus.awaitingContinuation) ...[
                  Text(
                    'Décision possible jusqu’au ${MatchesStrings.date(m.expiresAt)}. Vous pouvez toujours relire vos échanges.',
                  ),
                  if (c.myContinued)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Votre choix de continuer est enregistré. La conversation reprend lorsque les conditions de continuation sont réunies.',
                      ),
                    )
                  else if (c.pendingCost case final cost?) ...[
                    Text(
                      'Cette demande reste à confirmer, avec un coût maximal accepté de $cost crédit${cost == 1 ? '' : 's'}. Aucun nouvel accord avec un autre coût ne sera envoyé.',
                    ),
                    HistaeButton(
                      onPressed: c.canContinue ? c.resumeContinuation : null,
                      child: const Text('Reprendre le même accord'),
                    ),
                  ] else ...[
                    if (c.quota case final q?)
                      Text(
                        q.premium
                            ? 'Votre formule actuelle : aucun crédit nécessaire pour votre accord.'
                            : '${q.remaining} nouvelle(s) continuation(s) disponible(s). Votre accord coûte au maximum 1 crédit.',
                      ),
                    HistaeButton(
                      onPressed:
                          c.canContinue &&
                              c.quota?.canStart == true &&
                              c.quotaReadAt != null
                          ? _continue
                          : null,
                      child: const Text('Lire le coût et choisir de continuer'),
                    ),
                    if (c.quota?.canStart == false)
                      const Text(
                        'Votre quota ne permet pas de nouvelle continuation actuellement.',
                      ),
                  ],
                ],
                TextButton(
                  onPressed: c.busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CreditsPage(controller: c),
                            ),
                          );
                          if (mounted) await c.activate();
                        },
                  child: const Text('Voir mes crédits'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chaque personne choisit indépendamment. Le choix de l’autre personne reste privé. Vous pouvez terminer la rencontre depuis les options de la conversation.',
                ),
                if (c.retrySeconds > 0)
                  Text('Nouvel essai possible dans ${c.retrySeconds} s'),
                OutlinedButton.icon(
                  onPressed: c.busy || c.loading || c.retrySeconds > 0
                      ? null
                      : _start,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualiser la rencontre et mes crédits'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
