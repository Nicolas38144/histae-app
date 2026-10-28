import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/match_models.dart';

class MatchesStrings {
  const MatchesStrings(this.strings);
  final AppStrings strings;

  String failure(ApiFailure e) => switch (e.code) {
    'match_not_found' || 'match_blocked' || 'match_expired' =>
      strings.messages.matchesStringsThisMatchIsNoLongerAvailable,
    'messaging_not_available' || 'invalid_match_state' =>
      strings.messages.matchesStringsSendingIsUnavailableInThisMatch,
    'invalid_message_request' || 'invalid_message_payload' =>
      strings.messages.matchesStringsWriteANonEmptyMessageOf,
    'idempotency_key_conflict' =>
      strings.messages.matchesStringsThisSendRequestNoLongerMatches,
    'message_not_found' =>
      strings.messages.matchesStringsThisMessageIsNoLongerAvailable,
    'invalid_cursor' => strings.messages.matchesStringsThisPageCanNoLongerBe,
    'photo_storage_unavailable' =>
      strings.messages.matchesStringsMatchesAreTemporarilyUnavailableTryAgain,
    _ => strings.failureMessage(e.kind),
  };

  String status(MatchStatus status) => switch (status) {
    MatchStatus.active => strings.messages.matchesStringsTheFirstWords,
    MatchStatus.awaitingContinuation =>
      strings.messages.matchesStringsSendingPaused,
    MatchStatus.confirmed => strings.messages.matchesStringsConversationOpen,
    MatchStatus.expired ||
    MatchStatus.ended => strings.messages.matchesStringsMatchEnded,
  };

  String date(DateTime value) => strings.shortDateTime(value);

  String stateBody(UserMatch match) => switch (match.status) {
    MatchStatus.active => strings.messages.matchesStringsFirstPeriodEndsOn(
      date(match.expiresAt),
    ),
    MatchStatus.awaitingContinuation =>
      strings.messages.matchesStringsSendingIsPausedDuringTheContinuation(
        date(match.expiresAt),
      ),
    MatchStatus.confirmed => match.inactivityExpiresAt == null
        ? strings.messages.matchesStringsYouCanContinueYourConversation
        : strings.messages.matchesInactivityDeadline(date(match.inactivityExpiresAt!)),
    MatchStatus.expired ||
    MatchStatus.ended => strings.messages.matchesPageThisMatchHasEnded,
  };
}
