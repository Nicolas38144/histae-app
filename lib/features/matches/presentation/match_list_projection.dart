import '../../../core/text/search_text.dart';
import '../data/match_models.dart';

/// Local search and grouping only; pagination and reads stay in the controller.
class MatchListProjection {
  MatchListProjection(
    Iterable<UserMatch> matches, {
    required DateTime now,
    required String search,
  }) {
    final visible = matches
        .where((match) => !match.isInactivityExpiredAt(now))
        .toList();
    hasMatches = visible.isNotEmpty;
    query = hasMatches ? normalizeSearchText(search) : '';
    final found = visible.where(
      (match) => normalizeSearchText(match.partner.firstname).contains(query),
    );
    current = List.unmodifiable(
      found.where((match) => !match.isArchivedAt(now)),
    );
    archived = List.unmodifiable(
      found.where((match) => match.isArchivedAt(now)),
    );
  }

  late final bool hasMatches;
  late final String query;
  late final List<UserMatch> current, archived;

  bool get hasResults => current.isNotEmpty || archived.isNotEmpty;
}
