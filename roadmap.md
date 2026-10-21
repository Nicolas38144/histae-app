# Roadmap mobile

Ce suivi distingue le **code implémenté**, la **disponibilité de l’API** et la **validation sur appareil**. Une fonctionnalité présente dans le client n’est pas, à elle seule, une preuve de fonctionnement en production.

Le [résumé fonctionnel](resume.md) décrit les parcours. Le [contrat HTTP Rust](../histae-api-rust/docs/http-contract.md) reste la référence des routes et DTO ; l’administration, les webhooks et l’exploitation du backend sont hors périmètre mobile.

## Lots et état

| Lot | Périmètre | État du client |
| --- | --- | --- |
| L0 | Contrat et préparation | Références établies ; vérifier les DTO concernés avant chaque évolution. |
| L1 | Configuration, réseau, navigation et thème | Implémenté. |
| L2 | OTP, session et documents/consentements | Implémenté. |
| L3 | Profil, préférences, réponses et photo | Implémenté. |
| L4 | Localisation ponctuelle, feed et choix | Implémenté, avec aperçu du profil et mode pause. |
| L5 | Matchs, chat, lecture et temps réel | Implémenté. |
| L6 | Révélation, continuation, crédits et vidéos | Implémenté, y compris SDK AdMob, UMP et suivi serveur. |
| L7 | Signalements, blocages, sessions, droits et suppression | Implémenté. |
| L8 | Appareils et notifications Firebase | Raccordement client implémenté ; réception native à valider. |
| L9 | Catalogue, abonnement, Checkout et portail | Implémenté pour Stripe sur Android externe ; facturation stores à intégrer. |
| L10 | Qualité, intégrations réelles et préparation bêta | À finaliser selon les critères ci-dessous. |

Les quatre langues, la direction artistique commune au site, le livre comme logo, l’ouverture animée et le cache de session sont intégrés. La configuration et les commandes sont centralisées dans le [README](README.md).

## Priorités de L10

1. Préparer les versions Play Store/App Store : intégration de facturation adaptée, identifiants, signatures et paramètres de distribution.
2. Valider les parcours activés avec comptes et appareils Android/iOS : OTP, photo, localisation, deux comptes en conversation et permissions natives.
3. Éprouver les interruptions : rotation de session, réseau lent ou mobile, réponse perdue, arrêt du processus, changement de compte et reprise des intentions.
4. Vérifier les fournisseurs dans leurs environnements dédiés : Firebase/APNs, AdMob/UMP/SSV, Stripe et ses webhooks.
5. Revoir accessibilité et rendu : longues bios, quatre langues, texte à 200 %, clavier, petits écrans, barres système et icônes natives.
6. Préparer les déclarations de confidentialité, les documents et la diffusion bêta avec les responsables concernés.

## Dépendances à vérifier

| Domaine | Validation attendue |
| --- | --- |
| API | Contrat déployé, migrations du mode pause, stockage privé, modération, outbox et maintenance disponibles. |
| Consentements | Documents présentés cohérents ; contrôle atomique des versions à étudier côté API au-delà du précontrôle mobile. |
| SMS | Livraison, quotas et réponses incertaines vérifiés avec un numéro de test autorisé. |
| Push | Options publiques, fournisseur API, permission, APNs/signature iOS, réception et ouverture à froid. |
| Vidéos | Message UMP publié, appareil de test, diffusion, intention et crédit confirmé par le webhook signé. |
| Paiements | Configuration de distribution, environnement test, retour navigateur, portail et projection des droits après webhook. |
| iOS | Compilation sur Mac, Keychain, permissions, partage, icône et démarrage natifs. |

Les flags locaux et consoles fournisseur peuvent évoluer sans modification du code. Ce document ne les présente donc pas comme une preuve d’activation ou de déploiement.

## Couverture des routes

Les routes suivantes sont raccordées au client. Les comportements et erreurs détaillés restent dans le contrat API ; leur validation réelle relève de L10. La lecture unitaire d’un message est disponible au repository, tandis que l’interface utilise la lecture groupée.

<details>
<summary>Inventaire mobile : 60 couples méthode / route</summary>

