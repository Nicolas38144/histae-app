# Histae App — résumé technique et fonctionnel

Mise à jour : 16 octobre 2026.

[Accueil](README.md) · [Roadmap et routes mobiles](roadmap.md) · [Contrat HTTP Rust](../histae-api-rust/docs/http-contract.md)

## 1. Périmètre et état actuel

`histae-app` est le futur client Flutter Android/iOS des utilisateurs de Histae. Le backend de référence est `histae-api-rust`, écrit en Rust avec Axum, Tokio et SQLx. PostgreSQL contient les données transactionnelles ; Redis sert notamment aux limites de débit et au relais temps réel ; les photos sont privées dans un stockage compatible S3. L'API, l'outbox et la maintenance ont des cycles de vie distincts.

L1, L2 et L3 sont implémentés : accueil/catalogue, OTP, session sécurisée, consentements versionnés, profil majeur, préférences, traits, réponses et photo unique. Flutter 3.47.7 / Dart 3.13.5 vérifiés, Dart `^3.13.1` conservé. L3 ajoute `image_picker: ^1.2.4`, `flutter_image_compress: ^2.5.1`, `http_parser: ^4.1.2`, `path_provider: ^2.1.6` et la configuration publique `.env`. Seul le catalogue est vérifié en réseau réel ; L2/L3 sont testés avec les contrats et des données simulées, sans validation SMS/compte/photo/appareil. Les fonctionnalités L4 à L10 restent à construire.

Le dashboard est hors périmètre. Aucun rôle administratif, WebAuthn administrateur, écran de modération ou route `/api/admin/*` ne doit être ajouté au mobile.

## 2. Références et entretien

Lire le [contrat HTTP](../histae-api-rust/docs/http-contract.md), les DTO et routes Rust concernés, leurs tests et les [collections Postman](../histae-api-rust/postman/README.md). Le backend n'expose pas de document OpenAPI/Swagger ; ne pas dépendre d'une génération depuis un endpoint de documentation supposé. Les anciens documents NestJS/Fastify ne décrivent plus le backend actuel.

Le présent résumé possède les précautions d'intégration mobile. La [roadmap](roadmap.md) possède l'ordre des lots et la matrice de couverture. Les corps, enums, erreurs et limites détaillés restent dans le contrat API : les vérifier avant chaque implémentation et signaler une divergence avec le code sans inventer de comportement.

Références complémentaires : [architecture](../histae-api-rust/docs/architecture.md), [développement](../histae-api-rust/docs/development.md), [configuration](../histae-api-rust/docs/configuration.md), [facturation](../histae-api-rust/docs/billing.md), [continuations et récompenses](../histae-api-rust/docs/continuation-and-rewards.md), [audit fonctionnel](../histae-api-rust/docs/feature-audit.md) et [roadmap production](../histae-api-rust/roadmap-production.md).

## 3. Conventions HTTP

La matrice mobile utilise les chemins complets, préfixe `/api` inclus. Choisir une seule convention dans le futur client afin de ne pas doubler ce préfixe. L'origine API doit être configurable selon l'environnement ; ne jamais fixer `localhost` dans le code métier. Adapter l'accès réseau à l'émulateur et au téléphone. HTTP en clair peut être nécessaire localement ; HTTPS reste requis pour la production.

`API_BASE_URL` est une origine sans `/api`, chemins complets dans les repositories. Cible utilisateur : `https://api.histae.com/api/`. Depuis L3, l'origine `https://api.histae.com` et `APP_ENV=production` sont dans `.env`, chargé comme asset avant les clients HTTP ; aucune valeur de secours dans Dart ni surcharge `--dart-define`. `.env` local ignoré, `.env.example` fourni pour installation/CI. Configuration publique embarquée, sans secret ; clés manquantes/doublons/valeurs invalides ferment l'intégration. HTTP refusé sauf `development` + debug ; exceptions natives limitées au debug. Catalogue réel vérifié HTTP 200 et deux formules décodées.

