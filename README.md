# Histae — application mobile

Client Flutter Android et iOS de Histae, application de rencontre fondée sur la découverte sans photo dans le feed, la révélation mutuelle des photos et la décision réciproque de poursuivre une conversation.

Mise à jour : 15 octobre 2026.

## État réel du dépôt

Le lot L1 remplace le compteur par un accueil Histae et une consultation du catalogue public. Le socle comprend configuration, thème clair/sombre, navigation publique, textes français centralisés, client HTTP annulable et erreurs typées. Le catalogue utilise exclusivement `GET /api/plans` ; les données simulées restent dans les tests. Aucune session, persistance privée, notification, publicité ou intégration de paiement n'est encore livrée.

Le manifeste conserve Dart `^3.13.1` et `cupertino_icons`. L1 ajoute uniquement `http: ^1.6.0` et `flutter_localizations` du SDK. Navigation avec `Navigator` / `MaterialPageRoute`, état avec `ChangeNotifier` et dépendances injectées par constructeur. SDK vérifié : Flutter 3.47.7, Dart 3.13.5.

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

Installer un SDK Flutter compatible avec la contrainte Dart du manifeste et les outils de la plateforme ciblée, puis, depuis ce dépôt :

```bash
flutter pub get
flutter run
```

L'API fournie pour les appels est **`https://api.histae.com/api/`**. Par défaut, `APP_ENV=production` et `API_BASE_URL=https://api.histae.com`. Le paramètre attend une **origine sans `/api`**, sans paramètres, fragment ni identifiants ; les dépôts de données ajoutent les chemins complets `/api/...` une seule fois. Aucun secret n'est nécessaire pour le catalogue.

Pour un environnement de développement explicitement choisi, remplacer l'origine au lancement :

```bash
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` rejoint l'ordinateur depuis l'émulateur Android standard. Pour un téléphone, utiliser l'IP LAN réelle de l'ordinateur, par exemple `http://192.168.1.10:8080`, sur le même réseau ; pour le simulateur iOS, l'adresse de l'hôte Mac. `localhost` sur un téléphone désigne le téléphone. Vérifier écoute et pare-feu du serveur ; la configuration Docker de développement de l'API écoute par défaut sur `127.0.0.1` (`HISTAE_API_BIND_IP` permet de choisir l'interface).

HTTPS est obligatoire hors mode debug et pour `staging`/`production`. HTTP n'est permis qu'en `development` + debug. Android autorise le réseau dans le manifeste principal et HTTP uniquement dans celui de debug. iOS utilise `Info-Debug.plist` en Debug avec l'exception ATS de réseau local et son texte de permission ; Release/Profile conservent `Info.plist` sans cette exception. Conserver les propriétés communes des deux fichiers iOS en cohérence. Ces réglages iOS restent à compiler et essayer sur Mac/appareil. Une configuration invalide affiche un état explicite sans requête ni journalisation de sa valeur.

Le bootstrap authentifié et la navigation fondée sur session/consentements arrivent en L2. Le catalogue reste public et ne donne aucun droit Premium ni possibilité d'achat.

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

## Principes de développement

- Avancer par tranches fonctionnelles branchées sur l'API, avec des états de chargement, vide, erreur et reprise.
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

