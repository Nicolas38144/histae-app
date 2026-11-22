import '../../../core/network/json_fields.dart';

final class CaseworkEntry {
  const CaseworkEntry._({
    required this.id,
    required this.body,
    this.topic,
    this.status,
    this.createdAt,
    this.response,
    this.fromTeam = false,
  });

  factory CaseworkEntry.fromJson(Object? value, {required bool isThread}) {
    final json = jsonObject(value);
    final id = serverId(json, 'id');
    if (isThread) {
      return CaseworkEntry._(
        id: id,
        body: jsonString(json, 'body'),
        fromTeam: json['author'] == 'team',
      );
    }

    final date = json['created_at'];
    return CaseworkEntry._(
      id: id,
      topic: optionalText(json, 'reason') ?? optionalText(json, 'category'),
      status: jsonString(json, 'status'),
      body:
          optionalText(json, 'body') ?? optionalText(json, 'description') ?? '',
      createdAt: date is String ? DateTime.tryParse(date) : null,
      response: optionalText(json, 'response'),
    );
  }

  final String id;
  final String body;
  final String? topic;
  final String? status;
  final DateTime? createdAt;
  final String? response;
  final bool fromTeam;
}
