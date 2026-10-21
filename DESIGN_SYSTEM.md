# Système visuel Histae

L’app reprend l’identité du [site Histae](https://www.histae.com/fr/) : livre ouvert, bleu nuit, lavande, touches abricot et titres à empattements. Le mode nuit est appliqué par défaut.

## Ton et contenu

Écrire simplement, avec chaleur et des actions concrètes. Garder le vouvoiement en français. Les messages courants parlent des personnes et de leurs possibilités, sans exposer les mécanismes réseau. Un résultat incertain reste présenté comme incertain : aucun enregistrement, paiement ou crédit ne doit être annoncé sans confirmation.

Laisser de la place aux bios longues et aux réponses. Les contenus des personnes ne sont ni réécrits ni traduits automatiquement. Les exemples et captures de démonstration utilisent des profils fictifs identifiés comme tels. Les états vides proposent une action utile sans simuler d’activité.

## Couleurs et typographie

Les valeurs de référence sont dans [HistaeTokens](lib/core/theme/histae_tokens.dart), appliquées par le [thème Flutter](lib/app/theme.dart).

| Usage | Valeur |
| --- | --- |
| Fond principal | `#0D1421` |
| Fond secondaire | `#141D2D` |
| Panneau | `#1A2231` |
| Texte principal | `#F9F7F2` |
| Texte secondaire | `#C6C1D3` |
| Accent lavande | `#B69CFF` |
| Accent abricot | `#F09A82` |
| Action principale | Dégradé `#F2A48C` → `#D8B3F7`, texte bleu nuit. |

**Inter** porte les textes, boutons et formulaires ; **Source Serif 4** porte les titres. Les tailles s’adaptent à la largeur et à la préférence de texte du système. Les cartes utilisent des bordures fines et un rayon courant de 20 px ; les actions principales sont arrondies en pilule.

Les polices sont embarquées avec leurs licences : [Inter](assets/fonts/inter/OFL.txt), [Source Serif 4](assets/fonts/source_serif_4/OFL.txt) et la famille historique [DM Serif Display](assets/fonts/dm_serif_display/OFL.txt).

## Logo et ouverture

Le logo est le **livre ouvert**, seul ou accompagné du nom Histae. La source produit est [histae-logo.svg](assets/branding/histae-logo.svg). Les signatures sombre et claire, leurs PNG et l’icône native sont dans [assets/branding](assets/branding/).

Les icônes Android/iOS montrent uniquement le livre, avec une marge adaptée aux masques natifs. Android dispose aussi de calques adaptatifs et monochromes. Les proportions de l’icône sont distinctes de celles des en-têtes. Le [guide de lancement iOS](ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) précise les ressources de l’écran natif.

À l’ouverture, **H.** se sépare pour dévoiler **istae**, puis le livre apparaît. Cette animation de 1 480 ms ne joue qu’au montage ; elle est ignorée si les animations sont désactivées et se termine lors d’une suspension. Le contenu, la session et la navigation conservent leur état.

Le [générateur d’assets](tool/generate_brand_assets.cjs) nécessite Node.js, Sharp et les sources SVG locales de `pictures/logos/nouvelle-da/02-les-pages/`. Il régénère les fichiers produit et les tailles natives ; son option `--site` exporte aussi les assets du site.

## Composition des écrans

Le **Feed** réserve l’espace aux profils, sans bouton commercial. Les bios et réponses restent entièrement lisibles ; faire défiler un texte long ne doit pas déclencher un passage accidentel au profil suivant.

Dans **Matchs**, l’introduction précède une réserve de crédits compacte et défilante. Free voit les crédits gratuits et publicitaires disponibles ainsi que l’action Vidéos. Premium dispose d’un message adapté, sans bouton vidéo. Une lecture inconnue ou échouée ne produit pas un faux solde nul.

Le **Profil** commence par la présentation, les réponses et l’aperçu public, puis regroupe les détails, le mode pause et les réglages du compte. Un seul accès affiche Premium pour Free ou Mon abonnement pour Premium ; l’état de chargement reste neutre.

L’éditeur de réponses distingue la question, le texte, son ordre et les actions de retrait/déplacement. La sélection recherche dans les questions disponibles ; l’enregistrement du remplacement complet est explicite. Les consentements sensibles et de localisation utilisent des interrupteurs, séparés des documents CGU et notice.

## Composants et accessibilité

`HistaeScaffold`, `HistaeButton`, les cartes et les séparateurs composent des widgets Flutter standards. La décoration conserve les états désactivés, le focus, la sémantique et le comportement du clavier. Les valeurs et droits affichés restent fournis par les contrôleurs.

La barre Feed / Matchs / Profil occupe aussi la zone de sécurité inférieure ; les barres système suivent le thème. Avec un petit écran, le clavier ou du texte à 200 %, garder le défilement et les mots entiers. L’en-tête du chat devient compact ; les détails et confirmations restent défilables. Ne pas réduire globalement l’échelle de texte choisie par la personne.

## Vérification visuelle

Les scénarios `tool/preview_*_test.dart` produisent des aperçus des vrais widgets avec données simulées sous `build/previews/`. Pour l’ouverture, par exemple :

```bash
flutter test tool/preview_brand_test.dart --update-goldens
```

Selon l’outil, définir `FLUTTER_ROOT` vers le SDK local. Examiner les états utiles, les longues traductions, le texte à 200 %, le clavier et les zones système. Ajouter un test seulement si le comportement modifié le justifie. Les masques d’icône, polices et démarrages natifs restent à contrôler sur Android et iOS.

Voir le [README](README.md) pour les commandes communes et la [roadmap](roadmap.md) pour les validations restantes.
