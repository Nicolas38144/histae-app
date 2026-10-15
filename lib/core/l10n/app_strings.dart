import 'package:flutter/widgets.dart';

import '../network/api_failure.dart';

// Centralized French copy; add locales and a delegate when a second language
// is introduced. Material's built-in labels are localized separately.
class AppStrings {
  const AppStrings();
  static AppStrings of(BuildContext context) => const AppStrings();

  String get appName => 'Histae';
  String get welcomeTitle => 'Une rencontre commence par une conversation.';
  String get welcomeBody =>
      'Découvrez une personne à travers ses mots. '
      'Les photos se révèlent lorsque vous le choisissez tous les deux.';
  String get catalogAction => 'Découvrir les formules';
  String get catalogTitle => 'Les formules Histae';
  String get catalogIntro =>
      'Consultez les formules et leurs conditions. '
      'La révélation des photos demande toujours votre accord mutuel.';
  String get catalogReadOnly =>
      'La souscription n’est pas encore disponible dans l’application.';
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
  String trial(int days) => 'Période d’essai : $days jour(s)';
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
