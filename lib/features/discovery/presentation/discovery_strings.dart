import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';

class DiscoveryStrings {
  const DiscoveryStrings(this.strings);
  final AppStrings strings;

  String failure(ApiFailure e) => switch (e.code) {
    'discovery_not_ready' =>
      strings
          .messages
          .discoveryStringsYourDiscoveryConditionsHaveChangedRefresh,
    'discovery_unavailable' =>
      strings.messages.discoveryStringsDiscoveryIsTemporarilyUnavailable,
    'invalid_cursor' =>
      strings.messages.discoveryStringsThisPageHasExpiredRefreshProfiles,
    'invalid_feed_query' || 'invalid_feed_request' =>
      strings.messages.discoveryStringsProfilesCannotBeLoadedRightNow,
    'swipe_already_recorded' =>
      strings.messages.discoveryStringsAChoiceIsAlreadyRecordedFor,
    'discovery_candidate_not_found' || 'match_blocked' =>
      strings.messages.discoveryStringsThisProfileIsNoLongerAvailable,
    _ => strings.failureMessage(e.kind),
  };

  String location(LocationIssue issue) => switch (issue) {
    LocationIssue.disabled =>
      strings.messages.discoveryStringsDeviceLocationIsDisabledEnableIt,
    LocationIssue.denied =>
      strings.messages.discoveryStringsLocationAccessWasDeniedYouCan,
    LocationIssue.deniedForever =>
      strings.messages.discoveryStringsAllowLocationAccessInYourDevice,
    LocationIssue.timeout =>
      strings.messages.discoveryStringsYourLocationWasNotFoundIn,
    LocationIssue.stale =>
      strings.messages.discoveryStringsThisLocationIsTooOldOr,
    LocationIssue.unavailable =>
      strings.messages.discoveryStringsYourLocationCannotBeObtainedRight,
    LocationIssue.cancelled =>
      strings.messages.discoveryStringsLocationWasInterruptedYouCanRequest,
  };

  String actionTitle(DiscoveryAction action) => switch (action) {
    DiscoveryAction.photo => strings.messages.discoveryPhotoTitle,
    DiscoveryAction.profile =>
      strings.messages.discoveryStringsYourIntroduction,
    DiscoveryAction.resumeDiscovery =>
      strings.messages.discoveryStringsYourProfileIsPaused,
    DiscoveryAction.sex => strings.messages.discoveryStringsYourProfileSSex,
    DiscoveryAction.preferences =>
      strings.messages.discoveryStringsYourDatingPreferences,
    DiscoveryAction.sensitiveConsent =>
      strings.messages.discoveryStringsSensitiveData,
    DiscoveryAction.locationConsent =>
      strings.messages.discoveryStringsYourLocationChoice,
    DiscoveryAction.freshPresence =>
      strings.messages.discoveryStringsARecentLocation,
  };

  String actionBody(DiscoveryAction action) => switch (action) {
    DiscoveryAction.photo => strings.messages.discoveryPhotoBody,
    DiscoveryAction.profile =>
      strings.messages.discoveryStringsAddYourFirstNameDateOf,
    DiscoveryAction.resumeDiscovery =>
      strings.messages.discoveryStringsYourProfileIsHiddenFromNew,
    DiscoveryAction.sex =>
      strings.messages.discoveryStringsFillInThisFieldToEnable,
    DiscoveryAction.preferences =>
      strings.messages.discoveryStringsChooseThePeopleAgesAndDistance,
    DiscoveryAction.sensitiveConsent =>
      strings.messages.discoveryStringsUsingSexAndPreferencesRequiresYour,
    DiscoveryAction.locationConsent =>
      strings.messages.discoveryStringsDecideWhetherHistaeCanUseYour,
    DiscoveryAction.freshPresence =>
      strings.messages.discoveryStringsOneLocationReadingIsEnoughYour,
  };

  String notice(String? code) => switch (code) {
    'location_approximate' =>
      strings.messages.discoveryStringsApproximateLocationUsedDistancesMayBe,
    'location_updated' =>
      strings.messages.discoveryStringsYourLocationHasBeenUpdated,
    'presence_uncertain' =>
      strings.messages.discoveryStringsLocationSubmissionIsUncertainItsStatus,
    'blocked' => strings.messages.discoveryStringsThisProfileIsBlockedYouCan,
    'candidate_unavailable' =>
      strings.messages.discoveryStringsThisProfileWasRemovedFromDiscovery,
    _ => '',
  };

  String distance(double km) =>
      strings.messages.distanceKm(strings.decimal(km));

  String pending(PendingAction action) => switch (action) {
    PendingAction.like => strings.messages.discoveryStringsResumeTheSameLike,
    PendingAction.pass => strings.messages.discoveryStringsResumeTheSamePass,
    PendingAction.block => strings.messages.discoveryStringsResumeBlocking,
  };
}
