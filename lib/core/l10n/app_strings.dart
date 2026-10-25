import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/client_message.dart';
import '../network/api_failure.dart';
import 'generated/app_messages.dart';

export '../models/client_message.dart';

/// Locale-aware facade for formatting and domain-to-copy mappings.
class AppStrings {
  const AppStrings([this._localeName = 'fr']);
  final String _localeName;

  String get localeName => messages.localeName;

  static AppStrings of(BuildContext context) => AppStrings(
    Localizations.of<AppMessages>(context, AppMessages)?.localeName ?? 'fr',
  );

  AppMessages get messages {
    final language = _localeName.replaceAll('-', '_').split('_').first;
    return lookupAppMessages(
      AppMessages.supportedLocales.firstWhere(
        (l) => l.languageCode == language,
        orElse: () => const Locale('fr'),
      ),
    );
  }

  String clientMessage(ClientMessage value) => switch (value) {
    ClientMessage.questionUnavailable =>
      messages.answersEditorRemoveTheUnavailableQuestionBeforeSaving,
    ClientMessage.messageEmpty => messages.messageEmpty,
    ClientMessage.messageTooLong => messages.messageTooLong,
    ClientMessage.reportTooLong => messages.reportTooLong,
    ClientMessage.answerInvalid => messages.answerInvalid,
    ClientMessage.peopleRequired => messages.peopleRequired,
    ClientMessage.sexInvalid => messages.sexInvalid,
    ClientMessage.underage => messages.underage,
    ClientMessage.birthdateInvalid => messages.birthdateInvalid,
    ClientMessage.distanceInvalid => messages.distanceInvalid,
    ClientMessage.bioTooLong => messages.bioTooLong,
    ClientMessage.firstnameInvalid => messages.firstnameInvalid,
    ClientMessage.ageRangeInvalid => messages.ageRangeInvalid,
    ClientMessage.videoQuotaRequired =>
      messages.rewardedVideoControllerRefreshYourBalanceToAccessVideos,
    ClientMessage.videoNoFill =>
      messages.rewardedVideoControllerNoVideoIsAvailableRightNow,
    ClientMessage.videoExpired =>
      messages.rewardedVideoControllerThisRequestHasExpiredCancelIt,
    ClientMessage.videoAvailabilityUnknown =>
      messages.rewardedVideoControllerVideoAvailabilityCouldNotBeChecked,
    ClientMessage.videoClosed =>
      messages.rewardedVideoControllerTheVideoWasClosedBeforeThe,
    ClientMessage.videoUnavailable =>
      messages.rewardedVideoControllerVideosAreTemporarilyUnavailableYouCan,
    ClientMessage.videoNetwork =>
      messages.rewardedVideoControllerTheVideoCouldNotBeLoaded,
    ClientMessage.videoLoad =>
      messages.rewardedVideoControllerTheVideoCouldNotBeLoaded218,
    ClientMessage.videoShow =>
      messages.rewardedVideoControllerTheVideoCouldNotBeShown,
    ClientMessage.videoConsentTimeout =>
      messages.rewardedVideoControllerLoadingAdvertisingPreferencesIsTakingToo,
    ClientMessage.videoConsentMisconfigured =>
      messages.rewardedVideoControllerTheVideoPrivacyFormIsNot,
    ClientMessage.videoConsentNetwork =>
      messages.rewardedVideoControllerAdvertisingPreferencesCouldNotBeLoaded,
    ClientMessage.videoNotConfigured =>
      messages.rewardedVideoControllerVideosAreNotConfiguredForThis,
    ClientMessage.videoPlanDisabled =>
      messages.rewardedVideoControllerVideosAreTemporarilyDisabledForYour,
    ClientMessage.videoPremium =>
      messages.rewardedVideoControllerPremiumLetsYouContinueWithoutCredits,
    ClientMessage.videoPrivacyUnavailable =>
      messages.rewardedVideoControllerYourPreferencesAreCurrentlyUnavailable,
    ClientMessage.videoConsentUnavailable =>
      messages.rewardedVideoControllerYourAdvertisingPreferencesCouldNotBe,
    ClientMessage.videoReserveFull =>
      messages.rewardedVideoControllerYourVideoReserveIsFullUse,
    ClientMessage.videoDeviceNotConfigured =>
      messages.rewardedVideoGatewayVideosAreNotYetConfiguredFor,
    ClientMessage.videoPlatformUnsupported =>
      messages.rewardedVideoGatewayVideosAreAvailableOnAndroidAnd,
  };

  String date(DateTime value) =>
      DateFormat.yMd(localeName).format(value.toLocal());

  String dateTime(DateTime value) =>
      DateFormat.yMd(localeName).add_Hm().format(value.toLocal());

