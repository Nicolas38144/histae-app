/// Exact language codes accepted by the API. No Flutter or transport dependency.
enum ApiLanguage {
  fr,
  en,
  es,
  it;

  String get code => name;

  static ApiLanguage? tryParse(Object? value) {
    for (final language in values) {
      if (language.code == value) return language;
    }
    return null;
  }
}
