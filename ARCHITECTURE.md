# Architecture Flutter de Histae

Refactoring transversal des 17 et 18 octobre 2026, avant L10.

L'application conserve son organisation par fonctionnalité, ses contrôleurs `ChangeNotifier` et ses dépôts injectés. La refonte porte sur les dépendances et la responsabilité des classes ; elle n'ajoute ni fournisseur de paiement, ni accès Premium local, ni administration.

## Organisation

| Emplacement | Responsabilité |
| --- | --- |
| `lib/app/bootstrap.dart` | Chargement strict de la configuration publique, licences et nettoyage des exports interrompus |
| `lib/app/app_dependencies.dart` | Construction explicite des clients, dépôts, session et services de notification/facturation |
| `lib/app/app.dart` | Thème, localisation, cycle de vie global et invalidation de la navigation privée |
| `lib/app/session_gate.dart`, `welcome_page.dart` | Affichage lié à l'état de session et accueil public |
| `lib/app/main_shell.dart`, `main_navigation_bar.dart` | Trois onglets privés, barre commune et propriété des contrôleurs de profil, découverte et matchs |
| `lib/app/notification_navigation.dart`, `notification_overlay.dart` | Parcours temporaire d'une notification et bandeau générique |
| `lib/core` | Configuration, primitives réseau, opérations sérialisées, modèles réellement partagés et composants visuels communs |
| `lib/core/theme/histae_tokens.dart`, `lib/core/widgets/histae_*.dart` | Valeurs du site, fond commun, mot-symbole et actions accessibles |
| `features/*/domain` | Contrats ou modèles purs qui doivent être partagés sans dépendre d'un contrôleur ou d'un accès HTTP |
| `features/*/data` | Contrats de dépôts, implémentations `Api…Repository`, décodage et services natifs/stockage |
| `features/*/application` | État des parcours, commandes utilisateur, suspension, annulation et rejet des réponses périmées |
| `features/*/presentation` | Pages, formulaires, composants et textes propres à la fonctionnalité |

Le dossier `core` n'importe aucune fonctionnalité. Les dépôts des fonctionnalités privées dépendent du contrat `AuthenticatedSession` ; ils n'importent pas `SessionController`. Les neuf dépôts exposent une interface et une implémentation HTTP distincte. Le constructeur habituel, par exemple `BillingRepository(session)`, reste une factory vers son implémentation API. Les tests peuvent injecter une autre implémentation du contrat sans changer un écran.

Les modèles n'ont pas tous besoin d'une seconde représentation métier : les DTO simples restent dans `data`. Les contrats de session et de consentement ont un emplacement explicite dans `domain`. Les primitives de lecture JSON, UUID serveur, dates et curseurs ne dépendent plus du profil ou du chat. La réponse publique à une question est commune au feed et au profil partenaire.

## État, ressources et responsabilités

L'interface observe un contrôleur et déclenche ses méthodes. Les règles d'autorisation, de consentement, de crédit et d'abonnement restent confirmées par les réponses de l'API. Les collections des profils, erreurs, appareils et démarches sont exposées en lecture seule. Les DTO de catalogue, feed, partenaire, pages de messages et consentements copient leurs listes pour empêcher une modification depuis un autre objet.

`HistaeApp` reste propriétaire des dépendances qui lui sont confiées. Il détache les observateurs, ferme le coordinateur de notifications, puis dispose les contrôleurs avant la session et le client du catalogue. Chaque page reste responsable du contrôleur qu'elle crée ; un contrôleur reçu d'un parent n'est pas détruit par la page. Les abonnements SDK, connexions SSE et minuteries sont libérés par leur propriétaire.

Les formulaires de profil sont répartis en quatre pages. Le socle `ProfileEditorState` garde les comportements de brouillon, de sortie confirmée et de perte d'accès. Les confirmations communes utilisent une boîte de dialogue défilable. Le hub de confidentialité, son détail, le profil du partenaire, la carte de formule, le résumé et le choix de formule d'abonnement sont des composants distincts.

Depuis le complément de navigation du 18 octobre, `MainShell` possède les contrôleurs de profil, découverte et matchs. `ProfilePage` les reçoit via son contrôleur et celui de continuation, sans les détruire. Seul l'onglet visible est monté : un écran caché ne reçoit donc plus les reprises du cycle de vie. Les positions de défilement utilisent `PageStorage`, les brouillons de chat restent dans le contrôleur de matchs, et le feed relit sa préparation lors de sa réouverture. La couverture par une notification suspend et démonte l'onglet principal jusqu'au retour. La destruction du feed suspend son contrôleur sans notifier les routes de rencontre en cours de destruction. Le passage d'une rencontre à son chat sélectionne l'onglet Matchs puis vérifie l'appartenance et l'accès à l'historique via le contrôleur existant.

