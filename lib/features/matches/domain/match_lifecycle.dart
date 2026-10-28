enum MatchStatus { active, awaitingContinuation, confirmed, expired, ended }

/// Access and presentation deadlines projected from the server's match state.
/// Missing inactivity metadata preserves compatibility with older API snapshots.
class MatchLifecycle {
  const MatchLifecycle({
    required this.status,
    required this.expiresAt,
    this.inactivityExpiresAt,
    this.archived = false,
  });

  static const archiveAfter = Duration(days: 10);
  static const inactivityLifetime = Duration(days: 30);

  final MatchStatus status;
  final DateTime expiresAt;
  final DateTime? inactivityExpiresAt;
  final bool archived;

  bool get historyAllowed => switch (status) {
    MatchStatus.active ||
    MatchStatus.awaitingContinuation ||
    MatchStatus.confirmed => true,
    MatchStatus.expired || MatchStatus.ended => false,
  };

  bool get sendAllowed =>
      status == MatchStatus.active || status == MatchStatus.confirmed;

  DateTime? get inactivityDeadline =>
      status == MatchStatus.confirmed ? inactivityExpiresAt : null;

  DateTime? get archiveAt =>
      inactivityDeadline?.subtract(inactivityLifetime - archiveAfter);

  DateTime? get accessDeadline => !historyAllowed
      ? null
      : status == MatchStatus.confirmed
      ? inactivityDeadline
      : expiresAt;

  bool isInactivityExpiredAt(DateTime now) =>
      inactivityDeadline?.isAfter(now) == false;

  bool isArchivedAt(DateTime now) =>
      status == MatchStatus.confirmed &&
      !isInactivityExpiredAt(now) &&
      (archiveAt == null ? archived : !archiveAt!.isAfter(now));

  bool allowsHistoryAt(DateTime now) =>
      historyAllowed && !isInactivityExpiredAt(now);

  bool allowsDecisionAt(DateTime now) =>
      allowsHistoryAt(now) &&
      (status == MatchStatus.confirmed || expiresAt.isAfter(now));

  bool allowsSendAt(DateTime now) => sendAllowed && allowsDecisionAt(now);

  DateTime? nextTransitionAt(DateTime now) {
    final archive = archiveAt;
    return archive != null && archive.isAfter(now) ? archive : accessDeadline;
  }
}
