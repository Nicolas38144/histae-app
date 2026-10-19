import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
import 'profile_editor.dart';
import 'profile_panels.dart';
import 'question_picker.dart';

class AnswersEditor extends StatefulWidget {
  const AnswersEditor({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<AnswersEditor> createState() => _AnswersEditorState();
}

class _AnswerInput {
  _AnswerInput(this.id, this.prompt, String value)
    : text = TextEditingController(text: value);
  final String id, prompt;
  final TextEditingController text;
}

class _AnswersEditorState extends ProfileEditorState<AnswersEditor> {
  @override
  ProfileController get controller => widget.controller;
  late final inputs =
      (controller.answers.toList()
            ..sort((a, b) => a.position.compareTo(b.position)))
          .map((a) => _AnswerInput(a.questionId, a.question, a.answer))
          .toList();
  final removedInputs = <_AnswerInput>[];
  @override
  void dispose() {
    for (final a in [...inputs, ...removedInputs]) {
      a.text.dispose();
    }
    super.dispose();
  }

  Future<void> _addQuestion() async {
    if (busy || inputs.length >= 3) return;
    final question = await pickProfileQuestion(
      context,
      questions: controller.questions,
      selected: inputs.map((a) => a.id).toSet(),
    );
    if (!mounted ||
        busy ||
        question == null ||
        inputs.length >= 3 ||
        inputs.any((a) => a.id == question.id)) {
      return;
    }
    setState(() {
      inputs.add(_AnswerInput(question.id, question.prompt, ''));
      changed();
    });
  }

  @override
  Widget build(BuildContext context) => page(
    'Vos réponses',
    [
      const EditorialCard(
        eyebrow: 'VOS MOTS, VOTRE HISTOIRE',
        title: 'Trois questions.\nMille façons d’être vous.',
        body: 'Choisissez ce que vous souhaitez raconter. Vous décidez aussi de l’ordre de vos réponses.',
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            'Votre sélection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${inputs.length} / 3 réponses',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (inputs.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Votre premier mot.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Une habitude, une envie, une petite chose qui vous rend heureux. Commencez par une question.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      for (var i = 0; i < inputs.length; i++)
        Card(
          key: ValueKey(inputs[i].id),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'RÉPONSE ${(i + 1).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  inputs[i].prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: inputs[i].text,
                  onChanged: (_) => setState(changed),
                  enabled: !busy && !controller.saving,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(
                      RegExp(r'[\r\n]'),
                      replacementString: ' ',
                    ),
                  ],
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Réponse ${i + 1}',
                    alignLabelWithHint: true,
                    helperText: '10 à 300 caractères',
                    helperMaxLines: 2,
                    counterText:
                        '${inputs[i].text.text.trim().runes.length} / 300',
                    counterStyle: TextStyle(
                      color: inputs[i].text.text.trim().runes.length > 300
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!controller.questions.any((q) => q.id == inputs[i].id))
                  const Text(
                    'Cette question n’est plus dans le catalogue. Retirez-la pour enregistrer une nouvelle sélection.',
                  ),
                for (final a in controller.answers.where(
                  (a) => a.questionId == inputs[i].id,
                ))
                  ProfileModerationLabel(moderation: a.moderation),
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Monter la réponse ${i + 1}',
                      onPressed: i == 0 || busy
                          ? null
                          : () => setState(() {
                              final a = inputs.removeAt(i);
                              inputs.insert(i - 1, a);
                              changed();
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Descendre la réponse ${i + 1}',
                      onPressed: i == inputs.length - 1 || busy
                          ? null
                          : () => setState(() {
                              final a = inputs.removeAt(i);
                              inputs.insert(i + 1, a);
                              changed();
                            }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              removedInputs.add(inputs.removeAt(i));
                              changed();
                            }),
                      child: const Text('Retirer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      if (inputs.length < 3)
        OutlinedButton.icon(
          onPressed: busy ? null : _addQuestion,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter une question'),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Votre sélection est complète. Retirez une question pour en choisir une autre.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 16),
      Text(
        'Vos réponses seront visibles sur votre profil après validation. Évitez les coordonnées personnelles.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
    saveLabel: 'Enregistrer mes réponses',
    saveInFooter: true,
    save: () async {
      final drafts = inputs.map((a) => AnswerDraft(a.id, a.text.text)).toList();
      for (final d in drafts) {
        final error = d.validate();
        if (error != null) {
          setState(() {
            message = error;
          });
          return;
        }
        if (!controller.questions.any((q) => q.id == d.questionId)) {
          setState(() {
            message = 'Retirez la question indisponible avant d’enregistrer.';
          });
          return;
        }
      }
      if (!await confirmAction(
            context,
            inputs.isEmpty
                ? 'Effacer toutes vos réponses ?'
                : 'Enregistrer cette sélection ?',
            'Cette sélection remplacera toutes vos réponses actuelles, dans cet ordre.',
            action: inputs.isEmpty ? 'Tout effacer' : 'Enregistrer',
          ) ||
          !mounted) {
        return;
      }
      await submit(() => controller.saveAnswers(drafts));
    },
  );
}
