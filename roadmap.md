# Histae App — roadmap de développement

Mise à jour : 23 août 2026.

## 1. Objectif et périmètre

Construire l’application Flutter iOS et Android destinée aux utilisateurs de Histae. Le dashboard d’administration existe déjà et reste entièrement hors de ce dépôt : l’application ne doit appeler aucune route `/admin/*`, ne doit contenir aucun rôle opérateur et ne doit proposer aucune fonction de modération administrative.

Le backend utilisateur est désormais suffisamment stable pour commencer Flutter. Les priorités API P0 et P1 sont implémentées et couvertes par des contrats HTTP : bootstrap de session, traits courants, découverte, matchs enrichis, messages idempotents, lecture groupée, SSE, appareils/FCM, suppression sécurisée et abonnement Stripe.

Le seul manque fonctionnel important reste le véritable système de photo. L’API accepte provisoirement une URL HTTPS externe ; upload, stockage Histae, transformation, modération et URL signée restent à construire avant une bêta publique.

## 2. Périmètre du produit mobile

### MVP utilisateur

- authentification par OTP et restauration de session ;
- consentements juridiques versionnés et onboarding reprenable ;
- profil majeur, bio, préférences, traits et localisation à l’usage ;
- diagnostic de préparation à la découverte ;
- feed géolocalisé et swipes `like`/`pass` ;
- création d’un match par likes réciproques ;
- liste des matchs enrichie, révélation mutuelle et continuation ;
- conversation texte paginée, idempotente et avec lecture groupée ;
- synchronisation SSE et notifications FCM ;
- signalement, blocage et déblocage ;
- demandes RGPD, export, logout et suppression de compte ;
- consultation des plans et de l’abonnement ;
- Checkout Stripe hébergé et portail client, sous réserve des règles des stores ciblés.

### Hors périmètre initial

- toute fonctionnalité administrateur ou superadministrateur ;
- pièces jointes de chat, audio et vidéo ;
- galerie multi-photo ;
- localisation permanente en arrière-plan ;
- file durable de swipes hors ligne ;
- algorithme de recommandation local ;
- collecte de carte bancaire dans l’application ;
- clients web et desktop.

## 3. État de préparation de l’API

| Domaine | État pour Flutter | Décision mobile |
| --- | --- | --- |
| Auth/session | Prêt | refresh single-flight et refresh token en stockage sécurisé |
| Consentements | Prêt | `required_actions` reste la source de vérité |
| Profil/préférences | Prêt | traiter les `404` comme étapes d’onboarding |
| Photos | Provisoire | URL HTTPS nullable ; pipeline Histae avant bêta publique |
| Traits/localisation | Prêt | utiliser les routes utilisateur et la position ponctuelle |
| Découverte/swipes | Prêt | pagination opaque, aucune annulation locale d’un swipe |
| Matchs/chat | Prêt | idempotence, non-lus, dernier message et lecture groupée disponibles |
| Temps réel/push | Prêt côté API | SSE comme signal d’invalidation, FCM à valider sur appareils réels |
| Sûreté/RGPD | Prêt | suppression avec jeton de confirmation dédié |
| Stripe | Prêt côté API | Checkout/portail hébergés, droits issus du webhook uniquement |
| OpenAPI/tests | Prêt | `/docs-json` et 51 contrats HTTP utilisateur |

Il n’est plus nécessaire d’attendre de nouvelles routes pour commencer les écrans. Les seules décisions préalables sont maintenant des décisions Flutter/produit : architecture, design, navigation, gestion provisoire de la photo, retour depuis Stripe et activation de la monétisation selon les règles Apple/Google.

## 4. Chemin critique actualisé

```text
gel OpenAPI, UX et conventions
             │
             ▼
socle Flutter, navigation et client HTTP
             │
             ▼
authentification, session et consentements
             │
             ▼
profil, localisation et découverte
             │
             ▼
matchs, chat, SSE et notifications
             │
             ▼
sûreté, vie privée et abonnement
             │
             ▼
tests appareils, conformité et bêta
```

Le véritable pipeline photo, la configuration opérationnelle Stripe/FCM et l’infrastructure de bêta peuvent avancer en parallèle. La photo ne bloque pas le socle, l’authentification, les paramètres, le chat ou le développement des cartes avec un placeholder.

