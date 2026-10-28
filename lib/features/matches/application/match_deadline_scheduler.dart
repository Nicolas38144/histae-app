import 'dart:async';

import '../data/match_models.dart';

typedef _DeadlineKey = (String, MatchStatus, DateTime);

/// Owns one timer for archive/access transitions, with no HTTP or UI side effects.
/// Expired snapshots are checked once until their server deadline changes.
class MatchDeadlineScheduler {
  MatchDeadlineScheduler({required this.now, required this.onElapsed});

  final DateTime Function() now;
  final void Function(List<UserMatch> expired) onElapsed;
  final _checked = <_DeadlineKey>{};
  Timer? _timer;
  int _revision = 0;

  static _DeadlineKey? _key(UserMatch match) {
    final deadline = match.lifecycle.accessDeadline;
    return deadline == null ? null : (match.id, match.status, deadline);
  }

  void update(Iterable<UserMatch> matches) {
    _timer?.cancel();
    final revision = ++_revision;
    final observed = List<UserMatch>.of(matches);
    final currentKeys = observed.map(_key).whereType<_DeadlineKey>().toSet();
    _checked.retainAll(currentKeys);
    final clock = now();
    DateTime? next;
    for (final match in observed) {
      if (_checked.contains(_key(match))) continue;
      final deadline = match.lifecycle.nextTransitionAt(clock);
      if (deadline != null && (next == null || deadline.isBefore(next))) {
        next = deadline;
      }
    }
    if (next == null) return;
    final delay = next.difference(clock);
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (revision != _revision) return;
      final clock = now();
      final expired = <UserMatch>[];
      for (final match in observed) {
        final key = _key(match);
        if (key != null && !key.$3.isAfter(clock) && _checked.add(key)) {
          expired.add(match);
        }
      }
      onElapsed(List.unmodifiable(expired));
    });
  }

  void cancel() {
    _revision++;
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    cancel();
    _checked.clear();
  }
}