- JSON, sauf upload photo multipart ; champs inconnus refusés et corps JSON limité à 1 Mio.
- Date de naissance `YYYY-MM-DD` ; horodatages avec fuseau, calculs en UTC et affichage local.
- Prix en centimes avec devise explicite ; distances en kilomètres.
- Une réponse `204` ne contient pas de JSON.
- Erreurs sous la forme `{ "error": { "code": "...", "message": "..." } }` : piloter le comportement par `code`, pas par le texte anglais.
- Conserver un `X-Request-ID` UUID v4 pour un diagnostic sans données privées.
- Respecter `Retry-After` sur `429` et lorsqu'il est fourni sur `503`. Ne pas transformer une indisponibilité en erreur de formulaire.

Les curseurs sont opaques. Réutiliser les mêmes filtres, dédupliquer les identifiants et s'arrêter à `next_cursor: null`. Le curseur du feed expire après 15 minutes : après `invalid_cursor`, recommencer sans curseur. La pagination ne fige pas un instantané ; rafraîchir après une modification pertinente. N'ajouter ni offset déprécié ni paramètres de pagination à une route qui ne les prévoit pas.

Il n'existe pas de retry universel : appliquer les règles d'idempotence de chaque opération. OTP, photo, message et Checkout exigent une clé UUID v4 stable pour une même intention et un contenu identique. Une nouvelle clé après timeout peut créer un second effet ou être refusée. Conserver les paramètres nécessaires à la reprise pendant la fenêtre autorisée ; ne pas créer pour autant une file générale de mutations hors ligne.

## 4. Inscription, authentification et sessions

Les entrées « Créer mon compte » et « J'ai déjà un compte » utilisent les routes OTP, puis `GET /api/auth/me` et les consentements. La vérification crée le compte s'il n'existe pas : aucun endpoint d'inscription séparé ni mot de passe n'est inventé. L'espace personnel est conditionné par la session et les choix obligatoires serveur. L3 permet maintenant de créer le profil majeur et ses préférences ; la découverte de L4 désigne le feed sans photo, pas un guide de l'application.

Les numéros sont français E.164 `+33`, normalisés comme dans Rust ; code OTP à six chiffres. `202` ne prouve pas la réception du SMS. Refus de livraison, livraison incertaine, code invalide/expiré et quota sont distincts. Le renvoi explicite crée une nouvelle intention ; la reprise conserve UUID v4 et paramètres en mémoire. Une vérification dont le résultat est perdu impose un nouveau code sans reprise automatique.

Les routes mobiles utilisent `Authorization: Bearer <access_token>`. Le refresh token opaque reçu sous la forme `jti:secret` doit rester dans un stockage sécurisé. Garder l'access token en mémoire et enregistrer la rotation de façon cohérente avec le nouveau refresh.

Un seul refresh doit s'exécuter à la fois. Les requêtes concurrentes attendent cette rotation ; aucune boucle de rafraîchissement n'est autorisée. Le rejeu d'un ancien refresh authentique non expiré révoque sa famille : pas de fenêtre de grâce et pas de retry aveugle après perte de réponse. Une réponse perdue peut nécessiter une nouvelle connexion OTP. Rejouer une requête métier après rotation uniquement si ses règles de rejeu le permettent.

L2 remplace avant l'appel l'entrée sécurisée `ready` par `rotating`, sans ancien refresh, puis écrit et relit le nouveau refresh avant de publier l'access token. Un arrêt ou résultat incertain ferme la session. Le transport ne relance rien ; la couche session autorise une seule reprise des requêtes L2/L3 après un 401 confirmé pour access token expiré, avec un contenu identique. Elle ne relance aucune mutation après timeout. Une révocation ferme directement la session. Logout attend la rotation courante, tente la révocation puis purge mémoire et jeton persistant ; la révocation distante incertaine est annoncée. Les réponses tardives d'un ancien compte sont ignorées.

Prévoir restauration de session, logout courant, liste/révocation des sessions et logout global. Le serveur ne renvoie aucun rôle administratif dans le bootstrap mobile. Au logout, fermer SSE, désactiver les abonnements locaux et purger jetons et caches privés ; informer d'une révocation distante non confirmée si le réseau est indisponible.

## 5. Consentements et onboarding

