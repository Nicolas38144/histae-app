# Histae — application mobile

Client Flutter Android et iOS de Histae, application de rencontre fondée sur la découverte sans photo dans le feed, la révélation mutuelle des photos et la décision réciproque de poursuivre une conversation.

Mise à jour : 16 octobre 2026.

## État réel du dépôt

L1 à L4 sont implémentés : accueil/catalogue public, OTP, session sécurisée, consentements, profil/préférences/photo et découverte sans photo avec localisation ponctuelle, diagnostic, pagination et choix like/pass. Un intérêt réciproque ouvre le récapitulatif du match retourné par le serveur. Le blocage est accessible dès le feed. Seul le catalogue est vérifié en réseau réel ; les parcours privés utilisent les vrais contrats et des contrôles simulés, sans validation SMS/compte/appareil. Le chat et la liste persistante des matchs arrivent en L5. Notifications, publicités et ventes restent à construire.

Le manifeste conserve Dart `^3.13.1` et `cupertino_icons`. Aux dépendances L1/L2 s'ajoutent en L3 `image_picker: ^1.2.4`, `flutter_image_compress: ^2.5.1`, `http_parser: ^4.1.2` et `path_provider: ^2.1.6`. Navigation avec `Navigator` / `MaterialPageRoute`, état avec `ChangeNotifier`, dépendances injectées par constructeur. SDK vérifié : Flutter 3.47.7, Dart 3.13.5.

## Documentation et références

