import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/match_models.dart';

class MatchesStrings {
  static String failure(ApiFailure e) => switch (e.code) {
    'match_not_found' ||
    'match_blocked' ||
    'match_expired' => 'Cette rencontre n’est plus disponible.',
    'messaging_not_available' || 'invalid_match_state' => 'Les envois ne sont pas disponibles dans l’état actuel de cette rencontre. Actualisez la conversation.',
    'invalid_message_request' || 'invalid_message_payload' =>
      'Écrivez un message non vide de 2 000 caractères maximum.',
    'idempotency_key_conflict' => 'Cette demande d’envoi ne correspond plus à ses paramètres d’origine. Aucun nouvel envoi n’a été créé. Actualisez la conversation.',
    'message_not_found' =>
      'Ce message n’est plus disponible. Actualisez la conversation.',
    'invalid_cursor' =>
      'Cette page ne peut plus être utilisée. L’historique va être relu.',
    'photo_storage_unavailable' =>
      'Les rencontres sont temporairement indisponibles. Réessayez plus tard.',
    _ => const AppStrings().failureMessage(e.kind),
  };
  static String status(MatchStatus status) => switch (status) {
    MatchStatus.active => 'Les premiers mots',
    MatchStatus.awaitingContinuation => 'Envois suspendus',
    MatchStatus.confirmed => 'Conversation ouverte',
    MatchStatus.expired || MatchStatus.ended => 'Rencontre terminée',
  };
  static String date(DateTime value) {
    final d = value.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)} à ${pad(d.hour)}:${pad(d.minute)}';
  }

  static String stateBody(UserMatch match) => switch (match.status) {
    MatchStatus.active => 'Première période jusqu’au ${date(match.expiresAt)}.',
    MatchStatus.awaitingContinuation =>
      'L’envoi est suspendu pendant la décision de continuation, jusqu’au ${date(match.expiresAt)}. L’historique reste accessible.',
    MatchStatus.confirmed => 'Vous pouvez poursuivre votre conversation.',
    MatchStatus.expired || MatchStatus.ended => 'Cette rencontre est terminée.',
  };
}
