enum PhoneCountry {
  france;

  /// Accept national typing and international OS autofill, then send E.164.
  String? normalize(String input) {
    final international = normalizeFrenchPhone(input);
    if (international != null) return international;
    final local = input.trim().replaceAll(RegExp(r'[ .()\-]'), '');
    final national = local.startsWith('0') ? local.substring(1) : local;
    return RegExp(r'^[1-9][0-9]{8}$').hasMatch(national)
        ? '+33$national'
        : null;
  }
}

String? normalizeFrenchPhone(String input) {
  final phone = input.trim().replaceAll(RegExp(r'[ .()\-]'), '');
  return RegExp(r'^\+33[1-9][0-9]{8}$').hasMatch(phone) ? phone : null;
}
