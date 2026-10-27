class SavedAnswerDraft {
  const SavedAnswerDraft(this.questionId, this.prompt, this.answer);
  final String questionId, prompt, answer;

  Map<String, String> toJson() => {
    'question_id': questionId,
    'prompt': prompt,
    'answer': answer,
  };

  factory SavedAnswerDraft.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['question_id'] is! String ||
        value['prompt'] is! String ||
        value['answer'] is! String) {
      throw const FormatException();
    }
    return SavedAnswerDraft(
      value['question_id'] as String,
      value['prompt'] as String,
      value['answer'] as String,
    );
  }
}