| Document | Utilité |
| --- | --- |
| [Résumé technique et fonctionnel](resume.md) | Fonctionnement du produit, précautions d'intégration et architecture proposée |
| [Roadmap et matrice de couverture](roadmap.md) | Lots progressifs, routes mobiles, état d'avancement et critères de validation |
| [Contrat HTTP Rust](../histae-api-rust/docs/http-contract.md) | Référence des routes, DTO, autorisations, erreurs et règles de rejeu |
| [Documentation API](../histae-api-rust/docs/README.md) | Architecture, développement et configuration du backend |
| [Collections Postman](../histae-api-rust/postman/README.md) | Exemples de requêtes et parcours d'intégration |
| [Préparation production de l'API](../histae-api-rust/roadmap-production.md) | Validations fournisseur et exploitation encore nécessaires |

Le projet de travail mobile nécessite uniquement les dépôts voisins `histae-app` et `histae-api-rust`. Le site et le dashboard ne sont pas des dépendances de développement du mobile.

L'API actuelle est écrite en Rust avec Axum, Tokio et SQLx. PostgreSQL, Redis et un stockage S3 privé portent les données et services nécessaires. Le contrat HTTP est manuel et vérifié par les tests du backend : aucun endpoint OpenAPI/Swagger n'est exposé. Les anciens contrats de l'API NestJS ne doivent pas servir de référence.

## Démarrage

Installer un SDK Flutter compatible avec la contrainte Dart du manifeste et les outils de la plateforme ciblée. Créer le fichier local `.env` avec les deux valeurs publiques ci-dessous (il existe déjà dans cet espace de travail), puis :

```bash
flutter pub get
flutter run
```

L'API fournie pour les appels est **`https://api.histae.com/api/`**. La configuration publique vient exclusivement du fichier `.env`, chargé comme asset avant de créer les clients HTTP. L'adresse et l'environnement ne sont plus des valeurs de secours dans le code Dart. Fichier initial :

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
```

`API_BASE_URL` attend une **origine sans `/api`**, paramètres, fragment ni identifiants ; les repositories ajoutent les chemins `/api/...` une seule fois. Pour un environnement local explicitement choisi, modifier `.env`, puis relancer l'application :

```dotenv
APP_ENV=development
API_BASE_URL=http://10.0.2.2:8080
```

`.env` est ignoré dans le suivi des fichiers. À la demande de l'utilisateur, aucun fichier d'exemple ne doit être recréé. Le fichier est embarqué dans le paquet mobile : **configuration publique uniquement, aucun secret**. Il n'y a plus de surcharge par `--dart-define`. Le lecteur accepte commentaires sur des lignes séparées et valeurs entre guillemets ; aucune interpolation ni variable supplémentaire. Clé manquante, doublon ou valeur invalide ferme l'intégration sans adresse de secours ni journalisation. En CI, fournir `.env` avant compilation.

`10.0.2.2` rejoint l'ordinateur depuis l'émulateur Android standard. Pour un téléphone, utiliser l'IP LAN réelle de l'ordinateur, par exemple `http://192.168.1.10:8080`, sur le même réseau ; pour le simulateur iOS, l'adresse de l'hôte Mac. `localhost` sur un téléphone désigne le téléphone. Vérifier écoute et pare-feu du serveur ; la configuration Docker de développement de l'API écoute par défaut sur `127.0.0.1` (`HISTAE_API_BIND_IP` permet de choisir l'interface).

HTTPS est obligatoire hors mode debug et pour `staging`/`production`. HTTP n'est permis qu'en `development` + debug. Android autorise le réseau dans le manifeste principal et HTTP uniquement dans celui de debug. iOS utilise `Info-Debug.plist` en Debug avec l'exception ATS de réseau local et son texte de permission ; Release/Profile conservent `Info.plist` sans cette exception. Conserver les propriétés communes des deux fichiers iOS en cohérence. Ces réglages iOS restent à compiler et essayer sur Mac/appareil. Une configuration invalide affiche un état explicite sans requête ni journalisation de sa valeur.

Le bootstrap appelle `/api/auth/me`, puis `/api/users/me/consents`. Les quatre choix sont distincts ; seuls les choix obligatoires indiqués par le serveur conditionnent l'espace personnel. Le catalogue reste public et ne donne aucun droit Premium ni possibilité d'achat. La déconnexion reste accessible pendant l'onboarding et lors d'une panne de lecture de session.

Pour préparer le backend, suivre son [guide de développement](../histae-api-rust/docs/development.md). Une URL accessible depuis l'émulateur ou le téléphone sera nécessaire : `localhost` sur un téléphone ne désigne pas l'ordinateur. Les dépendances et fournisseurs requis par le parcours doivent fonctionner dans l'environnement choisi.

## Vérifications de L1

Les tests couvrent configuration, contrats du catalogue, codes d'erreur, absence de retry automatique, `Retry-After`, timeout/annulation HTTP, réponses tardives, navigation, cycle de vie, petit écran et texte à 200 %. Les contrôles d'accessibilité de l'accueil portent sur les cibles tactiles, libellés et contraste. Les prix de `test/fixtures/plans.json` sont illustratifs, réservés aux tests.

L'appel réel vers `https://api.histae.com/api/plans` a répondu **HTTP 200** ; le client Dart de l'application a lu et décodé les deux formules avec `tool/check_catalog.dart`. L'intégration du catalogue est vérifiée depuis cet hôte, sans mutation ni compte. Les essais Android/iOS sur appareil, la compilation iOS et les fournisseurs restent non validés. Aucun service backend n'a été lancé ou modifié.

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

- **Parcours** : « Découvrir les profils » depuis votre espace personnel ; retour au profil et aux choix de vie privée toujours disponible. Le diagnostic serveur ouvre les étapes profil/sexe, préférences et consentements, sans déduire une éligibilité locale.
- **Localisation** : `geolocator: ^14.1.1`, accord métier courant puis explication et permission système. Une seule mesure, abonnement natif annulé après acquisition ou sortie/arrière-plan/retrait/logout. Pas de dernière position connue, de suivi de fond, de persistance ni de journalisation des coordonnées. Les positions approximatives sont acceptées ; refus, refus permanent, services désactivés, délai et mesure ancienne/invalide sont distincts. Le PATCH n'envoie que latitude/longitude. Après réponse perdue, relecture du diagnostic, aucun renvoi automatique. L'expiration `presence_expires_at` provoque une relecture, sans déclencher le GPS.
- **Feed** : composition ivoire/forêt inspirée de la référence, prénom/âge, distance reçue, bio, traits et réponses approuvées. Aucune photo ni URL partenaire dans le modèle ou les téléchargements. Aucune ville/catégorie inventée. Curseur opaque encodé, limite conservée, déduplication, reprise sans curseur après `invalid_cursor` et arrêt à `null`. Modification des préférences ou reprise au premier plan relit les ressources.
- **Choix** : double appui pour aimer ; geste vers le haut en fin de lecture pour passer, boutons accessibles en complément. Un geste servant à lire un profil long ne le passe pas : un autre geste depuis le bas est nécessaire. Aucun retour au profil précédent par geste vers le bas. Pendant un résultat incertain, seule la même cible/décision peut être reprise explicitement. Intention en mémoire dans la session, y compris après retour au profil ; aucune file durable ni retry universel. Quotas temporels respectés via `Retry-After`.
- **Match et sûreté** : seule la réponse `201` réciproque, avec membres vérifiés, ouvre le récapitulatif. Celui-ci confirme la rencontre créée sans prétendre connaître des droits de chat actuels ou révéler une photo. Le chat, l'historique des matchs et la synchronisation de leurs états restent L5. Blocage confirmé via `POST /api/users/me/blocks/:userId` (`204`), disponible même pour remplacer une intention like/pass incertaine ; aucun choix opposé n'est envoyé. Gestion complète des blocages et signalements reste L7.
- **Contrôles exécutés** : huit contrôles L4 ciblés réussis ; configuration existante vérifiée après retrait du fichier modèle. Vérification supplémentaire ciblée du geste de lecture longue, deux aperçus de feed inspectés, compilation Android debug réussie. Aucun essai authentifié entre deux comptes réels ni permission/GPS sur appareil. Aucun test backend exécuté et aucun changement backend.

Android déclare les permissions de position approximative/précise, sans permission de localisation en arrière-plan ni service de suivi demandé par l'app. Les deux plist iOS déclarent uniquement la localisation en cours d'utilisation. Pour une compilation iOS via Swift Package Manager, le plugin Apple résolu demande le flag de compilation natif `BYPASS_PERMISSION_LOCATION_ALWAYS=1` afin d'exclure l'appel « toujours » du binaire : sur Mac, `BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ios`. Ce flag ne va pas dans le `.env` de l'app. Configuration, compilation/signature et comportement iOS restent à valider sur Mac/appareil. Référence : [documentation officielle Geolocator](https://pub.dev/packages/geolocator) et manifeste Swift du plugin Apple résolu.

Prochain lot : **L5**, liste des matchs, chat, lecture et synchronisation SSE, avec les états et échéances serveur.

## Direction artistique

La composition de [la référence fournie](pictures/exemple_feed.png) guide toute l'app : cartes généreuses, titres à empattements, séparateurs fins, icônes sobres et espacements aérés. À la demande de l'utilisateur, **aucune palette rose/corail** : ivoire `#FAF8F3`, papier `#FFFDF8`, vert forêt `#345647`, encre `#252C28`, sable `#E4DAC9`. Le mode sombre conserve cette identité. Les titres utilisent DM Serif Display embarquée, sans téléchargement de police au lancement ; les contrôles gardent la typographie système et les grandes polices restent autorisées.

Les aperçus sont générés depuis les vrais widgets avec des données explicitement simulées, dans `build/previews/{welcome,registration,consents,profile,profile-editor,answers,feed,feed-end}.png`. Pour les régénérer, définir `FLUTTER_ROOT` vers le SDK puis lancer `flutter test tool/preview_app_test.dart --update-goldens`. Ils ont été inspectés visuellement ; ils ne constituent pas des captures d'appareil. Le feed L4 applique cette DA sans photo : geste haut en fin de lecture pour passer et double appui pour liker, sans retour à un profil précédent.

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

La police tierce DM Serif Display conserve sa [licence SIL OFL](assets/fonts/dm_serif_display/OFL.txt), embarquée et enregistrée dans le registre des licences Flutter. Elle ne change pas la licence propriétaire du code. Source : [dépôt officiel Google Fonts](https://github.com/google/fonts/tree/main/ofl/dmserifdisplay).