## 5. Phase 0 — figer le contrat mobile et les décisions UX

### Contrat

- Exporter `/docs-json` depuis un environnement de développement et le conserver comme référence de génération/fixtures.
- Définir une convention unique : les routes de la matrice ci-dessous sont relatives à une base se terminant par `/api`.
- Créer une fixture succès et une fixture erreur pour chaque écran critique.
- Recenser les codes d’erreur qui déclenchent une navigation plutôt qu’un simple message.
- Décider comment versionner les modèles si l’OpenAPI évolue pendant le développement.

### Produit et design

- Valider les parcours OTP, onboarding, découverte, match/chat, profil, sûreté, RGPD et abonnement.
- Définir le design system et les états chargement, vide, erreur, hors ligne et action en cours.
- Valider le vocabulaire français des consentements, motifs de signalement, statuts de match et statuts d’abonnement.
- Définir la présentation avant/après révélation mutuelle de la photo.
- Choisir le placeholder photo et le comportement tant que l’upload Histae n’existe pas.
- Décider si Checkout Stripe est activé dès le MVP ou derrière un feature flag par plateforme/pays.
- Définir les liens de retour Checkout/portail et leur comportement si l’application a été tuée.

### Critère de sortie

Chaque écran peut être implémenté avec un modèle API connu, un état d’erreur défini et aucune dépendance à une route administrative.

## 6. Phase 1 — socle Flutter

### Architecture

- Remplacer l’application compteur par un bootstrap minimal.
- Organiser `lib/` par fonctionnalité avec séparation présentation, application et données.
- Installer et configurer les choix retenus pour état/injection, navigation, HTTP, modèles JSON, stockage sécurisé et localisation.
- Prévoir dès le socle les modules `realtime`, `notifications` et `subscription`.
- Mettre en place le design system, la localisation française et les composants d’état partagés.

### Proposition technique

| Besoin | Choix de départ |
| --- | --- |
| État et injection | `flutter_riverpod` |
| Navigation | `go_router` |
| HTTP | `dio` avec intercepteurs limités |
| Modèles | `json_serializable` avec enums fermés |
| Refresh token | `flutter_secure_storage` |
| Localisation | `geolocator` |
| Push | `firebase_core` et `firebase_messaging` |
| URLs Stripe | navigateur système + gestion de liens de retour |
| Tests de parcours | `integration_test` |

Ces choix restent à confirmer au début de l’implémentation ; la roadmap ne fige pas leurs versions.

### Environnements

- Prévoir `development`, `staging` et `production` via `--dart-define`.
- Utiliser `10.0.2.2` sur émulateur Android et une adresse LAN explicite sur appareil physique.
- Autoriser HTTP en clair uniquement en développement local.
- Ne compiler aucun secret Stripe, Sweego, Firebase service account ou secret API.
- Ajouter les identifiants de bundle, signatures et permissions minimales iOS/Android.

### Client HTTP

- Ajouter un Bearer seulement lorsqu’un access token existe.
- Générer un `X-Request-ID` UUID par requête logique et le conserver pendant un retry.
- Convertir `{ "error": { "code", "message" } }` en erreurs typées.
- Implémenter timeouts, annulation et refresh single-flight.
- Rejouer une requête au plus une fois après refresh.
- Propager `Retry-After` et empêcher les boucles de retry.
- Ne jamais journaliser téléphone, jetons, coordonnées, corps de message ou export RGPD.

### Qualité

- Remplacer le test compteur par des tests de bootstrap et de navigation.
- Définir une commande locale regroupant format, analyse et tests.
- Garder `flutter analyze` sans avertissement.
- Ajouter les premières fixtures contractuelles issues de l’OpenAPI.

### Critère de sortie

L’application démarre par environnement, affiche le thème, choisit une route depuis un faux état de session et transforme correctement une réponse ou erreur API simulée.

## 7. Phase 2 — authentification et onboarding légal

### Authentification

- Saisir et normaliser un numéro français `+33`.
- Envoyer l’OTP avec une `Idempotency-Key` UUID v4 stable pendant les retries techniques.
- Vérifier le code à six chiffres et stocker uniquement le refresh token dans le stockage sécurisé.
- Garder l’access token en mémoire.
- Restaurer la session au démarrage par `POST /auth/refresh`, puis appeler `GET /auth/me`.
- Implémenter un seul refresh concurrent et purger la session après échec définitif.
- Au logout, envoyer le refresh token et le `device_id` éventuel, puis purger toutes les données locales.

