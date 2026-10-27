class SupportConfig {
  const SupportConfig({this.email});
  final String? email;

  factory SupportConfig.fromValues(Map<String, String> values) {
    final value = (values['SUPPORT_EMAIL'] ?? '').trim();
    if (value.isEmpty) return const SupportConfig();
    if (!RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$').hasMatch(value) ||
        value.contains(RegExp(r'[\r\n?#]'))) {
      throw const FormatException('Invalid public support configuration');
    }
    return SupportConfig(email: value);
  }
}
