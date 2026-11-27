import '../../../core/models/client_message.dart';
import '../../profile/data/profile_models.dart';

/// Form state held in device memory until phone verification.
class RegistrationDraft {
  ProfileDraft profile = const ProfileDraft('', '', null, null);
  Preferences preferences = const Preferences(18, 50, 50, '');

  ClientMessage? profileError(DateTime now) =>
      profile.validate(now) ??
      (profile.sex == null ? ClientMessage.sexInvalid : null);
}
