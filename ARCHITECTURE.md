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

Le dossier `core` n'importe aucune fonctionnalité. Les dépôts des fonctionnalités privées dépendent du contrat `AuthenticatedSession` ; ils n'importent pas `SessionController`. Les dépôts exposent une interface et une implémentation HTTP distincte. Le constructeur habituel, par exemple `BillingRepository(session)`, reste une factory vers son implémentation API. Les tests peuvent injecter une autre implémentation du contrat sans changer un écran.

Les modèles n'ont pas tous besoin d'une seconde représentation métier : les DTO simples restent dans `data`. Les contrats de session et de consentement ont un emplacement explicite dans `domain`. Les primitives de lecture JSON, UUID serveur, dates et curseurs ne dépendent plus du profil ou du chat. La réponse publique à une question est commune au feed et au profil partenaire.

## État, ressources et responsabilités

L'interface observe un contrôleur et déclenche ses méthodes. Les règles d'autorisation, de consentement, de crédit et d'abonnement restent confirmées par les réponses de l'API. Les collections des profils, erreurs, appareils et démarches sont exposées en lecture seule. Les DTO de catalogue, feed, partenaire, pages de messages et consentements copient leurs listes pour empêcher une modification depuis un autre objet.

`HistaeApp` reste propriétaire des dépendances qui lui sont confiées. Il détache les observateurs, ferme le coordinateur de notifications, puis dispose les contrôleurs avant la session et le client du catalogue. Chaque page reste responsable du contrôleur qu'elle crée ; un contrôleur reçu d'un parent n'est pas détruit par la page. Les abonnements SDK, connexions SSE et minuteries sont libérés par leur propriétaire.

Les formulaires de profil sont répartis en quatre pages. Le socle `ProfileEditorState` garde les comportements de brouillon, de sortie confirmée et de perte d'accès. Les confirmations communes utilisent une boîte de dialogue défilable. Le hub de confidentialité, son détail, le profil du partenaire, la carte de formule, le résumé et le choix de formule d'abonnement sont des composants distincts.

`MainShell` possède les contrôleurs de profil, découverte et matchs. Un `IndexedStack` monte les trois vues au démarrage et conserve leur état, leurs positions de lecture et leurs données pendant la session. Le changement d’onglet et la couverture par une route ne les détruisent plus. La clé du shell suit `session.resourceKey` : un changement de compte ou de consentement détruit les anciennes vues privées. Les conversations restent synchronisées par les événements serveur. L’ouverture d’un écran secondaire réutilise sa dernière lecture en mémoire lorsqu’elle existe ; sa première ouverture charge uniquement les données qui lui manquent. Les boutons et gestes d’actualisation font des lectures réseau explicites.

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

L’activation du quota est idempotente : elle initialise le solde une fois et réactive les actions sans relecture au retour d’une route. Le quota ne suit plus automatiquement chaque lecture de match ou d’historique. Les actualisations explicites, les validations après une dépense/récompense et les changements d’abonnement confirmés relisent le solde. Les coûts de continuation restent vérifiés au serveur avant acceptation, même lorsqu’un écran utilise les données conservées.


## Lecture récompensée

`RewardedVideoGateway` isole UMP et le SDK Google déjà présent ; `AdmobRewardedVideoGateway` est composé dans `AppDependencies` et transmis par `RewardedVideoScope`. Aucun appel natif au démarrage. `RewardedVideoController`, possédé par CreditsPage, possède une tentative volontaire et contrôle propriétaire, epoch de confidentialité, quota frais, formule, catalogue, stock et premier plan. Les formulaires et vidéos natifs peuvent suspendre l’activité sans donner la propriété de leur quota au MatchesPage sous-jacent. Les résultats après fermeture, déconnexion, perte de droits ou changement de compte sont ignorés ; les objets publicitaires sont libérés.

`RewardTracker` reste l’autorité de suivi HTTP ; il admet une nouvelle intention après `credited` et refuse un rappel de vidéo sans intention active. Le SDK n’attribue aucun crédit : il transmet seulement `custom_data` opaque à AdMob ; le webhook signé de l’API est seul autorisé à créditer. Les abandons avant affichage et fermetures sans récompense annulent la réservation, les résultats d’affichage incertains restent vérifiables. Pas de retry automatique sur les POST. Le choix UMP est indépendant des consentements Histae et peut être revu depuis les crédits ou Vie privée, même après passage Premium.

Gradle lit l’ID Android public dans `.env`. Un script de fin de build Xcode injecte l’ID iOS dans le plist compilé, après Flutter et avant signature. Les sources ne contiennent aucun ID d’application réel. La plateforme non configurée reste fermée ; l’unité de l’intention n’a aucun repli client. Les tests de frontière native simulent les codecs officiels pour contrôler UMP, `custom_data`, l’absence de `user_id` et l’ordre avant affichage.


## Gestion des réponses et diagnostics de consentement

`ProfilePanel`, `ProfileAnswersPreview` et `ProfileDetailTile` isolent la présentation de l’espace personnel. Le contrôleur et les droits serveur restent inchangés. Le sélecteur de questions travaille sur le catalogue déjà chargé ; il trie par `display_order`, filtre les choix déjà présents et cherche dans les libellés. Les brouillons appartiennent à AnswersEditor ; le PUT reste un remplacement complet confirmé. Le pied d’enregistrement est une option de ProfileEditorState, sans changer les autres éditeurs. Le parent Profil ignore les transitions natives d’une route qui possède déjà le quota.

