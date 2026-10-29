class SupportConfig {
  const SupportConfig({this.email, this.websiteOrigin});
  final String? email;
  final Uri? websiteOrigin;

  factory SupportConfig.fromValues(Map<String, String> values) {
    final value = (values['SUPPORT_EMAIL'] ?? '').trim();
    if (value.isNotEmpty &&
        (!RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$').hasMatch(value) ||
            value.contains(RegExp(r'[\r\n?#]')))) {
      throw const FormatException('Invalid public support configuration');
    }
    final website = (values['SUPPORT_WEBSITE_URL'] ?? '').trim();
    final origin = website.isEmpty ? null : Uri.tryParse(website);
    if (website.isNotEmpty &&
        (origin == null ||
            origin.scheme != 'https' ||
            origin.host.isEmpty ||
            origin.userInfo.isNotEmpty ||
            origin.hasQuery ||
            origin.hasFragment ||
            (origin.path.isNotEmpty && origin.path != '/'))) {
      throw const FormatException('Invalid public support website origin');
    }
    return SupportConfig(
      email: value.isEmpty ? null : value,
      websiteOrigin: origin,
    );
  }
}