Les quatre types sont `terms_of_service_acceptance`, `privacy_notice_acknowledgement`, `sensitive_data_consent` et `location_consent`. Aucun choix marketing n'existe dans ce contrat. Présenter les documents et versions requis retournés par l'API, sans précocher les choix ni envoyer une version choisie par Flutter.

Charger les consentements après le bootstrap et guider le parcours avec `onboarding_complete` et `required_actions`. Les CGU et la notice courantes conditionnent les routes utilisateur normales ; certaines routes de session et de vie privée restent accessibles avant onboarding complet. Ne pas bloquer globalement l'accès à la déconnexion, à l'export ou à la suppression derrière la découverte.

L2 affiche les quatre choix et les liens HTTPS/version serveur, sans précocher un nouvel accord. Les accords existants sont présentés comme état enregistré. Le navigateur ne reçoit aucun Bearer. Le retour d'un document conserve les choix non enregistrés seulement si les versions sont inchangées. Une relecture avant PUT détecte un changement ; le contrat ne permet pas de contrôle atomique entre ce GET et le PUT, faute de version client. Proposition backend séparée au README : versions attendues et conflit serveur, sans modification de l'API.

CGU et notice ne se retirent pas par la route de consentements : on peut refuser l'onboarding ou supprimer le compte. Retirer le consentement sensible efface sexe et préférences ; retirer celui de localisation efface la présence. Expliquer ces effets avant l'action, invalider les caches et respecter l'état retourné. Une permission native ne remplace pas un consentement métier.

Les retraits autorisés sont implémentés avec confirmation en L2. Documents, consentements et déconnexion restent accessibles sans profil/découverte prêts. Demandes de droits, export et suppression restent suivis en L7 ; ne pas les annoncer livrés.

## 6. Profil, préférences, traits et questions

Le profil impose une naissance valide et un âge minimal de 18 ans. Prénom et naissance sont requis même pour le PATCH ; omettre `sex` ou `bio` les remet à `null`. Le client doit envoyer l'état voulu sans effacer une donnée par accident. Le profil n'accepte pas de champ photo.

Les quatre préférences sont obligatoires à chaque PATCH : âges 18–99, distance entière 1–500 km et `looking_for` conforme à l'enum serveur. Les erreurs `profile_not_found` et `preferences_not_found` orientent vers une étape à compléter.

Utiliser les catalogues de traits et de questions, jamais des identifiants codés en dur. L'ajout de trait attend `{ traitId }`. L'enregistrement des réponses remplace atomiquement toute la liste : zéro à trois questions distinctes, ordre du tableau conservé et textes de 10 à 300 caractères, au plus 1 000 octets. Un tableau vide efface les réponses.

Le propriétaire voit ses états et motifs de modération. Dans les projections publiques, bio et réponses non approuvées sont masquées. Prévoir ce cas sans inventer un recours administratif absent du contrat mobile.

**Implémentation L3** : cinq écrans privés sur les treize routes, conservation explicite du sexe et de la bio, validation de majorité selon la date UTC, catalogues serveur, préférences sans valeurs arbitrairement préremplies et réponses ordonnées. Le PUT réponses attend `200 { answers }` ; traits et retrait photo attendent `204`. Remplacement/effacement des réponses confirmé, brouillons conservés après erreur et abandon confirmé. Relecture nécessaire après écriture incertaine ; aucune relance automatique après timeout. Seul un 401 d'expiration définitif permet un refresh et un rejeu identique. Profil, préférences, réponses et brouillons restent en mémoire ; révision de consentements/session invalide le cache, ferme les éditeurs et bloque les réponses tardives. Vie privée et logout restent accessibles.

## 7. Photo privée unique

Le pipeline photo est implémenté dans l'API Rust. L'ancienne saisie d'une URL externe est abandonnée. Utiliser `PUT /api/users/me/photo`, multipart avec un seul champ `photo`, et `DELETE` sur la même route.

Formats admis : JPG/JPEG, PNG, HEIC/HEIF et WebP, avec nom/MIME/signature cohérents. L'entrée est limitée à 500 000 octets et 40 Mpx ; le serveur produit un WebP privé sans métadonnées, au plus 2 048 px et 500 000 octets. Préparer le fichier avant envoi et conserver les mêmes octets, nom et MIME pendant une reprise idempotente. La fenêtre photo est de 24 heures, avec conflits distincts si le résultat a été remplacé ou consommé.

