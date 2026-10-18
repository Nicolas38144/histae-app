# Direction artistique Histae

Référence depuis le 18 octobre 2026 : [histae.com/fr](https://www.histae.com/fr/) et le dépôt voisin `histae-site`, notamment `app/globals.css`, `components/site-header.tsx` et `components/home-page.tsx`. La référence du site remplace la précédente palette forêt/papier ; la navigation à trois onglets et les gestes du feed sont conservés.

## Identité commune

| Usage | Valeur du site reprise dans l'app |
| --- | --- |
| Fond bleu nuit | `#0D1421` |
| Surface secondaire | `#141D2D` |
| Texte principal | `#F9F7F2` |
| Texte secondaire | `#C6C1D3` |
| Accent lavande | `#B69CFF` |
| Accent abricot | `#F09A82` |
| Prune | `#392243` |
| Action principale | Dégradé `#F2A48C` → `#D8B3F7`, texte bleu nuit |

Les valeurs communes sont regroupées dans `lib/core/theme/histae_tokens.dart` et utilisées par `lib/app/theme.dart`. Les cartes utilisent des surfaces légèrement relevées, des bordures fines et des angles de 20 px. Les boutons sont arrondis en pilule. Les halos restent discrets ; ils n'utilisent ni filtre de flou coûteux ni animation continue.

Le mot-symbole reprend « Histae. », avec son point abricot. Le motif des deux lignes qui se rejoignent, présent sur le site, est adapté au format mobile et dessiné avec Flutter. Il n'introduit ni requête réseau ni image distante.

## Typographie

Le site déclare Inter pour le texte courant et Georgia pour les titres. L'app embarque **Inter** et **Source Serif 4**, cette dernière conservant l'esprit des titres Georgia sur les deux plateformes sans distribuer une police système propriétaire. Les fichiers variables et leurs licences SIL OFL proviennent du dépôt officiel Google Fonts. Les licences sont déclarées dans le registre Flutter. Les anciens fichiers DM Serif Display sont conservés pour respecter la consigne de ne supprimer aucun fichier ; les écrans refondus utilisent les nouvelles familles.

Les titres de section ont une taille habituelle de 28 à 38 px, le titre d'accueil 46 px, les paragraphes 15 à 17 px. Les corps, boutons et formulaires restent en Inter. Les titres suivent la largeur disponible ; les sauts de ligne décoratifs des anciens en-têtes ne sont plus imposés.

## Composants et écrans

- `HistaeScaffold` applique le fond et l'en-tête à toutes les pages en conservant le comportement de `Scaffold`, du clavier et de la navigation.
- `HistaeButton` conserve les états, le focus et les interactions de `FilledButton` sur le dégradé du site. Une action désactivée garde un fond neutre.
- `EditorialCard` conserve son ancien point d'entrée et présente désormais un en-tête de section libre, comme ceux du site. Les séparateurs deviennent de simples lignes fines.
- L'accueil, le feed, les cartes de matchs, les formulaires du profil, le catalogue et les bulles du chat ont une composition adaptée. Les réglages du compte suivent les sections de modification du profil.
- Consentements, appareils, vie privée, signalement, crédits, continuation, photos et abonnement utilisent le même socle visuel. Prix, états, autorisations et décisions restent issus des contrôleurs et de l'API.
- La barre **Feed / Matchs / Profil** demeure commune aux trois espaces, avec un indicateur lavande pour l'onglet choisi.

Avec le clavier ou le texte agrandi, l'en-tête du chat devient compact. Le bouton d'information ouvre un dialogue défilable contenant l'état et l'échéance reçus du serveur. Les choix de photo et de continuation restent accessibles dans leur parcours existant. Les champs, pages et confirmations conservent le défilement ; aucune réduction globale des préférences de taille du texte n'est appliquée. Seul le mot-symbole décoratif s'adapte à l'espace disponible.

Les fonds de lancement Android et iOS reprennent le bleu nuit. Les barres système suivent le thème. L'app reste en mode nuit par défaut.

## Vérification

Les aperçus de `tool/preview_app_test.dart` et `tool/preview_billing_test.dart` emploient des comptes et réponses simulés. Les contrôles existants pertinents sont réutilisés ; aucun test n'est ajouté pour la seule modification de couleurs ou de décoration. Une compilation Android ne valide pas le rendu iOS : le lancement et les polices sur appareil réel restent à vérifier lors de L10.

Validation du 18 octobre : **52 contrôles ciblés réussis**, dix scénarios visuels et **44 aperçus générés et inspectés**, formatage sans changement restant, analyse Flutter sans problème et APK Android debug compilé. Les vues à 200 % et le clavier du chat font partie de la revue. Aperçu d'ensemble local : `build/previews/site-redesign-overview.png`.

Sources des polices : [Inter](https://github.com/google/fonts/tree/main/ofl/inter), [Source Serif 4](https://github.com/google/fonts/tree/main/ofl/sourceserif4).

## Logo retenu et ouverture

Le **livre ouvert** de la piste originale **02 / Les pages** est le logo Histae. Le nom peut l'accompagner ; il n'est pas une partie obligatoire du symbole. Les autres pistes et les variantes de lettres sont conservées comme recherches graphiques.

- Source du livre : `pictures/logos/nouvelle-da/02-les-pages/symbole.svg` ; copie produit : `assets/branding/histae-logo.svg`.
- Signature livre + nom : `assets/branding/histae-signature-dark.svg` et `histae-signature-light.svg`. Lettres vectorisées ; dérivés PNG en double résolution utilisés dans les en-têtes Flutter, sans dépendance SVG supplémentaire.
- Icône native : livre seul sur un carré opaque bleu nuit, sans coins arrondis dessinés dans le fichier. Les cinq densités Android et les dix-neuf entrées iOS sont générées depuis cette source.
- Android propose aussi des calques vectoriels adaptatifs et une version monochrome pour les icônes thématiques. Le livre tient dans la zone centrale protégée de 66 dp d'un calque de 108 dp.
- Site : en-tête et pied de page accompagnent le livre du nom ; jusqu'à 360 px, l'en-tête affiche le livre seul. Favicon SVG/PNG, icône Apple et manifeste partagent ce symbole. Le minimum fixe de largeur du body a été retiré pour éviter un débordement avec la barre de défilement.

L'ouverture Flutter dure **1 480 ms** : une courte tenue de **H.**, une séparation horizontale qui dévoile **istae**, l'apparition du livre au-dessus, puis un fondu vers l'écran courant. Elle ne joue qu'au montage de l'app. La session et les notifications se préparent en parallèle ; le contenu garde son état et ses routes. Les interactions et sa lecture par un lecteur d'écran restent suspendues pendant l'ouverture. Si les animations sont désactivées, l'app s'affiche directement. Une mise en arrière-plan termine l'ouverture, sans la rejouer à la reprise.

`tool/generate_brand_assets.cjs` régénère les exports avec Node et Sharp disponible dans le chemin de modules de l'outil, sans l'ajouter aux dépendances mobiles. L'option `--site <chemin-histae-site>` exporte également les fichiers du site. `tool/preview_brand_test.dart --update-goldens` capture les étapes réelles de l'ouverture ; la planche animée est dans `pictures/branding`.

Validation : **21 contrôles ciblés**, dont trois nouveaux sur l'ouverture (contenu vivant et interactions, réduction des animations, cycle de vie), analyse Flutter sans problème, APK Android debug compilé et présence des assets dans l'APK vérifiée. Dimensions et absence d'alpha des icônes iOS contrôlées. Site : types, lint et compilation/export validés ; rendu sur ordinateur et petit écran revu. Les essais natifs Android/iOS, notamment le masque d'icône et le démarrage à froid, restent à effectuer sur appareil. Le site a été modifié localement, sans déploiement.

Références : [icônes adaptatives Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive), [préférence Flutter de réduction des animations](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).
