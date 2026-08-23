# Histae App — résumé technique et fonctionnel

Mise à jour : 23 août 2026.

## 1. Objet

`histae-app` est le client Flutter iOS et Android destiné à tous les utilisateurs de Histae. Le backend NestJS/Fastify se trouve dans le dépôt voisin `histae-api`.

Le produit repose sur un parcours de rencontre sans photo dans le feed : deux likes réciproques créent un match de 24 heures, les participants peuvent consentir séparément à la révélation de leur photo, puis décider de continuer lorsque la première fenêtre expire. L’application intègre aussi dès le départ consentements juridiques, géolocalisation à l’usage, sûreté, droits RGPD, temps réel, notifications et abonnement Premium.

L’application n’est jamais un dashboard. Les rôles, écrans, métriques, files de modération et routes `/admin/*` restent exclusivement dans l’outil administratif existant.

## 2. État du dépôt Flutter

Le projet reste un squelette Flutter presque vierge :

- Dart `^3.13.1` et cibles iOS/Android initialisées ;
- application compteur du template dans `lib/main.dart` ;
- test widget du template ;
- seule dépendance applicative actuelle : `cupertino_icons` ;
- aucune navigation métier, couche réseau, configuration d’environnement ou persistance sécurisée ;
- aucun modèle API, écran Histae, design system, SSE, FCM ou intégration Stripe.

Le développement applicatif peut donc partir d’une architecture propre sans migration de code historique.

## 3. État réel du backend pour le mobile

Le contrat utilisateur est désormais prêt pour commencer Flutter. Les anciens écarts P0/P1 ont été fermés, à l’exception volontaire du stockage photo réel.

| Domaine | Capacités disponibles |
| --- | --- |
| Authentification | OTP français, idempotence d’envoi, access JWT court, refresh rotatif, bootstrap et logout appareil |
| Onboarding | quatre choix juridiques versionnés, URLs, versions requises et actions manquantes |
| Profil | prénom, date de naissance majeure, sexe, bio et URL photo HTTPS nullable |
| Préférences | âge, distance et personnes recherchées |
| Traits | catalogue, lecture des traits courants, ajout et retrait |
| Localisation | consentement séparé, présence ponctuelle et expiration après une heure |
| Découverte | diagnostic de préparation, feed par curseur et swipes immuables |
| Matchs | autre profil enrichi, états individuels, photo conditionnelle, dernier message et non-lus |
| Messagerie | historique paginé, idempotence, rate limit et lecture groupée |
| Temps réel | SSE multi-instance avec événements de match, message, lecture et abonnement |
| Push | appareils iOS/Android, FCM optionnel et suppression des tokens invalides |
| Sûreté | signalement, blocage, déblocage et invalidation des matchs |
| Vie privée | consentements, demandes RGPD, export, jeton de suppression dédié et effacement inter-bases/Stripe |
| Paiement | plans, projection d’abonnement, Checkout Stripe, portail client et webhooks signés |

L’API expose son OpenAPI à `/docs-json` en développement/test. Elle possède 51 contrats HTTP utilisateur et 271 tests documentés au total. Les modèles Flutter doivent être construits depuis ce contrat, pas depuis d’anciens exemples copiés dans ce dépôt.

## 4. Limites encore ouvertes

### Photo

Le profil accepte actuellement une URL HTTPS externe, sans identifiants intégrés. Il n’existe pas encore d’upload vers un stockage Histae, de transformation, d’URL signée, de modération média ou de suppression de fichier orchestrée.

Conséquences pour Flutter :

- `photo` doit rester nullable dans tous les modèles ;
- le feed ne montre jamais de photo ;
- les matchs ne montrent la photo qu’après révélation mutuelle ;
- l’interface peut utiliser un placeholder ou une fonctionnalité désactivée ;
- l’écran d’upload définitif attendra le pipeline Histae ;
- le stockage photo réel reste nécessaire avant une bêta publique.

### Exploitation des fournisseurs

Le code API Sweego, FCM et Stripe existe, mais les parcours réels dépendent de la configuration des environnements. FCM devra être validé avec un vrai token mobile. Stripe devra être testé en sandbox avec Checkout, SCA, échec de paiement, renouvellement, annulation et retours vers l’application.

