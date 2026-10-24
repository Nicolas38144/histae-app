import '../../profile/data/profile_models.dart';

/// Form state held in device memory until phone verification.
class RegistrationDraft {
  ProfileDraft profile = const ProfileDraft('', '', null, null);
  Preferences preferences = const Preferences(18, 99, 50, '');
}
