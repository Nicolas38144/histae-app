import '../../../core/network/api_failure.dart';

abstract final class BillingStrings {
  static String date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String status(String? value) => switch (value) {
    'trialing' => 'Période d’essai',
    'active' => 'Abonnement actif',
    'past_due' => 'Paiement à régulariser',
    'incomplete' => 'Paiement à terminer',
    'incomplete_expired' => 'Souscription expirée',
    'canceled' => 'Abonnement résilié',
    'unpaid' => 'Paiement impayé',
    'paused' => 'Abonnement en pause',
    _ => 'Votre formule actuelle',
  };
  static String notice(String? value) => switch (value) {
    'confirmed' => 'Vos droits ont été confirmés par Histae.',
    'awaiting_confirmation' => 'Paiement ouvert dans votre navigateur. À votre retour, vérifiez votre abonnement. La confirmation peut prendre quelques instants.',
    'portal_opened' => 'Gestion ouverte dans votre navigateur. Vérifiez votre abonnement à votre retour.',
    'attempt_closed' => 'La tentative précédente est terminée ou expirée. Votre formule a été vérifiée. Vous pouvez choisir une nouvelle souscription.',
    _ => '',
  };
  static String error(ApiFailure e) => switch (e.code) {
    'subscription_already_active' => 'Un abonnement existe déjà. Actualisez votre situation avant de poursuivre.',
    'checkout_already_in_progress' => 'Une souscription est déjà ouverte. Reprenez la tentative ou attendez son expiration.',
    'billing_customer_reconciliation_required' ||
    'billing_customer_conflict' ||
    'checkout_state_conflict' => 'Votre souscription est en cours de vérification. Réessayez plus tard avec la même tentative.',
    'idempotency_key_reused' => 'Cette tentative doit être vérifiée avant de poursuivre. Contactez l’assistance si le problème persiste.',
    'idempotency_key_consumed' =>
      'Cette tentative est terminée ou expirée. Vérifiez votre abonnement.',
    'billing_customer_not_found' =>
      'La gestion de cet abonnement n’est pas encore disponible.',
    'browser_unavailable' => 'Impossible d’ouvrir le navigateur. Votre tentative reste disponible pour réessayer.',
    'billing_unavailable' ||
    'stripe_request_failed' ||
    'stripe_checkout_unavailable' => 'Le paiement est temporairement indisponible. Votre tentative est conservée.',
    _ => switch (e.kind) {
      ApiFailureKind.network || ApiFailureKind.timeout => 'Connexion interrompue. Le résultat reste à vérifier ; votre tentative est conservée.',
      ApiFailureKind.rateLimited => 'Veuillez patienter avant de réessayer.',
      ApiFailureKind.secureStorage => 'Le stockage sécurisé est indisponible. Aucun nouveau paiement ne peut être ouvert.',
      ApiFailureKind.invalidResponse => 'La réponse ne permet pas de confirmer votre situation. Actualisez avant de poursuivre.',
      _ => 'Votre abonnement ne peut pas être vérifié pour le moment. Réessayez plus tard.',
    },
  };
}