États de modération : `pending`, `approved`, `rejected`. Une analyse indisponible mène à une revue, pas à une approbation automatique. La disponibilité technique d'une URL propriétaire et l'approbation publique sont deux notions différentes.

Les URL signées expirent après 300 secondes : recharger la ressource propriétaire ou le match accessible pour obtenir une URL actuelle, sans conserver l'URL comme identifiant durable. Aucun endpoint mobile de galerie ou de signature arbitraire n'existe.

**Implémentation L3** : sélecteur natif, conversion JPEG locale sans EXIF, orientation corrigée et réduction progressive sous 500 000 octets ; source locale plafonnée à 30 Mo avant lecture. Une seule intention photo en mémoire, octets immuables/UUID v4 conservés pour reprise explicite pendant 24 h. Conflits consommé/incompatible suppriment l'intention et demandent relecture, aucun réenvoi avec une nouvelle clé implicite. Retrait confirmé et nouvelle lecture. Les copies temporaires du sélecteur sont nettoyées uniquement sous le cache privé résolu de l'app ; originaux de la photothèque intacts. Après arrêt Android, sélection récupérée non rattachée automatiquement à un compte.

L'aperçu propriétaire télécharge des octets en mémoire, sans Bearer ni redirection vers le stockage, sans cache disque ni journalisation de l'URL. Images évincées du cache mémoire à la fermeture/purge, lien renouvelé par GET propriétaire après quatre minutes et au retour au premier plan. Le motif de modération est affiché même si l'URL est techniquement lisible. Aucun téléchargement partenaire anticipé. Permission photothèque déclarée dans les deux plist iOS ; aucune permission caméra/micro ajoutée. Les codecs/permissions/récupérations natifs restent à valider sur appareil.

Le feed n'affiche pas de photo ; celle du partenaire reste `null` avant révélation mutuelle. Ne pas la télécharger de manière anticipée. Le DELETE `204` rend la photo invisible dans les nouvelles lectures ; l'objet est supprimé en arrière-plan. Les URL déjà émises restent soumises à leur expiration ou à la suppression de l'objet.

## 8. Localisation, découverte et swipes

Demander une position à l'usage après explication et consentement, sans suivi permanent en arrière-plan. La présence nécessaire à la découverte doit dater de moins d'une heure ; proposer un rafraîchissement pertinent à l'entrée du feed ou au retour au premier plan.

Le diagnostic `discovery-status` expose les actions `profile`, `sex`, `preferences`, `sensitive_data_consent`, `location_consent`, `fresh_presence`. L'utiliser pour réparer le parcours plutôt que reproduire l'éligibilité serveur.

Le feed expose prénom, âge, sexe, distance arrondie, traits, bio et réponses approuvées. Les critères sont réciproques et les positions exactes ne sont pas publiques. Deux likes créent un seul match. Un swipe conservé ne peut pas être changé ; après réponse perdue, rejouer seulement le même choix. Ne pas proposer d'annulation, de liste des likes entrants ou de file durable de swipes hors ligne.

## 9. Matchs, révélation et continuation

| État | Comportement mobile |
| --- | --- |
| `active` | Envoi et lecture pendant les 24 premières heures ; révélation mutuelle facultative |
| `awaiting_continuation` | Fenêtre suivante de 24 heures ; envoi suspendu, historique et lecture accessibles |
| `confirmed` | Deux accords valides ; conversation rouverte |
| `expired` | Accord mutuel absent à l'échéance ; messagerie indisponible |
| `ended` | Match clôturé et retiré des listes mobiles |

Les délais partent de l'échéance d'origine ; une maintenance tardive ne les rallonge pas. Utiliser les états et dates serveur et resynchroniser aux échéances. `my_revealed` et `my_continued` décrivent uniquement les choix du demandeur ; la photo dépend de `photos_revealed`. Révélation et continuation sont des accords indépendants, y compris pour Premium.

