import '../../../core/network/api_failure.dart';
import '../data/privacy_models.dart';

String rightLabel(DataRight type) => switch (type) {
  DataRight.access => 'Accès à mes données',
  DataRight.erasure => 'Demande d’effacement',
  DataRight.portability => 'Portabilité',
  DataRight.rectification => 'Rectification',
  DataRight.restriction => 'Limitation du traitement',
  DataRight.objection => 'Opposition au traitement',
};
String rightStatus(RightStatus status) => switch (status) {
  RightStatus.pending => 'Reçue',
  RightStatus.inProgress => 'En cours',
  RightStatus.completed => 'Terminée',
  RightStatus.rejected => 'Rejetée',
};
String reasonLabel(ReportReason reason) => switch (reason) {
  ReportReason.inappropriateContent => 'Contenu inapproprié',
  ReportReason.fakeProfile => 'Faux profil',
  ReportReason.harassment => 'Harcèlement',
  ReportReason.spam => 'Spam',
  ReportReason.other => 'Autre motif',
};
String privacyDate(DateTime time) {
  final d = time.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String privacyNotice(String? code) => switch (code) {
  'session_revoked' => 'Cette session a été révoquée.',
  'unblocked' => 'Cette personne est débloquée. Les anciennes rencontres ne sont pas rétablies.',
  'request_open' => 'Une demande de ce type est déjà ouverte. Son suivi est disponible ci-dessous.',
  'request_received' =>
    'Votre demande a été reçue. Son traitement sera suivi ici.',
  'export_ready' => 'Votre export est prêt sur cet appareil. Vous pouvez choisir où le partager.',
  'share_closed' => 'La feuille de partage est fermée. Cela ne confirme pas la réception du fichier.',
  _ => '',
};
String privacyFailure(ApiFailure failure) => switch (failure.code) {
  'export_cleanup' => 'Le nettoyage du fichier temporaire n’a pas abouti. Réessayez de l’effacer.',
  'export_share' => 'Le partage n’a pas pu être ouvert. Téléchargez à nouveau votre export pour réessayer.',
  'export_local_storage' =>
    'Le fichier n’a pas pu être enregistré. Vérifiez l’espace disponible.',
  'data_export_too_large' || 'export_local_limit' => 'Votre export dépasse la taille autorisée. Vous pouvez déposer une demande d’accès à vos données.',
  'data_request_already_open' => 'Une demande de ce type est déjà ouverte.',
  'report_already_pending' =>
    'Un signalement de cette personne est déjà en attente de traitement.',
  'invalid_or_expired_deletion_token' => 'La confirmation a expiré. Recommencez la suppression si vous le souhaitez.',
  _ => switch (failure.kind) {
    ApiFailureKind.rateLimited =>
      'Trop de demandes. Patientez avant de réessayer.',
    ApiFailureKind.cancelled => 'L’opération a été interrompue.',
    _ => 'La réponse n’a pas pu être confirmée. Actualisez le suivi avant de reprendre la même demande.',
  },
};
String sessionNotice(String? notice) => switch (notice) {
  'erasure_accepted' => 'Votre demande de suppression a été acceptée. Votre compte est inaccessible ; le nettoyage de vos données continue en arrière-plan.',
  'erasure_unconfirmed' => 'La réponse à la suppression n’a pas été reçue. La session de cet appareil est fermée ; l’acceptation de la demande reste à confirmer.',
  'erasure_not_accepted' => 'La suppression du compte n’a pas été acceptée. La session de cet appareil est fermée. Reconnectez-vous si vous souhaitez recommencer.',
  'closure_unconfirmed' => 'Une fermeture de session ou de compte a été interrompue. La session locale est fermée ; le résultat sur le serveur n’est pas confirmé.',
  'logout_all_confirmed' => 'Toutes vos sessions ont été révoquées.',
  'logout_confirmed' => 'Vous êtes déconnecté.',
  _ => 'Vous êtes déconnecté sur cet appareil. La révocation sur le serveur n’a pas pu être confirmée.',
};
