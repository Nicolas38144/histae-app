import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/privacy_models.dart';

String rightLabel(AppStrings strings, DataRight type) => switch (type) {
  DataRight.access => strings.messages.privacyStringsAccessToMyData,
  DataRight.erasure => strings.messages.privacyStringsErasureRequest,
  DataRight.portability => strings.messages.privacyStringsPortability,
  DataRight.rectification => strings.messages.privacyStringsRectification,
  DataRight.restriction =>
    strings.messages.privacyStringsRestrictionOfProcessing,
  DataRight.objection => strings.messages.privacyStringsObjectionToProcessing,
};

String rightDescription(AppStrings strings, DataRight type) => switch (type) {
  DataRight.access => strings.messages.privacyRightAccessHelp,
  DataRight.erasure => strings.messages.privacyRightErasureHelp,
  DataRight.portability => strings.messages.privacyRightPortabilityHelp,
  DataRight.rectification => strings.messages.privacyRightRectificationHelp,
  DataRight.restriction => strings.messages.privacyRightRestrictionHelp,
  DataRight.objection => strings.messages.privacyRightObjectionHelp,
};

String rightStatus(AppStrings strings, RightStatus status) => switch (status) {
  RightStatus.pending => strings.messages.privacyStringsReceived,
  RightStatus.inProgress => strings.messages.privacyStringsInProgress,
  RightStatus.completed => strings.messages.privacyStringsCompleted,
  RightStatus.rejected => strings.messages.privacyStringsRejected,
};

String rightDetailsPrompt(AppStrings strings, DataRight type) => switch (type) {
  DataRight.rectification => strings.messages.privacyRequestRectificationPrompt,
  _ => strings.messages.privacyRequestDetailsLabel,
};

String reasonLabel(AppStrings strings, ReportReason reason) => switch (reason) {
  ReportReason.inappropriateContent =>
    strings.messages.privacyStringsInappropriateContent,
  ReportReason.fakeProfile => strings.messages.privacyStringsFakeProfile,
  ReportReason.harassment => strings.messages.privacyStringsHarassment,
  ReportReason.spam => strings.messages.privacyStringsSpam,
  ReportReason.other => strings.messages.privacyStringsOtherReason,
};

String privacyDate(AppStrings strings, DateTime time) => strings.dateTime(time);

String privacyNotice(AppStrings strings, String? code) => switch (code) {
  'session_revoked' => strings.messages.privacyStringsThisSessionWasRevoked,
  'unblocked' =>
    strings.messages.privacyStringsThisPersonIsUnblockedPreviousMatches,
  'request_open' => strings.messages.privacyStringsARequestOfThisTypeIs,
  'request_received' =>
    strings.messages.privacyStringsYourRequestWasReceivedProcessingWill,
  'export_ready' => strings.messages.privacyStringsYourExportIsReadyOnThis,
  'share_closed' => strings.messages.privacyStringsTheShareSheetIsClosedThis,
  _ => '',
};

String privacyFailure(AppStrings strings, ApiFailure failure) =>
    switch (failure.code) {
      'invalid_data_request' => strings.messages.privacyRequestDetailsInvalid,
      'export_cleanup' =>
        strings.messages.privacyStringsTemporaryFileCleanupFailedTryErasing,
      'export_share' =>
        strings.messages.privacyStringsSharingCouldNotBeOpenedDownload,
      'export_local_storage' =>
        strings.messages.privacyStringsTheFileCouldNotBeSaved,
      'data_export_too_large' || 'export_local_limit' =>
        strings.messages.privacyStringsYourExportExceedsTheAllowedSize,
      'data_request_already_open' =>
        strings.messages.privacyStringsARequestOfThisTypeIs692,
      'report_already_pending' =>
        strings.messages.privacyStringsAReportAboutThisPersonIs,
      'invalid_or_expired_deletion_token' =>
        strings.messages.privacyStringsConfirmationExpiredRestartDeletionIfYou,
      _ => switch (failure.kind) {
        ApiFailureKind.rateLimited =>
          strings.messages.devicesPageTooManyRequestsWaitBeforeTrying,
        ApiFailureKind.cancelled =>
          strings.messages.privacyStringsTheOperationWasInterrupted,
        _ => strings.messages.privacyStringsTheResponseCouldNotBeConfirmed,
      },
    };

String sessionNotice(AppStrings strings, String? notice) => switch (notice) {
  'erasure_accepted' =>
    strings.messages.privacyStringsYourDeletionRequestWasAcceptedYour,
  'erasure_unconfirmed' =>
    strings.messages.privacyStringsNoDeletionResponseWasReceivedThe,
  'erasure_not_accepted' =>
    strings.messages.privacyStringsAccountDeletionWasNotAcceptedThis,
  'closure_unconfirmed' =>
    strings.messages.privacyStringsSessionOrAccountClosureWasInterrupted,
  'logout_all_confirmed' =>
    strings.messages.privacyStringsAllYourSessionsWereRevoked,
  _ => strings.messages.privacyStringsYouAreSignedOutOnThis,
};
