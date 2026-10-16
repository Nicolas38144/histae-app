import '../../../core/network/api_failure.dart';
import '../../matches/presentation/matches_strings.dart';

class ContinuationStrings {
  static String failure(ApiFailure e) => switch (e.code) {
    'continuation_plan_changed' => 'Votre formule a changé. Relisez vos crédits et confirmez à nouveau le coût présenté.',
    'continuation_quota_reached' =>
      'Aucune nouvelle continuation n’est disponible dans votre quota actuel.',
    'continuation_not_available_yet' => 'La période de décision n’est pas encore ouverte. Actualisez la rencontre.',
    'advertising_disabled' =>
      'Les vidéos récompensées sont actuellement indisponibles.',
    'advertising_not_eligible' => 'Aucune nouvelle vidéo récompensée n’est disponible pour votre compte actuellement.',
    'advertising_stock_full' =>
      'Votre stock de crédits publicitaires est plein, réservations comprises.',
    'reward_not_found' =>
      'Cette récompense n’est plus accessible. Vérifiez vos crédits.',
    'admob_verification_unavailable' => 'La vérification de la récompense est temporairement indisponible. Aucun crédit n’est confirmé pour le moment.',
    _ => MatchesStrings.failure(e),
  };
}
