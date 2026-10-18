# Histae — application mobile

Client Flutter Android et iOS de Histae, application de rencontre fondée sur la découverte sans photo dans le feed, la révélation mutuelle des photos et la décision réciproque de poursuivre une conversation.

Mise à jour : 18 octobre 2026.

## État réel du dépôt

L1 à L5, le cœur de L6, L7 et la gestion des appareils L8 sont implémentés. Les flux push L8 sont préparés mais désactivés, sans projet Firebase, conformément au choix utilisateur. L7 ajoute signalement, blocages, sessions, demandes de données, export et suppression du compte. Le mode nuit reste appliqué par défaut. Les vidéos restent désactivées : dépendance Google présente, intégration native/UMP et essais fournisseur encore ouverts. Les identifiants publics Android restent dans le seul `.env` local ; champs iOS à compléter. Seul le catalogue est vérifié en réseau réel ; les parcours privés sont vérifiés avec des réponses simulées. L9 ajoute le suivi de l’abonnement et prépare Checkout/portail ; ventes désactivées en attendant Stripe test et les retours HTTPS. L10 reste à construire.

Le manifeste conserve Dart `^3.13.1` et `cupertino_icons`. Aux dépendances L1/L2 s'ajoutent en L3 `image_picker: ^1.2.4`, `flutter_image_compress: ^2.5.1`, `http_parser: ^4.1.2` et `path_provider: ^2.1.6`. Navigation avec `Navigator` / `MaterialPageRoute`, état avec `ChangeNotifier`, dépendances injectées par constructeur. SDK vérifié : Flutter 3.47.7, Dart 3.13.5.

Après connexion et validation des consentements obligatoires, l'application s'ouvre sur le feed. Une barre arrondie commune donne accès à **Feed**, **Matchs** et **Profil**. Les formulaires, conversations et réglages s'ouvrent au-dessus de ces onglets. Le profil conserve les accès aux crédits, à la vie privée, aux appareils et à l'abonnement.

