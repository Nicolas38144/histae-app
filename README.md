# Histae — application mobile

Histae est une application de rencontre qui donne de la place aux mots : profils sans photo dans le feed, conversations et révélation mutuelle des photos.

Le client Flutter cible Android et iOS, propose le français, l’anglais, l’espagnol et l’italien, et utilise le mode nuit par défaut. Son identité visuelle est commune au site Histae, avec le livre ouvert comme logo.

## Démarrage

Installer Flutter avec une version de Dart compatible avec `^3.13.1` et les outils de la plateforme ciblée. Le projet cible Android API 24 minimum et iOS 15 minimum ; le développement iOS nécessite macOS et Xcode.

Créer un fichier `.env` à la racine, ou compléter celui déjà présent :

```dotenv
APP_ENV=production
API_BASE_URL=https://api.histae.com
```

`API_BASE_URL` contient uniquement l’origine, **sans `/api`**. Les repositories ajoutent les chemins `/api/...` ; les appels aboutissent ainsi à `https://api.histae.com/api/`.

```bash
flutter pub get
flutter run
```

Pour une API locale depuis l’émulateur Android standard, utiliser `APP_ENV=development` et `API_BASE_URL=http://10.0.2.2:8080`. Sur téléphone, utiliser l’adresse LAN accessible de l’ordinateur. HTTP est autorisé uniquement en développement et en debug ; les autres configurations exigent HTTPS.

Le `.env` est ignoré par le suivi des fichiers, mais **embarqué dans l’application** : il doit contenir uniquement de la configuration publique. Les secrets Stripe, clés privées et comptes de service Firebase restent côté API. Fournir ce fichier en CI avant la compilation et relancer l’app après modification. Aucun `.env.example` n’est maintenu.

## Services externes

Les vidéos, notifications et paiements dépendent de leur configuration mobile, de l’API et des fournisseurs. Leur disponibilité ne se déduit pas de la seule présence des écrans.

<details>
<summary>Champs optionnels du .env</summary>

Ces valeurs permettent de préparer les services en les gardant désactivés.

```dotenv
# Vidéos récompensées AdMob
ADMOB_ANDROID_APP_ID=
ADMOB_IOS_APP_ID=
ADMOB_ANDROID_REWARDED_AD_UNIT=
ADMOB_IOS_REWARDED_AD_UNIT=

# Notifications Firebase
PUSH_ENABLED=false
FIREBASE_PROJECT_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_ANDROID_API_KEY=
FIREBASE_ANDROID_APP_ID=
FIREBASE_IOS_API_KEY=
FIREBASE_IOS_APP_ID=
FIREBASE_IOS_BUNDLE_ID=

# Achats natifs Google Play / App Store
BILLING_ENABLED=false
```

</details>

**AdMob** utilise des IDs d’application avec `~` et des IDs de blocs récompensés avec `/`. Le visionnage est volontaire, après vérification UMP ; le crédit est accordé après validation serveur. Les IDs d’application sont également injectés dans la configuration native Android/iOS.

**Firebase** nécessite les paramètres publics du projet et de l’application native concernée, puis `PUSH_ENABLED=true`. La gestion des appareils enregistrés reste accessible quand les push sont désactivés. L’envoi des notifications se configure séparément côté API et worker.

**Achats natifs** : Android utilise Google Play Billing, iOS utilise StoreKit. Les prix affichés viennent du SDK du store ; les droits Premium appartiennent au compte Histae et sont confirmés par l’API avant finalisation. L’app propose la restauration et ouvre le store d’origine pour la gestion. Aucun essai ni offre d’introduction n’est proposé. Activer `BILLING_ENABLED=true` après configuration des produits et validation sur appareils Sandbox / Play test.

**Stripe** est réservé au site Histae, après connexion par UUID + téléphone + OTP. Un abonnement Stripe existant est indiqué comme géré sur le site, sans bouton de paiement externe dans l’app. Les anciennes variables de distribution et de retour Stripe du `.env` mobile ne sont plus utilisées. Voir le [guide de facturation](../histae-api-rust/docs/store-billing.md) pour les produits, credentials serveur, notifications et étapes d’activation.

## Fonctionnement

Après connexion par code SMS et validation des documents nécessaires à l’accès au compte, trois onglets donnent accès au **Feed**, aux **Matchs** et au **Profil**. Le profil rassemble les informations personnelles, les réponses, l’aperçu dans le feed, le mode pause, l’UUID copiable et les réglages du compte. Les crédits et les vidéos sont accessibles depuis Matchs ; l’accès Premium ou Mon abonnement se trouve dans le profil.

Les trois onglets chargent leurs données au démarrage et conservent leur état pendant la session. Changer d’onglet ou revenir dans l’app réutilise les données ; les gestes et boutons d’actualisation lancent une nouvelle lecture. Les écrans secondaires chargent leurs données à la première ouverture. Les messages restent reçus en direct, et les actions ou événements serveur peuvent déclencher les vérifications nécessaires.

