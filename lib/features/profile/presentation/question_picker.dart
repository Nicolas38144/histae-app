import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../data/profile_models.dart';

Future<ProfileQuestion?> pickProfileQuestion(
  BuildContext context, {
  required List<ProfileQuestion> questions,
  required Set<String> selected,
}) => showModalBottomSheet<ProfileQuestion>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _QuestionPicker(questions: questions, selected: selected),
);

class _QuestionPicker extends StatefulWidget {
  const _QuestionPicker({required this.questions, required this.selected});
  final List<ProfileQuestion> questions;
  final Set<String> selected;

  @override
  State<_QuestionPicker> createState() => _QuestionPickerState();
}

class _QuestionPickerState extends State<_QuestionPicker> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final available =
        widget.questions.where((q) => !widget.selected.contains(q.id)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final filtered = available
        .where(
          (q) =>
              q.prompt.toLowerCase().contains(search.text.trim().toLowerCase()),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.of(context)
                        .messages
                        .questionPickerChooseAQuestion,
                    style: largeText
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: AppStrings.of(context)
                      .messages
                      .questionPickerCloseQuestions,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).messages.questionPickerSearch,
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  available.isEmpty
                      ? AppStrings.of(context)
                            .messages
                            .questionPickerNoOtherQuestionsAreCurrentlyAvailable
                      : AppStrings.of(context)
                            .messages
                            .questionPickerNoQuestionsMatchYourSearch,
                ),
              ),
            for (final q in filtered)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(q.prompt),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () => Navigator.pop(context, q),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