### Consentements

- Charger `GET /users/me/consents` après création ou restauration de session.
- Présenter séparément CGU et notice avec leurs versions et URLs serveur.
- Ne précocher aucun choix.
- Enregistrer avec `PUT /users/me/consents` et piloter la navigation avec `required_actions`.
- Demander les consentements sensible et de localisation juste avant les usages concernés.
- Expliquer les effets destructifs d’un retrait avant confirmation.

### Tests prioritaires

- retry OTP avec même clé et renvoi explicite avec nouvelle clé ;
- OTP invalide/expiré, `429` et `503` ;
- plusieurs `401` simultanés ;
- redémarrage avec refresh valide, invalide ou révoqué ;
- reprise d’onboarding après fermeture ;
- changement de version juridique imposant un nouveau passage.

### Critère de sortie

Un utilisateur peut créer/restaurer sa session, terminer ou reprendre les consentements et se déconnecter sans laisser de jeton exploitable.

## 8. Phase 3 — profil, préférences et découverte

### Profil et traits

- Créer/modifier prénom, date de naissance, sexe, bio et photo provisoire nullable.
- Laisser le serveur décider définitivement de la majorité et des contraintes métier.
- Charger `GET /users/me/traits`, afficher le catalogue `GET /traits`, puis ajouter/retirer les sélections.
- Utiliser un placeholder tant que le stockage photo Histae n’est pas livré.

### Localisation et préparation

- Expliquer l’usage avant la permission native « lors de l’utilisation ».
- Enregistrer le consentement métier indépendamment de la permission système.
- Envoyer une position courante à `PATCH /users/me/presence`, sans suivi de fond.
- Utiliser `GET /users/me/discovery-status` pour guider précisément vers `profile`, `sex`, `preferences`, `sensitive_data_consent`, `location_consent` ou `fresh_presence`.
- Traiter `profile_not_found` et `preferences_not_found` comme des étapes, pas comme des pannes.

### Feed et swipes

- Charger `GET /feed` avec le curseur opaque du serveur.
- Afficher prénom, âge, sexe, bio, distance et traits, sans inventer de photo dans le feed.
- Précharger raisonnablement la page suivante sans dupliquer les profils.
- Envoyer un choix `like` ou `pass` et ne jamais proposer de décision opposée ensuite.
- Retenter seulement la même décision lorsque le résultat réseau est inconnu.
- Ne pas persister de file de swipes hors ligne.
- Ouvrir le match renvoyé lorsque `matched=true`.

### Critère de sortie

Deux comptes de test peuvent terminer leur configuration, se découvrir, swiper et créer un seul match cohérent.

## 9. Phase 4 — matchs, chat et temps réel

### Matchs

- Charger `GET /matches/me` par curseur et conserver l’ordre serveur.
- Afficher l’autre utilisateur, le dernier message, les non-lus, `my_revealed`, `photos_revealed` et `my_continued`.
- Représenter `active`, `awaiting_continuation`, `confirmed`, `expired` et `ended`.
- Afficher un compte à rebours depuis `expires_at`, puis resynchroniser à l’échéance.
- Enregistrer révélation et continuation sans deviner l’accord de l’autre personne.
- Charger le quota de continuation depuis l’API.

### Messagerie

- Charger les messages récents puis paginer vers l’historique avec `next_cursor`.
- Générer une `Idempotency-Key` UUID v4 par message logique et la conserver pour ses retries.
- Présenter les états local/envoi/confirmé/échec sans créer de doublon.
- Marquer les messages reçus avec la route groupée « lu jusqu’à ».
- Conserver la route de lecture unitaire seulement pour compatibilité si nécessaire.
- Interdire l’envoi local lorsque l’état serveur ne permet plus la messagerie.

### SSE

- Ouvrir `GET /users/me/events` après authentification.
- Reconnecter avec backoff après perte réseau, reprise de l’application ou rotation de session.
- Traiter `match.created`, `match.updated`, `matches.invalidated`, `message.created`, `message.read` et `subscription.updated` comme des signaux de resynchronisation.
- Toujours relire la ressource HTTP concernée ; un événement SSE n’est pas une source de vérité durable.
- Ne pas maintenir le flux inutilement lorsque l’application reste longtemps suspendue.

