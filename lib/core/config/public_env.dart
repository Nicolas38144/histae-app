/// Reads only the public settings allowed in the bundled asset. This parser
/// intentionally does not interpolate variables or accept unknown keys.
Map<String, String> parsePublicEnv(
  String source, {
  required Set<String> allowedKeys,
}) {
  final values = <String, String>{};
  for (final raw in source.replaceFirst('\uFEFF', '').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf('=');
    if (separator < 1) {
      throw const FormatException('Invalid public configuration');
    }
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (!allowedKeys.contains(key) || values.containsKey(key)) {
      throw const FormatException('Invalid public configuration');
    }
    if (value.startsWith('"') || value.startsWith("'")) {
      if (value.length < 2 || !value.endsWith(value[0])) {
        throw const FormatException('Invalid public configuration');
      }
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return Map.unmodifiable(values);
}