  String shortDateTime(DateTime value) =>
      DateFormat.Md(localeName).add_Hm().format(value.toLocal());

  String decimal(num value) => (NumberFormat.decimalPattern(
    localeName,
  )..maximumFractionDigits = 1).format(value);

  String get appName => messages.appOpeningHistae;

  String get wordsFirst => messages.appStringsWordsFirst;

  String get registrationHeading => messages.appStringsLetSGetToKnowYou;

  String get loginHeading => messages.appStringsGoodToSeeYouAgain;

  String get trustHeading => messages.appStringsWithConfidence;

  String get signIn => messages.appStringsSignIn;

  String get createAccount => messages.appStringsCreateMyAccount;

  String get existingAccount => messages.appStringsIAlreadyHaveAnAccount;

  String get myAccount => messages.appStringsMySpace;

  String get otpIntroduction => messages.appStringsVerifyYourNumberWithACode;

  String get onboardingRequired =>
      messages.appStringsCompleteTheRequiredChoicesIndicatedBy;

  String get actionInProgress => messages.appStringsWorking;

  String get phoneLabel => messages.appStringsFrenchPhoneNumberStartingWith33;

  String get phoneHint => messages.appStrings33612345678;

  String get phoneHelp => messages.appStringsEnter33FollowedBy9Digits;

  String get sendOtp => messages.appStringsRequestACode;

  String get resendOtp => messages.appStringsRequestANewCode;

  String get resumeOtp => messages.appStringsResumeThePreviousRequest;

  String get otpLabel => messages.appStrings6DigitVerificationCode;

  String get verifyOtp => messages.appStringsVerifyCode;

  String get changePhone => messages.appStringsChangeNumber;

  String get otpAccepted => messages.appStringsYourRequestWasAcceptedThisDoes;

  String get verificationUncertain =>
      messages.appStringsVerificationCouldNotBeConfirmedRequest;

  String get sessionLoading => messages.appStringsCheckingYourSession;

  String get sessionUnavailable => messages.appStringsYourSessionIsUnavailable;

  String get logout => messages.appStringsSignOut;

  String get logoutUnconfirmed => messages.appStringsYouAreSignedOutOnThis;

  String get privacyTitle => messages.appStringsYourChoicesAndPrivacy;

  String get consentsTitle => messages.appStringsYourConsents;

  String get consentsIntro => messages.appStringsFindTheTermsOfUseAnd;

  String get saveChoices => messages.appStringsSaveMyChoices;

  String get refreshChoices => messages.appStringsRefreshMyConsents;

  String get withdraw => messages.appStringsWithdrawMyConsent;

  String get confirmWithdrawal => messages.appStringsConfirmWithdrawal;

  String get cancel => messages.appStringsCancel;

  String get openDocumentError =>
      messages.appStringsTheDocumentCouldNotBeOpened;

  String get readDocument => messages.appStringsReadDocument;

  String get documentsChanged =>
      messages.appStringsTheDocumentsHaveChangedReadThe;

  String get choicesSaved => messages.appStringsYourChoicesHaveBeenSaved;

  String get accountTitle => messages.appStringsYourHistaeSpace;

  String get accountReady => messages.appStringsYourAccountIsCreatedAndYour;

  String get privacyScope => messages.appStringsYouCanViewYourDocumentsManage;

  String authFailure(ApiFailure error) => switch (error.code) {
    'invalid_phone_number' => messages.appStringsEnterAValidFrenchPhoneNumber,
    'invalid_otp_request' => messages.appStringsEnterTheSixDigitsOfThe,
    'invalid_or_expired_otp' => messages.appStringsTheCodeIsInvalidOrHas,
    'otp_delivery_unavailable' => messages.appStringsTheSmsCouldNotBeSent,
    'otp_delivery_unknown' => messages.appStringsSmsDeliveryIsUncertainTheCode,
    'idempotency_key_conflict' =>
      messages.appStringsThisRequestNoLongerMatchesIts,
    'account_unavailable' => messages.appStringsThisAccountIsUnavailable,
    'legal_documents_changed' => documentsChanged,
    _ => failureMessage(error.kind),
  };

  String get welcomeTitle => messages.appStringsTakeYourTimeToMeet;

  String get welcomeBody =>
      messages.appStringsDiscoverSomeoneThroughTheirWordsPhotos;

  String get catalogAction => messages.appStringsExplorePlans;

  String get catalogTitle => messages.appStringsHistaePlans;

  String get catalogIntro =>
      messages.appStringsExplorePlansAndTheirConditionsRevealing;

  String get catalogReadOnly =>
      messages.appStringsViewYourSubscriptionAndSignUp;

  String get loading => messages.appStringsLoadingPlans;

  String get emptyTitle => messages.appStringsNoPlansAvailable;

