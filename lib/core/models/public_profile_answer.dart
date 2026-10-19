import '../network/json_fields.dart';

class PublicProfileAnswer {
  const PublicProfileAnswer(
    this.questionId,
    this.question,
    this.answer,
    this.position,
  );

  factory PublicProfileAnswer.fromJson(Object? value) {
    final j = jsonObject(value);
    jsonString(j, 'code');
    return PublicProfileAnswer(
      serverId(j, 'question_id'),
      jsonString(j, 'question'),
      jsonString(j, 'answer'),
      jsonField<int>(j, 'position'),
    );
  }
  final String questionId, question, answer;
  final int position;
}
