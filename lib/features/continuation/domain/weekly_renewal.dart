/// Display only: quota renewal itself remains owned by the server.
DateTime nextWeeklyRenewal(DateTime now) {
  final utc = now.toUtc();
  final monday = DateTime.utc(utc.year, utc.month, utc.day - utc.weekday + 1);
  return monday.add(const Duration(days: 7));
}