Les erreurs UMP sont classées à leur frontière native, en tenant compte des codes différents sur Android/iOS. Les messages fournisseur contenant un ID restent hors de l’interface et des logs ajoutés. La reprise sur échec d’actualisation exige `canRequestAds` vrai du SDK et un propriétaire encore valide. Ni le stockage Histae, ni la présence d’un ID AdMob ne constituent un accord publicitaire. Aucun nouveau champ de consentement API n’est introduit.

## Séparation des responsabilités — 19 octobre 2026

`DiscoveryVisibilityRepository` porte les GET/PATCH et le décodage strict du mode pause. Son contrôleur garde uniquement les commandes, les états en lecture seule, l’annulation liée au compte, l’incertitude et le délai de reprise. Le constructeur habituel conserve sa compatibilité ; `withRepository` permet l’injection du dépôt. Le contrat réseau et la règle de relecture après réponse incertaine ne changent pas.

`ProfileFeedPreview` est une projection immuable des seuls textes publics approuvés. `ProfileController` décide si les données chargées permettent cet aperçu ; l’écran affiche le résultat sans recalculer la modération, l’ordre des réponses ou l’âge. `ageOn` partage le calcul calendaire UTC avec la validation de majorité.

Les cartes du profil et de préparation de la découverte ont leurs propres widgets, mais restent des enfants distincts des listes : les regrouper dans une colonne changerait les points d’ancrage du défilement lors du changement d’échelle du texte. La navigation et les confirmations restent dans les pages. `ConsentControl` se limite au rendu adaptatif d’un document ou d’un accord ; `legal_document_opener.dart` isole l’ouverture native HTTPS et conserve les exports historiques de `consents_page.dart`.

Vérification du refactoring : 48 contrôles existants ciblés réussis, formatage et analyse propres, 15 captures strictement identiques aux références, sans mise à jour des images de référence. Aucun package ni contrat API ajouté par ce refactoring.

## Localisation de l’interface — 19 octobre 2026

Les textes de l’interface sont portés par quatre catalogues ARB (français, anglais, espagnol, italien), avec génération Flutter dans `core/l10n/generated`. `AppStrings` reste la façade des formats et des erreurs métier ; les correspondances propres aux fonctionnalités reçoivent cette façade explicitement. Les validateurs et le lecteur vidéo renvoient `ClientMessage`, indépendant de Flutter, puis la présentation traduit au rendu. Les erreurs de photo sont conservées sous une forme résolue au rendu. Aucune locale globale mutable ni traduction automatique de contenu personnel. Le raccordement des requêtes API à la préférence de langue est décrit dans le complément ci-dessous.

`LocaleController` et son stockage injectable appartiennent à l’application. La préférence est restaurée avant le premier rendu, conservée entre comptes et indépendante des données de session. Le navigateur garde sa clé et son état lors du changement de langue. Le français initial est conservé ; le mode appareil résout les variantes régionales et revient au français pour les langues non prises en charge. Les libellés Material et Cupertino utilisent les délégués Flutter. `intl` assure les formats et les messages ICU gèrent les pluriels. Les permissions iOS ont leurs ressources natives générées depuis les mêmes catalogues.

Le test de localisation contrôle les quatre catalogues et analyse la syntaxe des widgets pour refuser de nouveaux textes visibles en dur. `analyzer` est une dépendance de développement uniquement. La procédure de contribution et les limites des contenus API/dialogues natifs sont documentées dans `lib/core/l10n/README.md`.

## Langue du contrat API — 20 octobre 2026

`ApiLanguage` porte les quatre codes exacts sans dépendance Flutter. La composition partage la source
`LocaleController` avec les deux clients HTTP, la session, le catalogue et les notifications.
`LanguageRepository` ne fait que les GET/PATCH de préférence et leur décodage ;
`AccountLanguageBinding` relie ce dépôt au propriétaire authentifié et au choix d’interface. Le socle
`core` reçoit un callback et n’importe aucune fonctionnalité.

La langue d’une requête est fixée avant une éventuelle rotation d’accès. OTP et Checkout possèdent
leur instantané dans l’intention, comme leur clé et leur payload. La révision de localisation est
séparée des révisions de confidentialité : les lectures et libellés changent sans purger les brouillons,
la navigation ou les écritures en attente. Les contrôleurs conservent leurs gardes de session,
leurs délais de reprise et leur propriété des annulations. Les consentements comparent aussi l’URL
et la langue du document présenté ; leur relecture pour traduction ne simule pas une reconnexion.

Voir [les routes couvertes et la validation à réaliser avec Flutter](docs/api-languages.md).


## Politique de lecture pendant une session

`ReadSnapshots.forView` est réservé à l’initialisation des vues secondaires et à
la réouverture d’un historique. `SessionController.request` mémorise les GET JSON
réussis (128 entrées au maximum, sans stockage disque), séparés par compte,
révision de consentement, langue, chemin et paramètres. Les lectures ordinaires
restent fraîches : actualisation manuelle, pagination demandée, vérification après
écriture et événements temps réel. Les écritures, même incertaines, invalident les
instantanés ; les événements de match invalident les seuls chemins concernés.
Les refus, erreurs et réponses annulées ne sont pas mémorisés, et un échec
d’actualisation ne permet pas de restaurer un ancien succès. La déconnexion et les
changements de périmètre privé purgent la mémoire. Les téléchargements d’export,
l’authentification et les flux SSE ne passent jamais par ce cache.

Les reprises de fenêtre ne synchronisent plus automatiquement le compte, le
profil, le catalogue, le quota, les appareils ou les listes de confidentialité.
Le retour d’un paiement réellement ouvert reste une vérification explicite.
Les échéances locales désactivent les actions sans déclencher de lecture. Une
réutilisation conserve la date de lecture initiale des URL de photo signées :
ouvrir de nouveau une vue ne prolonge jamais leur durée de validité.