  String get emptyBody => messages.appStringsPlansAreCurrentlyUnavailable;

  String get retry => messages.appStringsTryAgain;

  String get refresh => messages.appStringsRefresh;

  String get configurationTitle => messages.appStringsServiceNotConfigured;

  String get configurationBody =>
      messages.appStringsTheServiceIsNotYetConfigured;

  String get errorTitle => messages.appStringsUnableToLoadPlans;

  String get offlineTitle => messages.appStringsConnectionUnavailable;

  String retryIn(int seconds) => messages.appStringsTryAgainInS(seconds);

  String requestReference(String id) => messages.appStringsRequestReference(id);

  String money(int cents, String currency) => NumberFormat.currency(
    locale: localeName,
    name: currency,
    symbol: currency,
  ).format(cents / 100);

  String monthly(int cents, String currency) =>
      messages.priceMonthly(money(cents, currency));

  String annual(int cents, String currency) =>
      messages.priceAnnual(money(cents, currency));

  String weeklyCredits(int credits) =>
      messages.appStringsCreditsIncludedPerWeek(credits);

  String weeklyLimit(int limit) =>
      messages.appStringsContinuationsPerWeekUpTo(limit);

  String get noWeeklyLimit => messages.appStringsNoWeeklyLimitOnContinuations;

  String adStock(int limit) =>
      messages.appStringsMaximumVideoCreditBalance(limit);

  String ads(bool removed) => removed
      ? messages.appStringsAdsRemoved
      : messages.appStringsAdsNotRemoved;

  String rewards(bool enabled) => enabled
      ? messages.appStringsVideoRewardsEnabledForThisPlan
      : messages.appStringsVideoRewardsUnavailableForThisPlan;

  String? featureTitle(String code, String? fallback) => switch (code) {
    'messages' => messages.appStringsMessaging,
    'photo_reveal' => messages.appStringsMutualPhotoReveal,
    'continuations' => messages.appStringsContinueAConversation,
    'advertising_credits' => messages.appStringsOptionalVideoRewards,
    'no_ads' => messages.appStringsAdFree,
    _ => fallback,
  };

  String? featureDescription(String code, String? fallback) => switch (code) {
    'messages' => messages.appStringsChatDuringTheInitialPeriodThen,
    'photo_reveal' => messages.appStringsPhotosAreRevealedAfterYouBoth,
    'continuations' => messages.appStringsEachPersonAgreesSeparatelyAndUses,
    'advertising_credits' =>
      messages.appStringsTheServerValidatesTheRewardBefore,
    'no_ads' => messages.appStringsThisPlanRemovesAds,
    _ => fallback,
  };

  String failureMessage(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.secureStorage =>
      messages.appStringsSecureStorageIsUnavailableUnlockYour,
    ApiFailureKind.sessionUncertain =>
      messages.appStringsYourSessionCannotBeRestoredWith,
    ApiFailureKind.network => messages.appStringsTheServiceCannotBeReachedCheck,
    ApiFailureKind.timeout => messages.appStringsTheServiceIsTakingTooLong,
    ApiFailureKind.invalidResponse =>
      messages.appStringsTheServiceResponseCouldNotBe,
    ApiFailureKind.validation => messages.appStringsTheServiceDidNotAcceptThe,
    ApiFailureKind.unauthenticated =>
      messages.appStringsPleaseSignInToYourAccount,
    ApiFailureKind.consentRequired =>
      messages.appStringsCompleteTheRequiredConsents,
    ApiFailureKind.discoveryNotReady =>
      messages.appStringsCompleteYourProfileToDiscoverPeople,
    ApiFailureKind.quota =>
      messages.appStringsYourAvailableAllowanceDoesNotPermit,
    ApiFailureKind.forbidden =>
      messages.appStringsThisActionIsCurrentlyNotAllowed,
    ApiFailureKind.notFound => messages.appStringsTheRequestedContentIsNoLonger,
    ApiFailureKind.conflict =>
      messages.appStringsThingsHaveChangedRefreshBeforeTrying,
    ApiFailureKind.expired => messages.appStringsThisContentHasExpired,
    ApiFailureKind.payloadTooLarge =>
      messages.appStringsTheSubmittedContentExceedsTheAllowed,
    ApiFailureKind.rateLimited =>
      messages.appStringsTooManyRequestsWaitBeforeTrying,
    ApiFailureKind.unavailable || ApiFailureKind.server =>
      messages.appStringsTheServiceIsTemporarilyUnavailable,
    ApiFailureKind.cancelled => messages.appStringsLoadingWasInterrupted,
    ApiFailureKind.unexpected =>
      messages.appStringsTheServiceReturnedAnUnexpectedResponse,
  };
}
