import '../../../core/models/public_profile_answer.dart';
import '../data/profile_models.dart';

/// Public text only. Photos and private profile fields cannot enter a preview.
class ProfileFeedPreview {
  ProfileFeedPreview._({
    required this.firstname,
    required this.age,
    required this.bio,
    required List<String> traits,
    required List<PublicProfileAnswer> answers,
  }) : traits = List.unmodifiable(traits),
       answers = List.unmodifiable(answers);

  factory ProfileFeedPreview.fromProfile({
    required OwnerProfile profile,
    required List<ProfileTrait> traits,
    required List<ProfileAnswer> answers,
    required DateTime now,
  }) {
    final approvedAnswers =
        answers
            .where((answer) => answer.moderation.status == 'approved')
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return ProfileFeedPreview._(
      firstname: profile.firstname,
      age: ageOn(parseBirthdate(profile.birthdate)!, now),
      bio: profile.bioModeration?.status == 'approved' ? profile.bio : null,
      traits: [for (final trait in traits) trait.name],
      answers: [
        for (final answer in approvedAnswers)
          PublicProfileAnswer(
            answer.questionId,
            answer.question,
            answer.answer,
            answer.position,
          ),
      ],
    );
  }

  final String firstname;
  final int age;
  final String? bio;
  final List<String> traits;
  final List<PublicProfileAnswer> answers;
}
