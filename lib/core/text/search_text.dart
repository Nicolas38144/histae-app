/// Literal, case-insensitive name matching for the app's supported languages.
String normalizeSearchText(String value) {
  var result = value.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  for (final group in const {
    'àáâäãå': 'a',
    'èéêë': 'e',
    'ìíîï': 'i',
    'òóôöõ': 'o',
    'ùúûü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ýÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  }.entries) {
    for (final rune in group.key.runes) {
      result = result.replaceAll(String.fromCharCode(rune), group.value);
    }
  }
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}
