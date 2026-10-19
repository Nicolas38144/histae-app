import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/profile_models.dart';

// Feature copy is kept together to support a later localization catalogue.

class ProfileStrings {
  const ProfileStrings(this.strings);
  final AppStrings strings;

  String failure(ApiFailure e) => switch (e.code) {
    'invalid_profile' =>
      strings.messages.profileStringsCheckYourFirstNameDateOf,
    'invalid_preferences' =>
      strings.messages.profileStringsCheckAllFourPreferencesAndTheir,
    'invalid_profile_answers' =>
      strings.messages.profileStringsCheckYourAnswersUpToThree,
    'profile_question_not_found' =>
      strings.messages.profileStringsAQuestionIsNoLongerAvailable,
    'trait_not_found' =>
      strings.messages.profileStringsThisTraitIsNoLongerAvailable,
    'profile_not_found' =>
      strings.messages.profileStringsCreateYourProfileFirst,
    'photo_selection_unavailable' =>
      strings.messages.profileStringsThePhotoCouldNotBePrepared,
    'invalid_photo' =>
      strings.messages.profileStringsThisPhotoIsNotRecognizedChoose,
    'photo_too_large' =>
      strings.messages.profileStringsThePreparedPhotoMustBeNo,
    'photo_storage_unavailable' =>
      strings.messages.profileStringsPhotosAreTemporarilyUnavailable,
    'photo_update_in_progress' || 'photo_update_conflict' =>
      strings.messages.profileStringsAPhotoUpdateIsInProgress,
    'idempotency_key_consumed' || 'idempotency_key_conflict' =>
      strings.messages.profileStringsThisPhotoRequestCanNoLonger,
    _ => strings.failureMessage(e.kind),
  };

  String moderation(Moderation? m) {
    if (m == null) return strings.messages.profileStringsNoAnalysisAvailable;
    final status = switch (m.status) {
      'pending' => strings.messages.profileStringsUnderReview,
      'approved' => strings.messages.profileStringsApproved,
      _ => strings.messages.profileStringsNeedsEditing,
    };
    if (m.reasons.isEmpty) return status;
    return '$status · ${m.reasons.map((r) => switch (r) {
      'spam' => strings.messages.profileStringsRepetitiveOrPromotionalContent,
      'insult' => strings.messages.profileStringsInsultingLanguage,
      'personal_contact' => strings.messages.profileStringsPersonalContactDetails,
      'sexual_content' || 'explicit_image' => strings.messages.profileStringsExplicitContent,
      'face_not_detected' => strings.messages.profileStringsNoFaceDetected,
      'multiple_faces' => strings.messages.profileStringsMultipleFaces,
      'blurry' => strings.messages.profileStringsBlurryImage,
      'analysis_unavailable' => strings.messages.profileStringsAnalysisTemporarilyUnavailable,
      'legacy_unreviewed' => strings.messages.profileStringsContentNeedsRechecking,
      _ => strings.messages.profileStringsReviewNeeded,
    }).join(', ')}';
  }

  Map<String, String> get sexes => {
    '': strings.messages.profileStringsNotProvided,
    'female': strings.messages.profileStringsWoman,
    'male': strings.messages.profileStringsMan,
    'other': strings.messages.profileStringsOther,
  };

  Map<String, String> get lookingFor => {
    'female': strings.messages.profileStringsWomen,
    'male': strings.messages.profileStringsMen,
    'both': strings.messages.profileStringsWomenAndMen,
    'other': strings.messages.profileStringsOther,
  };
}