La refonte visuelle du 18 octobre aligne tous les parcours sur [le site Histae](https://www.histae.com/fr/) et son dépôt `histae-site` : bleu nuit, lavande, touches abricot, titres à empattements, boutons dégradés et panneaux à bordure fine. L'accueil reprend le mot-symbole et le motif de rencontre du site. Le feed, le profil, les matchs, le chat et le catalogue ont une composition adaptée au mobile. Inter et Source Serif 4 sont embarquées avec leurs licences ; le mode nuit reste appliqué par défaut. Voir le [système visuel](DESIGN_SYSTEM.md).

## Documentation et références

| Document | Utilité |
| --- | --- |
| [Résumé technique et fonctionnel](resume.md) | Fonctionnement du produit, précautions d'intégration et architecture proposée |
| [Roadmap et matrice de couverture](roadmap.md) | Lots progressifs, routes mobiles, état d'avancement et critères de validation |
| [Architecture Flutter](ARCHITECTURE.md) | Responsabilités, injection des dépendances, contrats et règles du refactoring transversal |
| [Système visuel](DESIGN_SYSTEM.md) | Identité commune au site, couleurs, typographies, composants et adaptations mobiles |
| [Contrat HTTP Rust](../histae-api-rust/docs/http-contract.md) | Référence des routes, DTO, autorisations, erreurs et règles de rejeu |
| [Documentation API](../histae-api-rust/docs/README.md) | Architecture, développement et configuration du backend |
| [Collections Postman](../histae-api-rust/postman/README.md) | Exemples de requêtes et parcours d'intégration |
| [Préparation production de l'API](../histae-api-rust/roadmap-production.md) | Validations fournisseur et exploitation encore nécessaires |

Le mobile utilise `histae-api-rust` comme référence des contrats. Le dépôt voisin `histae-site` sert désormais de référence graphique ; il n'est pas une dépendance d'exécution de l'app. Le dashboard n'est pas nécessaire au développement mobile.

L'API actuelle est écrite en Rust avec Axum, Tokio et SQLx. PostgreSQL, Redis et un stockage S3 privé portent les données et services nécessaires. Le contrat HTTP est manuel et vérifié par les tests du backend : aucun endpoint OpenAPI/Swagger n'est exposé. Les anciens contrats de l'API NestJS ne doivent pas servir de référence.

## Démarrage

Installer un SDK Flutter compatible avec la contrainte Dart du manifeste et les outils de la plateforme ciblée. Fournir le fichier local `.env` avec l'environnement et l'origine API ci-dessous (il existe déjà dans cet espace de travail), puis :

```bash
flutter pub get
flutter run
```

L'API fournie pour les appels est **`https://api.histae.com/api/`**. La configuration publique vient exclusivement du fichier `.env`, chargé comme asset avant de créer les clients HTTP. L'adresse et l'environnement ne sont plus des valeurs de secours dans le code Dart. Fichier initial :

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
ADMOB_ANDROID_APP_ID=
ADMOB_IOS_APP_ID=
ADMOB_ANDROID_REWARDED_AD_UNIT=
ADMOB_IOS_REWARDED_AD_UNIT=
```

`API_BASE_URL` attend une **origine sans `/api`**, paramètres, fragment ni identifiants ; les repositories ajoutent les chemins `/api/...` une seule fois. Pour un environnement local explicitement choisi, modifier `.env`, puis relancer l'application :

```dotenv
APP_ENV=development
API_BASE_URL=http://10.0.2.2:8080
```

`.env` est ignoré dans le suivi des fichiers. À la demande de l'utilisateur, aucun fichier d'exemple ne doit être recréé. Il est embarqué : **configuration publique uniquement, aucun secret**. Le lecteur accepte les deux clés API obligatoires, les quatre clés AdMob facultatives et les champs Firebase décrits en L8, commentaires et valeurs entre guillemets, sans interpolation ni surcharge `--dart-define`. Les champs AdMob vides sont autorisés : IDs d'application avec `~`, unités récompensées avec `/`. Les valeurs Android reçues ont été renseignées localement ; iOS reste vide. Une clé inconnue, un doublon, une valeur invalide ou une clé API manquante ferme l'intégration sans repli ni journalisation. En CI, fournir `.env` avant compilation.

Ces champs AdMob réservent la configuration du futur SDK ; les remplir n'active aucune publicité et aucun identifiant n'est codé en dur dans Dart ou les manifestes. Le futur SDK utilisera `ad_unit` et `custom_data` de l'intention API, sans identifiant Histae personnel. L'unité Android fournie devra aussi être configurée côté API pour la vérification serveur ; aucun changement de configuration backend n'a été effectué ici. Le raccordement SDK/UMP, le raccordement natif des IDs et l'activation fournisseur restent une intervention explicite distincte. Références : [initialisation Google](https://developers.google.com/admob/flutter/quick-start), [vidéo/SSV](https://developers.google.com/admob/flutter/rewarded), [choix UMP](https://developers.google.com/admob/flutter/privacy).

`10.0.2.2` rejoint l'ordinateur depuis l'émulateur Android standard. Pour un téléphone, utiliser l'IP LAN réelle de l'ordinateur, par exemple `http://192.168.1.10:8080`, sur le même réseau ; pour le simulateur iOS, l'adresse de l'hôte Mac. `localhost` sur un téléphone désigne le téléphone. Vérifier écoute et pare-feu du serveur ; la configuration Docker de développement de l'API écoute par défaut sur `127.0.0.1` (`HISTAE_API_BIND_IP` permet de choisir l'interface).

HTTPS est obligatoire hors mode debug et pour `staging`/`production`. HTTP n'est permis qu'en `development` + debug. Android autorise le réseau dans le manifeste principal et HTTP uniquement dans celui de debug. iOS utilise `Info-Debug.plist` en Debug avec l'exception ATS de réseau local et son texte de permission ; Release/Profile conservent `Info.plist` sans cette exception. Conserver les propriétés communes des deux fichiers iOS en cohérence. Ces réglages iOS restent à compiler et essayer sur Mac/appareil. Une configuration invalide affiche un état explicite sans requête ni journalisation de sa valeur.

Le bootstrap appelle `/api/auth/me`, puis `/api/users/me/consents`. Les quatre choix sont distincts ; seuls les choix obligatoires indiqués par le serveur conditionnent l'espace personnel. Le catalogue reste public et ne donne aucun droit Premium ni possibilité d'achat. La déconnexion reste accessible pendant l'onboarding et lors d'une panne de lecture de session.

Pour préparer le backend, suivre son [guide de développement](../histae-api-rust/docs/development.md). Une URL accessible depuis l'émulateur ou le téléphone sera nécessaire : `localhost` sur un téléphone ne désigne pas l'ordinateur. Les dépendances et fournisseurs requis par le parcours doivent fonctionner dans l'environnement choisi.

## Vérifications de L1

Les tests couvrent configuration, contrats du catalogue, codes d'erreur, absence de retry automatique, `Retry-After`, timeout/annulation HTTP, réponses tardives, navigation, cycle de vie, petit écran et texte à 200 %. Les contrôles d'accessibilité de l'accueil portent sur les cibles tactiles, libellés et contraste. Les prix de `test/fixtures/plans.json` sont illustratifs, réservés aux tests.

Le contrôle réseau avec `tool/check_catalog.dart` doit être relancé après le déploiement du contrat courant (`plans` et `offers`). Les contrôles locaux utilisent des réponses simulées. Les essais Android/iOS sur appareil, la compilation iOS et les fournisseurs restent à valider ; aucun service backend n'a été lancé ou modifié depuis cet hôte.

Contrôles exécutés : formatage, analyse Flutter sans problème, **54 tests réussis**, compilation Android debug. Pour relancer les contrôles et, séparément, le GET public volontaire :

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
dart run tool/check_catalog.dart
```

Le contrôle réseau est séparé des tests ordinaires et ne remplace pas un essai de l'interface sur appareil. Les fonctionnalités connues du catalogue sont traduites par code ; prix, quotas et indicateurs restent les valeurs serveur.

Références consultées pour les choix de L1 : [HTTP Dart et annulation](https://pub.dev/packages/http), [navigation Flutter](https://docs.flutter.dev/ui/navigation), [localisation Flutter](https://docs.flutter.dev/ui/internationalization), [sécurité réseau Android](https://developer.android.com/privacy-and-security/security-config), [réseau local iOS](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking) et [confidentialité du réseau local iOS](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).

## L2 — inscription, session et consentements

- L'envoi OTP garde en mémoire une intention UUID v4 et un téléphone normalisé. Reprendre une demande conserve ses paramètres ; un renvoi explicitement demandé crée une nouvelle intention. `202` signifie demande acceptée, pas SMS reçu. Un résultat de vérification incertain impose un nouveau code, sans rejeu automatique.
- Seul le refresh est conservé dans le stockage sécurisé, avec l'origine API et l'état du cycle de rotation. L'access token, l'identité et les consentements restent en mémoire. Ni téléphone, OTP, profil ni jeton d'accès ne sont persistés.
- Avant un refresh, une entrée `rotating` sans ancien token remplace l'entrée `ready`. La nouvelle entrée est écrite et relue avant publication du nouvel access token. Une réponse perdue ou un arrêt pendant cette rotation ferme la session plutôt que rejouer le prédécesseur. Les 401 concurrents attendent une seule rotation ; en L2, les GET et le PUT de consentements identique peuvent être rejoués une fois ; L3 étend cette possibilité à ses requêtes après un 401 confirmé pour access token expiré, sans retry réseau. Une révocation ferme directement la session.
- La déconnexion attend une rotation déjà lancée puis tente la révocation avec la paire actuelle. Elle purge toujours la mémoire et remplace l'entrée sécurisée par un marqueur sans jeton ; une révocation distante non confirmée est annoncée. Une erreur de stockage ferme l'accès et reste visible.
- Les liens HTTPS juridiques et leurs versions viennent du serveur, sans Bearer transmis au navigateur. Aucun nouveau choix n'est précoché. Un accord existant est affiché comme tel. Les retraits sensible/localisation exigent une confirmation décrivant l'effacement ; les CGU et la notice n'ont pas de retrait. Le retour d'un document resynchronise les ressources et conserve les choix non enregistrés seulement si les versions restent identiques.

Configuration native : Android API 24 minimum (minimum réel du package installé), sauvegarde automatique désactivée et préférences exclues des transferts. iOS : Keychain limité à cet appareil et accessible une fois déverrouillé, entitlements configurés pour Debug/Release/Profile. La vérification de relecture du stockage ne remplace pas un essai sur appareil.

Vérifications automatiques : **85 tests réussis**, dont session concurrente, panne de stockage, réponse perdue, idempotence OTP, inscription avant accès privé, versions juridiques, retraits et grand texte. Analyse, formatage et compilation Android debug exécutés. Les tests n'envoient aucun SMS. **Non validés** : réception SMS, parcours authentifié avec compte réel, redémarrage/Keychain/Keystore sur appareil, ouverture des documents réels après OTP et compilation iOS sur Mac. Les routes L2 sont branchées sur l'API fournie ; les simulations sont exclusivement dans les tests et aperçus.

Références de dépendances : [stockage sécurisé](https://pub.dev/packages/flutter_secure_storage) et [ouverture des documents](https://pub.dev/packages/url_launcher).

### Limite contractuelle des versions juridiques — proposition backend séparée

L'app relit les versions juste avant le PUT et refuse un accord si elles diffèrent de celles présentées. Le contrat actuel n'accepte pourtant aucun champ de version client : une modification serveur entre ce GET et le PUT ne peut pas être détectée atomiquement par Flutter. Une évolution séparée de l'API pourrait accepter la version attendue par choix, la vérifier dans l'opération serveur et renvoyer un conflit si elle a changé. Aucun changement backend ni contournement client n'a été effectué.

## L3 — profil et photo personnelle

- **Interface et API** : espace personnel éditorial, création/modification d'un profil majeur, quatre préférences ensemble, traits issus du catalogue, zéro à trois réponses avec ordre modifiable et confirmation du remplacement complet. Les treize routes L3 sont reliées au client authentifié. `sex` et `bio` sont toujours envoyés explicitement, y compris `null` ; `traitId` respecte la casse du contrat. Les motifs et états de modération viennent du serveur.
- **Photo** : sélection système d'une seule image, conversion locale JPEG, orientation corrigée, EXIF retiré et sortie plafonnée à 500 000 octets. Les sources locales de plus de 30 Mo sont refusées avant lecture, et une réduction progressive est tentée. Multipart `photo`, `photo.jpg`, `image/jpeg`. Même clé UUID v4 et mêmes octets pendant une reprise explicite, au plus 24 h. Aucun nouvel envoi automatique après une réponse perdue. Remplacement choisi explicitement et retrait confirmé ; un résultat consommé impose une relecture.
- **Confidentialité et reprise** : profil, formulaires, réponses et intention photo restent en mémoire, purgés au changement de session/consentements. Les copies temporaires du sélecteur ne sont nettoyées que dans le cache privé de l'app, sans toucher aux originaux de la photothèque. Une sélection Android retrouvée après arrêt du processus doit être refaite, sans rattachement automatique à un compte. Les brouillons texte non enregistrés demandent confirmation avant abandon.
- **URL et transport** : aperçu du seul propriétaire, sans Bearer au stockage, redirections ou cache disque ; octets d'image évincés du cache mémoire à la fermeture/purge. Ressource propriétaire relue après quatre minutes et au retour au premier plan pour renouveler le lien signé de 300 s. Aucune photo partenaire ni feed anticipé. Les mutations ne se rejouent qu'après un 401 d'expiration explicite, une fois après refresh ; jamais après timeout. Une écriture incertaine impose une relecture, sauf reprise photo identique. `Retry-After` bloque les nouvelles tentatives.
- **Vérifications et limites** : tests majorité UTC/années bissextiles, nullabilité, UTF-8, préférences, `traitId`, ordre/remplacement des réponses, multipart, réponse perdue, purge et expiration du lien. Aperçus manuels profil, formulaire et questions inspectés. Aucun appel authentifié ni upload réel effectué. Sélection/compression/permissions, HEIC sur appareils Android/iOS, coupures réseau réelles et iOS sur Mac restent ouverts. Voir la livraison L3 dans la roadmap pour les contrôles exécutés.

Sources : contrat HTTP Rust, DTO/routes/services profils, catalogue et média, tests `profiles_contract.rs`, `catalog_postgres.rs`, `media_integration.rs`, `photo_codec.rs` et collections Postman. Backend consulté uniquement, aucun changement ni test exécuté. Références de packages : [sélecteur Flutter](https://pub.dev/packages/image_picker), [compression native](https://pub.dev/packages/flutter_image_compress), [répertoires temporaires](https://pub.dev/packages/path_provider), [multipart HTTP annulable](https://pub.dev/documentation/http/latest/http/AbortableMultipartRequest-class.html).

Suite livrée en L4 ci-dessous. Les validations réelles de L2/L3 restent ouvertes.

## L4 — découverte sans photo

- **Parcours** : onglet « Feed » affiché après connexion ; onglet Profil et choix de vie privée toujours accessibles. Le diagnostic serveur ouvre les étapes profil/sexe, préférences et consentements, sans déduire une éligibilité locale.
- **Localisation** : `geolocator: ^14.1.1`, accord métier courant puis explication et permission système. Une seule mesure, abonnement natif annulé après acquisition ou sortie/arrière-plan/retrait/logout. Pas de dernière position connue, de suivi de fond, de persistance ni de journalisation des coordonnées. Les positions approximatives sont acceptées ; refus, refus permanent, services désactivés, délai et mesure ancienne/invalide sont distincts. Le PATCH n'envoie que latitude/longitude. Après réponse perdue, relecture du diagnostic, aucun renvoi automatique. L'expiration `presence_expires_at` provoque une relecture, sans déclencher le GPS.
- **Feed** : composition bleu nuit/lavande alignée sur le site, prénom/âge, distance reçue, bio, traits et réponses approuvées. Aucune photo ni URL partenaire dans le modèle ou les téléchargements. Aucune ville/catégorie inventée. Curseur opaque encodé, limite conservée, déduplication, reprise sans curseur après `invalid_cursor` et arrêt à `null`. Modification des préférences ou reprise au premier plan relit les ressources.
- **Choix** : double appui pour aimer ; geste vers le haut en fin de lecture pour passer, boutons accessibles en complément. Un geste servant à lire un profil long ne le passe pas : un autre geste depuis le bas est nécessaire. Aucun retour au profil précédent par geste vers le bas. Pendant un résultat incertain, seule la même cible/décision peut être reprise explicitement. Intention en mémoire dans la session, y compris après retour au profil ; aucune file durable ni retry universel. Quotas temporels respectés via `Retry-After`.
- **Match et sûreté** : seule la réponse `201` réciproque, avec membres vérifiés, ouvre le récapitulatif. Celui-ci confirme la rencontre créée ; son accès au chat livré en L5 relit d'abord la collection autorisée. Blocage confirmé via `POST /api/users/me/blocks/:userId` (`204`), disponible même pour remplacer une intention like/pass incertaine ; aucun choix opposé n'est envoyé. Gestion complète des blocages et signalements livrée en L7.
- **Contrôles exécutés** : huit contrôles L4 ciblés réussis ; configuration existante vérifiée après retrait du fichier modèle. Vérification supplémentaire ciblée du geste de lecture longue, deux aperçus de feed inspectés, compilation Android debug réussie. Aucun essai authentifié entre deux comptes réels ni permission/GPS sur appareil. Aucun test backend exécuté et aucun changement backend.

Android déclare les permissions de position approximative/précise, sans permission de localisation en arrière-plan ni service de suivi demandé par l'app. Les deux plist iOS déclarent uniquement la localisation en cours d'utilisation. Pour une compilation iOS via Swift Package Manager, le plugin Apple résolu demande le flag de compilation natif `BYPASS_PERMISSION_LOCATION_ALWAYS=1` afin d'exclure l'appel « toujours » du binaire : sur Mac, `BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ios`. Ce flag ne va pas dans le `.env` de l'app. Configuration, compilation/signature et comportement iOS restent à valider sur Mac/appareil. Référence : [documentation officielle Geolocator](https://pub.dev/packages/geolocator) et manifeste Swift du plugin Apple résolu.

## L5 — rencontres, chat et temps réel

- **Parcours** : onglet « Matchs » de la barre principale et ouverture depuis le reçu réciproque. Liste paginée, dernier message, non-lus serveur, profil textuel du partenaire et historique paginé. Aucun appel au GET administratif `/api/matches/:userId` : une rencontre demandée est recherchée dans la collection mobile autorisée. Curseurs opaques conservés, déduplication par ID, ordre serveur et reprise sans curseur invalide.
- **Envoi** : texte normalisé avec les espaces ECMAScript, maximum 2 000 points de code Unicode. Une intention garde les mêmes mots et UUID v4 après une réponse perdue, y compris après retour à la liste ; reprise explicite seulement. Aucun nouvel envoi implicite ni stockage disque des brouillons/messages. Les accusés « Envoyé »/« Lu » viennent des réponses serveur.
- **États** : `active` et `confirmed` autorisent l'envoi ; `awaiting_continuation` garde l'historique et suspend la composition. Les dates serveur sont affichées ; l'échéance déclenche une relecture et fige l'envoi, sans fabriquer la période suivante. Une conversation confirmée n'expire pas selon son ancienne date. Clôture et blocage confirmés ; réponse perdue = relecture et reprise de la même action. Données retirées après refus définitif, invalidation, retrait de consentement ou logout ; réponses tardives ignorées.
- **Lecture** : PATCH groupé ancré sur un message reçu réellement visible dans la conversation au premier plan. Aucun marquage sur simple événement, notification, écran couvert ou app suspendue. La route unitaire reste disponible au repository sans requête par bulle.
- **SSE** : Bearer en en-tête, une connexion utile dans l'espace rencontres, arrêt en arrière-plan/à la sortie. Décodage UTF-8 fragmenté, commentaires, CR/LF, données multilignes et tailles bornées ; trames incomplètes abandonnées. Reconnexion avec délai progressif/aléatoire et `Retry-After`, timeout d'inactivité de 70 s. Les événements, reconnexions et reprises relisent les ressources autorisées ; aucun replay hors ligne supposé. Le `401` d'access token expiré utilise la rotation sérialisée existante ; une révocation ferme la session. Référence de format : [spécification SSE WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html).
- **Vérifications** : neuf tests ciblés L5 réussis, analyse sans problème, quatre aperçus simulés inspectés (dont grand texte/clavier), formatage et APK Android debug. Aucune nouvelle dépendance ni modification backend. Deux comptes réels, lecture/SSE sur réseau mobile, arrêt/reprise natifs et iOS restent à valider. L'avertissement déjà connu de compatibilité future Kotlin de `flutter_image_compress_common` subsiste.

## L6 — révélation, continuation et crédits

- **Révélation** : choix distinct confirmé via PATCH sans corps. Seul `photos_revealed` reçu dans une nouvelle lecture autorise à conserver l'URL partenaire et à ouvrir sa photo ; le premier accord n'autorise aucun téléchargement. Vue dédiée, aucun préchargement dans le feed ou la liste des rencontres. Téléchargement HTTPS sans Bearer/redirection/cache disque, borné à 5 Mo et 15 s ; lien relu après quatre minutes et à la reprise. Octets et cache image évincés à la fermeture, suspension ou perte d'accès ; réponses tardives ignorées.
- **Continuation** : quota et rencontre relus avant présentation du coût maximal personnel, `0` Premium ou `1` Free. Confirmation explicite, envoi du seul `credit_cost`, aucun calcul local de débit. Une réponse perdue conserve le coût accepté pour une reprise identique en mémoire. `continuation_plan_changed` exige une nouvelle présentation/acceptation ; changement de semaine, nouvelle lecture ou confirmation trop ancienne invalident l'offre affichée. Les choix du partenaire restent privés ; seul l'état serveur rouvre la conversation. Un crédit déjà débité n'est pas remboursé à la clôture.
- **Crédits** : écran depuis profil/rencontres/continuation, solde, allocation, réservations, stock publicitaire et plafond lus du serveur, sans addition locale comme autorité. Les changements de rencontre/SSE, la reprise et les décisions relisent les ressources ; la formule Premium ne paie jamais pour le partenaire.
- **Récompenses** : repository POST/GET/DELETE et suivi propriétaire préparés ; reprise par plateforme, attente progressive bornée/`Retry-After`, annulation confirmée, transition `expired` → `credited` admise. Un callback local ne crédite rien : seul `credited` serveur déclenche la relecture du quota. Aucun bouton ne crée/lance une vidéo dans la version livrée, conformément au choix utilisateur. SDK, UMP, configuration API AdMob, iOS et validation SSV réelle restent ouverts, même après renseignement des identifiants Android.
- **Vérifications exécutées** : huit contrôles L6 ciblés, treize contrôles existants de configuration et sept contrôles existants du chat réussis. Cinq aperçus simulés en mode nuit inspectés ; grand texte/petit écran et retour de navigation vérifiés. Analyse sans problème, formatage et APK Android debug compilé. Deux comptes réels, photos/SSE sur réseau mobile et iOS restent à valider. Aucun nouveau package, aucune commande Git, aucun test ou changement backend.

La suite L7 est livrée ci-dessous. L'activation des vidéos reste suivie séparément.

## L7 — sûreté, sessions et vie privée

- **Accès** : espace « Vie privée et sécurité » depuis le profil et depuis les consentements avant la fin de l'inscription. Consentements existants conservés. Sessions, demandes, export et suppression restent accessibles sans onboarding terminé ; blocages et signalements exigent l'accès autorisé par l'API.
- **Signalement et blocage** : accès depuis feed, reçu, conversation et profil du partenaire. Cinq motifs serveur, description facultative limitée à 2 000 octets UTF-8 avant normalisation. Après réponse perdue, seule la même intention peut être reprise tant que l'écran reste ouvert ; `409` indique un signalement déjà en attente. Aucun envoi automatique ni persistance du récit. Blocage distinct confirmé ; liste sans photo et déblocage sans restaurer d'ancien match.
- **Sessions et droits** : pagination opaque des sessions, révocation d'une session, de la session courante ou de toutes les sessions. Six types de demandes et statuts serveur, sans pagination inventée. La demande d'effacement du suivi ne ferme pas immédiatement le compte. Mutation incertaine : relecture puis reprise explicite de la même cible/type, avec `Retry-After`.
- **Export** : `share_plus ^13.3.1` ajouté. Flux authentifié sans redirection, écrit par morceaux sur disque privé sans charger tout le JSON en mémoire. Maximum local 512 Mio, longueur annoncée vérifiée ; en-têtes 2 min, inactivité 30 s, transfert 10 min. Aucun partage d'un fichier incomplet. Partage système confirmé, sans promesse de réception. Nettoyage sérialisé limité aux propres fichiers `histae-export-<uuid>.json[.part]` dans `histae_private_exports` et leur copie `share_plus`, sans suivre de lien ni effacer les autres caches. Nettoyage au démarrage/sortie/suspension/perte de session, différé au retour pendant un partage actif. Les échecs sont repris ; une copie enregistrée par la destination reste sous son contrôle. [Documentation du partage](https://pub.dev/packages/share_plus).
- **Suppression** : saisie `SUPPRIMER` et confirmation finale avant émission du jeton dédié, conservé seulement en mémoire. Avant le DELETE, un marqueur sécurisé `closing` retire le refresh réutilisable et invalide les écrans. Une seule requête terminale sans rotation/rejeu après cette barrière. `202` ferme et annonce le nettoyage en cours ; réponse perdue = résultat incertain. Un redémarrage `closing` ne réutilise pas l'ancien refresh. Même protection pour révocation courante et logout global.
- **Vérifications** : neuf contrôles L7 ciblés et dix-huit contrôles existants session/SSE réussis. Neuf aperçus simulés en mode nuit inspectés, dont grand texte/petit écran, navigation avant onboarding et retour à l'accueil après suppression acceptée. Analyse, formatage et APK Android debug vérifiés. Partage/export natifs, stockage sécurisé, suppression avec compte réel et iOS restent à valider sur appareils. Backend consulté uniquement, sans test ni modification.

La dépendance `google_mobile_ads ^9.1.0` était déjà présente au début de L7 sans raccordement natif. Son fournisseur Android de lancement automatique est exclu du manifeste fusionné pendant que les vidéos restent désactivées ; l'activation exige l'intégration des IDs/UMP selon le [guide Google](https://developers.google.com/admob/flutter/quick-start). Aucun ID AdMob réel ajouté aux documents publics.

La suite L8 est livrée ci-dessous ; l'activation Firebase reste en attente.

## L8 — appareils et notifications

- **Appareils** : écran depuis le profil et la confidentialité après onboarding, conformément aux trois routes autorisées. Liste non paginée avec plateforme, version et dates reçues, sans token affiché ni conservé dans la projection publique. Retrait confirmé, `204`/`404` relus ; après réponse perdue, même cible en attente jusqu'à vérification. Retirer un appareil push ne ferme pas sa session de connexion.
- **Choix utilisateur** : notifications maintenues désactivées faute de projet Firebase. Les champs publics ci-dessous sont ajoutés au seul `.env` local. Aucun fichier modèle recréé. Avec `PUSH_ENABLED=false`, le code Dart n'initialise pas Firebase, ne demande aucune permission et n'enregistre aucun identifiant push auprès de l'API. La gestion des appareils existants reste utilisable.

```dotenv
PUSH_ENABLED=false
FIREBASE_PROJECT_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_ANDROID_API_KEY=
FIREBASE_ANDROID_APP_ID=
FIREBASE_IOS_API_KEY=
FIREBASE_IOS_APP_ID=
FIREBASE_IOS_BUNDLE_ID=
```

- **Raccordement préparé** : `firebase_core ^5.0.0`, `firebase_messaging ^17.0.0` et `package_info_plus ^10.2.2`. Configuration explicite via `.env`, ressources Android natives générées seulement si cette plateforme est configurée et le flag activé, aucun projet de secours. Auto-initialisation Messaging et Analytics désactivées dans Android et les deux plist iOS. SDK 17 : identifiant d'installation FCM (`register`/`onRegistered`) transmis dans le champ contractuel `push_token`, sans utiliser les anciennes méthodes dépréciées. Permission après explication/confirmation, APNs obtenu avant l'enregistrement iOS, version issue de l'application installée. Un enregistrement n'est jamais une preuve de réception. [Client Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/client), [SDK Messaging](https://pub.dev/packages/firebase_messaging), [version d'application](https://pub.dev/packages/package_info_plus).
- **Session et reprises** : opérations fournisseur sérialisées, intention d'enregistrement identique conservée en mémoire après réponse perdue ; aucune relance automatique de cette mutation incertaine. Mise à jour lors d'une nouvelle identité FCM, retrait de l'ancien enregistrement après acceptation du nouveau. L'état sécurisé contient uniquement origine, propriétaire, UUID d'appareil, choix d'activation et jusqu'à 64 IDs de notifications ouvertes ; aucun identifiant FCM copié dans ce stockage Dart. Retrait distant ou réinstallation sans préférence locale = aucune réactivation implicite. L'arrêt local garde un marqueur de désactivation si le nettoyage échoue, pour le reprendre sans se réenregistrer au redémarrage. Perte de session/consentements : intentions et données en mémoire purgées, arrêt fournisseur demandé.
- **Réception et navigation** : au premier plan, bandeau générique construit par l'app, sans reprendre titre, texte, URL ou expéditeur du payload. Déduplication des présentations en mémoire (128 IDs) et des ouvertures dans l'état sécurisé (64 IDs, bornés et liés au propriétaire/origine). `getInitialMessage` et `onMessageOpenedApp` préparés ; la restauration de session attend une identité vérifiée. Avant navigation, relecture de session puis de la collection mobile autorisée et de l'historique ; aucun GET administratif ni ouverture d'un match inaccessible. Une autre notification remplace le seul parcours de notification en conservant ses brouillons. Les autres flux chat/SSE sont suspendus pendant ce parcours, puis repris. Depuis L9, les alertes de facturation ouvrent la projection d’abonnement authentifiée ; aucun état de paiement n’est déduit du payload.
- **Arrière-plan** : le système affiche les alertes génériques envoyées par l'API ; le handler Dart ne lit aucune donnée privée, ne journalise rien et ne navigue pas. La déduplication applicative ne supprime pas un doublon déjà affiché par l'OS. Aucun historique de notifications ni rattrapage de tâches push désactivées n'est inventé. [Réception Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
- **Vérifications** : dix contrôles L8 ciblés et treize contrôles existants de configuration réussis. Sept aperçus simulés inspectés, dont refus d'activation par configuration, retrait, vide, grand texte, bandeau et conversation autorisée. Analyse sans problème, formatage et APK Android debug compilé. Aucune réception FCM/APNs réelle, permission sur téléphone ou compilation iOS revendiquée. Backend consulté uniquement, sans changement ni test exécuté.

Pour une activation ultérieure, créer les applications Firebase avec les identifiants Android/iOS réellement retenus, renseigner les options publiques et vérifier les restrictions des clés client, puis configurer séparément le fournisseur FCM côté API. Aucun compte de service, clé privée FCM ou clé APNs ne doit entrer dans le `.env` embarqué. Sur Mac, activer **Push Notifications** avec l'entitlement `aps-environment` et la signature adaptés, et associer la clé APNs à Firebase. Le mode d'arrière-plan et le raccordement UIScene/APNs sont préparés ; la capacité/signature reste à finaliser, sans entitlement de production inventé. [Configuration iOS Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/client), [canaux natifs Flutter](https://docs.flutter.dev/platform-integration/platform-channels).

Suite prévue après L8 : L9, livré ci-dessous. L'activation push et les essais Android/iOS restent suivis séparément. Les avertissements de compatibilité future KGP concernent désormais `firebase_core` et `flutter_image_compress_common` ; ils n'empêchent pas la compilation actuelle.

## L9 — offres et abonnement

Le catalogue public et l'écran d'abonnement affichent trois cartes : **Free**, **Premium Mensuel**
et **Premium Annuel**. Le catalogue initial de l'API indique 0 EUR, 5 EUR/mois et 48 EUR/an. Les cartes
lisent `offers` dans `GET /api/plans` pour le nom, le prix, la devise et la périodicité ;
`plan_code` référence les fonctionnalités et quotas communs dans `plans`. Aucun tarif métier n'est
ajouté en dur. Les deux offres Premium ont les mêmes droits et ne proposent aucune période d'essai.
La facturation annuelle est présentée comme un paiement en une fois chaque année, avec son équivalent
mensuel indicatif. Chaque bouton Premium prépare uniquement sa propre périodicité Checkout.
Le contrat exige `plans` et `offers` ; une réponse sans `offers` est rejetée avec une erreur
réessayable, sans reconstruire les cartes depuis `plans`. Une liste `offers` explicitement vide
reste vide. Les continuations et les droits conservent les niveaux `free`/`premium`, sans troisième rôle.
L'activation des paiements et les essais réels restent indépendants de cet affichage.

Le catalogue et les modèles clients ne contiennent plus de champ `trial_days`. Aucun essai n'est
proposé dans les cartes ni à la création Checkout. Le statut fournisseur `trialing` reste reconnu
dans les projections d'abonnement. Déployer ensemble l'API, le dashboard et la nouvelle compilation
de l'app ; les anciennes réponses catalogue ne sont plus prises en charge.

L'écran **Mon abonnement et les formules**, depuis le profil, charge le catalogue public et la projection privée `/api/users/me/subscription`. Plan effectif, accès, essai, dates, impayé et résiliation viennent de l'API. Une notification de facturation ouvre désormais cette lecture authentifiée. Les tarifs, devise et fonctionnalités affichés viennent du catalogue ; aucun prix ou identifiant Stripe métier n'est envoyé par le client.

Choix utilisateur : **Android distribué hors Play Store avec Stripe**, paiements **désactivés** avant publication des pages de retour et validation de Stripe test sur téléphone. Le `.env` local contient :

```dotenv
BILLING_ENABLED=false
BILLING_DISTRIBUTION=android_external
BILLING_SUCCESS_URL=https://www.histae.com/billing/success?session_id={CHECKOUT_SESSION_ID}
BILLING_CANCEL_URL=https://www.histae.com/billing/cancel
BILLING_PORTAL_RETURN_URL=https://www.histae.com/billing/return
```

Ces trois valeurs sont publiques et doivent reproduire exactement `STRIPE_CHECKOUT_SUCCESS_URL`, `STRIPE_CHECKOUT_CANCEL_URL` et `STRIPE_PORTAL_RETURN_URL` du serveur. Le succès doit contenir le marqueur littéral `{CHECKOUT_SESSION_ID}`. Elles ne sont pas transmises à Checkout et ne remplacent pas la configuration serveur. Aucune clé Stripe secrète ni référence de prix ne doit entrer dans le `.env` embarqué. L'activation exige les trois liens HTTPS et la distribution choisie ; elle reste refusée sur iOS, Web et bureau. Aucun flag distant n'est supposé.

Le navigateur système reçoit uniquement l'URL hébergée validée, sans Bearer. Les hôtes Stripe standards `checkout.stripe.com` et `billing.stripe.com` sont acceptés ; les domaines personnalisés sont bloqués jusqu'à configuration explicite dans un futur lot. Les entrées HTTPS sans langue `/billing/success`, `/billing/cancel` et `/billing/return` sont implémentées dans `histae-site`. Elles choisissent la première langue prise en charge parmi les préférences du navigateur (`fr`, `en`, `es`, `it`), puis rejoignent la page localisée en conservant les paramètres. Le français sert de secours ; sans JavaScript, quatre liens permettent un choix manuel. Les URL déjà localisées conservent leur langue. Elles guident vers **Mon abonnement**, sans lire l'identifiant de session ni confirmer de paiement. Leur publication sur `histae.com`, le report des trois URL dans le `.env` API du serveur et une nouvelle compilation de l'app restent nécessaires avant activation. Les `.env` ne sont pas transférés par une mise à jour du code. La reprise se fait en revenant dans l'application : relecture au premier plan, bouton de vérification, relecture après `subscription.updated` et reconnexion SSE. Après arrêt complet, rouvrir **Mon abonnement** restaure la tentative et relit les droits. Aucun lien universel/app link ni retour automatique vers l'app n'est revendiqué. Une URL de succès, un événement ou l'ouverture du navigateur n'accordent jamais Premium ; seule la projection de l'API le confirme. [Confirmation Stripe côté serveur](https://docs.stripe.com/payments/existing-customers?platform=web&ui=stripe-hosted).

Une nouvelle souscription nécessite la confirmation de la périodicité, du prix serveur et du renouvellement. L'intention UUID v4 et `monthly`/`annual` sont écrits puis vérifiés dans le stockage sécurisé **avant** le POST. Origine et propriétaire bornent la reprise après fermeture. Aucune URL de paiement, donnée bancaire ou permission Premium n'est persistée. Réponse perdue, panne ou double appui : reprise explicite avec la même clé et la même période. Une clé consommée exige une relecture des droits avant de libérer une nouvelle tentative ; aucun retry réseau automatique. Le portail exige aussi la disponibilité serveur. Suspension et déconnexion annulent les requêtes et ignorent leurs réponses tardives ; changement de compte purge les données privées et la tentative.

La configuration retenue ne doit pas servir à une distribution Play Store ou App Store. Leurs règles et programmes régionaux nécessitent une intégration distincte avant activation : [règles Google Play, dont abonnements de rencontre](https://support.google.com/googleplay/android-developer/answer/9858738), [règles Apple 3.1](https://developer.apple.com/app-store/review/guidelines/#payments), consultées le 17 octobre 2026.

Vérifications L9 : dix contrôles ciblés de configuration, droits, stockage, idempotence, navigation, portail et notifications ; treize contrôles existants de configuration et une régression de navigation push également réussis. Analyse sans problème, 110 fichiers formatés et APK Android debug compilé. Six aperçus simulés dans `build/previews/subscription-*.png`, dont écran 320 px avec texte à 160 %. Génération manuelle : `flutter test tool/preview_billing_test.dart --update-goldens` avec `FLUTTER_ROOT` défini. Les essais Stripe test (SCA, refus, essai, renouvellement, résiliation, webhooks retardés et fermeture réelle de l'app) restent à effectuer après configuration. Aucun achat réel ou de test fournisseur n'a été lancé ; aucun fichier backend modifié. Contrat HTTP, DTO, service, tests de contrat et Postman consultés seulement.

Prochain lot : **L10**, qualité et préparation bêta. L'activation des paiements, push et vidéos reste suivie séparément.

## Refactoring transversal avant L10

Refonte achevée le 18 octobre 2026 : démarrage et dépendances explicites, neuf contrats de dépôts, session abstraite pour les autres fonctionnalités, composants de présentation séparés, listes protégées, brouillons/envois isolés et primitives asynchrones partagées. Les formulaires passent par les commandes du contrôleur ; les téléchargements de photos privées utilisent un service commun borné et annulable, sans Bearer, redirection ou cache disque. Les imports historiques restent disponibles lorsque les classes ont été extraites. Aucun fichier source supprimé, aucune nouvelle dépendance ou modification backend. Détails et règles de maintenance dans [ARCHITECTURE.md](ARCHITECTURE.md).

Vérifications : 166 tests lors du contrôle global, puis 39 contrôles ciblés profil/messages/photos comprenant le troisième et dernier nouveau test ; **167 contrôles distincts réussis**. Trois nouveaux contrôles seulement, consacrés à la sérialisation après échec, à l'annulation du compteur et au transport sécurisé des photos. Analyse stricte sans problème, formatage de 143 fichiers vérifié, APK Android debug final compilé. Quatre scénarios visuels ont généré 22 aperçus simulés ; planche d'ensemble et écrans représentatifs inspectés. Aucune validation fournisseur réelle ou compilation iOS revendiquée.

La configuration mobile invalide `BILLING_ENABLED=stripe` a été corrigée en `false`. Les autres réglages et liens de retour sont conservés. Les paiements, push et vidéos restent désactivés. Les avertissements de compatibilité future KGP des dépendances Firebase/image sont toujours présents ; ils n'empêchent pas la compilation actuelle. L10 et les validations sur appareils restent à effectuer.

## Direction artistique

La référence artistique courante est [le site Histae](https://www.histae.com/fr/) et son dépôt `histae-site`. La palette, les polices et les composants communs sont détaillés dans [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Le mode nuit reste appliqué par défaut ; une variante claire cohérente reste définie. Le visuel initial `pictures/exemple_feed.png` conserve son rôle de référence pour les gestes et la navigation, avec la nouvelle identité du site.

Les aperçus proviennent des vrais widgets avec des données simulées, sous `build/previews/`. L6 ajoute `continuation`, `continuation-cost`, `continuation-recorded`, `credits` et `credits-videos-disabled` (`.png`). Définir `FLUTTER_ROOT` puis utiliser `flutter test tool/preview_app_test.dart --plain-name 'preview L6' --update-goldens` pour ce lot. Ils ne sont pas des captures d'appareil. L5/L6 sont en mode nuit ; les anciens aperçus L1–L4 gardent leur rendu historique clair.

Les neuf aperçus L7 se trouvent également dans `build/previews/` : `privacy-hub`, `privacy-sessions`, `privacy-rights`, `privacy-accessible`, `privacy-export`, `privacy-deletion`, `privacy-deletion-accepted`, `privacy-blocks` et `report` (`.png`). Même commande de génération avec `--plain-name 'preview L7'`. Ils ne valident pas le partage natif ni une suppression réelle.

L8 ajoute `devices-overview`, `devices-list`, `devices-accessible`, `devices-remove-confirmation`, `devices-empty`, `push-foreground` et `push-conversation`. Génération manuelle avec `--plain-name 'preview L8'` ; les deux derniers utilisent un fournisseur simulé réservé aux tests, sans activer les push de l'application.

## Principes de développement

- Avancer par tranches fonctionnelles branchées sur l'API, avec des états de chargement, vide, erreur et reprise.
- Préférence utilisateur : limiter les nouveaux tests aux contrôles indispensables (session, données sensibles, risque de perte et opérations réseau incertaines). Vérifications simples pour les retouches visuelles ou sans risque ; pas de suite systématique sur tout.
- Garder le serveur comme autorité pour les consentements, matchs, quotas, récompenses et abonnements.
- Ne pas intégrer d'administration ni appeler de route `/api/admin/*`.
- Ne compiler aucun secret serveur dans l'app et ne pas journaliser de données privées.
- Utiliser les données simulées uniquement dans les tests et aperçus identifiés.
- Actualiser la roadmap et le résumé après chaque lot, en distinguant code mobile, intégration API et validation sur appareil réel.
- Ne pas exécuter de commande Git ni supprimer de fichier dans le cadre du travail confié à l'agent. Fournir un message de commit en anglais après les modifications.
- Si un script `.sh` est créé ou modifié, ne pas effectuer de tests de ce script.

Les contrôles Flutter à effectuer lors de changements applicatifs sont le formatage, l'analyse et les tests pertinents. Une modification documentaire seule ne valide aucun parcours mobile.

## Licence

Copyright © 2026 Nicolas GERMANI. Tous droits réservés.

Le code est propriétaire, consultable et auditable ; sa publication ne donne pas de droit de modification ou de réutilisation. Voir [LICENSE.md](LICENSE.md). Ne pas présenter le projet comme un logiciel open source.

Les polices tierces Inter et Source Serif 4 sont embarquées avec leurs licences SIL OFL, enregistrées dans Flutter. La police historique DM Serif Display et sa licence sont conservées. Ces licences ne changent pas la licence propriétaire du code. Sources et fichiers : [système visuel](DESIGN_SYSTEM.md).