### Distribution mobile

Avant d’afficher Checkout, les règles Apple App Store et Google Play applicables aux fonctionnalités numériques doivent être vérifiées pour chaque plateforme et pays. L’activation Stripe doit donc être contrôlable par feature flag distant ou configuration d’environnement.

## 5. Conventions HTTP à respecter

- La base API se termine par `/api`; les routes présentées ci-dessous lui sont relatives.
- Le développement local utilise une URL configurable ; ne jamais figer `localhost` dans le code métier.
- Les corps sont JSON et les champs supplémentaires sont refusés.
- La limite d’un corps JSON est de 1 Mio.
- Les erreurs suivent `{ "error": { "code", "message" } }`.
- Le comportement mobile dépend de `code`; `message` sert uniquement de repli d’affichage/diagnostic.
- Chaque requête logique reçoit un `X-Request-ID` UUID, conservé pendant un retry.
- Les listes renvoient `next_cursor`; le curseur est opaque et ne doit jamais être décodé.
- `limit` vaut 1 à 100 ; la pagination par offset est dépréciée.
- Un `429` peut inclure `Retry-After` et doit suspendre l’action concernée.
- Un `503` indique une indisponibilité temporaire, pas une erreur de formulaire.
- Le client ne doit jamais envoyer de champ non décrit par l’OpenAPI.

## 6. Session et authentification

### Parcours

1. `POST /auth/otp/send` avec téléphone `+33` et `Idempotency-Key` UUID v4.
2. `POST /auth/otp/verify` avec le code à six chiffres.
3. Conservation du refresh token dans le stockage sécurisé ; access token en mémoire.
4. Au redémarrage, rotation par `POST /auth/refresh`.
5. Bootstrap par `GET /auth/me` pour obtenir `user_id` et `onboarding_complete`.
6. Logout par `POST /auth/logout`, avec le `device_id` éventuel, puis purge locale.

Une même action d’envoi OTP réutilise sa clé lors d’un retry technique. Une action utilisateur explicite « renvoyer » crée une nouvelle clé.

Le client HTTP doit sérialiser le refresh : si plusieurs requêtes reçoivent `401`, une seule rotation est exécutée, les autres attendent, puis chaque requête est rejouée au maximum une fois. Un refresh définitivement refusé purge la session et retourne à l’authentification.

Le JWT n’est pas une source d’autorisation côté mobile. L’application ne déduit aucun rôle et n’essaie jamais d’accéder à l’administration.

## 7. Onboarding, profil et découverte

### Consentements

Les quatre choix serveur sont :

1. `terms_of_service_acceptance` ;
2. `privacy_notice_acknowledgement` ;
3. `sensitive_data_consent` ;
4. `location_consent`.

Les deux premiers sont requis dans leur version courante pour les routes utilisateur normales. Les deux autres sont demandés juste avant le traitement concerné. Aucun choix n’est précoché.

Après chaque création/restauration de session, le mobile appelle `GET /users/me/consents`. `required_actions` est la source de vérité. Un retrait du consentement sensible supprime sexe et préférences ; un retrait du consentement de localisation supprime la présence. L’interface doit annoncer ces conséquences et invalider ses caches.

### Profil et découverte prête

Le profil impose une date calendrier stricte et un âge minimal de 18 ans. Les préférences sont validées côté serveur. L’autorisation native de localisation ne remplace pas le consentement métier.

`GET /users/me/discovery-status` indique précisément les étapes manquantes :

- `profile` ;
- `sex` ;
- `preferences` ;
- `sensitive_data_consent` ;
- `location_consent` ;
- `fresh_presence`.

Le mobile doit utiliser ce diagnostic plutôt que reconstruire les règles. La présence expire après une heure ; elle peut être rafraîchie à l’entrée du feed ou au retour au premier plan, sans suivi en arrière-plan.

### Feed et swipes

Le feed expose identité publique, âge, sexe, bio, distance arrondie et traits, sans photo. Les décisions `like` et `pass` sont immuables pendant leur rétention. Le client ne propose ni annulation ni file hors ligne pouvant envoyer une décision opposée. Un retry ne peut rejouer que la même décision logique.

