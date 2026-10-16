# Histae — application mobile

Client Flutter Android et iOS de Histae, application de rencontre fondée sur la découverte sans photo dans le feed, la révélation mutuelle des photos et la décision réciproque de poursuivre une conversation.

Mise à jour : 16 octobre 2026.

## État réel du dépôt

L1 et l'implémentation de L2 sont présents : accueil, catalogue public, inscription/reconnexion par OTP, session sécurisée, restauration, déconnexion et consentements versionnés. Les entrées « Créer mon compte » et « J'ai déjà un compte » utilisent le même parcours prévu par le backend : l'OTP valide crée le compte s'il n'existe pas ou reconnecte son propriétaire. L'espace personnel attend une session authentifiée puis les consentements obligatoires retournés par le serveur. La création du profil et la vérification de majorité arrivent en L3 ; la découverte arrive en L4. Aucune découverte, notification, publicité ou vente n'est encore disponible.

Le manifeste conserve Dart `^3.13.1` et `cupertino_icons`. Aux dépendances L1 (`http`, `flutter_localizations`) s'ajoutent `flutter_secure_storage: ^11.2.0` et `url_launcher: ^6.3.2` (6.3.3 résolu). Navigation avec `Navigator` / `MaterialPageRoute`, état avec `ChangeNotifier` et dépendances injectées par constructeur. SDK vérifié : Flutter 3.47.7, Dart 3.13.5.

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
- Avant un refresh, une entrée `rotating` sans ancien token remplace l'entrée `ready`. La nouvelle entrée est écrite et relue avant publication du nouvel access token. Une réponse perdue ou un arrêt pendant cette rotation ferme la session plutôt que rejouer le prédécesseur. Les 401 concurrents attendent une seule rotation ; seuls les GET de L2 et le PUT de consentements identique peuvent être rejoués une fois. Une révocation ferme directement la session.
- La déconnexion attend une rotation déjà lancée puis tente la révocation avec la paire actuelle. Elle purge toujours la mémoire et remplace l'entrée sécurisée par un marqueur sans jeton ; une révocation distante non confirmée est annoncée. Une erreur de stockage ferme l'accès et reste visible.
- Les liens HTTPS juridiques et leurs versions viennent du serveur, sans Bearer transmis au navigateur. Aucun nouveau choix n'est précoché. Un accord existant est affiché comme tel. Les retraits sensible/localisation exigent une confirmation décrivant l'effacement ; les CGU et la notice n'ont pas de retrait. Le retour d'un document resynchronise les ressources et conserve les choix non enregistrés seulement si les versions restent identiques.

Configuration native : Android API 24 minimum (minimum réel du package installé), sauvegarde automatique désactivée et préférences exclues des transferts. iOS : Keychain limité à cet appareil et accessible une fois déverrouillé, entitlements configurés pour Debug/Release/Profile. La vérification de relecture du stockage ne remplace pas un essai sur appareil.

Vérifications automatiques : **85 tests réussis**, dont session concurrente, panne de stockage, réponse perdue, idempotence OTP, inscription avant accès privé, versions juridiques, retraits et grand texte. Analyse, formatage et compilation Android debug exécutés. Les tests n'envoient aucun SMS. **Non validés** : réception SMS, parcours authentifié avec compte réel, redémarrage/Keychain/Keystore sur appareil, ouverture des documents réels après OTP et compilation iOS sur Mac. Les routes L2 sont branchées sur l'API fournie ; les simulations sont exclusivement dans les tests et aperçus.

Références de dépendances : [stockage sécurisé](https://pub.dev/packages/flutter_secure_storage) et [ouverture des documents](https://pub.dev/packages/url_launcher).

### Limite contractuelle des versions juridiques — proposition backend séparée

L'app relit les versions juste avant le PUT et refuse un accord si elles diffèrent de celles présentées. Le contrat actuel n'accepte pourtant aucun champ de version client : une modification serveur entre ce GET et le PUT ne peut pas être détectée atomiquement par Flutter. Une évolution séparée de l'API pourrait accepter la version attendue par choix, la vérifier dans l'opération serveur et renvoyer un conflit si elle a changé. Aucun changement backend ni contournement client n'a été effectué.

## Direction artistique

La composition de [la référence fournie](pictures/exemple_feed.png) guide toute l'app : cartes généreuses, titres à empattements, séparateurs fins, icônes sobres et espacements aérés. À la demande de l'utilisateur, **aucune palette rose/corail** : ivoire `#FAF8F3`, papier `#FFFDF8`, vert forêt `#345647`, encre `#252C28`, sable `#E4DAC9`. Le mode sombre conserve cette identité. Les titres utilisent DM Serif Display embarquée, sans téléchargement de police au lancement ; les contrôles gardent la typographie système et les grandes polices restent autorisées.

Les aperçus sont générés depuis les vrais widgets avec des données explicitement simulées, dans `build/previews/{welcome,registration,consents}.png`. Pour les régénérer, définir `FLUTTER_ROOT` vers le SDK puis lancer `flutter test tool/preview_app_test.dart --update-goldens`. Ils ont été inspectés visuellement ; ils ne constituent pas des captures d'appareil. Le feed sera réalisé en L4, sans photo, avec swipe vers le haut pour passer et double appui pour liker, sans retour vers le bas.

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

La police tierce DM Serif Display conserve sa [licence SIL OFL](assets/fonts/dm_serif_display/OFL.txt), embarquée et enregistrée dans le registre des licences Flutter. Elle ne change pas la licence propriétaire du code. Source : [dépôt officiel Google Fonts](https://github.com/google/fonts/tree/main/ofl/dmserifdisplay).


