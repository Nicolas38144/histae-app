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