## 8. Matchs, messages et temps réel

### Machine d’état

```text
active (24 h)
    │ échéance serveur
    ▼
awaiting_continuation (24 h)
    ├── deux accords ──► confirmed
    └── échéance ──────► expired

blocage ou suppression ──► ended
```

Le serveur reste l’unique source de vérité. Le mobile peut afficher un compte à rebours à partir de `expires_at`, mais recharge la ressource à l’échéance.

`GET /matches/me` fournit désormais l’autre utilisateur, `my_revealed`, `photos_revealed`, `my_continued`, `unread_count` et `last_message`. La photo reste `null` jusqu’à la révélation mutuelle.

### Messagerie

Les messages sont paginés du plus récent au plus ancien. L’interface les présente chronologiquement et charge les pages anciennes avec le curseur renvoyé.

Chaque message logique reçoit une `Idempotency-Key` UUID v4 conservée jusqu’au résultat définitif. Un retry strictement identique retourne le même message ; la clé ne doit jamais être recyclée pour un autre contenu ou match.

La lecture groupée utilise `PATCH /matches/:id/messages/read` avec `read_through_message_id`. La route unitaire peut rester un repli de compatibilité, mais ne doit pas provoquer une requête par message lors de l’ouverture d’une conversation.

### SSE

`GET /users/me/events` envoie :

- `connected` et un heartbeat ;
- `match.created` ;
- `match.updated` ;
- `matches.invalidated` ;
- `message.created` ;
- `message.read` ;
- `subscription.updated`.

Le flux SSE sert de signal de resynchronisation. Après un événement, l’application recharge la ressource HTTP correspondante. Elle doit reconnecter avec backoff après perte réseau ou reprise, sans supposer qu’elle a reçu tous les événements pendant sa suspension.

## 9. Appareils et notifications

Après autorisation utilisateur et obtention d’un token FCM, l’application l’enregistre avec plateforme et version. L’API ne réexpose jamais ce token ; elle renvoie un `device_id` public à conserver pour logout ou révocation.

Les notifications ne contiennent pas le texte privé des messages. Leur ouverture navigue vers la ressource concernée puis déclenche une lecture API. Une notification n’est jamais une preuve suffisante d’un match, d’un message, d’un paiement ou d’un abonnement actif.

Cas à traiter : rotation FCM, réinstallation, token `UNREGISTERED`, permission refusée, premier plan, arrière-plan et application tuée.

## 10. Abonnement Stripe

### Principe de sécurité

Le mobile n’envoie jamais Product ID, Price ID, Customer ID, montant, devise ou durée d’essai. Il choisit seulement `monthly` ou `annual`. Le serveur choisit les objets Stripe et seul un webhook signé met à jour les droits.

Le mobile :

1. charge `GET /plans` ;
2. charge `GET /users/me/subscription` ;
3. crée Checkout avec une clé d’idempotence ;
4. ouvre l’URL hébergée dans le navigateur système ;
5. au retour, recharge l’abonnement ;
6. utilise le portail client pour moyen de paiement, changement de tarif et annulation.

`access_granted` est la seule information à utiliser pour débloquer Premium. Une URL de succès Checkout ou un écran revenu au premier plan ne prouve pas le paiement. Le client attend la projection serveur, éventuellement signalée par `subscription.updated`.

Aucune clé Stripe secrète et aucune logique de vérification de paiement ne résident dans Flutter. Un SDK de collecte de carte n’est pas requis pour le Checkout hébergé actuel.

## 11. Sûreté et vie privée

- Un blocage clôt les matchs de la paire ; l’application purge immédiatement leurs données locales après `204`.
- Les signalements utilisent un motif fermé et une description optionnelle.
- Les comptes bloqués sont listables et révocables par l’utilisateur.
- Les demandes RGPD couvrent accès, effacement, portabilité, rectification, restriction et objection.
- L’export est un JSON à écrire dans un fichier temporaire partageable puis à supprimer.
- La suppression du compte exige d’abord `POST /users/me/deletion-token`.
- Le jeton dédié, à usage unique et court, est envoyé à `DELETE /users/me`.
- L’interface ne quitte l’état « suppression en cours » qu’après le `204` effectif.
- Un `503 data_erasure_unavailable` garde une voie de retry et ne doit jamais être présenté comme un succès.

