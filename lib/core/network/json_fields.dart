import 'api_failure.dart';

Never invalidResponse() =>
    throw const ApiFailure(ApiFailureKind.invalidResponse);

String? optionalText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) invalidResponse();
  return value as String?;
}

String serverId(Map<String, dynamic> json, String key) {
  final id = jsonString(json, key);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    invalidResponse();
  }
  return id;
}

DateTime wireTime(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    invalidResponse();
  }
  return DateTime.tryParse(value)?.toUtc() ?? invalidResponse();
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const ApiFailure(ApiFailureKind.invalidResponse);
  }
  return value;
}

T jsonField<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! T) throw const ApiFailure(ApiFailureKind.invalidResponse);
  return value;
}

String jsonString(Map<String, dynamic> json, String key) {
  final value = jsonField<String>(json, key);
  if (value.isEmpty) throw const ApiFailure(ApiFailureKind.invalidResponse);
  return value;
}

String? pageCursor(Map<String, dynamic> j) {
  final cursor = optionalText(j, 'next_cursor');
  if (cursor != null && (cursor.isEmpty || cursor.length > 512)) {
    invalidResponse();
  }
  return cursor;
}
