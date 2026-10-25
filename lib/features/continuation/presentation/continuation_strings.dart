import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../matches/presentation/matches_strings.dart';

class ContinuationStrings {
  const ContinuationStrings(this.strings);
  final AppStrings strings;

  String failure(ApiFailure e) => switch (e.code) {
    'photo_required' => strings.messages.photoRevealMissing,
    'continuation_plan_changed' =>
      strings.messages.continuationStringsYourPlanHasChangedCheckYour,
    'continuation_quota_reached' =>
      strings.messages.continuationStringsNoNewContinuationIsAvailableWithin,
    'continuation_not_available_yet' =>
      strings.messages.continuationStringsTheDecisionPeriodIsNotOpen,
    'advertising_disabled' =>
      strings.messages.continuationStringsRewardedVideosAreCurrentlyUnavailable,
    'advertising_not_eligible' =>
      strings.messages.continuationStringsNoNewRewardedVideoIsCurrently,
    'advertising_stock_full' =>
      strings.messages.continuationStringsYourVideoCreditReserveIsFull,
    'reward_not_found' =>
      strings.messages.continuationStringsThisRewardIsNoLongerAccessible,
    'admob_verification_unavailable' =>
      strings
          .messages
          .continuationStringsRewardVerificationIsTemporarilyUnavailableNo,
    _ => MatchesStrings(strings).failure(e),
  };
}