Le logout ou la suppression purge refresh token, caches de profils/matchs/messages, fichiers d’export et identifiants d’appareil locaux.

## 12. Écrans et navigation

### Démarrage

- splash/bootstrap ;
- saisie téléphone ;
- vérification OTP ;
- restauration/expiration de session.

### Onboarding

- CGU et notice de confidentialité ;
- profil majeur ;
- consentement sensible ;
- sexe, préférences, bio et traits ;
- consentement localisation et permission native ;
- diagnostic de préparation à la découverte.

### Navigation principale

Une barre à trois destinations convient au premier produit :

- **Découvrir** : feed, détails, `pass`, `like`, état vide et configuration manquante ;
- **Matchs** : liste enrichie, conversations, révélation et continuation ;
- **Profil** : profil, préférences, traits, localisation, abonnement, appareils, sûreté et vie privée.

Checkout et portail s’ouvrent hors de la WebView principale, puis reviennent via un lien contrôlé ou une reprise explicitement gérée.

## 13. Architecture Flutter proposée

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   └── router.dart
├── core/
│   ├── config/
│   ├── design_system/
│   ├── errors/
│   ├── network/
│   ├── realtime/
│   ├── security/
│   ├── storage/
│   └── widgets/
└── features/
    ├── auth/
    ├── onboarding/
    ├── profile/
    ├── discovery/
    ├── matches/
    ├── chat/
    ├── notifications/
    ├── safety/
    ├── privacy/
    └── subscription/
```

Dans chaque fonctionnalité :

- `presentation` contient écrans, widgets et états UI ;
- `application` contient contrôleurs/view models et cas d’usage ;
- `data` contient DTO, services HTTP et repositories ;
- `domain` n’est ajouté que si une logique locale réelle le justifie.

Les repositories dépendent d’interfaces réseau/stockage remplaçables. Les widgets ne manipulent ni Dio, ni JSON brut, ni stockage sécurisé directement.

## 14. État global du routeur

```text
bootstrapping
├── aucune session ─────────────► signed_out
├── refresh refusé ─────────────► signed_out
└── session restaurée
    ├── choix requis ───────────► legal_onboarding
    ├── profil incomplet ───────► profile_onboarding
    ├── découverte incomplète ──► discovery_setup
    └── prêt ───────────────────► authenticated
