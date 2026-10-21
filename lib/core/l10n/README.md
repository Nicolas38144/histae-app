# Traductions de l’interface

Les sources sont les quatre catalogues [ARB](arb/) : français, anglais, espagnol et italien. Les textes d’interface, validations, confirmations et libellés d’accessibilité doivent y être déclarés.

## Ajouter ou modifier un texte

1. Ajouter une clé descriptive dans les quatre catalogues, avec les paramètres et métadonnées nécessaires dans le français.
2. Utiliser un message ICU pour les pluriels ; éviter les phrases et suffixes assemblés dans le code.
3. Régénérer les classes Flutter :

```bash
flutter gen-l10n
```

Utiliser `AppStrings.of(context).messages` pour les textes et `AppStrings` pour les formats de dates, nombres, prix et erreurs. Les couches de données et d’état renvoient des codes ou `ClientMessage`, traduits par la présentation. Ne pas éditer les fichiers de [generated](generated/) à la main.

## Préférence et contenus

`LocaleController` possède la préférence d’appareil, restaurée avant le premier rendu. Sans choix explicite, le compte vérifié peut fournir sa langue via `AccountLanguageBinding`. Le français est le repli ; le mode appareil résout la langue principale du système. Changer de langue conserve la navigation et les brouillons.

L’API localise ses catalogues et documents selon `Accept-Language`. Les textes personnels ne sont pas traduits automatiquement. La langue d’un document effectivement présenté et celle de son acceptation restent distinctes de la préférence d’interface. Voir le [guide des langues API](../../../docs/api-languages.md).

Les dialogues du système et des fournisseurs suivent leurs réglages natifs. Si les textes de permission iOS des ARB changent, régénérer également leurs ressources :

```bash
dart run tool/generate_native_localizations.dart
```

## Vérification ciblée

Depuis la racine de l’app :

```bash
flutter test test/localization_test.dart
```

Ce contrôle vérifie notamment la complétude des catalogues, les paramètres, les pluriels et l’absence de libellés en dur. Pour une revue visuelle des quatre langues, utiliser `tool/preview_localizations_test.dart` et examiner les longues traductions, le texte agrandi et le clavier. Les commandes communes sont dans le [README principal](../../../README.md).