Règles actuelles : Free reçoit trois crédits chaque lundi à 00:00 UTC sans cumul, peut conserver jusqu'à trois crédits publicitaires et confirmer au plus six continuations par semaine. Premium n'utilise pas de crédit et n'est pas soumis à ce plafond personnel. Afficher les valeurs du catalogue et de `continuation-quota`, sans recalculer le solde localement ni coder ces limites comme autorité.

Chaque personne Free accepte explicitement son coût maximal avec `credit_cost: 1` ; Premium annonce `0`. L'API réserve puis débite après les deux accords. Le premier accord reste privé ; ni événement ni affichage ne doit révéler le choix du partenaire. Une clôture ou expiration libère les réservations ; un crédit déjà débité n'est pas remboursé. Un changement de plan peut imposer de relire le quota et de représenter le coût avant un nouvel accord.

Chaque participant peut terminer un match sans bloquer le partenaire. Après succès, retirer la conversation et ses données locales ; les anciens accès et rejeux de messages deviennent indisponibles. Présenter « Ce match est terminé », sans auteur ni motif supposés.

## 10. Messagerie et temps réel

Historique paginé, messages texte non vides limités à 2 000 caractères, états envoi/confirmé/échec et déduplication par identifiant serveur. Une intention d'envoi garde sa clé UUID v4 pour ses reprises. Ne pas renvoyer un ancien message comme une nouvelle intention après un timeout.

Privilégier le marquage groupé par `read_through_message_id` ; la route unitaire reste disponible, sans imposer une requête par message. Ne pas marquer un message comme lu sur simple réception d'une notification.

Le SSE authentifié doit pouvoir envoyer le Bearer. Événements : `connected`, `match.created`, `match.updated`, `matches.invalidated`, `message.created`, `message.read`, `subscription.updated`, avec heartbeat toutes les 25 secondes. Le flux ferme à expiration du JWT ou après détection de révocation. Prévoir une reconnexion bornée avec backoff et une seule connexion utile par session.

SSE n'a pas de replay hors ligne. Relire les ressources après reconnexion, reprise de l'app ou invalidation. Une notification ou un événement ne remplace pas le contrôle d'accès HTTP. Ne pas maintenir inutilement le flux quand l'app est suspendue.

## 11. Appareils et push

Demander l'autorisation au moment pertinent, puis enregistrer `{ push_token, platform, app_version? }`. Conserver l'UUID public d'appareil retourné et rafraîchir l'enregistrement lors d'une rotation du token. La session est liée par le Bearer, pas choisie par le client. Prévoir liste et suppression des appareils.

FCM est optionnel côté serveur et nécessite une configuration et des essais réels. Les notifications ne contiennent pas le texte privé d'un message. Dédupliquer leur `notification_id`, car un doublon fournisseur est possible. À l'ouverture, valider la session et relire la ressource avant navigation. Gérer premier plan, arrière-plan, application arrêtée, permission refusée et lien devenu inaccessible.

## 12. Récompenses publicitaires

Les vidéos sont volontaires et réservées aux comptes Free éligibles. Vérifier `rewarded_advertising_enabled` et les réponses serveur ; le fournisseur est désactivé par défaut. Aucun droit de suivi publicitaire ne découle des consentements de rencontre.

Créer ou reprendre une intention avec la plateforme, transmettre au SDK l'unité et `custom_data` retournés, puis suivre l'intention. États : `pending`, `credited`, `expired`, `cancelled`. Annuler une intention abandonnée lorsque pertinent ; l'annulation invalide les preuves ultérieures.

Seul le callback signé vérifié côté serveur crédite le compte. Le callback local du SDK ne modifie jamais le solde. Après crédit confirmé, relire le quota. Gérer stock plein, inéligibilité, intention expirée et vérification indisponible sans promettre un crédit immédiat.

## 13. Offres et abonnement

Charger `/api/plans` et l'état d'abonnement. Le catalogue actuel prévoit Free, Premium mensuel 5 €, annuel 48 € et un essai initial de 30 jours sous conditions ; les valeurs d'affichage viennent du serveur, en centimes et avec devise. Ne pas promettre un nouvel essai à un compte l'ayant déjà consommé.

