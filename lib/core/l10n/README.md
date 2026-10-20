# Traductions de l’interface

Les catalogues `arb/app_fr.arb`, `app_en.arb`, `app_es.arb` et `app_it.arb` sont la source des textes. Aucun libellé, message de validation, confirmation ou texte d’accessibilité ne doit être ajouté dans un widget, un contrôleur ou un modèle.

Ajouter une clé descriptive dans les quatre catalogues, avec ses paramètres dans les métadonnées du français, puis exécuter `flutter gen-l10n`. Ne pas modifier les fichiers `generated/` : les chaînes Dart qu’ils contiennent sont produites par Flutter. Utiliser `AppStrings.of(context).messages` pour la copie et `AppStrings` pour les dates, nombres, prix et erreurs métier. Les pluriels sont des messages ICU complets, sans suffixe concaténé.

Les couches de données et d’état renvoient des codes/énumérations (`ApiFailure`, `ClientMessage`), jamais une phrase traduite. La présentation choisit le texte au rendu ; un changement de langue traduit aussi une erreur déjà affichée. Les catalogues de questions, traits, offres et documents sont localisés par l’API selon `Accept-Language`, avec son repli français. Les bios, réponses et messages des personnes ne sont jamais traduits par le client.

`LocaleController` possède la préférence explicite d’appareil. Sans choix local enregistré, `AccountLanguageBinding` peut reprendre la préférence du compte vérifié ; une sélection connectée est aussi enregistrée via le dépôt de langue. Le français est conservé au premier lancement ; l’accueil et le profil donnent accès au choix français, anglais, espagnol, italien ou langue de l’appareil. Une variante régionale prise en charge utilise sa langue principale ; une langue non prise en charge revient au français. La préférence est restaurée avant `runApp`, enregistrée sous une clé séparée et conservée à la déconnexion. Une erreur d’enregistrement est affichée sans prétendre que le choix a été mémorisé. Le changement ne recrée ni la session, ni le navigateur, ni les brouillons.

Les permissions iOS sont aussi décrites dans les ARB. Après modification, exécuter `dart run tool/generate_native_localizations.dart` pour actualiser les ressources natives `InfoPlist.strings` des quatre langues. Les dialogues du système et des fournisseurs suivent leurs propres réglages de langue ; le choix Flutter ne modifie pas les réglages du téléphone ni directement la langue des dialogues natifs. Les nouvelles demandes Stripe utilisent la langue transmise à l’API ; une tentative Checkout reprise conserve sa langue d’origine.

Vérification ciblée : `flutter test test/localization_test.dart`. Elle contrôle la complétude des catalogues, les paramètres, les pluriels, l’encodage, les libellés en dur dans les widgets, le stockage et la conservation de la navigation et du brouillon. Revue visuelle avec données simulées : `flutter test tool/preview_localizations_test.dart --update-goldens`, captures dans `build/previews/localization/`.

Les règles réseau, les documents réellement présentés, le stockage des intentions et les validations
à lancer sans fournisseur réel sont décrits dans [le guide des langues API](../../../docs/api-languages.md).
