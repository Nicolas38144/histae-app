import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
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
    AppStrings.of(context).messages.answersEditorYourAnswers,
    [
      EditorialCard(
        eyebrow: AppStrings.of(context)
            .messages
            .answersEditorYourWordsYourStory,
        title: AppStrings.of(context)
            .messages
            .answersEditorThreeQuestionsAThousandWaysTo,
        body: AppStrings.of(context)
            .messages
            .answersEditorChooseWhatYouWantToShare,
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            AppStrings.of(context).messages.answersEditorYourSelection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            AppStrings.of(context).messages
                .answersEditor3Answers(inputs.length),
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
                  AppStrings.of(context).messages.answersEditorYourFirstWord,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.of(context)
                      .messages
                      .answersEditorAHabitAWishALittle,
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
                  AppStrings.of(context).messages
                      .answersEditorAnswer((i + 1).toString().padLeft(2, '0')),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.questionPrompt(inputs[i].id, inputs[i].prompt),
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
                    labelText: AppStrings.of(context).messages
                        .answersEditorAnswer737(i + 1),
                    alignLabelWithHint: true,
                    helperText: AppStrings.of(context)
                        .messages
                        .answersEditor10To300Characters,
                    helperMaxLines: 2,
                    counterText: AppStrings.of(context).messages
                        .answersEditor300(
                          inputs[i].text.text.trim().runes.length,
                        ),
                    counterStyle: TextStyle(
                      color: inputs[i].text.text.trim().runes.length > 300
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!controller.questions.any((q) => q.id == inputs[i].id))
                  Text(
                    AppStrings.of(context)
                        .messages
                        .answersEditorThisQuestionIsNoLongerIn,
                  ),
                for (final a in controller.answers.where(
                  (a) => a.questionId == inputs[i].id,
                ))
                  ProfileModerationLabel(moderation: a.moderation),
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: AppStrings.of(context).messages
                          .answersEditorMoveAnswerUp(i + 1),
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
                      tooltip: AppStrings.of(context).messages
                          .answersEditorMoveAnswerDown(i + 1),
                      onPressed: i == inputs.length - 1 || busy
                          ? null
                          : () => setState(() {
                              final a = inputs.removeAt(i);
                              inputs.insert(i + 1, a);
                              changed();
                            }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    HistaeButton.text(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              removedInputs.add(inputs.removeAt(i));
                              changed();
                            }),
                      child: Text(
                        AppStrings.of(context).messages.devicesPageRemove,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      if (inputs.length < 3)
        HistaeButton.outlinedIcon(
          onPressed: busy ? null : _addQuestion,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            AppStrings.of(context).messages.answersEditorAddAQuestion,
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            AppStrings.of(context)
                .messages
                .answersEditorYourSelectionIsCompleteRemoveA,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 16),
      Text(
        AppStrings.of(context)
            .messages
            .answersEditorYourAnswersWillAppearOnYour,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
    saveLabel: AppStrings.of(context).messages.answersEditorSaveMyAnswers,
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
            message = ClientMessage.questionUnavailable;
          });
          return;
        }
      }
      if (!await confirmAction(
            context,
            inputs.isEmpty
                ? AppStrings.of(context)
                      .messages
                      .answersEditorEraseAllYourAnswers
                : AppStrings.of(context)
                      .messages
                      .answersEditorSaveThisSelection,
            AppStrings.of(context)
                .messages
                .answersEditorThisSelectionWillReplaceAllYour,
            action: inputs.isEmpty
                ? AppStrings.of(context).messages.answersEditorEraseAll
                : AppStrings.of(context).messages.answersEditorSave,
          ) ||
          !mounted) {
        return;
      }
      await submit(() => controller.saveAnswers(drafts));
    },
  );
}
