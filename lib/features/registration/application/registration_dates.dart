/// Latest birthdate allowed by the profile's eighteenth-birthday rule.
DateTime latestAdultBirthdate(DateTime now) {
  final today = now.toUtc();
  final year = today.year - 18;
  final candidate = DateTime(year, today.month, today.day);
  return candidate.month == today.month
      ? candidate
      : DateTime(year, today.month + 1, 0);
}