Le chat conserve une seule copie de la liste des messages par reconstruction d'écran. `MessageOutbox` possède les brouillons et les intentions d'envoi : la clé et le contenu d'un message en attente ne peuvent pas changer. La purge de la conversation ou du compte efface ces deux catégories de données.

Les écrans ne déclenchent plus directement les mutations des dépôts du profil : identité, préférences, traits, réponses et retrait de photo passent par les commandes du contrôleur. Le chargement des images de stockage signé est isolé dans `SignedPhotoLoader`, partagé entre photo propriétaire et partenaire. Ce service n'utilise ni Bearer, ni redirection, ni cache disque ; taille maximale de 5 000 000 octets, délai global de quinze secondes, fermeture et annulation explicites. Le droit de révéler l'image et le rejet des résultats périmés restent vérifiés par le parcours concerné.

## Concurrence et sécurité

- `RequestCancellation` et les flux `ApiEventStream`/`ApiDownload` sont séparés du client HTTP ; leurs anciens chemins d'import restent exportés pour compatibilité.
- `SerialExecutor` ordonne les opérations locales. Une erreur est transmise à l'appelant et n'empêche pas les opérations suivantes, notamment une purge. Il n'effectue aucune nouvelle tentative.
- `RetryTicker` ne fait que rafraîchir un compteur visuel. Chaque fonctionnalité garde sa propre règle de conservation de `Retry-After`, son horloge injectable et sa politique de reprise. Il ne relance pas une requête.
- Le refresh et la fermeture de session gardent leurs barrières de stockage sécurisé. Aucun mécanisme de retry universel n'est introduit sur les mutations.
- Les lectures et commandes privées restent liées à la session, à sa révision et au cycle de vie du parcours. Une réponse tardive ne restaure pas les données d'un autre compte.
- `parsePublicEnv` n'accepte que les clés publiques autorisées, sans interpolation. Les clés inconnues, doublons ou valeurs incorrectes ferment la configuration sans journaliser son contenu.
- La valeur mobile incorrecte `BILLING_ENABLED=stripe` a été corrigée en `false`. Les liens de retour existants sont conservés. Aucun paiement, push ou vidéo n'est activé par le refactoring.

Les anciens fichiers de modèles et le point d'entrée `profile_editors.dart` restent des exports de compatibilité lorsque leur contenu a été extrait. Aucun fichier source n'est supprimé et aucun fichier modèle `.env` n'est recréé.

## Contrôles et évolution

