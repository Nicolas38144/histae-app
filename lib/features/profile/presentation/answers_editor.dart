import 'package:flutter/material.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';
import 'profile_editor.dart';
import 'profile_strings.dart';

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
  late final inputs = controller.answers
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

  @override
  Widget build(BuildContext context) => page(
    'Vos réponses',
    [
      const EditorialCard(
        title: 'Une question.\nVotre regard.',
        body: 'Jusqu’à trois réponses, dans l’ordre qui vous ressemble. De 10 à 300 caractères chacune.',
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < inputs.length; i++)
        Card(
          key: ValueKey(inputs[i].id),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  inputs[i].prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                field(inputs[i].text, 'Réponse ${i + 1}', lines: 4),
                if (!controller.questions.any((q) => q.id == inputs[i].id))
                  const Text(
                    'Cette question n’est plus dans le catalogue. Retirez-la pour enregistrer une nouvelle sélection.',
                  ),
                for (final a in controller.answers.where(
                  (a) => a.questionId == inputs[i].id,
                ))
                  Text(ProfileStrings.moderation(a.moderation)),
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
      if (inputs.length < 3) ...[
        const SizedBox(height: 24),
        Text(
          'Choisir une question',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (controller.questions.isEmpty)
          const Text('Aucune question n’est proposée pour le moment.'),
        for (final q in controller.questions.where(
          (q) => !inputs.any((a) => a.id == q.id),
        ))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      inputs.add(_AnswerInput(q.id, q.prompt, ''));
                      changed();
                    }),
              child: Text(q.prompt),
            ),
          ),
      ],
    ],
    saveLabel: 'Enregistrer mes réponses',
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