### Critère de sortie

Deux comptes observent les mêmes transitions, discutent sans doublon, accusent lecture et se resynchronisent après coupure ou reprise.

## 10. Phase 5 — sûreté, vie privée et paramètres

### Sûreté

- Rendre signalement et blocage accessibles depuis le profil de match et le chat.
- Utiliser uniquement les motifs fermés fournis par le contrat.
- Après blocage `204`, fermer l’écran concerné et purger immédiatement match, profil et messages locaux.
- Lister les comptes bloqués et permettre leur déblocage.

### Droits et consentements

- Afficher et modifier profil, préférences, traits, localisation et consentements facultatifs.
- Créer une demande RGPD et afficher son historique/statut.
- Transformer l’export JSON en fichier temporaire partageable puis le supprimer.
- Afficher les conséquences de la suppression du compte.
- Appeler d’abord `POST /users/me/deletion-token`, puis confirmer avec `DELETE /users/me`.
- Ne considérer la suppression réussie qu’après le `204`; proposer un retry explicite sur `503`.

### Critère de sortie

L’utilisateur contrôle ses données et sa sûreté sans dashboard, et chaque mutation invalide les caches concernés.

## 11. Phase 6 — appareils, push et notifications

- Demander l’autorisation de notification au moment pertinent, pas au premier écran sans contexte.
- Enregistrer le token FCM et la plateforme avec `POST /users/me/devices`.
- Rafraîchir l’enregistrement après rotation du token ou mise à jour importante de l’application.
- Conserver localement le `device_id` public pour logout/suppression explicite.
- Lister/révoquer les appareils si cette interface est retenue dans les paramètres.
- Ouvrir la bonne ressource après notification puis la recharger depuis l’API.
- Ne jamais afficher ou journaliser le token fournisseur.
- Tester token révoqué, appareil réinstallé, notification en premier plan/arrière-plan et application tuée.

### Critère de sortie

Un appareil réel reçoit les notifications prévues sans contenu privé et toute ouverture produit une resynchronisation fiable.

## 12. Phase 7 — plans et abonnement Stripe

### Expérience utilisateur

- Charger les offres avec `GET /plans` et l’état effectif avec `GET /users/me/subscription`.
- Utiliser uniquement `access_granted` et la projection serveur pour débloquer Premium.
- Choisir `monthly` ou `annual`; ne jamais envoyer montant, devise, Product ID, Price ID ou Customer ID.
- Créer Checkout avec une clé d’idempotence stable et ouvrir l’URL dans un navigateur sécurisé.
- Au retour, recharger l’abonnement ; ne pas déduire un paiement réussi de l’URL seule.
- Utiliser le portail client pour paiement, changement de tarif et annulation.
- Réagir à `subscription.updated` et aux notifications de paiement sans exposer de donnée financière.

### Préconditions de mise en vente

- Valider le parcours complet avec les clés et cartes de test Stripe.
- Tester SCA, paiement échoué, essai, renouvellement, annulation et retour application.
- Vérifier les règles Apple App Store et Google Play pour chaque plateforme/pays avant d’afficher un lien Checkout externe.
- Activer la monétisation par feature flag afin de pouvoir masquer Checkout sans nouvelle version urgente.
- Ne jamais intégrer de clé secrète Stripe dans Flutter ; Checkout est hébergé par Stripe et les droits viennent des webhooks API.

### Critère de sortie

L’utilisateur consulte son état, ouvre Checkout ou le portail, puis voit les droits réellement confirmés par l’API.

## 13. Phase 8 — durcissement et bêta

### Tests

- Tester repositories, modèles, mapping d’erreurs et refresh single-flight.
- Couvrir chaque écran critique en chargement, vide, succès, erreur et hors ligne.
- Automatiser OTP simulé, onboarding, découverte, match/chat, blocage, export, suppression et abonnement de test.
- Tester au minimum un iPhone réel et un appareil Android d’entrée de gamme.
- Tester grandes polices, lecteur d’écran, mode sombre si retenu et reprise après suspension.

### Sécurité et confidentialité

- Auditer logs et rapports de crash pour exclure toute donnée personnelle.
- Vérifier la purge des caches et fichiers temporaires au logout et à la suppression.
- Vérifier permissions et textes de justification iOS/Android.
- Revoir stockage des jetons, deep links, navigation externe et HTTPS.
- Faire valider les écrans juridiques/localisation par le juriste ou DPO.

