import 'dart:convert';

import '../../../core/network/json_fields.dart';
import '../../matches/data/match_models.dart';
import 'saved_answer_draft.dart';

class DraftSnapshot {
  DraftSnapshot({
    required this.owner,
    required Map<String, String> messages,
    required List<SavedAnswerDraft>? answers,
    List<MessageIntent> pending = const [],
  }) : messages = Map.unmodifiable(messages),
       answers = answers == null ? null : List.unmodifiable(answers),
       pending = List.unmodifiable(pending);

  final String owner;
  final Map<String, String> messages;
  final List<SavedAnswerDraft>? answers;
  final List<MessageIntent> pending;

  factory DraftSnapshot.decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['owner'] is! String ||
        value['messages'] is! Map<String, dynamic>) {
      throw const FormatException();
    }
    final messages = value['messages'] as Map<String, dynamic>;
    final answerValues = value['answers'];
    if (messages.values.any((text) => text is! String) ||
        answerValues != null && answerValues is! List<dynamic>) {
      throw const FormatException();
    }
    final answers = answerValues == null
        ? null
        : (answerValues as List<dynamic>)
              .map(SavedAnswerDraft.fromJson)
              .toList();
    if (answers != null &&
        (answers.length > 3 ||
            answers.map((a) => a.questionId).toSet().length !=
                answers.length)) {
      throw const FormatException();
    }
    return DraftSnapshot(
      owner: value['owner'] as String,
      messages: messages.cast<String, String>(),
      answers: answers,
      pending:
          (value['pending'] == null
                  ? <dynamic>[]
                  : jsonField<List<dynamic>>(value, 'pending'))
              .map(MessageIntent.fromJson)
              .toList(),
    );
  }

  String encode() => jsonEncode({
    'owner': owner,
    'messages': messages,
    'answers': answers?.map((answer) => answer.toJson()).toList(),
    'pending': pending.map((intent) => intent.toJson()).toList(),
  });
}
