# Langues des appels API

Les codes échangés sont `fr`, `en`, `es` et `it`. Les clients HTTP utilisent la langue résolue par `LocaleController` ; JSON, multipart, export et ouverture SSE portent `Accept-Language`. Les corps métier conservent leur contrat.

## Préférence du compte et de l’appareil

Le français est la langue initiale. Une préférence d’appareil enregistrée, y compris le mode système, prime. Sans choix local, `AccountLanguageBinding` lit `GET /api/users/me/language` pour adopter la préférence du compte vérifié ; cette lecture n’écrit aucune préférence.

Un choix explicite connecté s’applique à l’interface et appelle `PATCH /api/users/me/language` avec, par exemple, `{ "language": "it" }`. Un échec distant laisse l’interface utilisable, affiche l’échec et respecte `Retry-After` avant une nouvelle tentative volontaire. Restaurer l’app ou changer la langue du système ne réécrit pas silencieusement la préférence du compte.

La déconnexion retire le repli du compte, tout en conservant un choix explicite d’appareil. Une langue non prise en charge revient au français.

## Adaptation des parcours

| Parcours | Règle |
| --- | --- |
| Catalogue, profil, traits, questions, feed et matchs | Lectures localisées ; réponses d’une ancienne révision ignorées et pagination reprise au début si nécessaire. |
| Consentements | Vérifier version, URL et `document_language` du document présenté avant écriture. Conserver `accepted_document_language` comme preuve historique. |
| OTP | La langue est figée avec le téléphone et la clé d’idempotence ; un renvoi volontaire crée une nouvelle intention. |
| Checkout | La tentative conserve sa langue, sa période et sa clé lors d’une reprise, y compris après restauration. |
| Portail Stripe | La requête utilise la langue courante ; l’API choisit la locale et les URL autorisées. |
| Appareil push | L’exception de langue suit l’enregistrement ; `null` permet de suivre le compte. Un appareil déjà activé peut être réenregistré après un changement explicite. |
| Export et SSE | Langue transmise à l’ouverture ; clés d’export, protocole d’événements et contenus personnels conservés. |

Les bios, réponses et messages des personnes ne sont jamais traduits par le client. Les photos signées utilisent un transport distinct, sans Bearer. Les dialogues natifs gardent leurs propres réglages.

## Cohérence des requêtes

La révision de localisation est distincte de `resourceKey`. Changer de langue renouvelle les lectures concernées sans supprimer navigation, brouillons, crédits ou intentions d’écriture. Les données mises en cache dans une autre langue ne sont pas réutilisées.

Une reprise après un `401` d’expiration confirmé garde la langue de la requête d’origine. Un timeout ne déclenche pas de nouvelle mutation automatique. Une intention push ou Checkout déjà engagée conserve ses paramètres jusqu’à sa résolution.

Les choix de consentement non confirmés sont invalidés si le document présenté change, même à version juridique identique. Un changement de langue ne vaut pas consentement. Une lecture documentaire indisponible ne simule pas une déconnexion ; un rejet d’authentification conserve les protections de session habituelles.

Les anciens enregistrements Checkout sans champ de langue restent lisibles. L’API conserve l’autorité sur les URL et tentatives qu’elle possède déjà.

## Vérification

Après modification des ARB, suivre le [guide de traduction](../lib/core/l10n/README.md). Adapter les contrôles au parcours modifié ; pour le transport et la préférence de langue :

```bash
flutter test test/api_language_test.dart test/localization_test.dart
```

Ajouter les tests existants OTP, session, facturation ou notifications uniquement si ces parcours sont concernés. Les simulations ne nécessitent ni SMS, ni paiement, ni push réels.

Sur appareil, vérifier le choix avant connexion, le mode système, les documents juridiques, la reprise d’une tentative Checkout et la langue d’un appareil push déjà activé. Les contrôles communs sont dans le [README](../README.md) et les validations de livraison dans la [roadmap](../roadmap.md).