La refonte graphique du 18 octobre est décrite dans [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Le thème et les composants communs portent l'identité de `histae-site`, sans dépendance Flutter supplémentaire. `HistaeScaffold` compose un `Scaffold` standard et son décor ; `HistaeButton` compose un `FilledButton` standard et son dégradé. Les contrôleurs et les contrats HTTP ne portent aucune décision décorative. Les cartes de matchs et l'en-tête adaptatif du chat sont des composants de présentation distincts. Le registre de licences comprend les deux nouvelles polices embarquées. Les fonds natifs Android/iOS ont été adaptés au bleu nuit ; leur validation sur iOS reste à réaliser sur Mac.

L'analyse active `strict-casts`, `strict-inference`, `strict-raw-types`, l'ordre des imports et la surveillance des opérations asynchrones, abonnements et flux. Les versions de dépendances, la contrainte Dart et les fichiers natifs ne sont pas changés pour imposer une migration de bibliothèque.

Les contrôles existants servent à vérifier les contrats, les sessions, l'idempotence et la navigation. Trois contrôles supplémentaires couvrent seulement la sérialisation après échec, la fin/annulation d'un compteur et le transport borné/annulable des photos. Trois assertions d'interface ont été actualisées pour suivre le hub de confidentialité et le texte du catalogue déjà introduits par les lots précédents. Les aperçus utilisent exclusivement des comptes, fournisseurs et réponses simulés.

Références de conception : [recommandations Flutter](https://docs.flutter.dev/app-architecture/recommendations) et [guide d'architecture](https://docs.flutter.dev/app-architecture/guide), consultés le 17 octobre 2026. Les décisions sont adaptées au projet : les contrôleurs existants et `Navigator` sont conservés ; aucune dépendance de navigation, de génération de modèles ou de gestion d'état supplémentaire n'est nécessaire à cette refonte.

L10 demeure consacré aux essais réels, à l'accessibilité complète et à la préparation bêta. Une analyse, un test simulé ou une compilation Android ne valide pas une réception push, un paiement, un SMS ou une compilation iOS sur Mac.

Validation finale du 18 octobre : analyse stricte sans problème, formatage de 143 fichiers, 166 tests au passage global puis 39 ciblés après les dernières extractions (167 distincts, trois nouveaux), APK Android debug compilé. Quatre scénarios visuels ont généré 22 aperçus, inspectés en planche avec revue détaillée des écrans représentatifs. Les contrats HTTP et validations de fournisseurs demeurent ceux des lots L1–L9 ; aucun appel privé réel, paiement ou réception push n'a été exécuté pour cette refonte.

## Présentation d'ouverture

`AppOpening` est monté par le builder de `MaterialApp`, au-dessus des scopes et du navigateur existants. Il possède seulement son animation finie ; il ne possède aucune session ou route. Les services démarrent normalement. Le sous-arbre conserve sa position et son état pendant et après l'ouverture, y compris une route de notification ouverte pendant le démarrage. Les entrées tactiles, le focus et la sémantique du contenu sont exclus tant que l'animation le masque. L'observateur de cycle de vie termine l'ouverture lors d'une suspension ; `MediaQuery.disableAnimations` l'ignore immédiatement. Le contrôleur est libéré avec le widget.

`HistaeWordmark` affiche la signature vectorisée exportée en PNG, selon le fond clair/sombre ; `HistaeBrandSymbol` dessine le livre pour l'ouverture. Les SVG originaux et les exports natifs restent dans le dépôt. Aucun package d'animation, de splash ou de rendu SVG n'est ajouté.

## Formule et quota dans les onglets

Les écrans Profil et Matchs utilisent le `ContinuationController` de leur `MatchesController` de session, sans nouveau stockage ni calcul local de droits. `ContinuationBalanceCard` affiche `freeRemaining` et `advertisingRemaining`, et traite chargement, indisponibilité et Premium. Le profil adapte son unique accès d’abonnement à la formule effective du quota ; une ancienne lecture n’est pas utilisée comme autorité après échec.

L’activation à l’entrée d’un onglet se fait après la première frame, lorsque la suspension et le démontage de l’onglet précédent sont achevés. Au retour de CreditsPage ou SubscriptionPage, la route attend sa transition complète avant de réactiver la lecture partagée. Le parcours de crédits suspend le contrôleur de liste ; la reprise de la conversation reste portée par son MatchesPage et n’est pas bloquée par l’encart.


## Lecture récompensée

`RewardedVideoGateway` isole UMP et le SDK Google déjà présent ; `AdmobRewardedVideoGateway` est composé dans `AppDependencies` et transmis par `RewardedVideoScope`. Aucun appel natif au démarrage. `RewardedVideoController`, possédé par CreditsPage, possède une tentative volontaire et contrôle propriétaire, epoch de confidentialité, quota frais, formule, catalogue, stock et premier plan. Les formulaires et vidéos natifs peuvent suspendre l’activité sans donner la propriété de leur quota au MatchesPage sous-jacent. Les résultats après fermeture, déconnexion, perte de droits ou changement de compte sont ignorés ; les objets publicitaires sont libérés.

`RewardTracker` reste l’autorité de suivi HTTP ; il admet une nouvelle intention après `credited` et refuse un rappel de vidéo sans intention active. Le SDK n’attribue aucun crédit : il transmet seulement `custom_data` opaque à AdMob ; le webhook signé de l’API est seul autorisé à créditer. Les abandons avant affichage et fermetures sans récompense annulent la réservation, les résultats d’affichage incertains restent vérifiables. Pas de retry automatique sur les POST. Le choix UMP est indépendant des consentements Histae et peut être revu depuis les crédits ou Vie privée, même après passage Premium.

Gradle lit l’ID Android public dans `.env`. Un script de fin de build Xcode injecte l’ID iOS dans le plist compilé, après Flutter et avant signature. Les sources ne contiennent aucun ID d’application réel. La plateforme non configurée reste fermée ; l’unité de l’intention n’a aucun repli client. Les tests de frontière native simulent les codecs officiels pour contrôler UMP, `custom_data`, l’absence de `user_id` et l’ordre avant affichage.
