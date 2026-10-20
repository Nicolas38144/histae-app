# Langues des appels API mobiles

## Comportement

Les codes transmis sont exactement `fr`, `en`, `es`, `it`. Les deux `ApiClient` de la composition
racine partagent la source `LocaleController`, restaurée avant leur construction. Les requêtes JSON,
les uploads multipart et les ouvertures SSE/export portent `Accept-Language`. Aucun paramètre
`language` n’est ajouté aux corps qui ne l’acceptent pas. Les noms d’événements et les données
personnelles restent ceux du contrat ; les messages d’erreur utilisent toujours `error.code`.

Le français reste la langue initiale anonyme. Une préférence locale enregistrée (y compris « langue
de l’appareil ») prime. Sans préférence locale, la première identité authentifiée permet de lire
`GET /api/users/me/language` et d’adopter la préférence du compte pour cette session. Cette lecture
n’écrit ni la préférence locale ni celle du compte. Une déconnexion efface seulement ce repli
éphémère ; un choix explicite de cet appareil reste conservé.

Un choix explicite connecté applique la langue localement puis appelle `PATCH /api/users/me/language`
avec `{ "language": "it" }`. Un échec distant laisse la langue locale utilisable et affiche l’échec
via l’état du sélecteur. Sélectionner à nouveau permet une nouvelle tentative volontaire. Le délai
`Retry-After` d’un échec est conservé pour ne pas marteler cette route. La restauration et un
changement des réglages système ne réécrivent pas silencieusement la préférence du compte.

Le mode appareil résout sa langue principale ; une langue non prise en charge revient au français,
comme l’interface Flutter. `didChangeLocales` invalide les lectures et l’exception push de l’appareil
quand cette résolution change. Les dialogues natifs suivent leurs propres réglages.

## Routes couvertes

| Routes | Adaptation mobile |
| --- | --- |
| `GET /api/plans` | En-tête courant, invalidation et relecture du catalogue public après changement de langue. |
| `GET /api/traits`, `GET /api/profile-questions`, `GET /api/users/me/traits` | En-tête courant ; profils et catalogues relus sans réinitialiser les formulaires. |
| `GET /api/users/me`, `GET` et `PUT /api/users/me/profile-answers` | Questions localisées ; réponses personnelles et UUID conservés. |
| `GET /api/feed`, `GET /api/matches/me` | En-tête courant, rejet des lectures d’une ancienne langue et reprise de la pagination au début. Les intentions de swipe et brouillons de chat sont conservés. |
| `GET`, `PATCH /api/users/me/language` | Lecture et écriture typées de la préférence du compte via `LanguageRepository` et `AccountLanguageBinding`. |
| `GET`, `PUT /api/users/me/consents` | URL, version, `document_language` et `accepted_document_language` décodés ; précontrôle du document réellement présenté avant une décision. |
| `POST /api/auth/otp/send` | Langue figée avec le numéro et la clé d’idempotence pour toute reprise technique. Un renvoi volontaire crée une nouvelle intention dans la langue courante. Les numéros restent français `+33`. |
| `GET`, `POST /api/users/me/devices` | Exception de langue nullable décodée et envoyée. Réenregistrement d’un appareil déjà activé après changement ; aucun nouvel accord de notification n’est fabriqué. |
| `POST /api/users/me/subscription/checkout` | Langue figée et sauvegardée avec la tentative avant le premier POST. La période et la clé ne changent pas à la reprise. |
| `POST /api/users/me/subscription/portal` | Langue courante dans l’en-tête ; l’API choisit la locale Stripe et les URL de retour autorisées. |
| `GET /api/users/me/data-export` | En-tête courant ; conservation intégrale des clés, préférences et preuves historiques de l’export. |
| `GET /api/users/me/events` | En-tête à l’ouverture ; protocole SSE et contenus personnels inchangés. |

Toutes les autres routes JSON/multipart passent aussi par le même transport, sans changement de leur
payload métier. Les photos sur URL signée conservent leur transport séparé sans Bearer.

## Cohérence et sécurité

- Une reprise après un **401 d’expiration confirmé** garde la langue de la requête d’origine.
  Aucun retry général n’est ajouté après timeout ou résultat incertain.
- Le changement de langue a sa propre révision, distincte de `resourceKey` : il ne détruit pas
  la navigation, les brouillons, les crédits, les photos autorisées ou les intentions en attente.
- Les réponses de lecture d’une ancienne langue sont ignorées. Une indisponibilité pendant la
  relecture des consentements ne ferme pas la session ; une révocation ou un rejet d’authentification
  continue à purger les données comme auparavant.
- Une nouvelle URL ou langue documentaire invalide les choix non confirmés, même si la version
  juridique est inchangée. La requête PUT utilise la langue de son précontrôle. La langue du document
  disponible peut rester française par repli ; elle est distincte de la préférence d’interface et
  de la langue historique d’acceptation. Aucun changement de langue ne vaut consentement.
- Les notifications utilisent l’exception explicite de cet appareil ; `language: null` permet à
  un enregistrement sans exception de suivre le compte. Une intention de réenregistrement conserve
  sa langue pendant une reprise et converge ensuite vers le choix courant.
- Les anciens enregistrements Checkout sans champ de langue restent lisibles ; l’API conserve
  l’autorité sur la locale et les URL de toute tentative qu’elle possède déjà.
- Les requêtes et retours tardifs restent liés à l’identité et à l’origine d’API. Aucun jeton,
  numéro, texte privé ou URL de paiement n’est ajouté aux logs ou à un nouveau stockage.

## Validation sur une machine avec Flutter

Flutter et Dart ne sont pas installés sur la machine ayant préparé ce changement. **Aucune analyse
Dart, suite Flutter ou compilation n’y a été exécutée.** Les vérifications locales portent sur
les imports relatifs, les ressources ARB, l’inventaire des routes et la revue des signatures et flux.

Les sources ARB ont été actualisées. Les fichiers `generated/` n’ont pas été modifiés à la main :
les régénérer sur la machine Flutter avec la version compatible avec `pubspec.yaml` et le lockfile.

```bash
cd histae-app
flutter pub get
flutter gen-l10n
dart format lib test
flutter analyze
flutter test test/api_language_test.dart test/localization_test.dart test/otp_test.dart test/session_test.dart test/billing_test.dart test/notifications_test.dart
flutter test
flutter build apk --debug
```

Les nouveaux tests utilisent exclusivement des comptes et transports simulés : codes exacts, en-tête
sur JSON/multipart, reprise 401, OTP figé, Checkout restauré, documents et consentements, appareils
push, lecture/écriture du compte, résultat tardif après déconnexion, catalogue concurrent et brouillons.
Aucun SMS, paiement ou push réel n’est nécessaire.

Sur appareil, vérifier aussi un choix sur l’accueil avant OTP, le mode système avec variante régionale,
le changement connecté depuis Profil, le retour d’un document juridique, une tentative Checkout
reprise après changement de langue et le réenregistrement push d’un appareil déjà autorisé.
