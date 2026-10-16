# Histae App — roadmap de développement

Mise à jour : 16 octobre 2026.

[Accueil](README.md) · [Résumé d'intégration](resume.md) · [Contrat HTTP Rust](../histae-api-rust/docs/http-contract.md)

## 1. État de départ et suivi

L1 est intégré pour le catalogue. L2 et L3 sont implémentés : OTP/session/consentements, profil majeur, préférences, traits, réponses et photo personnelle. Les sept routes L2 et treize routes L3 utilisent les contrats réels ; seuls des tests simulés couvrent ces parcours privés. SMS, compte réel, stockage sécurisé et photo sur appareil restent à valider. L4 à L10 restent à construire. La découverte de L4 désigne le feed de profils sans photo. La DA suit `pictures/exemple_feed.png`, en ivoire/vert forêt/encre/sable, sans rose ni corail. Configuration publique déplacée dans `.env`, avec `.env.example` et sans adresse de secours dans Dart.

Cette roadmap couvre toutes les capacités utilisateur de l'API actuelle. Elle exclut l'administration, les webhooks fournisseur, la supervision et les opérations internes. Elle ne dépend pas des anciens dépôts NestJS ou d'un endpoint OpenAPI.

Les états doivent distinguer : `À faire`, `En cours`, `Implémenté`, `Intégré API`, `Validé sur appareil`. Une fonctionnalité ne passe pas directement à « validée » parce que son endpoint existe. Renseigner dans le suivi les vérifications, l'environnement et les blocages fournisseur ; ne pas mettre de données privées dans les preuves.

## 2. Ordre des lots

| Lot | Objectif | État |
| --- | --- | --- |
| L0 | Vérifier le contrat, l'inventaire, les parcours et l'environnement mobile | Vérifié pour L1 : SDK, catalogue, erreurs, routes/DTO/services, tests et Postman consultés ; approfondir par lot |
| L1 | Bootstrap, configuration, navigation, thème et client HTTP | Intégré API pour le catalogue ; 54 tests, analyse et compilation Android debug ; appareils/iOS en attente |
| L2 | Inscription/reconnexion OTP, session et onboarding juridique reprenable | Implémenté ; 85 tests au total et compilation Android debug ; SMS, compte réel et appareils à valider |
| L3 | Profil, préférences, traits, questions, photo et modération propriétaire | Implémenté sur les treize routes ; vérifications automatiques ci-dessous ; compte/photo/appareils à valider |
| L4 | Présence, diagnostic de préparation, découverte et swipes | À faire |
| L5 | Matchs, chat, lecture et synchronisation SSE | À faire |
| L6 | Révélation, continuation, crédits et récompenses volontaires | À faire |
| L7 | Sûreté, paramètres de confidentialité, sessions, export et suppression | À faire |
| L8 | Appareils, notifications push et ouverture depuis notification | À faire |
| L9 | Offres, abonnement, Checkout et portail selon la distribution retenue | À faire |
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
- **Consentements** : quatre types et documents versionnés serveur, aucun nouveau choix précoché, reprise après lecture d'un document, vérification des versions avant PUT, champs exacts `{ consent_type, granted }`. Confirmation des retraits sensible/localisation ; aucun retrait CGU/notice. Accès aux documents et à la déconnexion pendant l'onboarding ; export/demandes/suppression restent en L7.
- **DA commune** : composition éditoriale issue de la référence utilisateur ; ivoire, forêt, encre et sable, titres DM Serif Display, cartes arrondies et séparateurs discrets. Licence de police conservée ; adaptation sombre et grand texte. Aucun feed construit en avance.
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
- **Configuration** : `.env` ignoré dans le suivi, `.env.example` fourni, chargement avant initialisation des clients ; aucun hôte/environnement de secours dans le code Dart. Fichier public embarqué dans le paquet, sans secret ; origine validée et HTTPS hors debug local. Lire le README pour installation/CI.
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
- Appliquer la DA éditoriale de `pictures/exemple_feed.png` avec la palette forêt/ivoire. Swipe vers le haut pour passer, double appui pour liker, aucun retour par swipe vers le bas.
- Paginer avec curseurs opaques, dédupliquer et reprendre après curseur invalide.
- Envoyer like/pass ; rejouer seulement le même choix en cas d'incertitude, sans annulation ni file durable hors ligne.
- Ouvrir le match reçu après réciprocité.

Critère de sortie : deux comptes de développement peuvent se découvrir et créer un seul match cohérent.

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

## 11. L8 — appareils et push

- Configurer Android/iOS et Firebase sans embarquer de compte de service serveur.
- Demander la permission en contexte ; enregistrer et mettre à jour token, plateforme et version.
- Afficher/révoquer les appareils avec les données publiques de l'API.
- Gérer rotation FCM, permission refusée, réinstallation et désactivation fournisseur.
- Traiter premier plan, arrière-plan et application arrêtée ; dédupliquer `notification_id`.
- Valider session et ressource au retour d'une notification, sans exposer de contenu privé ni ouvrir un match devenu inaccessible.

Critère de sortie : essais documentés sur Android et iOS réels, ou limites d'environnement explicitement ouvertes.

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
| GET | `/api/auth/sessions` | L7 | Liste des sessions | À faire |
| DELETE | `/api/auth/sessions/:id` | L7 | Révoquer une session | À faire |
| POST | `/api/auth/logout-all` | L7 | Déconnexion globale | À faire |
| GET | `/api/users/me/consents` | L2 | État et documents requis | Implémenté ; quatre choix/versions/navigation testés ; réel à valider |
| PUT | `/api/users/me/consents` | L2, L7 | Accepter et gérer les choix autorisés | Implémenté L2 ; choix et retraits confirmés testés ; réel à valider |
| GET | `/api/users/me` | L3 | Profil propriétaire | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PATCH | `/api/users/me/profile` | L3 | Créer/modifier le profil | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/preferences` | L3 | Préférences courantes | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PATCH | `/api/users/me/preferences` | L3 | Modifier les préférences | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PATCH | `/api/users/me/presence` | L4 | Position ponctuelle | À faire |
| PUT | `/api/users/me/photo` | L3 | Envoyer/remplacer la photo unique | Implémenté ; contrats/tests client ; compte et appareil à valider |
| DELETE | `/api/users/me/photo` | L3 | Retirer la photo | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/traits` | L3 | Catalogue des traits | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/traits` | L3 | Traits sélectionnés | Implémenté ; contrats/tests client ; compte et appareil à valider |
| POST | `/api/users/me/traits` | L3 | Ajouter un trait | Implémenté ; contrats/tests client ; compte et appareil à valider |
| DELETE | `/api/users/me/traits/:traitId` | L3 | Retirer un trait | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/profile-questions` | L3 | Catalogue des questions | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/profile-answers` | L3 | Réponses propriétaires et modération | Implémenté ; contrats/tests client ; compte et appareil à valider |
| PUT | `/api/users/me/profile-answers` | L3 | Remplacer la liste ordonnée des réponses | Implémenté ; contrats/tests client ; compte et appareil à valider |
| GET | `/api/users/me/discovery-status` | L4 | Diagnostic de préparation | À faire |
| GET | `/api/feed` | L4 | Découverte paginée | À faire |
| POST | `/api/swipes` | L4 | Like/pass et résultat du match | À faire |
| GET | `/api/matches/me` | L5 | Liste des matchs | À faire |
| PATCH | `/api/matches/:id/reveal` | L6 | Accord de révélation | À faire |
| PATCH | `/api/matches/:id/continue` | L6 | Accord de continuation et coût | À faire |
| PATCH | `/api/matches/:id/end` | L5 | Terminer un match | À faire |
| GET | `/api/users/me/continuation-quota` | L6 | Crédits, réservations et plafond | À faire |
| GET | `/api/matches/:id/messages` | L5 | Historique paginé | À faire |
| POST | `/api/matches/:id/messages` | L5 | Envoi idempotent | À faire |
| PATCH | `/api/matches/:id/messages/read` | L5 | Lecture groupée | À faire |
| PATCH | `/api/matches/:id/messages/:msgId/read` | L5 | Lecture unitaire si nécessaire | À faire |
| POST | `/api/users/me/advertising-rewards` | L6 | Créer/reprendre une intention | À faire |
| GET | `/api/users/me/advertising-rewards/:id` | L6 | Suivre la validation serveur | À faire |
| DELETE | `/api/users/me/advertising-rewards/:id` | L6 | Annuler une intention | À faire |
| GET | `/api/users/me/devices` | L8 | Liste des appareils | À faire |
| POST | `/api/users/me/devices` | L8 | Enregistrer/rafraîchir le token push | À faire |
| DELETE | `/api/users/me/devices/:id` | L8 | Retirer un appareil | À faire |
| GET | `/api/users/me/events` | L5 | SSE authentifié | À faire |
| GET | `/api/plans` | L1, L6, L9 | Catalogue, tarifs et disponibilité publicitaire | Intégré API L1 : HTTP 200, deux formules décodées ; usages L6/L9 et appareils à faire |
| GET | `/api/users/me/subscription` | L9 | Abonnement et droits effectifs | À faire |
| POST | `/api/users/me/subscription/checkout` | L9 | Achat hébergé si distribution compatible | À faire |
| POST | `/api/users/me/subscription/portal` | L9 | Gestion de l'abonnement | À faire |
| GET | `/api/users/me/blocks` | L7 | Comptes bloqués | À faire |
| POST | `/api/users/me/blocks/:userId` | L7 | Bloquer un compte | À faire |
| DELETE | `/api/users/me/blocks/:userId` | L7 | Débloquer un compte | À faire |
| POST | `/api/reports` | L7 | Signaler un compte/contenu | À faire |
| POST | `/api/users/me/data-subject-requests` | L7 | Déposer une demande RGPD | À faire |
| GET | `/api/users/me/data-subject-requests` | L7 | Suivi des demandes | À faire |
| GET | `/api/users/me/data-export` | L7 | Export JSON privé | À faire |
| POST | `/api/users/me/deletion-token` | L7 | Préparer la confirmation de suppression | À faire |
| DELETE | `/api/users/me` | L7 | Accepter la suppression, fermer la session sur 202 | À faire |

Le webhook AdMob figure dans la section récompenses du contrat API, mais il est appelé par le fournisseur, jamais par Flutter. Il en va de même pour les webhooks Stripe et Sweego. Les routes de santé peuvent servir au diagnostic de développement, sans être un parcours utilisateur ou remplacer les erreurs des appels métier.

## 15. Dépendances externes et définition de terminé

| Dépendance | Validation restant à réaliser côté mobile |
| --- | --- |
| SMS/OTP | Configuration de développement, quotas et livraison réelle contrôlée |
| S3 et modération | Upload réel, formats appareils, état propriétaire, URL expirée et retrait |
| Maintenance/outbox | Transitions, effets différés et resynchronisation sans les simuler localement |
| FCM | Configuration iOS/Android et réception sur appareils réels |
| AdMob | Configuration serveur et SDK, mode de test, validation signée, disponibilité effective |
| Stripe | Environnement test, portail, retours app et droits projetés |
| Distribution | Stratégie de paiement, signatures, permissions et déclarations selon les règles applicables |

Une tranche est terminée lorsque son parcours fonctionne avec les vrais contrats, que chargement/vide/erreur/hors ligne sont traités, que les données privées sont protégées et que les vérifications pertinentes sont documentées. Pour les changements Flutter, effectuer formatage, analyse et tests ciblés disponibles ; signaler un outil ou un appareil manquant sans annoncer de réussite. Les tests ordinaires n'envoient ni SMS ni paiement ni récompense publicitaire réels.

Un blocage fournisseur ne doit pas arrêter les tâches indépendantes : garder la capacité dans la matrice, décrire ce qui est implémenté et ce qui reste à valider. Ne pas déclarer une fonction opérationnelle en production sur la seule base de fixtures.

Après chaque intervention, mettre à jour ce suivi et le résumé, expliquer le prochain petit lot et fournir un message de commit en anglais. Aucune commande Git ni suppression de fichier. Si un script `.sh` est créé ou modifié, ne pas effectuer de tests de ce script.



