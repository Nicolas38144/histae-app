# Architecture Flutter

L’app est organisée par fonctionnalité, avec des contrôleurs `ChangeNotifier`, des dépendances injectées par constructeur et la navigation Flutter (`Navigator` / `MaterialPageRoute`).

## Répartition des responsabilités

| Couche | Responsabilité |
| --- | --- |
| `lib/app/` | Démarrage, composition des dépendances, session, navigation et cycle de vie global. |
| `lib/core/` | Configuration, réseau, primitives asynchrones, localisation et composants communs. |
| `features/*/presentation/` | Affichage, interactions, navigation et confirmations. |
| `features/*/application/` | État observable, commandes, validation des actions et annulation. |
| `features/*/data/` | Repositories, transport, décodage, cache et services natifs. |
| `features/*/domain/` | Contrats et modèles partagés qui doivent rester indépendants de leur implémentation. |

Le chemin habituel est **vue → contrôleur → repository → client HTTP**. `core` n’importe aucune fonctionnalité. Les repositories privés dépendent de `AuthenticatedSession`, sans importer `SessionController`. Les modèles simples restent dans `data` ; les collections exposées sont protégées contre les modifications externes.

## Démarrage et propriété des ressources

`bootstrap` charge strictement le `.env` public, enregistre les licences et nettoie les exports interrompus. `AppDependencies` construit les clients et services. `HistaeApp` possède les dépendances reçues et les libère à sa destruction.

`SessionGate` choisit l’accueil, l’onboarding ou l’espace privé selon l’état confirmé de la session. `MainShell` possède les contrôleurs Feed, Matchs et Profil ; son `IndexedStack` conserve les trois vues et leur défilement. Sa clé suit `session.resourceKey`, afin de reconstruire l’espace privé après un changement de périmètre.

Un contrôleur créé par une page est libéré par cette page. Un contrôleur reçu d’un parent reste la propriété du parent. La suspension d’un parcours et la destruction de ses ressources sont des opérations distinctes.

## Cache et lectures

`SessionController` assure l’authentification et l’autorisation des requêtes. Le cache métier appartient aux repositories, composés par `SessionRepositories`. Le catalogue public possède son propre cache, séparé par langue.

`ReadSnapshots` conserve au maximum 128 entrées par instance, uniquement en mémoire. Les valeurs sont des modèles validés ; leur date de lecture initiale est conservée. `ReadPolicy.cached` réutilise une lecture disponible, tandis que `ReadPolicy.refresh` contacte le serveur.

| Déclencheur | Comportement |
| --- | --- |
| Démarrage des onglets ou première ouverture d’un détail | Initialiser les données manquantes via les commandes du contrôleur. |
| Changement d’onglet ou retour au premier plan | Conserver les données et réactiver les actions sans relecture systématique. |
| Actualisation manuelle ou pagination demandée | Effectuer une lecture explicite. |
| Écriture, événement serveur ou vérification d’un coût | Relire les ressources nécessaires selon le parcours. |
| Échéance locale | Invalider l’affichage ou l’action sans lancer de requête automatique. |

Une écriture invalide les ressources concernées avant et après l’appel, même si sa réponse est perdue. Les invalidations ciblées rejettent les remplissages tardifs concernés sans vider les lectures indépendantes. Un échec d’actualisation ne restaure pas un ancien succès.

Les changements de compte, consentements, langue ou accès privé purgent les caches concernés. Le changement de langue utilise une révision distincte : les lectures sont renouvelées sans effacer navigation, brouillons et intentions d’écriture. Les erreurs, réponses annulées, exports et flux SSE ne sont pas des instantanés réutilisables.

## Session, concurrence et persistance

La rotation du refresh token est sérialisée. Le stockage sécurisé est écrit puis relu avant de publier une nouvelle session ; une rotation incertaine ferme l’accès plutôt que réutiliser un ancien refresh. La fermeture de session et la suppression du compte disposent également d’une barrière durable.

Une requête peut être rejouée une fois après un `401` confirmant l’expiration de l’access token, si le parcours l’autorise. Aucun retry réseau universel ne s’applique aux mutations. Une reprise conserve la clé d’idempotence, le contenu et la langue de son intention.

| Données | Conservation |
| --- | --- |
| Access token, profils, messages, coordonnées, brouillons et URL signées | Mémoire du parcours ou de la session. |
| Refresh token et état de rotation/fermeture | Stockage sécurisé lié à l’origine API. |
| Tentative Checkout et préférence push | Métadonnées minimales dans des entrées sécurisées liées au propriétaire. |
| Langue explicitement choisie | Préférence d’appareil indépendante du compte. |
| Export privé | Fichier temporaire dédié, nettoyé après usage. |

`RequestCancellation`, les révisions et les générations empêchent une réponse tardive de restaurer des données périmées. `SerialExecutor` ordonne les opérations locales sans retry. `RetryTicker` actualise seulement un compteur visuel et respecte `Retry-After`.

## Messages et notifications

`RealtimeHub` fournit un transport SSE partagé aux rencontres, notifications et abonnements. Le parcours principal cesse de traiter les événements lorsqu’un parcours de notification le couvre ; le transport reste commun. Le flux est arrêté à la perte d’accès privé ou à la destruction de son propriétaire.

Les événements provoquent les lectures autorisées nécessaires. Une notification ne contient aucune preuve d’accès : son ouverture vérifie la session puis la collection mobile et l’historique. `MessageOutbox` conserve les brouillons et les intentions d’envoi immuables. Un accusé de lecture exige un message reçu visible dans une conversation au premier plan.

## Photos, crédits et fournisseurs

`SignedPhotoLoader` télécharge en mémoire, sans Bearer ni redirection, avec une limite de 5 000 000 octets et un délai de quinze secondes. Le parcours vérifie les droits avant l’affichage et évince l’image à la fermeture, à la perte d’accès ou à son échéance. Réouvrir une photo ne prolonge pas les quatre minutes calculées depuis la lecture de sa ressource.

Profil et Matchs utilisent le même `ContinuationController`. L’activation initialise le quota une fois ; les actualisations et vérifications après dépense, récompense ou changement de formule confirmé le relisent. Le coût d’une continuation est revérifié avant son acceptation.

`RewardedVideoGateway` isole UMP et AdMob ; `RewardTracker` suit l’intention côté API. Le rappel du SDK ne crédite jamais le compte : seule la validation serveur le permet. `BillingController` conserve une tentative Checkout durable et vérifie les droits après le retour effectif du navigateur ou un événement pertinent. Les passerelles natives restent injectables pour les tests.

## Présentation et langues

Le thème et les composants partagés portent la [direction artistique](DESIGN_SYSTEM.md). `AppOpening` anime l’ouverture sans posséder la session ni le navigateur ; les services continuent à démarrer. Les animations désactivées ou une suspension terminent cette présentation.

Les textes d’interface viennent des ARB. `LocaleController` possède la préférence d’appareil ; `AccountLanguageBinding` la relie au compte vérifié. Les erreurs métier restent des codes traduits au rendu. Voir les [conventions de traduction](lib/core/l10n/README.md) et le [contrat de langue réseau](docs/api-languages.md).

Les contrôles et commandes de développement sont dans le [README](README.md). Les validations fournisseur et appareil restantes sont suivies dans la [roadmap](roadmap.md).
