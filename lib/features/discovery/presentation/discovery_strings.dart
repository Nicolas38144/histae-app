import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';

class DiscoveryStrings {
  static String failure(ApiFailure e) => switch (e.code) {
    'discovery_not_ready' => 'Vos conditions de découverte ont changé. Actualisez les étapes ci-dessous.',
    'discovery_unavailable' => 'La découverte est temporairement indisponible.',
    'invalid_cursor' => 'Cette page a expiré. Actualisez les profils.',
    'invalid_feed_query' || 'invalid_feed_request' =>
      'Les profils ne peuvent pas être chargés pour le moment.',
    'swipe_already_recorded' =>
      'Un choix existe déjà pour ce profil. Il ne peut pas être modifié.',
    'discovery_candidate_not_found' ||
    'match_blocked' => 'Ce profil n’est plus disponible.',
    _ => const AppStrings().failureMessage(e.kind),
  };
  static String location(LocationIssue issue) => switch (issue) {
    LocationIssue.disabled => 'La localisation de l’appareil est désactivée. Activez-la dans les réglages, puis réessayez.',
    LocationIssue.denied => 'L’accès à la position a été refusé. Vous pourrez le redemander lorsque vous le souhaitez.',
    LocationIssue.deniedForever => 'L’accès à la position doit être autorisé dans les réglages de l’appareil.',
    LocationIssue.timeout => 'La position n’a pas été trouvée à temps. Réessayez dans un endroit mieux couvert.',
    LocationIssue.stale => 'Cette position est trop ancienne ou invalide pour être utilisée. Demandez une nouvelle mesure.',
    LocationIssue.unavailable =>
      'La position ne peut pas être obtenue pour le moment.',
    LocationIssue.cancelled =>
      'La localisation a été interrompue. Vous pouvez la redemander.',
  };
  static String actionTitle(DiscoveryAction action) => switch (action) {
    DiscoveryAction.profile => 'Votre présentation',
    DiscoveryAction.resumeDiscovery => 'Votre profil est en pause',
    DiscoveryAction.sex => 'Le sexe de votre profil',
    DiscoveryAction.preferences => 'Vos envies de rencontre',
    DiscoveryAction.sensitiveConsent => 'Les données sensibles',
    DiscoveryAction.locationConsent => 'Votre choix de localisation',
    DiscoveryAction.freshPresence => 'Une position récente',
  };
  static String actionBody(DiscoveryAction action) => switch (action) {
    DiscoveryAction.profile =>
      'Ajoutez votre prénom, votre date de naissance et votre présentation.',
    DiscoveryAction.resumeDiscovery => 'Votre profil est masqué des nouvelles découvertes. Vous pouvez poursuivre vos conversations et reprendre les rencontres à votre rythme.',
    DiscoveryAction.sex => 'Renseignez ce champ pour permettre les critères réciproques de rencontre.',
    DiscoveryAction.preferences => 'Choisissez les personnes, les âges et la distance qui vous correspondent.',
    DiscoveryAction.sensitiveConsent =>
      'L’utilisation du sexe et des préférences demande votre accord distinct.',
    DiscoveryAction.locationConsent => 'Décidez si Histae peut utiliser votre position pour les rencontres à proximité.',
    DiscoveryAction.freshPresence => 'Une mesure ponctuelle suffit. Votre position exacte n’apparaît pas sur les profils.',
  };
  static String notice(String? code) => switch (code) {
    'location_approximate' => 'Position approximative utilisée. Les distances peuvent être moins précises.',
    'location_updated' => 'Votre position a été actualisée.',
    'presence_uncertain' => 'L’envoi de la position reste incertain. Son état est relu auprès de Histae ; aucun renvoi automatique.',
    'liked' => 'Votre intérêt a été enregistré.',
    'passed' => 'Vous avez passé ce profil.',
    'blocked' =>
      'Ce profil est bloqué. Vous ne pourrez plus vous rencontrer ni échanger.',
    'candidate_unavailable' => 'Ce profil a été retiré de votre découverte. Aucun autre choix n’a été envoyé.',
    _ => '',
  };
  static String distance(double km) =>
      'À ${km.toStringAsFixed(km == km.roundToDouble() ? 0 : 1).replaceAll('.', ',')} km';
  static String pending(PendingAction action) => switch (action) {
    PendingAction.like => 'Reprendre le même « J’aime »',
    PendingAction.pass => 'Reprendre le même passage',
    PendingAction.block => 'Reprendre le blocage',
  };
}
