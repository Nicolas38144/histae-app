import 'api_failure.dart';

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
