import '../../../core/l10n/app_strings.dart';
import '../domain/consent_state.dart';

extension ConsentStrings on AppStrings {
  String consentLabel(ConsentType type) => switch (type) {
    ConsentType.terms => messages.consentStringsIAcceptTheTermsOfUse,
    ConsentType.privacy => messages.consentStringsIHaveReadThePrivacyNotice,
    ConsentType.sensitive => messages.consentStringsIConsentToTheProcessingOf,
    ConsentType.location => messages.consentStringsIConsentToTheProcessingOf198,
  };
  String consentTitle(ConsentType type) => switch (type) {
    ConsentType.terms => messages.consentStringsTermsOfUse,
    ConsentType.privacy => messages.consentStringsPrivacyNotice,
    ConsentType.sensitive => messages.consentStringsSensitiveData,
    ConsentType.location => messages.consentStringsLocation,
  };
  String withdrawalMessage(ConsentType type) => type == ConsentType.sensitive
      ? messages.consentStringsWithdrawingDeletesYourSexAndPreferences
      : messages.consentStringsWithdrawingDeletesYourLocationPresenceFrom;
}