Le client choisit uniquement `monthly` ou `annual` pour Checkout, avec une clé d'idempotence. Aucun Product ID, Price ID, Customer ID, montant ou durée d'essai n'est envoyé. Ouvrir l'URL retournée dans un navigateur approprié et traiter retour, annulation et reprise après fermeture. Une création incertaine se reprend avec la même clé et les mêmes paramètres dans les conditions du contrat ; ne pas multiplier les tentatives d'achat.

L'URL de succès ne prouve pas le paiement. Relire la projection serveur et `access_granted` pour les droits Premium, notamment après `subscription.updated`. Des mises à jour proviennent de webhooks et de la réconciliation serveur ; aucun endpoint d'activation locale n'existe. Le portail est disponible selon `customer_portal_available` et sa configuration serveur.

Avant activation des ventes, vérifier la documentation officielle Apple/Google applicable aux plateformes et marchés visés ; ne pas supposer que le Checkout web actuel convient à toutes les distributions. Une adaptation du backend peut être nécessaire selon la stratégie retenue. La consultation du catalogue et de l'abonnement peut avancer indépendamment de cette décision.

## 14. Sûreté, droits et suppression

Signalements : `inappropriate_content`, `fake_profile`, `harassment`, `spam`, `other`, avec description optionnelle. Blocage et fin de match sont distincts ; après blocage `204`, invalider les profils et conversations concernés. Lister les blocages et permettre leur retrait, sans supposer qu'un déblocage restaure un match.

Demandes RGPD : `access`, `erasure`, `portability`, `rectification`, `restriction`, `objection`. Consulter les demandes et leur statut ; un dépôt de demande n'est pas une exécution immédiate. L'export JSON doit être partagé/enregistré explicitement et son fichier temporaire nettoyé avec précaution.

La suppression du compte exige un jeton dédié, puis `DELETE /api/users/me` avec `{ confirmation_token }`. Le `202 { request_id, status: "in_progress" }` désactive immédiatement le compte : fermer la session et expliquer que le nettoyage continue en arrière-plan. Ne pas attendre un `204` ni annoncer un effacement déjà terminé. Une réponse perdue peut laisser le Bearer invalide ; le retry n'est pas un mécanisme public de suivi. Conserver une formulation honnête si le résultat reste incertain.

Les consentements, demandes de droits, export et suppression ne doivent pas devenir inaccessibles à cause d'un onboarding ou d'une découverte incomplète lorsque l'API les autorise.

## 15. Organisation Flutter et direction artistique

Structure L1 : `app` (application/navigation/thème), `core` (configuration, réseau, textes français, composants) et `features/catalog/{data,application,presentation}`. `CatalogController` utilise `ChangeNotifier`, le repository décode les DTO, le client HTTP est injecté. Aucune couche vide ajoutée pour les lots futurs. Les widgets ne manipulent ni secrets ni JSON réseau directement.

L2 ajoute `features/auth/{data,application,presentation}`, `features/consents/{data,presentation}`, `SessionController`, `OtpController` et un stockage sécurisé injectable. Le transport accepte méthode/corps/Bearer/clé sans retry. La navigation retire les écrans précédents au changement de session ; le retour système ne rouvre pas un écran privé après logout.

Choix L1 après consultation des documentations officielles : `http` pour les requêtes annulables, `Navigator` / `MaterialPageRoute` pour les deux écrans publics, `ChangeNotifier` pour leur état, `flutter_localizations` pour les libellés Material français. Les textes applicatifs sont centralisés dans `AppStrings` ; ajouter un délégué de traduction à l'introduction d'une seconde langue. Les thèmes suivent le système ; aucune réduction forcée de la taille du texte. Chargement, vide, erreur réseau, délai dépassé et nouvelle tentative sont explicites.

La navigation distingue restauration, inscription/connexion, synchronisation, consentements requis, espace personnel et erreur de session/stockage. Aucune session n'est simulée dans l'app. Une découverte non prête ne verrouillera pas les fonctions autorisées ; les liens entrants nécessiteront session et ressource accessibles.

