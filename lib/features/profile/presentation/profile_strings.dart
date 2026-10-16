import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../data/profile_models.dart';

// Feature copy is kept together to support a later localization catalogue.
class ProfileStrings {
  static String failure(ApiFailure e) => switch (e.code) {
    'invalid_profile' =>
      'Vérifiez le prénom, la date de naissance, le sexe et la présentation.',
    'invalid_preferences' =>
      'Vérifiez les quatre préférences et leurs limites.',
    'invalid_profile_answers' => 'Vérifiez vos réponses : trois questions distinctes maximum, de 10 à 300 caractères chacune.',
    'profile_question_not_found' => 'Une question n’est plus disponible. Relisez le catalogue avant de modifier votre sélection ; votre brouillon reste affiché.',
    'trait_not_found' =>
      'Ce trait n’est plus disponible. Actualisez les traits.',
    'profile_not_found' => 'Créez d’abord votre profil.',
    'photo_selection_unavailable' => 'La photo n’a pas pu être préparée. Vérifiez l’accès aux photos dans les réglages, ou choisissez une autre image.',
    'invalid_photo' =>
      'Cette photo n’est pas reconnue. Choisissez une autre image.',
    'photo_too_large' =>
      'La photo doit faire au maximum 500 000 octets après préparation.',
    'photo_storage_unavailable' =>
      'Les photos sont temporairement indisponibles.',
    'photo_update_in_progress' || 'photo_update_conflict' => 'Une mise à jour photo est en cours. Relisez le profil puis reprenez la même demande.',
    'idempotency_key_consumed' || 'idempotency_key_conflict' => 'Cette demande photo ne peut plus être reprise. Relisez votre profil avant de choisir une nouvelle photo.',
    _ => const AppStrings().failureMessage(e.kind),
  };
  static String moderation(Moderation? m) {
    if (m == null) return 'Aucune analyse disponible.';
    final status = switch (m.status) {
      'pending' => 'En cours de vérification',
      'approved' => 'Approuvé',
      _ => 'À modifier',
    };
    if (m.reasons.isEmpty) return status;
    return '$status · ${m.reasons.map((r) => switch (r) {
      'spam' => 'contenu répétitif ou promotionnel',
      'insult' => 'propos insultants',
      'personal_contact' => 'coordonnées personnelles',
      'sexual_content' || 'explicit_image' => 'contenu explicite',
      'face_not_detected' => 'visage non détecté',
      'multiple_faces' => 'plusieurs visages',
      'blurry' => 'image floue',
      'analysis_unavailable' => 'analyse temporairement indisponible',
      'legacy_unreviewed' => 'contenu à revérifier',
      _ => 'vérification nécessaire',
    }).join(', ')}';
  }

  static const sexes = {
    '': 'Non renseigné',
    'female': 'Femme',
    'male': 'Homme',
    'other': 'Autre',
  };
  static const lookingFor = {
    'female': 'Des femmes',
    'male': 'Des hommes',
    'both': 'Des femmes et des hommes',
    'other': 'Autre',
  };
}
