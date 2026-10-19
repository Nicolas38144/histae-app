# Histae App — roadmap de développement

Mise à jour : 19 octobre 2026.

Recherche de logo : les cinq pistes SVG initiales sont conservées dans [pictures/logos/nouvelle-da](pictures/logos/nouvelle-da/README.md), avec variantes et planche comparative. Le choix se poursuit sur la direction des pages. Cette livraison graphique ne modifie pas l'avancement des lots fonctionnels.

La direction **02 — Les pages** est retenue ; quatre [variantes typographiques](pictures/logos/les-pages-variantes/README.md) et leurs simulations dans le produit sont disponibles. Le choix de la variante à appliquer reste ouvert ; l'avancement fonctionnel est conservé.

[Accueil](README.md) · [Résumé d'intégration](resume.md) · [Contrat HTTP Rust](../histae-api-rust/docs/http-contract.md)

## 1. État de départ et suivi

L1 à L5, le cœur de L6, L7 et la gestion des appareils L8 sont implémentés. Les flux push L8 sont préparés mais désactivés, sans projet Firebase, conformément au choix utilisateur. L7 couvre sûreté, sessions, droits, export et suppression. Contrôles privés simulés uniquement ; comptes et appareils réels restent à valider. Vidéos désactivées, dépendance Google présente mais intégration native/UMP et fournisseur ouverts. IDs Android dans `.env`, iOS vides. L9 fournit le suivi de l’abonnement et Checkout/portail ; paiements activés localement le 19 octobre sur demande pour Android externe, essais réels encore ouverts. L10 reste à construire. DA en mode nuit ; aucun fichier modèle `.env` ne doit être recréé.

Cette roadmap couvre toutes les capacités utilisateur de l'API actuelle. Elle exclut l'administration, les webhooks fournisseur, la supervision et les opérations internes. Elle ne dépend pas des anciens dépôts NestJS ou d'un endpoint OpenAPI.

Les états doivent distinguer : `À faire`, `En cours`, `Implémenté`, `Intégré API`, `Validé sur appareil`. Une fonctionnalité ne passe pas directement à « validée » parce que son endpoint existe. Renseigner dans le suivi les vérifications, l'environnement et les blocages fournisseur ; ne pas mettre de données privées dans les preuves.

## 2. Ordre des lots

Refonte visuelle du 18 octobre 2026 : tous les parcours reprennent l'identité de `histae-site` et de [histae.com](https://www.histae.com/fr/), selon [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Le thème bleu nuit/lavande, les polices Inter et Source Serif 4, les boutons dégradés et les bordures fines remplacent la palette précédente. L'accueil, le feed, le profil, les matchs, le chat et le catalogue sont recomposés ; les autres pages utilisent les mêmes composants. L'en-tête du chat et son détail d'état s'adaptent au clavier et aux grandes polices. Les fonds de lancement natifs reprennent le bleu nuit. Aucun parcours métier ni fournisseur n'est ajouté ou activé. Les 52 contrôles existants ciblés et les dix scénarios visuels passent ; aucun test de simple décoration n'est ajouté.

Complément de navigation du 18 octobre 2026 : barre commune **Feed / Matchs / Profil**, feed à l'ouverture de l'espace authentifié, retrait des anciens raccourcis du profil et de la barre propre au feed. Le changement d'onglet suspend les lectures et le temps réel de l'écran quitté ; les contrôleurs restent liés à la session. Deux contrôles ciblés ajoutés couvrent la navigation, le texte à 200 %, la déconnexion et le passage d'une rencontre réciproque à une conversation autorisée. Avec les régressions concernées, 27 contrôles passent ; quatre scénarios d'aperçu ont été exécutés et les trois onglets inspectés visuellement. L10 reste le prochain lot fonctionnel.

Validation finale de la refonte graphique : 44 aperçus inspectés, analyse Flutter sans problème, formatage vérifié et APK Android debug compilé. Le rendu iOS et les essais réels sur appareils restent à valider dans L10.

Validation de ce complément : formatage sans changement restant, analyse Flutter sans problème et APK Android debug compilé. Les aperçus et contrôles utilisent uniquement des données simulées.

| Lot | Objectif | État |
| --- | --- | --- |
| L0 | Vérifier le contrat, l'inventaire, les parcours et l'environnement mobile | Vérifié pour L1 : SDK, catalogue, erreurs, routes/DTO/services, tests et Postman consultés ; approfondir par lot |
| L1 | Bootstrap, configuration, navigation, thème et client HTTP | Intégré API pour le catalogue ; 54 tests, analyse et compilation Android debug ; appareils/iOS en attente |
| L2 | Inscription/reconnexion OTP, session et onboarding juridique reprenable | Implémenté ; 85 tests au total et compilation Android debug ; SMS, compte réel et appareils à valider |
| L3 | Profil, préférences, traits, questions, photo et modération propriétaire | Implémenté sur les treize routes ; vérifications automatiques ci-dessous ; compte/photo/appareils à valider |
| L4 | Présence, diagnostic de préparation, découverte et swipes | Implémenté sur quatre routes + blocage ; huit contrôles ciblés ; deux comptes et appareils à valider |
| L5 | Matchs, chat, lecture et synchronisation SSE | Implémenté sur sept routes ; neuf tests ciblés, analyse et APK Android ; deux comptes/appareils à valider |
| L6 | Révélation, continuation, crédits et récompenses volontaires | Cœur implémenté ; huit contrôles ciblés ; vidéos désactivées par choix utilisateur, SDK/UMP et fournisseur en attente |
| L7 | Sûreté, paramètres de confidentialité, sessions, export et suppression | Implémenté ; neuf contrôles ciblés, dix-huit régressions session/SSE ; comptes et appareils réels à valider |
| L8 | Appareils, notifications push et ouverture depuis notification | Appareils implémentés, flux push préparés ; dix contrôles ciblés ; Firebase/push désactivés par choix utilisateur, réel/iOS en attente |
| L9 | Offres, abonnement, Checkout et portail selon la distribution retenue | Abonnement implémenté, Checkout/portail préparés ; dix contrôles ciblés ; Retours HTTPS et langues préparés ; publication et Stripe test à valider, ventes désactivées par choix utilisateur |
| L10 | Robustesse, accessibilité, appareils réels et préparation bêta | À faire |

Ces lots peuvent être divisés en interventions plus petites. Introduire les mécanismes nécessaires au bon moment : sécurité des jetons dès L2, blocage dès qu'une interaction est utilisable, contrôle d'état des matchs dès L5. Ne pas attendre L10 pour tester les risques métier.

## 3. L0 — contrat et préparation

- Lire le contrat HTTP, les DTO/routes/tests Rust concernés et les collections Postman.
- Confirmer que la matrice couvre toutes les capacités mobiles, sans inclure les callbacks serveur.
- Repérer les erreurs qui orientent vers une autre étape plutôt que vers un simple message.
- Examiner le SDK Flutter/Dart disponible et choisir les dépendances utiles avec leur documentation officielle.
- Définir navigation et composants communs : français, accessibilité, chargement, vide, erreur, hors ligne et action en cours.
- Choisir l'environnement API de développement et une URL accessible aux appareils ; ne pas utiliser de secrets serveur dans les paramètres Flutter.
- Préparer des fixtures à partir des DTO et réponses contractuelles actuels, sans les présenter comme des appels réseau réels.

Critère de sortie : premier lot borné, sources identifiées, convention d'URL claire et aucun modèle repris d'un ancien contrat.

## 4. L1 — socle Flutter

- Adapter le compteur et son test sans supprimer de fichier.
- Structurer application, socle partagé et fonctionnalités sans multiplier les couches vides.
- Ajouter configuration d'environnement, client HTTP, modèles initiaux et erreurs typées.
- Distinguer réseau indisponible, timeout, erreur de formulaire, `401`, `403`, `409`, `410`, `413`, `429` et `503`.
- Respecter `Retry-After`, annuler les requêtes devenues inutiles et garder un diagnostic expurgé avec `X-Request-ID`.
- Mettre en place thème, navigation et premiers composants accessibles.
- Vérifier un appel public réel au catalogue lorsque l'environnement est disponible.

Critère de sortie : app démarrable, origine API configurable, premier appel et états d'erreur utilisables ; aucune fausse session.

### Livraison L1 — 15 octobre 2026

- **Interface** : accueil → catalogue → retour, thème clair/sombre, français, chargement/vide/erreur/service non configuré, reprise explicite ; tests petit écran à 200 % et accessibilité de l'accueil. Aucun écran métier supplémentaire.
- **Accès API** : `CatalogRepository` appelle `GET /api/plans`, lit les DTO Rust (options omises, champs de fonctionnalités nullables, prix en centimes) sans pagination ni Bearer. Base par défaut fournie par l'utilisateur : `https://api.histae.com/api/`, représentée en configuration par l'origine `https://api.histae.com`. En L3, cette configuration est déplacée vers `.env` (voir README).
- **Socle** : `http` annulable, délai incluant la lecture du corps, UUID v4 `X-Request-ID`, erreurs par statut et `error.code`, `Retry-After` secondes/date et bouton bloqué jusqu'à l'échéance. Aucune relance automatique. Annulation au retour et à la suspension ; seule la lecture interrompue est reprise au retour au premier plan.
- **Architecture** : `app`, `core`, `features/catalog/{data,application,presentation}`, `Navigator` et `ChangeNotifier`. Les gardes session/consentements appartiendront à L2 avec une vraie session.
- **Sources vérifiées** : contrat HTTP, `src/catalog/{http,domain,service}.rs`, erreurs HTTP, routeur, tests `http_contract.rs`, `contract_harness.rs`, `catalog_postgres.rs`, requête publique `GET /api/plans` des collections Postman. Aucun test backend exécuté ; aucun changement backend.
- **Vérifications automatiques** : formatage, analyse sans problème, 54 tests réussis (configuration, DTO, erreurs, reprise, annulation sur HTTP local réel, navigation, suspension/reprise, petit écran et accessibilité), compilation Android debug. XML des manifestes Android et plist iOS vérifié ; cela ne valide pas leur comportement sur appareil.
- **Intégration réelle** : `GET https://api.histae.com/api/plans` → HTTP 200 ; deux formules décodées avec le client/repository Dart via `tool/check_catalog.dart`, hors suite de tests. Aucun succès fournisseur ou appareil revendiqué. Les fonctionnalités connues sont traduites en français par code, sans fixer localement les valeurs métier.

Étape retenue lors de L1 : L2, OTP et session sécurisée (idempotence OTP, refresh sérialisé, restauration et logout), puis consentements versionnés et gardes de navigation. Prévoir des essais OTP autorisés et la configuration du stockage sécurisé ; ne pas remplacer les fournisseurs par des comptes simulés.

## 5. L2 — inscription, OTP, session et consentements

- Livrer inscription/reconnexion : téléphone → demande OTP → vérification (création du compte si nécessaire) → bootstrap → consentements → espace personnel. Aucun endpoint d'inscription séparé n'existe.
- Distinguer demande acceptée et SMS reçu ; gérer livraison inconnue, rate limit et renvoi explicite.
- Stocker le refresh de façon sécurisée, access token en mémoire, avec une seule rotation concurrente.
- Gérer réponse de refresh perdue sans rejouer aveuglément un ancien token.
- Restaurer ou fermer proprement la session et éviter les doubles requêtes au redémarrage.
- Présenter les quatre types de consentement avec documents et versions serveur ; aucun choix précoché.
- Reprendre le parcours interrompu à partir des actions requises, avec accès aux routes de vie privée autorisées.
- Implémenter le logout courant et la purge dès ce lot ; compléter la gestion des autres sessions en L7.

Critère de sortie : connexion réelle et reprise d'onboarding sans jeton exposé, rotation concurrente ni dépendance à un rôle admin.

### Implémentation L2 — 16 octobre 2026

- **Interface** : « Créer mon compte » et « J'ai déjà un compte », téléphone français, OTP, envoi accepté/incertain, reprise d'une intention, renvoi explicite, erreurs et `Retry-After`. Le compte est créé par le serveur lors de la vérification OTP. Le profil, la majorité et ses préférences restent en L3 ; aucun feed n'est exposé avant les prérequis serveur de L4.
- **Session** : refresh sécurisé, access token en mémoire, restauration unique, rotation sérialisée, marqueur durable avant envoi, relecture de stockage avant publication, aucune reprise aveugle après réponse perdue. Fermeture après révocation/deuxième 401, déconnexion même hors ligne, annulation et purge des ressources de l'ancien compte.
- **Consentements** : quatre types et documents versionnés serveur, aucun nouveau choix précoché, reprise après lecture d'un document, vérification des versions avant PUT, champs exacts `{ consent_type, granted }`. Confirmation des retraits sensible/localisation ; aucun retrait CGU/notice. Accès aux documents et à la déconnexion pendant l'onboarding ; export/demandes/suppression livrés en L7.
- **DA commune** : depuis la refonte du 18 octobre, identité de `histae-site`, bleu nuit/lavande, Inter et Source Serif 4 embarquées, boutons dégradés et panneaux à bordure fine. Adaptations aux grandes polices et au clavier ; détails dans [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).
- **Sources** : contrat HTTP ; `src/identity/mobile/{http,service,account,tokens}.rs`, service OTP ; `src/profiles/{http,domain,service}.rs` ; tests `mobile_auth_contract.rs`, `otp_sweego_contract.rs`, `profiles_contract.rs` et exemples Postman. Sources consultées, tests backend non exécutés, backend non modifié.
- **Vérification automatique** : 85 tests Flutter, analyse et formatage ; compilation Android debug avec stockage sécurisé et police. Un rendu manuel supplémentaire produit trois aperçus inspectés, avec des données simulées identifiées. Les réglages XML natifs sont vérifiés ; cela ne prouve pas le comportement Keychain/Keystore sur appareil.
- **Intégration réelle et fournisseur** : seul le catalogue est déjà vérifié sur la vraie API. Aucun SMS envoyé, aucun compte réel créé et aucun jeton réel récupéré pendant les tests. L2 reste à valider avec un numéro autorisé sur Android/iOS, puis par arrêt/reprise et coupure réseau. Compilation/signature iOS sur Mac encore ouverte.
- **Limite backend à traiter séparément** : le PUT ne reçoit pas la version affichée ; la relecture mobile réduit le risque de document changé, sans contrôle atomique. Proposition de versions attendues et conflit serveur décrite dans le README, sans modifier l'API.

Suite réalisée en L3 : profil majeur, préférences, traits/questions et photo. Garder la validation SMS/appareil de L2 ouverte jusqu'à un essai réel.

## 6. L3 — profil, préférences et photo

- Créer/modifier un profil majeur sans effacer `sex` ou `bio` par omission.
- Lire et modifier les quatre préférences ensemble.
- Charger les traits, sélectionner/retirer avec `traitId` et les identifiants serveur.
- Charger les questions et remplacer l'ensemble ordonné des réponses sans perte involontaire.
- Afficher les états de modération propriétaire et expliquer le contenu en attente ou rejeté.
- Ajouter sélection et préparation d'une photo unique, multipart, idempotence, remplacement et retrait.
- Respecter 500 000 octets en entrée, les formats admis et l'expiration des URL signées.
- Ne pas reprendre un champ d'URL externe ni créer une galerie.

Critère de sortie : profil et photo réels modifiables ; erreurs, modération, réponse perdue et URL expirée ont un comportement explicite.

### Implémentation L3 — 16 octobre 2026

- **Interface** : espace personnel éditorial et cinq parcours : présentation, préférences, traits, réponses ordonnées et photo unique. Prénom/date requis, majorité UTC et date stricte, limites UTF-8. Sexe/bio envoyés explicitement, quatre préférences ensemble. Questions et traits fournis par le serveur ; `traitId` exact, ordre conservé, maximum trois réponses et remplacement/effacement confirmés. Brouillon conservé en cas d'erreur, abandon confirmé.
- **Photo/API** : JPEG local sans EXIF, réduction progressive sous 500 000 octets, fichier unique multipart, UUID v4 et octets immuables pour une reprise explicite pendant 24 h. Pas de retry après timeout ; une écriture incertaine impose une relecture, sauf reprise photo identique. Conflits consommé/en cours distincts, remplacement et retrait explicites, modération propriétaire. Retrait confirmé en `204`, sans annoncer le nettoyage distant achevé.
- **Confidentialité** : aucun profil/brouillon/photo persisté ; sélection Android interrompue non réaffectée automatiquement. Nettoyage limité aux copies dans le cache privé de l'app. Aperçu du seul propriétaire, sans Bearer/redirection/cache disque au stockage ni URL dans les logs ; purge des octets du cache mémoire à la fermeture. Lien de 300 s renouvelé par relecture après quatre minutes et au retour au premier plan. Purge et fermeture des éditeurs lors d'un changement de consentements/session ; réponses tardives ignorées. Vie privée et logout accessibles sans profil prêt.
- **Configuration** : `.env` ignoré dans le suivi, aucun fichier modèle à recréer, chargement avant initialisation des clients ; aucun hôte/environnement de secours dans le code Dart. Fichier public embarqué dans le paquet, sans secret ; origine validée et HTTPS hors debug local. Lire le README pour installation/CI.
- **Sources** : contrat HTTP, profils/catalogue/media (routes, DTO, services), collections Postman et tests profils/catalogue/media/codec consultés. Aucun changement ni test backend exécuté.
- **Validation restante** : aucun SMS, compte ou upload réel testé. Sélection/compression native, refus de permission, récupération après arrêt, HEIC et modération/S3 réels restent à essayer sur Android et iOS. Compilation/signature iOS sur Mac ouverte. Aucun feed construit avant L4.
- **Contrôles exécutés** : suite complète de 107 tests réussie, puis 23 tests L3 ciblés réussis après les derniers ajouts (110 tests présents au total). Deux contrôles de rendu supplémentaires ont généré six aperçus inspectés, dont les trois nouveaux écrans L3. Compilation Android debug réussie, analyse sans problème et formatage sans changement. Les deux plist iOS sont des XML valides avec une seule déclaration photothèque chacun. Ne pas refaire systématiquement toute la suite : l'utilisateur demande désormais de cibler les contrôles indispensables.
- **Dépendance native à suivre** : la compilation signale que `flutter_image_compress_common` applique encore KGP. La migration vers Kotlin intégré devra être suivie avant une future mise à jour de Flutter ; la compilation actuelle reste utilisable. Ce point ne remplace pas les essais de compression sur appareil.

Prochain lot : L4, présence et diagnostic serveur puis feed sans photo, swipe haut pour passer et double appui pour liker.

## 7. L4 — localisation et découverte

- Demander consentement métier et permission système au bon moment, sans suivi de fond.
- Envoyer une présence fraîche et traiter permission refusée, services désactivés et précision insuffisante si pertinente.
- Guider par `discovery-status` : profil, sexe, préférences, consentements et présence.
- Afficher feed et profils sans photo, avec bio, traits et réponses autorisés.
- Appliquer la DA de `histae-site` selon [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), avec les gestes de `pictures/exemple_feed.png` : swipe vers le haut pour passer, double appui pour liker, aucun retour par swipe vers le bas.
- Paginer avec curseurs opaques, dédupliquer et reprendre après curseur invalide.
- Envoyer like/pass ; rejouer seulement le même choix en cas d'incertitude, sans annulation ni file durable hors ligne.
- Ouvrir le match reçu après réciprocité.

Critère de sortie : deux comptes de développement peuvent se découvrir et créer un seul match cohérent.

### Implémentation L4 — 16 octobre 2026

- **Parcours/API** : accès par l'onglet Feed, étapes `discovery-status` réparables par les écrans existants, localisation ponctuelle et feed sans photo ; les quatre routes L4 sont utilisées. Date d'expiration serveur relue à l'échéance et au retour au premier plan. Aucun calcul local d'éligibilité.
- **Permission/confidentialité** : `geolocator 14.1.1`, consentement courant avant permission et avant envoi. Une mesure récente, précision réduite admise, erreurs natives distinctes et liens vers les réglages ; abonnement arrêté après mesure/sortie/arrière-plan. Pas de coordonnée en stockage/logs, ni de position connue réutilisée. Annulation/purge sur changement de consentements/session, réponses tardives ignorées. Android coarse/fine et iOS when-in-use déclarés ; pas de suivi de fond. Flag SPM iOS et essais Mac/appareils décrits au README, encore ouverts.
- **Feed/gestes** : titre serif, distance arrondie reçue, bio/traits/réponses serveur, sans photo ni ville/catégorie fabriquée. Double appui = like ; geste haut depuis la fin de lecture = pass ; lecture longue protégée et boutons accessibles. Aucun retour vers un précédent profil. Curseur opaque encodé, limite stable, déduplication, reprise unique sans curseur expiré et fin explicite ; aucun filtre client inventé.
- **Résultat perdu/match** : cible et décision conservées en mémoire entre visites du feed ; une seule demande en cours, reprise explicite du même choix et `Retry-After`, aucun stockage durable. Candidat indisponible/choix déjà enregistré retiré sans envoyer l'opposé. Seul le match retourné par le serveur avec les bons membres ouvre un récapitulatif ; chat et liste persistante restent L5, sans déduire de droit courant depuis ce reçu.
- **Sûreté anticipée** : blocage confirmé depuis le feed ou le reçu, POST sans corps → `204`, reprise à l'identique en cas d'incertitude. Le blocage peut remplacer explicitement une intention like/pass perdue et purge le reçu local concerné. Liste/déblocage/signalement livrés en L7.
- **Contrôles exécutés** : huit tests L4 ciblés réussis, puis vérification du geste de lecture longue après son ajustement. Treize vérifications existantes de configuration réussies après retrait de la dépendance au fichier modèle. Deux aperçus de feed avec données simulées générés et inspectés. Compilation Android debug réussie ; pas de nouvelle suite globale lancée. Analyse sans erreur, formatage et XML vérifiés : coarse/fine Android, when-in-use dans les deux plist, aucune localisation en arrière-plan.
- **Sources/limites** : HTTP/DTO/services/cursor Rust découverte, présence et confidentialité, tests `discovery_contract.rs`, `discovery_postgres.rs` et Postman consultés. Aucun changement ni test backend. Aucun SMS ou compte réel utilisé : le critère deux comptes et les permissions/GPS natifs Android/iOS restent non validés, de même que les anciens essais fournisseur L2/L3. Le warning Kotlin du compresseur L3 reste à suivre.

Prochain lot : L5, matchs/chat/lecture et SSE. Conserver les essais réels de L2 à L4 ouverts.

## 8. L5 — matchs, chat et SSE

- Lister les matchs avec dernier message, non-lus, profil du partenaire et champs individuels.
- Respecter `active`, `awaiting_continuation`, `confirmed`, `expired`, `ended` dès l'affichage et l'envoi.
- Afficher les échéances serveur ; suspendre l'envoi pendant la décision sans masquer l'historique accessible.
- Livrer historique paginé, envoi idempotent, états d'envoi et déduplication.
- Utiliser la lecture groupée ; conserver la route unitaire comme capacité disponible sans multiplier les appels.
- Ouvrir SSE avec Bearer, gérer expiration/révocation, backoff et une seule connexion utile.
- Resynchroniser après reconnexion, invalidation et reprise : aucun replay hors ligne n'est garanti.
- Ajouter fin volontaire d'un match et retrait des données devenues inaccessibles.

Critère de sortie : deux comptes échangent sans doublon, voient les lectures et retrouvent un état cohérent après coupure ou clôture.

### Implémentation L5 — 16 octobre 2026

- **Interface et accès** : rencontres depuis profil/feed/reçu réciproque ; liste, dernier message, non-lus, profil textuel partenaire et historique paginé. Une ouverture par ID parcourt la collection mobile autorisée ; aucune route GET administrative. Ordre/cursors serveur, déduplication, redémarrage après curseur invalide. Mode nuit appliqué à toute l'app sur demande utilisateur ; aucun nouveau package.
- **Échanges** : `201` du message décodé directement, `Idempotency-Key` UUID v4 stable et contenu immuable après timeout, reprise explicite en mémoire dans la session. Limite 2 000 points de code Unicode après normalisation ECMAScript. Lecture groupée à partir d'un message reçu visible au premier plan ; route unitaire disponible au repository. Les événements seuls ne marquent pas lu. État/date serveur, envois suspendus pendant `awaiting_continuation`, historique conservé ; aucune transition de 24 h fabriquée localement. Photos partenaires inutilisées jusqu'à L6.
- **Temps réel et confidentialité** : SSE avec Bearer, une connexion utile dans l'espace rencontres ; arrêt à la sortie/en arrière-plan. Décodeur UTF-8 et trames bornés, timeout inactif 70 s, backoff avec aléa/`Retry-After`. Relecture aux connexions, événements, échéances et reprises. `401` expiré partage la rotation existante ; révocation ferme la session. Fin volontaire/blocage confirmés et repris à l'identique en cas de réponse incertaine. Purge à la perte d'accès, invalidation, changement de consentements/session ; anciennes réponses ignorées. Aucune persistance des messages/brouillons/clés.
- **Sources** : contrat HTTP, DTO/routes/services/stockage Rust des matchs, messages et événements, tests contractuels et exemples Postman consultés uniquement. Format SSE vérifié dans la [spécification WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html). Backend non modifié et tests backend non exécutés.
- **Vérifications exécutées** : neuf tests ciblés réussis (envoi incertain, curseurs/ordre, états, purge et réponses tardives, fin/blocage, lecture visible, décodage, refresh SSE/JSON concurrent, connexion unique/annulation). Quatre aperçus simulés en mode nuit inspectés, dont grand texte/clavier et retour de navigation. Formatage, analyse sans problème et APK Android debug réussis. Pas de passage systématique de la suite entière. Essais de sortie ci-dessus encore ouverts entre deux comptes autorisés et sur appareils Android/iOS ; aucun échange réel ou succès fournisseur revendiqué.

Prochain lot : **L6**, révélation, continuation et quota/récompenses serveur.

## 9. L6 — révélation, continuations et récompenses

- Proposer la révélation comme accord séparé ; aucune photo de partenaire avant révélation mutuelle.
- Lire le quota avant de présenter le coût ; afficher stock, réservations et plafond fournis par le serveur.
- Envoyer le coût maximal accepté `credit_cost: 0` ou `1`, sans calcul local du débit.
- Gérer accord privé en attente, confirmation mutuelle, refus/expiration et changement de plan ou de semaine.
- Ne pas promettre de remboursement d'un crédit déjà débité à la clôture.
- Prévoir une action vidéo volontaire uniquement pour un compte éligible et un fournisseur disponible.
- Créer/reprendre l'intention, fournir `ad_unit` et `custom_data` au SDK, suivre le statut et annuler si approprié.
- Aucun crédit au callback client : attendre la validation serveur puis recharger le quota.

Critère de sortie : règles Free/Premium et confidentialité des choix respectées ; récompense validée côté serveur ou blocage fournisseur clairement identifié.

### Implémentation L6 — 16 octobre 2026

- **Accords** : écran « Photos et continuation » depuis le chat, choix indépendants et confirmations explicites. Révélation par PATCH sans corps ; conserver l'URL et ouvrir la vue photo seulement après `photos_revealed` dans une nouvelle lecture. Aucune image dans le feed ni téléchargement dans la liste. Vue privée en mémoire, HTTPS sans Bearer/redirection, limites 5 Mo/15 s, renouvellement avant cinq minutes, purge du cache image à la suspension/fermeture/perte d'accès.
- **Crédits et coût** : quota propriétaire, stock/réservations/plafond, catalogue et formule effective serveur. Avant chaque nouvel accord, relecture de la rencontre/quota puis acceptation du coût maximal personnel `credit_cost: 0|1`. Après réponse perdue, conserver ce coût en mémoire et reprendre explicitement à l'identique. Changement de formule/lecture/semaine ou confirmation trop ancienne = nouvelle présentation requise. Aucun débit, solde ou choix du partenaire calculé localement. État `confirmed` relu avant réouverture de l'envoi ; aucun remboursement promis après débit.
- **Récompenses et limite choisie** : POST/GET/DELETE disponibles au repository, suivi propriétaire à délai progressif borné et `Retry-After`, annulation confirmée, crédit uniquement après statut serveur `credited` puis relecture du quota. Un `expired` peut encore devenir `credited` après preuve tardive. Le callback local n'ajoute rien. **Aucun lancement/création de vidéo depuis l'interface livrée**, conformément au choix utilisateur. SDK natif, UMP, configuration AdMob côté API et validation SSV restent à réaliser avant activation. Pas de nouvelle dépendance ni de faux fournisseur.
- **Configuration** : `.env` local conserve l'origine API et reçoit quatre champs publics AdMob facultatifs. Android renseigné avec les valeurs utilisateur ; iOS vide. IDs d'application `~` et unités `/` validés distinctement. Valeurs réservées pour le futur SDK, sans remplacer l'unité/`custom_data` de l'intention API. Aucun ID en dur dans Dart/manifestes, aucun fichier modèle recréé, backend inchangé.
- **Sources et contrôles** : DTO/routes/services/stockage et tests Rust matchs/publicité, guide continuations/récompenses et Postman consultés, sans exécution backend. Documentation officielle Google [initialisation](https://developers.google.com/admob/flutter/quick-start), [vidéo/SSV](https://developers.google.com/admob/flutter/rewarded), [UMP](https://developers.google.com/admob/flutter/privacy). Huit contrôles L6, treize contrôles existants de configuration et sept contrôles existants du chat réussis ; cinq aperçus simulés en mode nuit inspectés, petit écran/grand texte et navigation vérifiés. Formatage et analyse sans problème ; essais entre deux comptes, photo/native et iOS ouverts. Aucun nouveau passage de toute la suite.

La suite L7 est livrée ci-dessous ; l'activation des vidéos reste une étape suivie séparément.

## 10. L7 — sûreté, paramètres et vie privée

- Rendre signalement et blocage accessibles dès qu'un profil de partenaire est exposé.
- Utiliser les motifs fermés ; gérer blocages et déblocages sans restaurer artificiellement un ancien match.
- Lister/révoquer les sessions et proposer la déconnexion globale ; traiter la révocation de la session courante.
- Gérer les consentements et les effets destructifs de leur retrait, sans proposer un retrait CGU/notice absent de l'API.
- Créer et consulter les demandes RGPD avec leurs statuts.
- Télécharger l'export, permettre son partage explicite et nettoyer le temporaire privé.
- Présenter une confirmation de suppression, obtenir le jeton dédié puis envoyer le DELETE.
- Sur `202`, fermer la session et annoncer le nettoyage en cours, sans prétendre qu'il est terminé.
- Traiter une réponse de suppression perdue sans réutiliser le Bearer invalide comme suivi public.

Critère de sortie : droits accessibles même quand l'onboarding est incomplet si l'API l'autorise, purge locale cohérente et absence de promesse d'effacement prématurée.

### Livraison L7 — 16 octobre 2026

- Espace de confidentialité depuis profil et consentements avant onboarding. Sessions paginées et révocation unitaire/courante/globale ; demandes de droits non paginées, six types et états serveur. Après mutation incertaine, relecture et reprise explicite de la même cible/type. Déblocage sans restaurer d'ancien match ; consentements existants conservés.
- Signalement feed/reçu/chat/profil partenaire : motifs fermés, limite brute 2 000 octets UTF-8, intention immuable en mémoire de l'écran, `409` déjà en attente et `Retry-After`. Blocage séparé confirmé ; aucune photo dans sa liste.
- Export sur disque privé : flux authentifié sans redirection, maximum 512 Mio, longueur exacte vérifiée ; en-têtes 2 min, inactivité 30 s et transfert 10 min. `share_plus ^13.3.1`, partage explicite sans statut de livraison inventé. Nettoyage sérialisé de ses seuls temporaires et copies de partage au démarrage/sortie/suspension/purge, différé au retour d'un partage actif. Aucun JSON complet en mémoire ni original utilisateur effacé.
- Suppression après saisie et confirmation, jeton dédié sans persistance. Barrière durable `closing` sans refresh avant l'unique DELETE ; aucun rejeu ni sonde d'authentification après un résultat incertain. `202` = compte inaccessible et nettoyage en cours. Même barrière pour session courante/logout global ; échec de stockage avant barrière = aucune requête terminale.
- Sources : contrat HTTP, DTO/routes/services droits/effacement/export/signalements/sessions, tests de contrat et Postman consultés. Backend en lecture seule, jamais lancé ni testé. Neuf contrôles L7 + dix-huit contrôles existants session/SSE réussis, neuf aperçus simulés inspectés, analyse/formatage et APK Android debug vérifiés. Partage/export et suppression réels, interruptions/stockage natifs et iOS restent ouverts.
- Dépendance Google déjà présente conservée, fournisseur Android automatique exclu pour garder les vidéos désactivées jusqu'au raccordement IDs natifs/UMP. IDs réels uniquement dans `.env`. Aucun Git ni fichier modèle recréé.

Suite L8 livrée ci-dessous ; configuration Firebase et validations sur téléphones restent ouvertes.

## 11. L8 — appareils et push

- Configurer Android/iOS et Firebase sans embarquer de compte de service serveur.
- Demander la permission en contexte ; enregistrer et mettre à jour token, plateforme et version.
- Afficher/révoquer les appareils avec les données publiques de l'API.
- Gérer rotation FCM, permission refusée, réinstallation et désactivation fournisseur.
- Traiter premier plan, arrière-plan et application arrêtée ; dédupliquer `notification_id`.
- Valider session et ressource au retour d'une notification, sans exposer de contenu privé ni ouvrir un match devenu inaccessible.

Critère de sortie : essais documentés sur Android et iOS réels, ou limites d'environnement explicitement ouvertes.

### Livraison L8 — 17 octobre 2026

- Liste/retrait d'appareils depuis profil/confidentialité après onboarding, trois routes exactes, sans pagination ni token dans la projection. Retrait distinct d'une fermeture de session ; relecture et reprise de la même cible après réponse perdue.
- Firebase absent : choix utilisateur explicite de laisser les push désactivés. Huit champs publics dans le `.env` ignoré, `PUSH_ENABLED=false`, aucune permission ni initialisation Firebase Dart dans cette configuration, aucun fichier modèle recréé.
- Dépendances `firebase_core ^5.0.0`, `firebase_messaging ^17.0.0`, `package_info_plus ^10.2.2` ; options explicites et ressources Android natives conditionnelles depuis `.env`, auto-init/Analytics désactivés. SDK 17 : identifiant d'installation FCM dans le champ `push_token`, version réelle installée. iOS : délégation UIScene, bridge APNs et deux plist préparés, capacité/signature `aps-environment` et clé APNs restant à configurer sur Mac.
- Permission contextuelle, enregistrement/rotation sérialisés, corps immuable en cas d'incertitude, pas de rejeu automatique après timeout. Préférence sécurisée liée à l'origine/propriétaire, UUID courant et jusqu'à 64 IDs d'ouvertures ; aucun identifiant fournisseur copié dans ce stockage. Retrait distant/réinstallation sans préférence = pas de réactivation implicite. Marqueur d'arrêt durable si le nettoyage échoue, puis reprise sans nouvel enregistrement.
- Premier plan : bandeau générique, déduplication 128 IDs en mémoire. Ouverture à froid/reprise : seuls types et UUID contractuels conservés, textes/liens distants ignorés ; session puis matchs/historique relus avant chat. Notification périmée n'ouvre pas un match inaccessible. Parcours de notification unique, brouillons conservés et autres flux SSE suspendus temporairement. Facturation : état d’abonnement authentifié depuis L9. Handler arrière-plan sans HTTP privé ni navigation ; les doublons OS déjà affichés ne sont pas supprimés par Dart et aucun rattrapage offline n'est supposé.
- Sources : contrat HTTP, DTO/routes/services/stockage/publication Rust, tests `notifications_contract.rs`, Postman et documentation officielle Firebase/Flutter consultés. Aucun test ni changement backend. Dix contrôles L8 + treize contrôles existants de configuration réussis ; sept aperçus simulés inspectés, analyse/formatage et APK Android debug vérifiés. Réception FCM/APNs, permissions sur téléphones, arrêt/reprise natifs et compilation iOS encore à valider. SDK publicitaire toujours désactivé.

Suite prévue après L8 : L9, livré ci-dessous. L'activation Firebase reste une étape indépendante en attente de projet/configuration et d'essais réels.

## 12. L9 — offres et abonnement

- Charger les tarifs, devise, essai et fonctionnalités du catalogue ; aucun montant métier figé dans les écrans.
- Afficher l'état d'abonnement à partir de `access_granted`, des dates et du plan effectif.
- Vérifier la stratégie de distribution avec les règles officielles des stores et marchés visés avant activation des ventes.
- Définir liens de retour, navigation externe et configuration d'activation ; ne pas supposer un feature flag distant déjà fourni par l'API.
- Créer/reprendre Checkout avec `monthly` ou `annual` et une clé stable, jamais un identifiant Stripe ou montant client.
- Relire l'abonnement au retour et après événement ; ne pas accorder Premium depuis l'URL de succès.
- Ouvrir le portail selon sa disponibilité réelle et sa configuration.
- Valider essai, SCA, échec, renouvellement, annulation, retour après arrêt de l'app et état de paiement incertain en environnement Stripe test.

Critère de sortie : droits réellement projetés par l'API et vente activée seulement pour une distribution vérifiée ; sinon catalogue/état utilisables et paiement explicitement en attente.

**Livré côté mobile** : écran d'abonnement depuis profil et notifications de facturation, catalogue dynamique, plan effectif/`access_granted`, dates et huit états Stripe. Lectures au retour du navigateur, reconnexion/événement SSE et réouverture après arrêt. Intention Checkout `monthly`/`annual` sauvegardée avant POST, UUID v4 stable, reprise explicite après résultat incertain et blocage de la seconde période. Prix/essai/renouvellement confirmés avant navigation. Liens Stripe standards validés, portail conditionné à la disponibilité serveur, erreurs françaises et `Retry-After`, requêtes annulées et données purgées au changement de compte. Aucun statut Premium attribué localement.

**Choix de distribution** : APK Android hors Play Store avec Stripe. `.env` : `BILLING_DISTRIBUTION=android_external`, `BILLING_ENABLED=false`, trois champs HTTPS renseignés : succès `https://www.histae.com/billing/success?session_id={CHECKOUT_SESSION_ID}`, annulation `https://www.histae.com/billing/cancel`, portail `https://www.histae.com/billing/return`, identiques aux URL locales API. iOS/Web/bureau restent fermés aux paiements. [Règles Play](https://support.google.com/googleplay/android-developer/answer/9858738) et [Apple 3.1](https://developer.apple.com/app-store/review/guidelines/#payments) consultées le 17 octobre 2026 ; pas d'autorisation supposée pour une distribution par les stores. Entrées HTTPS `/billing/success`, `/billing/cancel` et `/billing/return` implémentées dans `histae-site`, avec sélection de la première langue prise en charge du navigateur, français en secours et choix manuel sans JavaScript. Les paramètres sont conservés sans interprétation jusqu'aux pages localisées, sans confirmation de paiement. Restent à publier le site, reporter les URL dans le `.env` API du serveur et compiler l'app avant les essais ; retour manuel dans l'app suivi d'un GET authentifié ; aucun app link/lien universel automatique configuré. Voir les champs et les conditions dans [README](README.md#l9--offres-et-abonnement).

**Vérifications et limites** : dix contrôles L9 ciblés réussis, plus treize contrôles existants de configuration et une régression de navigation push. Six aperçus inspectés avec données simulées, dont 320 px/texte 160 %. Formatage vérifié (110 fichiers), analyse sans problème et APK Android debug compilé. Contrats/DTO/service/tests/Postman backend consultés seulement. Prix, essais et états privés simulés, aucun paiement Stripe exécuté. Mode test fournisseur, SCA, refus, renouvellement, résiliation et retours sur téléphone après arrêt restent à valider avec le serveur configuré. Ventes et portail désactivés conformément au choix utilisateur ; catalogue et droits consultables. Prochain lot : **L10**.

## Refactoring transversal avant L10

Refonte demandée le 17 octobre 2026. Démarrage et composition des dépendances séparés ; navigation de notification isolée ; neuf interfaces de dépôts et implémentations API ; contrat `AuthenticatedSession` indépendant du contrôleur concret. Primitives JSON/flux/annulation, compteurs et opérations locales sérialisées communs. Brouillons/envois du chat isolés, collections exposées en lecture seule et DTO à listes protégées. Formulaires, confidentialité, profil partenaire et abonnement répartis en composants dédiés. Typage/analyse stricts, manifests nettoyés sans changement de dépendances. Aucun changement backend, commande Git ou suppression de fichier.

La valeur mobile `BILLING_ENABLED=stripe` était invalide ; elle est remise à `false` sans activer les paiements. Push et vidéos restent désactivés. Les liens de retour existants sont conservés. Les règles de session, de rejeu et de droits serveur restent couvertes par les contrôles existants. Architecture et responsabilités : [ARCHITECTURE.md](ARCHITECTURE.md).

Achevé le 18 octobre : commandes du profil appelées depuis les vues, téléchargement des photos de stockage signé isolé et partagé (5 Mo, quinze secondes, sans Bearer/redirection/cache disque). 166 contrôles globaux, puis 39 ciblés sur les derniers changements dont un nouveau contrôle photo : **167 contrôles distincts réussis**, trois nouveaux seulement. Analyse stricte sans problème, formatage vérifié sur 143 fichiers et APK Android debug compilé. Quatre scénarios d'aperçu, 22 images simulées, planche d'ensemble et écrans représentatifs inspectés. Les essais API privée/fournisseurs sur téléphones et la compilation iOS restent ouverts ; L10 n'est pas déclaré terminé.

Les trois cartes **Free**, **Premium Mensuel** et **Premium Annuel** sont raccordées à `offers` dans
`GET /api/plans`, avec fonctionnalités via `plan_code` et `plans`. Prix, devise et essai viennent du serveur ;
le bouton de chaque carte Premium conserve sa propre périodicité. L'annuel indique sa facturation en une
fois. Les niveaux de droits restent Free/Premium. Déployer d'abord le backend qui expose `offers`, puis
le dashboard et cette version mobile. L'activation Stripe et les essais fournisseur restent ouverts.

## 13. L10 — qualité et bêta

- Vérifier accessibilité, grandes polices, textes longs, clavier et tailles d'écran.
- Vérifier suspension/reprise, changement Wi-Fi/mobile, réseau lent, erreurs fournisseur et requêtes concurrentes.
- Contrôler logs, rapports de crash, caches, fichiers temporaires, liens entrants et HTTPS.
- Préparer identifiants d'application, signatures, icônes, splash, permissions et fiches de distribution.
- Préparer déclarations de confidentialité et textes juridiques appropriés avec les personnes responsables.
- Valider l'environnement API ciblé : SMS, stockage/modération, PostgreSQL, Redis, outbox, maintenance, push, publicité, Stripe et supervision selon les fonctions activées.
- Distinguer vérification automatique, intégration backend, validation fournisseur et essai sur appareil réel.

Critère de sortie : chaque parcours activé a une preuve adaptée ; les fonctions dépendant encore d'une configuration externe ne sont pas annoncées comme opérationnelles.

## 14. Matrice de couverture des routes mobiles

Chemins complets, préfixe `/api` inclus. Les 56 routes restent suivies : catalogue intégré, sept routes L2 et treize routes L3 implémentées avec tests côté client ; parcours privés à valider avec compte/appareil réels. Après chaque lot, associer la preuve adaptée. La lecture unitaire peut être couverte comme alternative à la lecture groupée sans créer un second écran.

| Méthode | Route | Lot | Écran ou usage | État |
| --- | --- | --- | --- | --- |
| POST | `/api/auth/otp/send` | L2 | Demander/renvoyer OTP | Implémenté ; UUID stable, incertitude et quotas testés ; SMS réel à valider |
| POST | `/api/auth/otp/verify` | L2 | Inscription/reconnexion par OTP | Implémenté ; DTO et réponse perdue testés ; compte réel à valider |
| POST | `/api/auth/refresh` | L2 | Rotation de session sérialisée | Implémenté ; concurrence, panne et redémarrage testés ; appareil à valider |
| GET | `/api/auth/me` | L2 | Bootstrap authentifié | Implémenté ; navigation et révocation testées ; compte réel à valider |
| POST | `/api/auth/logout` | L2 | Déconnexion courante | Implémenté ; rotation concurrente/purge/hors ligne testés ; réel à valider |
| GET | `/api/auth/sessions` | L7 | Liste des sessions | Implémenté ; curseurs opaques contrôlés ; réel à valider |
| DELETE | `/api/auth/sessions/:id` | L7 | Révoquer une session | Implémenté ; actuelle/autre, relecture et purge contrôlées ; réel à valider |
| POST | `/api/auth/logout-all` | L7 | Déconnexion globale | Implémenté ; barrière sécurisée/purge contrôlées ; réel à valider |
| GET | `/api/users/me/consents` | L2 | État et documents requis | Implémenté ; quatre choix/versions/navigation testés ; réel à valider |
| PUT | `/api/users/me/consents` | L2, L7 | Accepter et gérer les choix autorisés | Implémenté L2 ; choix et retraits confirmés testés ; réel à valider |
| GET | `/api/users/me` | L3 | Profil propriétaire | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PATCH | `/api/users/me/profile` | L3 | Créer/modifier le profil | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/preferences` | L3 | Préférences courantes | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PATCH | `/api/users/me/preferences` | L3 | Modifier les préférences | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PATCH | `/api/users/me/presence` | L4 | Position ponctuelle | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| PUT | `/api/users/me/photo` | L3 | Envoyer/remplacer la photo unique | Implémenté ; contrats/tests client ; compte et appareil à valider |
| DELETE | `/api/users/me/photo` | L3 | Retirer la photo | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/traits` | L3 | Catalogue des traits | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/traits` | L3 | Traits sélectionnés | Implémenté ; contrats/tests client ; compte et appareil à valider |
| POST | `/api/users/me/traits` | L3 | Ajouter un trait | Implémenté ; contrats/tests client ; compte et appareil à valider |
| DELETE | `/api/users/me/traits/:traitId` | L3 | Retirer un trait | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/profile-questions` | L3 | Catalogue des questions | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/profile-answers` | L3 | Réponses propriétaires et modération | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PUT | `/api/users/me/profile-answers` | L3 | Remplacer la liste ordonnée des réponses | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/discovery-status` | L4 | Diagnostic de préparation | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| GET | `/api/feed` | L4 | Découverte paginée | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| POST | `/api/swipes` | L4 | Like/pass et résultat du match | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| GET | `/api/matches/me` | L5 | Liste des matchs | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| PATCH | `/api/matches/:id/reveal` | L6 | Accord de révélation | Implémenté ; accord et photo conditionnelle contrôlés ; deux comptes/appareils à valider |
| PATCH | `/api/matches/:id/continue` | L6 | Accord de continuation et coût | Implémenté ; coût/reprise/changement de formule contrôlés ; deux comptes/appareils à valider |
| PATCH | `/api/matches/:id/end` | L5 | Terminer un match | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| GET | `/api/users/me/continuation-quota` | L6 | Crédits, réservations et plafond | Implémenté ; projection serveur et coût contrôlés ; compte/appareil à valider |
| GET | `/api/matches/:id/messages` | L5 | Historique paginé | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| POST | `/api/matches/:id/messages` | L5 | Envoi idempotent | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| PATCH | `/api/matches/:id/messages/read` | L5 | Lecture groupée | Implémenté ; contrôles client ciblés ; deux comptes/appareils à valider |
| PATCH | `/api/matches/:id/messages/:msgId/read` | L5 | Lecture unitaire si nécessaire | Disponible au repository ; UI groupée ; compte/appareil à valider |
| POST | `/api/users/me/advertising-rewards` | L6 | Créer/reprendre une intention | Repository/suivi préparés ; aucun lancement UI ; SDK/UMP/fournisseur en attente par choix utilisateur |
| GET | `/api/users/me/advertising-rewards/:id` | L6 | Suivre la validation serveur | Suivi et crédit serveur contrôlés en simulation ; SDK/SSV réel en attente |
| DELETE | `/api/users/me/advertising-rewards/:id` | L6 | Annuler une intention | Repository/confirmation préparés ; protection vidéo terminée contrôlée ; réel en attente |
| GET | `/api/users/me/devices` | L8 | Liste des appareils | Implémenté ; projection sans token, onboarding et purge contrôlés ; compte réel à valider |
| POST | `/api/users/me/devices` | L8 | Enregistrer/rafraîchir le token push | Contrat/SDK/permission/rotation/reprises préparés et simulés ; push désactivés en attente Firebase et appareils |
| DELETE | `/api/users/me/devices/:id` | L8 | Retirer un appareil | Implémenté ; confirmation, réponse perdue et arrêt courant contrôlés ; réel à valider |
| GET | `/api/users/me/events` | L5 | SSE authentifié | Implémenté ; Bearer/refresh/connexion unique contrôlés ; réseau/appareils à valider |
| GET | `/api/plans` | L1, L6, L9 | Catalogue, tarifs et disponibilité publicitaire | Intégré API L1 ; lecture L6 branchée, vidéos maintenues désactivées ; affichage L9 branché ; appareils en attente |
| GET | `/api/users/me/subscription` | L9 | Abonnement et droits effectifs | Implémenté ; accès/dates/états contrôlés côté client ; compte et appareil réels à valider |
| POST | `/api/users/me/subscription/checkout` | L9 | Achat hébergé si distribution compatible | Implémenté ; intention durable, reprise et navigation contrôlées ; activé dans la configuration mobile locale Android externe, achat réel non validé |
| POST | `/api/users/me/subscription/portal` | L9 | Gestion de l'abonnement | Implémenté ; disponibilité serveur et navigateur contrôlés ; activé localement sur Android externe si le serveur le permet, gestion réelle à valider |
| GET | `/api/users/me/blocks` | L7 | Comptes bloqués | Implémenté ; liste sans photo ; réel à valider |
| POST | `/api/users/me/blocks/:userId` | L4, L7 | Bloquer un compte depuis feed ou reçu | Implémenté L4 ; confirmation et reprise ciblées ; réel à valider |
| DELETE | `/api/users/me/blocks/:userId` | L7 | Débloquer un compte | Implémenté ; relecture, sans restauration ; réel à valider |
| POST | `/api/reports` | L7 | Signaler un compte/contenu | Implémenté ; UTF-8, intention stable, 201/409/429/purge contrôlés ; réel à valider |
| POST | `/api/users/me/data-subject-requests` | L7 | Déposer une demande RGPD | Implémenté ; types, doublon/relecture et onboarding ; réel à valider |
| GET | `/api/users/me/data-subject-requests` | L7 | Suivi des demandes | Implémenté ; statuts et liste non paginée ; réel à valider |
| GET | `/api/users/me/data-export` | L7 | Export JSON privé | Implémenté ; flux/refresh/troncature/nettoyage contrôlés ; natif à valider |
| POST | `/api/users/me/deletion-token` | L7 | Préparer la confirmation de suppression | Implémenté ; jeton mémoire après confirmation ; réel à valider |
| DELETE | `/api/users/me` | L7 | Accepter la suppression, fermer la session sur 202 | Implémenté ; barrière, 202 et réponse perdue contrôlés ; réel à valider |

Le webhook AdMob figure dans la section récompenses du contrat API, mais il est appelé par le fournisseur, jamais par Flutter. Il en va de même pour les webhooks Stripe et Sweego. Les routes de santé peuvent servir au diagnostic de développement, sans être un parcours utilisateur ou remplacer les erreurs des appels métier.

## 15. Dépendances externes et définition de terminé

| Dépendance | Validation restant à réaliser côté mobile |
| --- | --- |
| SMS/OTP | Configuration de développement, quotas et livraison réelle contrôlée |
| S3 et modération | Upload réel, formats appareils, état propriétaire, URL expirée et retrait |
| Maintenance/outbox | Transitions, effets différés et resynchronisation sans les simuler localement |
| FCM | Projet/options publiques, fournisseur API et APNs/signature iOS à configurer ; push désactivés, réception Android/iOS réelle à valider |
| AdMob | Configuration serveur et SDK, mode de test, validation signée, disponibilité effective |
| Stripe | Environnement test, portail, retours app et droits projetés |
| Distribution | Stratégie de paiement, signatures, permissions et déclarations selon les règles applicables |

Une tranche est terminée lorsque son parcours fonctionne avec les vrais contrats, que chargement/vide/erreur/hors ligne sont traités, que les données privées sont protégées et que les vérifications pertinentes sont documentées. Pour les changements Flutter, effectuer formatage, analyse et tests ciblés disponibles ; signaler un outil ou un appareil manquant sans annoncer de réussite. Les tests ordinaires n'envoient ni SMS ni paiement ni récompense publicitaire réels.

Un blocage fournisseur ne doit pas arrêter les tâches indépendantes : garder la capacité dans la matrice, décrire ce qui est implémenté et ce qui reste à valider. Ne pas déclarer une fonction opérationnelle en production sur la seule base de fixtures.

Après chaque intervention, mettre à jour ce suivi et le résumé, expliquer le prochain petit lot et fournir un message de commit en anglais. Aucune commande Git ni suppression de fichier. Si un script `.sh` est créé ou modifié, ne pas effectuer de tests de ce script.




## 16. Identité et ouverture — 18 octobre 2026

Logo original **02 / Les pages** appliqué : le livre est le symbole autonome, le nom est facultatif. Site : en-tête/pied de page, favicon et manifeste ; app : signature des en-têtes, icônes Android et iOS. Android dispose de calques adaptatifs et monochrome. Ouverture H. → Histae. avec livre et fondu, en parallèle de la restauration, sans rejeu au retour d'arrière-plan et avec prise en compte de la réduction des animations.

Vérifications : analyse Flutter, 21 contrôles ciblés (trois nouveaux), aperçu animé issu des images Flutter et APK debug ; types/lint/build/export du site et revue ordinateur/petit écran. Le site reste localement modifié. L10 reste ouvert : essais du démarrage à froid et des masques d'icônes sur appareils, compilation iOS sur Mac, puis qualité bêta. Aucun appel privé réel ni changement d'API.

## 17. Accès Premium/vidéos et ajustements mobiles — 19 octobre 2026

- Raccourcis sur feed/profil vers les parcours existants. Une lecture de vidéo reste indisponible tant que le SDK AdMob et UMP ne sont pas raccordés. Aucun crédit accordé localement.
- `BILLING_ENABLED=true` dans le seul `.env` mobile local, à la demande explicite de l’utilisateur. Android externe uniquement, avec les garde-fous de confirmation et de lecture des droits serveur ; iOS inchangé. Une nouvelle compilation est fournie.
- Fond bleu nuit uniforme sous la navigation et style système racine ; icône native réduite, sources SVG et PNG régénérés.
- API inspectée sans modification : configuration locale Stripe live/AdMob complète et cohérente avec le mobile ; catalogue public avec publicité activée pour Free ; trois retours HTTPS accessibles. Consoles fournisseur, webhooks et transaction de bout en bout non validés.

16 contrôles ciblés réussis, dont un nouveau pour les raccourcis ; analyse et APK Android debug vérifiés, six aperçus manuels dont petit écran à 200 %. Aucun achat/SMS/visionnage réel. Prochaines étapes : raccordement SDK AdMob/UMP, validation fournisseur puis L10 sur appareils. Les mentions de désactivation des paiements dans les comptes rendus historiques décrivent leur état avant cette activation.

## 18. Répartition finale des accès — 19 octobre 2026

Le feed retrouve toute sa hauteur : suppression des raccourcis de formule et de vidéo. Le profil propose un seul accès, **Premium pour Free**, **Mon abonnement pour Premium**, selon le quota serveur relu ; une formule inconnue utilise le libellé neutre de gestion. Dans Matchs : compteurs `free_remaining` et `advertising_remaining` plus bouton **Vidéos** pour Free. Les réservations et le stock total ne sont pas confondus avec le disponible. Premium affiche l’absence de coût en crédits, sans vidéo, y compris sur l’écran détaillé des crédits. La lecture SDK demeure désactivée.

Les soldes se relisent au retour d’une route, au changement d’onglet et après reprise. Un échec ne produit pas de faux zéro. Activation du contrôleur partagé après démontage de l’onglet précédent, pour éviter qu’une suspension tardive annule la nouvelle lecture. Le chat et les notifications conservent leur reprise et leurs contrôles d’accès ; l’ouverture d’une conversation entrante n’attend pas la lecture des crédits.

Vérifications : 22 contrôles ciblés, deux scénarios d’accès Free/Premium remplaçant l’ancien scénario des raccourcis, dix captures simulées (dont 320 × 568 à 200 %), analyse sans problème et APK Android debug. Aucun fournisseur réel appelé. Prochain lot : raccordement AdMob/UMP puis validations L10 sur appareil. Cette répartition remplace les emplacements précédents de la section 17.


## 19. Vos crédits et AdMob/UMP — 19 octobre 2026

Refonte complète de Vos crédits, avec soldes gratuits/vidéos distincts, plafond de semaine, explications repliables et états indisponibles sans faux chiffres. Raccordement du SDK existant : injection des IDs natifs depuis `.env`, UMP avant requête publicitaire, bloc et `custom_data` fournis par l’intention API, annulation des tentatives sans visionnage, suivi exclusivement serveur et reprise après récompense créditée. Free uniquement, sous éligibilité du catalogue et réserve non pleine. Choix publicitaires accessibles également depuis Vie privée.

19 contrôles ciblés réussis, analyse et APK Android debug, aperçus de six états dont texte à 200 %. Le catalogue public autorise Free. Aucun changement backend, paiement, SMS ou publicité réelle. Restent pour L10 : diffusion et validation SSV sur appareil de test, vérification des réglages UMP/SSV de la console AdMob, build iOS sur Mac et essais natifs. Cette section remplace les précédentes mentions de lecteur SDK désactivé.


## 20. Gestion du profil et consentements explicites — 19 octobre 2026

Refonte du profil et des réponses : aperçu ordonné/modération, cartes de détail, sélecteur de questions recherchable, limite de trois, réorganisation et retrait, enregistrement fixe et remplacement confirmé. Consentements modifiables montrés en premier avec retrait explicite ; documents nécessaires et limites du contrat expliqués.

Blocage vidéo identifié dans les journaux réels : aucun formulaire UMP pour l’ID actuel. Publier et associer le message Réglementations européennes dans AdMob ; aucune modification API. Erreurs UMP classées et récupération sur accord antérieur uniquement si le SDK l’autorise. Cycle de vie du quota préservé sous les routes natives depuis Profil et Matchs.

25 contrôles ciblés, analyse propre, 12 captures manuelles dont 200 %/clavier, APK Android debug. Aucun changement backend, formulaire de console publié automatiquement ou nouvelle publicité réelle. L10 garde la validation de diffusion et SSV après configuration AdMob, puis les essais iOS sur Mac.


## 21. Progression de Matchs stabilisée — 19 octobre 2026

Une seule barre fixe sous l’en-tête regroupe les chargements des rencontres et des crédits. Suppression des indicateurs alternés dans la liste/carte, protection du chargement initial contre une actualisation manuelle concurrente, et absence de faux état vide/indisponible à l’entrée. Relectures temps réel, accès vidéo et navigation depuis les notifications conservés.

Vérifications : 12 contrôles ciblés, dont un scénario différant liste/quota puis simulant une relecture temps réel et une panne ; analyse propre. Aucun changement backend. Prochaine vérification : rendu du chargement sur l’émulateur avec la nouvelle compilation.