L’API reste l’autorité pour les consentements, matchs, quotas, récompenses et abonnements. Le mode pause est un réglage serveur : sa disponibilité dépend du déploiement de `GET/PATCH /api/users/me/discovery-settings`.

## Identifiant du compte

Dans **Mon compte**, le profil affiche l’UUID du compte authentifié avec sélection du texte et bouton de copie. Le même composant est utilisé dans l’abonnement ; il n’est pas ajouté à l’aperçu public. Les confirmations et erreurs de copie sont traduites dans les quatre langues.

## Organisation du code

| Dossier | Rôle |
| --- | --- |
| `lib/app/` | Démarrage, injection des dépendances, navigation et périmètre de session. |
| `lib/core/` | Réseau, configuration, traductions, thème et composants communs. |
| `lib/features/` | Fonctionnalités séparées en présentation, contrôleurs et accès aux données. |
| `test/` et `tool/` | Tests ciblés et aperçus avec des données simulées. |

Les widgets déclenchent les commandes des contrôleurs et observent leur état avec `ChangeNotifier`. Les repositories possèdent le cache en mémoire et invalident les ressources concernées après une écriture. `SessionController` gère l’authentification ; `SessionRepositories` compose les données privées et leur purge. Les parcours de rencontres, notifications et abonnement partagent le transport temps réel. Voir [ARCHITECTURE.md](ARCHITECTURE.md).

`BillingController` manipule les valeurs immuables et le contrat `BillingGateway`. Seul `NativeBillingGateway` connaît les types et paramètres des SDK Apple/Google. Le dépôt HTTP valide les DTO ; les widgets observent l’état et déclenchent les intentions. Les réponses tardives après déconnexion sont ignorées ; restauration, reprise et événements serveur relisent les droits.

## Développement et vérifications

Adapter les contrôles aux fichiers modifiés. Exemple pour une correction du cache :

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test test/read_snapshots_test.dart test/cache_lifecycle_regressions_test.dart
```

Une compilation Android de développement se lance avec `flutter build apk --debug`. Les aperçus des vrais widgets sont générés par les scénarios `tool/preview_*_test.dart`, avec des données simulées, sous `build/previews/`.

Tous les textes d’interface viennent des quatre catalogues ARB de `lib/core/l10n/arb/`. Après modification, exécuter `flutter gen-l10n` ; ne pas modifier les fichiers générés à la main. Le [guide des traductions](lib/core/l10n/README.md) détaille les conventions.

Conventions pour les contributions et le travail assisté :

- Garder les données simulées dans les tests et aperçus ; ne pas journaliser de données privées ni appeler de routes administratives.
- Ajouter des tests pour les risques importants : session, données sensibles, perte de données et opérations réseau incertaines. Une retouche documentaire seule ne nécessite pas de tests Flutter.
- Ne pas exécuter de commande Git, supprimer de fichier ou recréer de fichier d’exemple `.env`. Fournir les messages de commit en anglais. Ne pas tester les scripts `.sh` créés ou modifiés.

Les tests simulés et une compilation locale ne valident pas les services réels. Les parcours SMS, permissions natives, push, vidéos récompensées et paiements restent à vérifier sur appareils avec les environnements fournisseurs appropriés. La préparation bêta est suivie dans la roadmap.

### Validation de la facturation et du profil — 22 octobre 2026

Analyse Flutter sans problème et **236 tests réussis** avec fournisseurs simulés, dont vérification avant finalisation, restauration, changement de compte, copie à 200 % dans les quatre langues, profil dégradé, logout et parcours vidéo. Aucun SMS ni paiement réel. Les builds Android/iOS et achats réels restent à valider sur les appareils prévus ; les tests ont utilisé un SDK Flutter temporaire sur le poste de développement.

## Documentation

| Document | Contenu |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | Responsabilités, état, dépendances et gestion des ressources. |
| [Système visuel](DESIGN_SYSTEM.md) | Logo, couleurs, typographies et composants. |
| [Résumé fonctionnel](resume.md) | Parcours et règles d’intégration mobile. |
| [Roadmap](roadmap.md) | État des lots, routes couvertes et validations restantes. |
| [Traductions](lib/core/l10n/README.md) | Contribution aux catalogues ARB et génération. |
| [Langues et API](docs/api-languages.md) | Préférences de langue, documents et reprises réseau. |
| [Contrat HTTP](../histae-api-rust/docs/http-contract.md) | Routes et contrats de l’API Rust de référence. |
| [Achats multicanaux](../histae-api-rust/docs/store-billing.md) | Achats natifs, paiement sur le site et activation. |
| [Développement API](../histae-api-rust/docs/development.md) | Installation et lancement du backend. |

## Licence

Copyright © 2026 Nicolas GERMANI. Code propriétaire, tous droits réservés : voir [LICENSE.md](LICENSE.md). Les polices embarquées conservent leurs licences tierces, détaillées dans le système visuel.
