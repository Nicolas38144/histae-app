import 'package:flutter/widgets.dart';

import '../network/api_failure.dart';

// Centralized French copy; add locales and a delegate when a second language
// is introduced. Material's built-in labels are localized separately.
class AppStrings {
  const AppStrings();
  static AppStrings of(BuildContext context) => const AppStrings();

  String get appName => 'Histae';
  String get wordsFirst => 'LES MOTS D’ABORD';
  String get registrationHeading => 'Faisons connaissance.';
  String get loginHeading => 'Heureux de vous retrouver.';
  String get trustHeading => 'En toute confiance.';
  String get signIn => 'Se connecter';
  String get createAccount => 'Créer mon compte';
  String get existingAccount => 'J’ai déjà un compte';
  String get myAccount => 'Mon espace';
  String get otpIntroduction =>
      'Validez votre numéro avec un code reçu par SMS. '
      'Ce parcours crée votre compte s’il n’existe pas, ou vous reconnecte sinon.';
  String get onboardingRequired =>
      'Complétez les choix obligatoires indiqués par le serveur avant de poursuivre.';
  String get actionInProgress => 'Action en cours…';
  String get phoneLabel => 'Numéro français au format +33';
  String get phoneHint => '+33 6 12 34 56 78';
  String get phoneHelp =>
      'Saisissez +33 suivi des 9 chiffres, sans le zéro initial.';
  String get sendOtp => 'Demander un code';
  String get resendOtp => 'Demander un nouveau code';
  String get resumeOtp => 'Reprendre la demande précédente';
  String get otpLabel => 'Code de vérification à 6 chiffres';
  String get verifyOtp => 'Vérifier le code';
  String get changePhone => 'Changer de numéro';
  String get otpAccepted =>
      'La demande a été acceptée. Cela ne confirme pas la réception du SMS.';
  String get verificationUncertain =>
      'La vérification n’a pas pu être confirmée. '
      'Demandez un nouveau code pour vous reconnecter ; le précédent peut avoir été consommé.';
  String get sessionLoading => 'Vérification de votre session…';
  String get sessionUnavailable => 'Votre session n’est pas accessible';
  String get logout => 'Se déconnecter';
  String get logoutConfirmed => 'Vous êtes déconnecté.';
  String get logoutUnconfirmed =>
      'Vous êtes déconnecté sur cet appareil. '
      'La révocation de la session sur le serveur n’a pas pu être confirmée.';
  String get privacyTitle => 'Vos choix et votre vie privée';
  String get consentsTitle => 'Vos consentements';
  String get consentsIntro =>
      'Chaque choix est indépendant. Les conditions d’utilisation '
      'et la prise de connaissance de la notice sont nécessaires pour utiliser Histae. '
      'Les autres choix concernent les données sensibles et la localisation.';
  String get consentCurrent => 'Accord enregistré pour la version actuelle';
  String get saveChoices => 'Enregistrer mes choix';
  String get refreshChoices => 'Actualiser mes consentements';
  String get withdraw => 'Retirer mon consentement';
  String get confirmWithdrawal => 'Confirmer le retrait';
  String get cancel => 'Annuler';
  String get openDocumentError =>
      'Le document n’a pas pu être ouvert. Vérifiez votre connexion et réessayez.';
  String documentVersion(String version) =>
      'Lire le document — version $version';
  String get documentsChanged =>
      'Les documents ont changé. Relisez les nouvelles versions avant de confirmer vos choix.';
  String get choicesSaved => 'Vos choix ont été enregistrés.';
  String get accountTitle => 'Votre espace Histae';
  String get accountReady =>
      'Votre compte est créé et vos consentements obligatoires sont à jour. '
      'Vous pourrez compléter votre profil lors de la prochaine mise à jour.';
  String get privacyScope =>
      'Vous pouvez consulter vos documents, gérer vos consentements '
      'ou vous déconnecter ici, même si votre parcours n’est pas terminé.';
  String authFailure(ApiFailure error) => switch (error.code) {
    'invalid_phone_number' =>
      'Saisissez un numéro français valide au format +33.',
    'invalid_otp_request' => 'Saisissez les six chiffres du code reçu.',
    'invalid_or_expired_otp' => 'Le code est invalide ou a expiré.',
    'otp_delivery_unavailable' => 'L’envoi du SMS n’a pas pu être effectué. Vous pouvez reprendre la demande.',
    'otp_delivery_unknown' =>
      'L’envoi du SMS reste incertain. Le code peut encore arriver. '
          'Vous pouvez saisir ce code ou reprendre la même demande.',
    'idempotency_key_conflict' => 'Cette demande ne correspond plus à son intention d’origine. Demandez un nouveau code.',
    'account_unavailable' => 'Ce compte n’est pas disponible.',
    'legal_documents_changed' => documentsChanged,
    _ => failureMessage(error.kind),
  };
  String get welcomeTitle => 'Prendre le temps de se rencontrer.';
  String get welcomeBody =>
      'Découvrez une personne à travers ses mots. '
      'Les photos se révèlent lorsque vous le choisissez tous les deux.';
  String get catalogAction => 'Découvrir les formules';
  String get catalogTitle => 'Les formules Histae';
  String get catalogIntro =>
      'Consultez les formules et leurs conditions. '
      'La révélation des photos demande toujours votre accord mutuel.';
  String get catalogReadOnly =>
      'Retrouvez votre abonnement et les possibilités de souscription depuis votre profil.';
  String get loading => 'Chargement des formules…';
  String get emptyTitle => 'Aucune formule disponible';
  String get emptyBody =>
      'Les formules ne sont pas disponibles pour le moment.';
  String get retry => 'Réessayer';
  String get refresh => 'Actualiser';
  String get configurationTitle => 'Service non configuré';
  String get configurationBody =>
      'Le service n’est pas encore configuré '
      'pour cette version de l’application.';
  String get errorTitle => 'Impossible de charger les formules';
  String get offlineTitle => 'Connexion indisponible';
  String retryIn(int seconds) => 'Nouvel essai possible dans $seconds s';
  String requestReference(String id) => 'Référence de la demande : $id';
  String money(int cents, String currency) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} $currency';
  String monthly(int cents, String currency) =>
      '${money(cents, currency)} / mois';
  String annual(int cents, String currency) => '${money(cents, currency)} / an';
  String weeklyCredits(int credits) => 'Crédits inclus par semaine : $credits';
  String weeklyLimit(int limit) => 'Continuations par semaine : $limit maximum';
  String get noWeeklyLimit => 'Continuations sans plafond hebdomadaire';
  String adStock(int limit) =>
      'Stock maximal de crédits publicitaires : $limit';
  String ads(bool removed) =>
      removed ? 'Publicités retirées' : 'Publicités non retirées';
  String rewards(bool enabled) => enabled
      ? 'Récompenses publicitaires activées pour cette formule'
      : 'Récompenses publicitaires indisponibles pour cette formule';

  String? featureTitle(String code, String? fallback) => switch (code) {
    'messages' => 'Messagerie',
    'photo_reveal' => 'Révélation mutuelle des photos',
    'continuations' => 'Poursuivre une conversation',
    'advertising_credits' => 'Récompenses vidéo volontaires',
    'no_ads' => 'Sans publicité',
    _ => fallback,
  };

  String? featureDescription(String code, String? fallback) => switch (code) {
    'messages' => 'Échangez pendant la période initiale, puis après votre accord mutuel de continuation.',
    'photo_reveal' =>
      'Les photos se révèlent après votre accord à tous les deux.',
    'continuations' =>
      'Chaque personne donne son accord et utilise ses propres droits.',
    'advertising_credits' =>
      'Le serveur valide la récompense avant d’attribuer les crédits.',
    'no_ads' => 'Cette formule retire les publicités.',
    _ => fallback,
  };

  String failureMessage(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.secureStorage =>
      'Le stockage sécurisé est indisponible. '
          'Déverrouillez votre appareil et réessayez. La connexion reste fermée.',
    ApiFailureKind.sessionUncertain => 'La session ne peut pas être restaurée avec certitude. Reconnectez-vous avec un nouveau code.',
    ApiFailureKind.network =>
      'Le service est injoignable. Vérifiez votre connexion puis réessayez.',
    ApiFailureKind.timeout =>
      'Le service met trop de temps à répondre. Vous pouvez réessayer.',
    ApiFailureKind.invalidResponse =>
      'La réponse du service n’a pas pu être lue.',
    ApiFailureKind.validation =>
      'La demande n’a pas été acceptée par le service.',
    ApiFailureKind.unauthenticated => 'Une connexion au compte est nécessaire.',
    ApiFailureKind.consentRequired =>
      'Les consentements requis doivent être complétés.',
    ApiFailureKind.discoveryNotReady =>
      'Votre profil doit être complété pour découvrir des personnes.',
    ApiFailureKind.quota => 'Le quota disponible ne permet pas cette action.',
    ApiFailureKind.forbidden =>
      'Cette action n’est pas autorisée actuellement.',
    ApiFailureKind.notFound => 'Le contenu demandé n’est plus accessible.',
    ApiFailureKind.conflict =>
      'La situation a changé. Actualisez avant de réessayer.',
    ApiFailureKind.expired => 'Ce contenu a expiré.',
    ApiFailureKind.payloadTooLarge =>
      'Le contenu envoyé dépasse la taille autorisée.',
    ApiFailureKind.rateLimited =>
      'Trop de demandes ont été envoyées. Patientez avant de réessayer.',
    ApiFailureKind.unavailable ||
    ApiFailureKind.server => 'Le service est temporairement indisponible.',
    ApiFailureKind.cancelled => 'Le chargement a été interrompu.',
    ApiFailureKind.unexpected => 'Le service a renvoyé une réponse inattendue.',
  };
}