```

`403 onboarding_incomplete` force une resynchronisation des consentements. `409 discovery_not_ready` conduit au diagnostic de configuration. Un compte supprimé, banni ou un refresh refusé retourne à `signed_out` après purge.

## 15. Stockage local et confidentialité

### Persistant

- refresh token dans le stockage sécurisé ;
- préférences d’interface non sensibles ;
- identifiant d’appareil public si nécessaire ;
- configuration non secrète et feature flags.

### Mémoire ou cache effaçable

- access token ;
- profil, feed, matchs, messages et abonnement ;
- curseurs de pagination ;
- état SSE et notifications.

### À ne pas persister durablement par défaut

- OTP ;
- numéro complet ;
- coordonnées précises ;
- file de swipes ;
- export RGPD ;
- token FCM dans les logs ou diagnostics ;
- contenu privé dans les rapports de crash.

Une base locale complexe n’est pas nécessaire au premier lot. Des caches en mémoire et un stockage sécurisé minimal réduisent les risques de cohérence et de confidentialité.

## 16. Routes consommées par l’application

Toutes sont relatives à `/api`.

| Domaine | Routes |
| --- | --- |
| Auth | `GET /auth/me`, `POST /auth/otp/send`, `POST /auth/otp/verify`, `POST /auth/refresh`, `POST /auth/logout` |
| Plans/Stripe | `GET /plans`, `GET /users/me/subscription`, `POST /users/me/subscription/checkout`, `POST /users/me/subscription/portal` |
| Compte | `GET /users/me`, `PATCH /users/me/profile`, `PATCH /users/me/preferences`, `PATCH /users/me/presence` |
| Consentements | `GET/PUT /users/me/consents` |
| Traits | `GET /traits`, `GET/POST /users/me/traits`, `DELETE /users/me/traits/:traitId` |
| Découverte | `GET /users/me/discovery-status`, `GET /feed`, `POST /swipes` |
| Matchs/chat | `GET /matches/me`, `PATCH /matches/:id/reveal`, `PATCH /matches/:id/continue`, `GET/POST /matches/:id/messages`, routes de lecture, quota |
| Mobile | routes appareils sous `/users/me/devices`, `GET /users/me/events` |
| Sûreté | `POST /reports`, routes `/users/me/blocks` |
| Vie privée | routes `/users/me/data-subject-requests`, export, jeton et suppression du compte |

Le webhook `/billing/stripe/webhook`, les routes de santé et toutes les routes `/admin/*` ne sont pas appelés par l’application.

## 17. Stratégie de test Flutter

- Tests unitaires : DTO, mapping d’erreurs, repositories, contrôleurs, refresh single-flight, idempotence locale et invalidation de cache.
- Tests widget : chargement, vide, succès, erreur, accessibilité et textes longs pour chaque écran critique.
- Tests de navigation : redirections session/onboarding/découverte et deep links contrôlés.
- Tests d’intégration : OTP simulé, reprise de session, consentements, localisation, feed → match, chat, blocage, export, suppression et Stripe test.
- Tests réseau : mode avion, timeout, `401` concurrents, `429`, `503`, SSE interrompu et reprise.
- Appareils réels : au moins un iPhone et un Android d’entrée de gamme, FCM inclus.
- Contrats : fixtures générées depuis `/docs-json` et mises à jour explicitement lors d’un changement API.

Les tests automatisés ordinaires n’envoient pas de SMS réel et n’effectuent aucun paiement. Stripe utilise uniquement le mode test et ses cartes de test.

## 18. Choix techniques à confirmer

| Besoin | Proposition initiale |
| --- | --- |
| État/injection | `flutter_riverpod` |
| Navigation | `go_router` |
| HTTP | `dio` |
| JSON | `json_serializable` |
| Jetons | `flutter_secure_storage` |
| Localisation | `geolocator` |
| Notifications | `firebase_core`, `firebase_messaging` |
| Liens externes | navigateur système et gestionnaire de deep links |
| Parcours | `integration_test` |

Les versions seront choisies au moment de l’ajout. Aucun package ne doit devenir une frontière métier ni rendre les repositories difficiles à tester.

## 19. Première tranche recommandée

1. Exporter `/docs-json` et produire les premières fixtures.
2. Remplacer le compteur par `app`, `bootstrap` et `router`.
3. Ajouter configuration d’environnement, client HTTP et erreurs typées.
4. Implémenter stockage sécurisé et refresh single-flight.
5. Livrer verticalement téléphone → OTP → consentements → bootstrap authentifié.
6. Ajouter ensuite profil/préférences/traits/localisation avant le feed.

Cette tranche valide les décisions structurantes sans attendre photo, FCM ou Stripe.

## 20. Références

- [`histae-api/routes.md`](../histae-api/routes.md) : contrat HTTP détaillé ;
- [`histae-api/resume.md`](../histae-api/resume.md) : architecture et garanties backend ;
- [`histae-api/test.md`](../histae-api/test.md) : inventaire des tests et procédure de validation ;
- [`roadmap.md`](roadmap.md) : ordre de réalisation Flutter.

## 21. Conclusion

L’API n’est plus le facteur bloquant du démarrage Flutter. Le contrat utilisateur couvre l’ensemble du parcours, y compris temps réel, push, RGPD et Stripe. Le développement peut commencer immédiatement par le socle, la session et l’onboarding.

Les vigilances principales sont maintenant la qualité du client mobile, la gestion de cycle de vie réseau/session, les tests sur appareils réels, les règles de distribution Stripe et le futur pipeline photo. Aucune fonctionnalité d’administration ne doit être ajoutée à `histae-app`.
