import '../../../core/l10n/app_strings.dart';
import '../domain/consent_state.dart';

extension ConsentStrings on AppStrings {
  String consentLabel(ConsentType type) => switch (type) {
    ConsentType.terms => 'J’accepte les conditions d’utilisation',
    ConsentType.privacy =>
      'J’ai pris connaissance de la notice de confidentialité',
    ConsentType.sensitive => 'J’accepte le traitement de mes données sensibles',
    ConsentType.location => 'J’accepte le traitement de ma localisation',
  };
  String consentTitle(ConsentType type) => switch (type) {
    ConsentType.terms => 'Conditions d’utilisation',
    ConsentType.privacy => 'Notice de confidentialité',
    ConsentType.sensitive => 'Données sensibles',
    ConsentType.location => 'Localisation',
  };
  String withdrawalMessage(ConsentType type) => type == ConsentType.sensitive
      ? 'Ce retrait efface votre sexe et vos préférences sur le serveur. '
            'La découverte pourra devenir indisponible. Confirmer ce retrait ?'
      : 'Ce retrait efface votre présence sur le serveur. '
            'La découverte pourra devenir indisponible. Il ne change pas la permission système. Confirmer ce retrait ?';
}
