import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/privacy_controller.dart';
import '../data/privacy_models.dart';
import 'privacy_choice.dart';
import 'privacy_frame.dart';
import 'privacy_strings.dart';

class PrivacyDetailPage extends StatefulWidget {
  const PrivacyDetailPage({
    super.key,
    required this.controller,
    required this.section,
  });
  final PrivacyController controller;
  final PrivacySection section;
  @override
  State<PrivacyDetailPage> createState() => _PrivacyDetailPageState();
}

class _PrivacyDetailPageState extends State<PrivacyDetailPage> {
  PrivacyController get c => widget.controller;
  DataRight _type = DataRight.access;
  final _confirmation = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(c.enter(widget.section));
    });
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  bool get enabled =>
      c.active && !c.busy && !c.loading && !c.sharing && c.retrySeconds == 0;
  Future<bool> _confirm(
    String title,
    String body, {
    String action = 'Confirmer',
  }) => confirmAction(context, title, body, action: action);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      final title = switch (widget.section) {
        PrivacySection.sessions => 'Mes sessions',
        PrivacySection.blocks => 'Personnes bloquées',
        PrivacySection.rights => 'Mes demandes de données',
        PrivacySection.export => 'Exporter mes données',
        PrivacySection.deletion => 'Supprimer mon compte',
      };
      return PopScope(
        canPop: !c.deleting && !c.sharing,
        child: PrivacyFrame(
          title: title,
          children: [
            if (c.loading || c.busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: LinearProgressIndicator(
                  semanticsLabel: 'Opération en cours',
                ),
              ),
            if (c.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(privacyNotice(c.notice)),
                ),
              ),
            if (c.failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(privacyFailure(c.failure!)),
                ),
              ),
            if (c.retrySeconds > 0)
              Text('Nouvel essai possible dans ${c.retrySeconds} s'),
            ...switch (widget.section) {
              PrivacySection.sessions => _sessions(),
              PrivacySection.blocks => _blocks(),
              PrivacySection.rights => _rights(),
              PrivacySection.export => _export(),
              PrivacySection.deletion => _delete(),
            },
          ],
        ),
      );
    },
  );
  List<Widget> _sessions() => [
    const Text(
      'Fermer une session retire son accès à votre compte. Les dates sont affichées dans l’heure de cet appareil.',
    ),
    const SizedBox(height: 16),
    if (c.pendingRevoke != null)
      const Text(
        'Une révocation reste à confirmer. Actualisez la liste, puis reprenez la même session si elle est toujours présente.',
      ),
    for (final session in c.sessions)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                session.current ? 'Cet appareil' : 'Autre session',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Créée le ${privacyDate(session.createdAt)}'),
              Text(
                'Dernier renouvellement le ${privacyDate(session.refreshedAt)}',
              ),
              Text('Expire le ${privacyDate(session.expiresAt)}'),
              OutlinedButton(
                onPressed:
                    enabled &&
                        (c.pendingRevoke == null ||
                            c.pendingRevoke == session.id)
                    ? () async {
                        if (await _confirm(
                              'Fermer cette session ?',
                              session.current
                                  ? 'Vous serez déconnecté sur cet appareil.'
                                  : 'Cet accès sera révoqué. L’appareil concerné devra se reconnecter.',
                            ) &&
                            mounted) {
                          await c.revoke(session);
                        }
                      }
                    : null,
                child: Text(
                  c.pendingRevoke == session.id
                      ? 'Reprendre la révocation'
                      : 'Fermer cette session',
                ),
              ),
            ],
          ),
        ),
      ),
    if (!c.loading && c.sessions.isEmpty) const Text('Aucune session chargée.'),
    OutlinedButton(
      onPressed: enabled ? c.load : null,
      child: const Text('Actualiser les sessions'),
    ),
    if (c.cursor != null)
      OutlinedButton(
        onPressed: enabled ? () => c.load(more: true) : null,
        child: const Text('Charger la suite'),
      ),
    const SizedBox(height: 20),
    TextButton(
      onPressed: enabled
          ? () async {
              if (await _confirm(
                    'Fermer toutes les sessions ?',
                    'Vous serez également déconnecté sur cet appareil.',
                    action: 'Tout fermer',
                  ) &&
                  mounted) {
                await c.session.logoutEverywhere();
              }
            }
          : null,
      child: const Text('Fermer toutes mes sessions'),
    ),
  ];
  List<Widget> _blocks() => [
    const Text(
      'Débloquer une personne ne rétablit aucune ancienne rencontre ni conversation.',
    ),
    if (c.pendingUnblock != null)
      const Text(
        'Un déblocage reste à confirmer. Actualisez avant de reprendre la même demande.',
      ),
    const SizedBox(height: 16),
    for (final person in c.blocks)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                person.firstname ?? 'Profil bloqué',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Bloqué le ${privacyDate(person.blockedAt)}'),
              OutlinedButton(
                onPressed:
                    enabled &&
                        (c.pendingUnblock == null ||
                            c.pendingUnblock == person.id)
                    ? () async {
                        if (await _confirm(
                              'Débloquer cette personne ?',
                              'Vous pourrez à nouveau vous découvrir selon vos préférences. Les anciens échanges restent fermés.',
                              action: 'Débloquer',
                            ) &&
                            mounted) {
                          await c.unblock(person.id);
                        }
                      }
                    : null,
                child: Text(
                  c.pendingUnblock == person.id
                      ? 'Reprendre le déblocage'
                      : 'Débloquer',
                ),
              ),
            ],
          ),
        ),
      ),
    if (!c.loading && c.blocks.isEmpty)
      const Text('Aucune personne bloquée dans cette liste.'),
    OutlinedButton(
      onPressed: enabled ? c.load : null,
      child: const Text('Actualiser les blocages'),
    ),
  ];
  List<Widget> _rights() => [
    const Text(
      'Ces demandes sont transmises pour traitement. Une demande d’effacement ici ne ferme pas immédiatement votre compte. Pour le fermer dès maintenant, utilisez « Supprimer mon compte » dans votre espace de confidentialité.',
    ),
    const SizedBox(height: 24),
    PrivacyChoice<DataRight>(
      key: const Key('privacy-right-choice'),
      value: c.pendingRight ?? _type,
      label: 'Votre démarche',
      choices: {for (final type in DataRight.values) type: rightLabel(type)},
      onChanged: enabled && c.pendingRight == null
          ? (value) => setState(() => _type = value)
          : null,
    ),
    if (c.pendingRight != null)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'La réponse reste à confirmer. Actualisez le suivi avant de reprendre cette même démarche.',
        ),
      ),
    HistaeButton(
      onPressed: enabled
          ? () async {
              final type = c.pendingRight ?? _type;
              if (await _confirm(
                    'Transmettre cette demande ?',
                    '${rightLabel(type)} : cette démarche sera enregistrée pour traitement. Son état sera visible dans le suivi.',
                    action: 'Transmettre',
                  ) &&
                  mounted) {
                await c.request(type);
              }
            }
          : null,
      child: Text(
        c.pendingRight == null
            ? 'Transmettre ma demande'
            : 'Reprendre cette demande',
      ),
    ),
    const SizedBox(height: 24),
    Text(
      'Le suivi de vos demandes',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    for (final request in c.rights)
      Card(
        child: ListTile(
          title: Text(rightLabel(request.type)),
          subtitle: Text(
            '${rightStatus(request.status)} · ${privacyDate(request.requestedAt)}${request.completedAt == null ? '' : '\nTerminée le ${privacyDate(request.completedAt!)}'}',
          ),
        ),
      ),
    if (!c.loading && c.rights.isEmpty)
      const Text('Aucune demande dans votre suivi.'),
    OutlinedButton(
      onPressed: enabled ? c.load : null,
      child: const Text('Actualiser le suivi'),
    ),
  ];
  List<Widget> _export() => [
    const EditorialCard(
      eyebrow: 'UNE COPIE POUR VOUS',
      title: 'Vos données,\nà portée de main.',
      body: 'Votre export contient des informations personnelles. Il est téléchargé dans un espace temporaire privé. Vous choisissez ensuite où le partager.',
    ),
    const SizedBox(height: 20),
    const Text(
      'La préparation peut prendre quelques minutes. Le fichier temporaire est nettoyé à la sortie ou en arrière-plan. Pendant un partage, il est conservé jusqu’au retour dans Histae. Une copie enregistrée par la destination dépend de celle-ci.',
    ),
    const SizedBox(height: 20),
    HistaeButton.icon(
      onPressed: enabled ? c.downloadExport : null,
      icon: const Icon(Icons.download_outlined),
      label: Text(
        c.exportPath == null
            ? 'Télécharger mon export'
            : 'Télécharger à nouveau',
      ),
    ),
    if (c.exportPath != null) ...[
      Builder(
        builder: (buttonContext) => OutlinedButton.icon(
          onPressed: enabled
              ? () async {
                  if (!await _confirm(
                        'Partager votre export ?',
                        'Choisissez une destination de confiance pour ce fichier personnel.',
                        action: 'Choisir une destination',
                      ) ||
                      !buttonContext.mounted) {
                    return;
                  }
                  final box = buttonContext.findRenderObject();
                  if (box is! RenderBox || !box.hasSize) return;
                  final origin = box.localToGlobal(Offset.zero) & box.size;
                  await c.shareExport((path) async {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(path, mimeType: 'application/json')],
                        title: 'Mon export Histae',
                        sharePositionOrigin: origin,
                      ),
                    );
                  });
                }
              : null,
          icon: const Icon(Icons.ios_share),
          label: const Text('Choisir où partager le fichier'),
        ),
      ),
    ],
    TextButton(
      onPressed: enabled ? c.clearExport : null,
      child: const Text('Effacer le fichier temporaire'),
    ),
  ];
  List<Widget> _delete() => [
    const EditorialCard(
      eyebrow: 'UNE DÉCISION PERSONNELLE',
      title: 'Clore ce\nchapitre.',
      body: 'La suppression ferme votre compte et vos sessions. Vos rencontres et vos échanges deviennent inaccessibles. Cette action est irréversible.',
    ),
    const SizedBox(height: 24),
    const Text(
      'Une fois la demande acceptée, le nettoyage de vos données continue en arrière-plan. Vous pouvez exporter vos données avant de poursuivre. En cas de réponse perdue, l’app fermera la session locale sans annoncer une suppression confirmée.',
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _confirmation,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(
        labelText: 'Écrivez SUPPRIMER pour confirmer',
      ),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 20),
    HistaeButton(
      onPressed: enabled && _confirmation.text == 'SUPPRIMER'
          ? () async {
              if (await _confirm(
                    'Supprimer définitivement votre compte ?',
                    'Votre compte sera fermé dès l’acceptation de la demande. Le nettoyage continuera ensuite en arrière-plan.',
                    action: 'Supprimer mon compte',
                  ) &&
                  mounted) {
                _confirmation.clear();
                await c.erase();
              }
            }
          : null,
      child: Text(
        c.deleting
            ? 'Demande en cours…'
            : 'Supprimer définitivement mon compte',
      ),
    ),
  ];
}
