import 'package:flutter/material.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../application/report_controller.dart';
import '../data/privacy_models.dart';
import '../data/privacy_repository.dart';
import 'privacy_choice.dart';
import 'privacy_strings.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    required this.session,
    required this.target,
    this.matchId,
    this.onBlock,
  });
  final AuthenticatedSession session;
  final String target;
  final String? matchId;
  final Future<void> Function()? onBlock;
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late final c = ReportController(
    PrivacyRepository(widget.session),
    widget.target,
    matchId: widget.matchId,
  );
  final _text = TextEditingController();
  ReportReason _reason = ReportReason.inappropriateContent;
  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  void _changed() {
    if (!c.accessible || c.submitted) _text.clear();
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      final editable = !c.sending && c.pending == null && !c.submitted;
      return HistaeScaffold(
        appBar: AppBar(title: const Text('Signaler un profil')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const EditorialCard(
                    eyebrow: 'PRENDRE SOIN DES ÉCHANGES',
                    title: 'Un espace\noù se sentir bien.',
                    body: 'Votre signalement sera transmis pour examen. Le blocage est un choix distinct, disponible après l’envoi.',
                  ),
                  const SizedBox(height: 24),
                  if (!c.submitted) ...[
                    PrivacyChoice<ReportReason>(
                      value: _reason,
                      label: 'Motif',
                      choices: {
                        for (final reason in ReportReason.values)
                          reason: reasonLabel(reason),
                      },
                      onChanged: editable
                          ? (value) => setState(() => _reason = value)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      enabled: editable,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Description (facultative)',
                        alignLabelWithHint: true,
                        helperText: 'Un court récit des faits suffit.',
                      ),
                    ),
                    if (c.validation != null) Text(c.validation!),
                    if (c.pending != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'La réponse reste à confirmer. Seul ce même signalement pourra être renvoyé. Revenir en arrière abandonne le brouillon local, sans annuler un éventuel envoi.',
                        ),
                      ),
                    if (c.failure != null) Text(privacyFailure(c.failure!)),
                    if (c.retrySeconds > 0)
                      Text('Nouvel essai possible dans ${c.retrySeconds} s'),
                    const SizedBox(height: 20),
                    HistaeButton(
                      onPressed: c.sending || c.retrySeconds > 0
                          ? null
                          : () => c.submit(_reason, _text.text),
                      child: Text(
                        c.sending
                            ? 'Envoi en cours…'
                            : c.pending != null
                            ? 'Reprendre ce signalement'
                            : 'Envoyer le signalement',
                      ),
                    ),
                  ] else ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        c.alreadyPending
                            ? 'Un signalement de cette personne est déjà en attente de traitement.'
                            : 'Votre signalement a été reçu. Merci de nous avoir alertés.',
                      ),
                    ),
                    if (widget.onBlock != null)
                      OutlinedButton(
                        onPressed: () async {
                          if (!await confirmAction(
                                context,
                                'Bloquer cette personne ?',
                                'Les échanges seront terminés. Vos anciennes rencontres ne seront pas rétablies après un déblocage.',
                                action: 'Bloquer',
                              ) ||
                              !context.mounted ||
                              !c.accessible) {
                            return;
                          }
                          await widget.onBlock!();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Bloquer aussi cette personne'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