| Méthode | Route | Lot | Usage |
| --- | --- | --- | --- |
| POST | `/api/auth/otp/send` | L2 | Demander/renvoyer OTP |
| POST | `/api/auth/otp/verify` | L2 | Inscription/reconnexion par OTP |
| POST | `/api/auth/refresh` | L2 | Rotation de session sérialisée |
| GET | `/api/auth/me` | L2 | Bootstrap authentifié |
| POST | `/api/auth/logout` | L2 | Déconnexion courante |
| GET | `/api/auth/sessions` | L7 | Liste des sessions |
| DELETE | `/api/auth/sessions/:id` | L7 | Révoquer une session |
| POST | `/api/auth/logout-all` | L7 | Déconnexion globale |
| GET | `/api/users/me/consents` | L2 | État et documents requis |
| PUT | `/api/users/me/consents` | L2, L7 | Accepter et gérer les choix autorisés |
| GET | `/api/users/me` | L3 | Profil propriétaire |
| PATCH | `/api/users/me/profile` | L3 | Créer/modifier le profil |
| GET | `/api/users/me/preferences` | L3 | Préférences courantes |
| PATCH | `/api/users/me/preferences` | L3 | Modifier les préférences |
| PATCH | `/api/users/me/presence` | L4 | Position ponctuelle |
| PUT | `/api/users/me/photo` | L3 | Envoyer/remplacer la photo unique |
| DELETE | `/api/users/me/photo` | L3 | Retirer la photo |
| GET | `/api/traits` | L3 | Catalogue des traits |
| GET | `/api/users/me/traits` | L3 | Traits sélectionnés |
| POST | `/api/users/me/traits` | L3 | Ajouter un trait |
| DELETE | `/api/users/me/traits/:traitId` | L3 | Retirer un trait |
| GET | `/api/profile-questions` | L3 | Catalogue des questions |
| GET | `/api/users/me/profile-answers` | L3 | Réponses propriétaires et modération |
| PUT | `/api/users/me/profile-answers` | L3 | Remplacer la liste ordonnée des réponses |
| GET | `/api/users/me/discovery-status` | L4 | Diagnostic de préparation |
| GET | `/api/feed` | L4 | Découverte paginée |
| POST | `/api/swipes` | L4 | Like/pass et résultat du match |
| GET | `/api/matches/me` | L5 | Liste des matchs |
| PATCH | `/api/matches/:id/reveal` | L6 | Accord de révélation |
| PATCH | `/api/matches/:id/continue` | L6 | Accord de continuation et coût |
| PATCH | `/api/matches/:id/end` | L5 | Terminer un match |
| GET | `/api/users/me/continuation-quota` | L6 | Crédits, réservations et plafond |
| GET | `/api/matches/:id/messages` | L5 | Historique paginé |
| POST | `/api/matches/:id/messages` | L5 | Envoi idempotent |
| PATCH | `/api/matches/:id/messages/read` | L5 | Lecture groupée |
| PATCH | `/api/matches/:id/messages/:msgId/read` | L5 | Lecture unitaire si nécessaire |
| POST | `/api/users/me/advertising-rewards` | L6 | Créer/reprendre une intention |
| GET | `/api/users/me/advertising-rewards/:id` | L6 | Suivre la validation serveur |
| DELETE | `/api/users/me/advertising-rewards/:id` | L6 | Annuler une intention |
| GET | `/api/users/me/devices` | L8 | Liste des appareils |
| POST | `/api/users/me/devices` | L8 | Enregistrer/rafraîchir le token push |
| DELETE | `/api/users/me/devices/:id` | L8 | Retirer un appareil |
| GET | `/api/users/me/events` | L5 | SSE authentifié |
| GET | `/api/plans` | L1, L6, L9 | Catalogue, tarifs et disponibilité publicitaire |
| GET | `/api/users/me/subscription` | L9 | Abonnement et droits effectifs |
| POST | `/api/users/me/subscription/checkout` | L9 | Achat hébergé si distribution compatible |
| POST | `/api/users/me/subscription/portal` | L9 | Gestion de l'abonnement |
| GET | `/api/users/me/blocks` | L7 | Comptes bloqués |
| POST | `/api/users/me/blocks/:userId` | L4, L7 | Bloquer un compte depuis feed ou reçu |
| DELETE | `/api/users/me/blocks/:userId` | L7 | Débloquer un compte |
| POST | `/api/reports` | L7 | Signaler un compte/contenu |
| POST | `/api/users/me/data-subject-requests` | L7 | Déposer une demande RGPD |
| GET | `/api/users/me/data-subject-requests` | L7 | Suivi des demandes |
| GET | `/api/users/me/data-export` | L7 | Export JSON privé |
| POST | `/api/users/me/deletion-token` | L7 | Préparer la confirmation de suppression |
| DELETE | `/api/users/me` | L7 | Accepter la suppression, fermer la session sur 202 |
| GET | `/api/users/me/language` | Transversal | Lire la préférence du compte |
| PATCH | `/api/users/me/language` | Transversal | Enregistrer un choix de langue explicite |
| GET | `/api/users/me/discovery-settings` | Complément L4 | Lire le mode pause |
| PATCH | `/api/users/me/discovery-settings` | Complément L4 | Modifier le mode pause |

</details>

Les webhooks AdMob, Stripe et SMS sont appelés par les fournisseurs, jamais par Flutter. Les routes de santé servent au diagnostic du backend, pas à remplacer les erreurs des parcours utilisateur.

## Critère de livraison

Pour chaque parcours activé, consigner l’environnement, la version, le contrôle effectué et le résultat. Couvrir les états chargement, vide, erreur, résultat incertain et perte d’accès avec les vérifications adaptées au risque.

Les tests ordinaires restent simulés. Une analyse, un test ou une compilation Android ne valide ni un fournisseur réel ni iOS. Les commandes et conventions de contribution sont dans le [README](README.md) ; mettre à jour ce suivi uniquement lorsque le périmètre ou les validations restantes changent.