La DA reprend la composition de `pictures/exemple_feed.png` : arrondis, titres à empattements, séparateurs fins et espaces aérés. La palette rose/corail est remplacée à la demande de l'utilisateur par ivoire `#FAF8F3`, papier `#FFFDF8`, forêt `#345647`, encre `#252C28` et sable `#E4DAC9`, avec adaptation sombre. DM Serif Display est embarquée avec sa licence SIL OFL ; le code reste propriétaire. Trois aperçus ont été inspectés (`tool/preview_app_test.dart`, données de test). L4 appliquera cette DA au feed sans photo : swipe haut pour passer, double appui pour liker, aucun retour vers le bas.

## 16. Stockage et validation

Persister le strict nécessaire : refresh sécurisé, préférences d'interface et identifiants publics utiles. Garder initialement profils, feed, matchs et messages en mémoire ou dans un cache effaçable. Toute persistance ultérieure doit être justifiée, protégée et invalidable. Ne pas persister durablement OTP, coordonnées exactes, exports ou URL photo signées par défaut.

L2 persiste une seule entrée sécurisée (origine, phase, refresh à l'état `ready`), sans access token, téléphone, OTP, identité ni consentements. Android : API 24 minimum réel du package, sauvegarde désactivée et préférences exclues des transferts. iOS : Keychain `unlocked_this_device`, entitlements sur les trois configurations. Une erreur ou relecture incohérente du stockage ferme l'accès ; comportement natif encore à éprouver sur appareils.

Aucun jeton, téléphone, position exacte, message privé ou URL signée dans les logs ou rapports de crash. Au changement de compte, empêcher tout mélange des caches, requêtes et connexions en cours.

Les tests Flutter pertinents couvrent sérialisation, erreurs, rotation concurrente, idempotence, navigation, consentements et états critiques. Les tests ordinaires n'envoient aucun SMS réel, ne créditent aucune publicité réelle et n'effectuent aucun paiement. Les essais de fournisseur utilisent les environnements dédiés. Documenter séparément analyse/tests automatisés, intégration API et validation sur appareils Android/iOS.

## 17. Vérifications et limites restantes

L1 est implémenté : accueil/catalogue, origine configurable, thèmes et erreurs typées. Le client envoie un UUID v4 `X-Request-ID`, ne suit pas les redirections et n'effectue aucun retry ni refresh automatique. Timeout couvrant en-têtes et corps ; annulation à la fermeture/suspension, réponses tardives ignorées, reprise de la seule lecture interrompue. `Retry-After` en secondes ou date interdit la nouvelle tentative avant échéance. Les erreurs conservent seulement statut, code, identifiant de demande validé et délai ; aucun corps, message anglais ou URL n'est journalisé. Le catalogue reste en mémoire, sans persistance et sans action d'achat.

Les fixtures suivent les DTO Rust du catalogue, OTP, consentements et profil/photo ; valeurs et identifiants sont simulés. Tests backend/Postman consultés, pas exécutés. Une suite complète de **107 tests** a réussi, puis **23 tests L3 ciblés** après les derniers ajouts (110 tests présents au total). Six aperçus DA générés et inspectés, formatage sans changement, analyse sans erreur et compilation Android debug réussie. Le GET réel du catalogue a répondu HTTP 200 avec deux formules décodées. Aucun SMS, compte ou upload réel testé. L2/L3 utilisent leurs vrais endpoints ; fournisseurs, stockage/permissions/codecs sur appareils et iOS restent ouverts. Prochain lot : **L4**, présence, diagnostic et feed sans photo. Préférence utilisateur : à l'avenir, nouveaux tests et exécution ciblés sur les contrôles indispensables, sans couverture systématique des changements visuels ou à faible risque.

Les parcours L4 à L10 restent à construire. Les capacités serveur photo, SMS, push, publicité et Stripe nécessitent la configuration appropriée et des validations réelles ; leur présence dans le code ne prouve pas la disponibilité de l'environnement. Les signatures mobiles, liens de retour, permissions métier, règles de distribution et déclarations de confidentialité restent à préparer. Les plist iOS commun/debug sont à maintenir ensemble et à compiler sur Mac ; aucune validation iOS réalisée sur cet hôte Windows. Consulter la roadmap production API pour les limites d'exploitation, sans les masquer par une simulation mobile.