### Exploitation

- Ajouter une remontée de crash compatible avec les décisions juridiques.
- Préparer icônes, splash screens, signatures et fiches stores.
- Compléter les déclarations de confidentialité Apple/Google.
- Valider l’environnement backend de bêta : SMS, Stripe, FCM, Redis, Scylla, worker de maintenance, métriques, alertes et sauvegardes.
- Réaliser les essais sur réseau lent, perte de réseau et changement Wi-Fi/mobile.

### Critère de sortie

Les parcours critiques passent sur appareils réels, aucun secret ou donnée privée ne fuit, et l’environnement de bêta possède une supervision minimale.

## 14. Matrice des routes mobiles

Toutes les routes sont relatives à la base `/api`.

| Lot | Routes consommées |
| --- | --- |
| Auth | `GET /auth/me`, `POST /auth/otp/send`, `POST /auth/otp/verify`, `POST /auth/refresh`, `POST /auth/logout` |
| Plans/abonnement | `GET /plans`, `GET /users/me/subscription`, `POST /users/me/subscription/checkout`, `POST /users/me/subscription/portal` |
| Profil | `GET /users/me`, `PATCH /users/me/profile`, `GET/PATCH /users/me/preferences`, `PATCH /users/me/presence` |
| Consentements | `GET/PUT /users/me/consents` |
| Traits | `GET /traits`, `GET /users/me/traits`, `POST /users/me/traits`, `DELETE /users/me/traits/:traitId` |
| Découverte | `GET /users/me/discovery-status`, `GET /feed`, `POST /swipes` |
| Matchs | `GET /matches/me`, `PATCH /matches/:id/reveal`, `PATCH /matches/:id/continue`, `GET /users/me/continuation-quota` |
| Chat | `GET/POST /matches/:id/messages`, `PATCH /matches/:id/messages/read`, `PATCH /matches/:id/messages/:msgId/read` |
| Appareils/temps réel | `GET/POST /users/me/devices`, `DELETE /users/me/devices/:id`, `GET /users/me/events` |
| Sûreté | `POST /reports`, `GET /users/me/blocks`, `POST/DELETE /users/me/blocks/:userId` |
| Vie privée | `GET/POST /users/me/data-subject-requests`, `GET /users/me/data-export`, `POST /users/me/deletion-token`, `DELETE /users/me` |

Le mobile n’appelle ni le webhook Stripe ni aucune route `/admin/*`.

## 15. Jalons

| Jalon | Contenu | Validation |
| --- | --- | --- |
| M0 — Contrat gelé | phase 0 | OpenAPI/fixtures et décisions UX validés |
| M1 — Alpha onboarding | phases 1 et 2 | session et consentements sur iOS/Android |
| M2 — Alpha découverte | phase 3 | deux comptes créent un match réel |
| M3 — Bêta interne | phases 4 à 6 | chat, SSE, push, sûreté et RGPD opérationnels |
| M4 — Monétisation test | phase 7 | parcours Stripe test complet et resynchronisé |
| M5 — Bêta publique | phase 8 + photos | appareils réels, juridique, exploitation et pipeline photo validés |

## 16. Définition de « terminé »

Une fonctionnalité n’est terminée que si :

- succès, chargement, vide, erreur et hors ligne sont traités ;
- les codes d’erreur API déclenchent le bon comportement ;
- l’accessibilité de base est vérifiée ;
- aucune donnée sensible n’est journalisée ;
- les caches sont invalidés après mutation ou événement ;
- tests unitaires et widget pertinents passent ;
- au moins un test couvre le parcours principal ;
- `dart format`, `flutter analyze` et `flutter test` passent ;
- aucune route ou notion d’administration n’est introduite.

## 17. Prochaines actions concrètes

1. Exporter et figer `/docs-json` pour le client mobile.
2. Valider les maquettes OTP → consentements → profil → découverte → match/chat.
3. Choisir les packages du socle et l’architecture de dossiers.
4. Décider le placeholder et le feature flag photo jusqu’au pipeline Histae.
5. Définir les deep links Stripe et valider la stratégie stores.
6. Remplacer le compteur Flutter par le bootstrap, le routeur et le client HTTP typé.

