# Histae App — résumé technique et fonctionnel

Mise à jour : 18 octobre 2026.

Identité visuelle : les cinq pistes initiales de logo SVG sont conservées dans [pictures/logos/nouvelle-da](pictures/logos/nouvelle-da/README.md), avec planche comparative et variantes. La recherche se poursuit sur les pages ; le mot-symbole actuel de l'app et du site est conservé pendant le choix de sa déclinaison.

Suite du choix graphique : **02 — Les pages** est retenue comme direction. Quatre intégrations au mot Histae sont proposées dans [les-pages-variantes](pictures/logos/les-pages-variantes/README.md), avec formats compacts et simulations de l'en-tête. La variante précise reste en cours de choix.

[Accueil](README.md) · [Roadmap et routes mobiles](roadmap.md) · [Contrat HTTP Rust](../histae-api-rust/docs/http-contract.md)

## 1. Périmètre et état actuel

Refonte visuelle du 18 octobre : 52 contrôles ciblés existants réussis, dix scénarios visuels et 44 aperçus inspectés, analyse sans problème, formatage vérifié et APK Android debug compilé. Validation iOS sur Mac et appareils réels encore prévue dans L10.

La navigation principale conserve trois onglets : **Feed**, **Matchs**, **Profil**. Le feed est affiché après l'onboarding juridique. La barre reste présente sur les trois espaces principaux ; conversations, formulaires et réglages utilisent des pages de détail. Le changement d'onglet suspend l'activité de l'écran quitté. Les contrôleurs restent liés à la session ; les notifications suspendent temporairement le parcours principal.

`histae-app` est le futur client Flutter Android/iOS des utilisateurs de Histae. Le backend de référence est `histae-api-rust`, écrit en Rust avec Axum, Tokio et SQLx. PostgreSQL contient les données transactionnelles ; Redis sert notamment aux limites de débit et au relais temps réel ; les photos sont privées dans un stockage compatible S3. L'API, l'outbox et la maintenance ont des cycles de vie distincts.

L1 à L5, le cœur de L6, L7 et la gestion des appareils L8 sont implémentés. Les flux push L8 sont préparés mais désactivés, sans projet Firebase, conformément au choix utilisateur. L7 ajoute signalement, gestion des blocages/sessions, droits, export et suppression. `share_plus ^13.3.1` ajouté ; dépendance Google déjà présente conservée, intégration native/UMP et vidéos encore désactivées. SDK Flutter 3.47.7 / Dart 3.13.5, contrainte Dart `^3.13.1`. Parcours privés simulés uniquement ; seul le catalogue vérifié en réseau réel. IDs Android dans le seul `.env` local, iOS vides, aucun fichier modèle recréé. L9 ajoute le suivi de l’abonnement et prépare les paiements, désactivés en attente de Stripe test et des retours HTTPS ; L10 reste à construire, mode nuit conservé.

Le dashboard est hors périmètre. Aucun rôle administratif, WebAuthn administrateur, écran de modération ou route `/api/admin/*` ne doit être ajouté au mobile.

## 2. Références et entretien

Lire le [contrat HTTP](../histae-api-rust/docs/http-contract.md), les DTO et routes Rust concernés, leurs tests et les [collections Postman](../histae-api-rust/postman/README.md). Le backend n'expose pas de document OpenAPI/Swagger ; ne pas dépendre d'une génération depuis un endpoint de documentation supposé. Les anciens documents NestJS/Fastify ne décrivent plus le backend actuel.

Le présent résumé possède les précautions d'intégration mobile. La [roadmap](roadmap.md) possède l'ordre des lots et la matrice de couverture. Les corps, enums, erreurs et limites détaillés restent dans le contrat API : les vérifier avant chaque implémentation et signaler une divergence avec le code sans inventer de comportement.

Références complémentaires : [architecture](../histae-api-rust/docs/architecture.md), [développement](../histae-api-rust/docs/development.md), [configuration](../histae-api-rust/docs/configuration.md), [facturation](../histae-api-rust/docs/billing.md), [continuations et récompenses](../histae-api-rust/docs/continuation-and-rewards.md), [audit fonctionnel](../histae-api-rust/docs/feature-audit.md) et [roadmap production](../histae-api-rust/roadmap-production.md).

## 3. Conventions HTTP

La matrice mobile utilise les chemins complets, préfixe `/api` inclus. Choisir une seule convention dans le futur client afin de ne pas doubler ce préfixe. L'origine API doit être configurable selon l'environnement ; ne jamais fixer `localhost` dans le code métier. Adapter l'accès réseau à l'émulateur et au téléphone. HTTP en clair peut être nécessaire localement ; HTTPS reste requis pour la production.

`API_BASE_URL` est une origine sans `/api`, chemins complets dans les repositories. Cible utilisateur : `https://api.histae.com/api/`. Depuis L3, l'origine `https://api.histae.com` et `APP_ENV=production` sont dans `.env`, chargé comme asset avant les clients HTTP ; aucune valeur de secours dans Dart ni surcharge `--dart-define`. `.env` local ignoré ; fournir ce fichier en installation/CI, sans recréer de modèle supprimé par l'utilisateur. Configuration publique embarquée, sans secret ; clés manquantes/doublons/valeurs invalides ferment l'intégration. HTTP refusé sauf `development` + debug ; exceptions natives limitées au debug. Catalogue réel vérifié HTTP 200 et deux formules décodées.

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

Les retraits autorisés sont implémentés avec confirmation en L2. Documents, consentements et déconnexion restent accessibles sans profil/découverte prêts. Demandes de droits, export et suppression sont implémentés en L7 depuis le même parcours avant onboarding ; essais réels sur comptes/appareils encore ouverts.

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

**Implémentation L4** : quatre routes branchées, étapes serveur réparables via profil/préférences/consentements existants. Acquisition ponctuelle après accord métier courant et explication/permission native ; aucune demande GPS automatique au démarrage ou à la reprise. Pas de position connue réutilisée. Source annulable, mesure locale récente et coordonnées valides, précision approximative admise ; refus/services désactivés/délai distincts. Seules latitude/longitude sont envoyées ; la date de présence vient du serveur. Après résultat incertain du PATCH, diagnostic relu sans renvoi automatique. À `presence_expires_at`, invalidation du lot affiché et relecture serveur ; le délai local ne fabrique pas un état d'éligibilité.

Le feed affiche les mots reçus, sans photo, ville ni catégories de traits fabriquées. Double appui = like ; un geste haut démarré en fin de lecture = pass. Les profils longs se lisent avant un geste distinct pour passer ; boutons accessibles équivalents, aucun historique par geste bas. Pagination à limite constante, curseur opaque encodé, déduplication et reprise sans curseur expiré. Retour des préférences/du premier plan : relecture, sans réutiliser un ancien lot. Une intention cible/décision reste en mémoire dans la session, y compris après retour au profil. Le choix opposé et les demandes concurrentes sont bloqués ; seule la reprise identique est proposée, avec `Retry-After`. Pas de file persistante. Retrait de consentement/logout purge données et intentions, réponses tardives ignorées.

Le `201` réciproque ouvre le reçu du match serveur après vérification des membres ; son bouton de conversation L5 relit les autorisations courantes. Blocage explicite depuis feed/reçu via POST sans corps → `204`, pouvant remplacer une intention like/pass incertaine sans envoyer l'opposé ; purger le reçu concerné. Gestion liste/déblocage/signalements livrée en L7. XML Android coarse/fine et plist iOS when-in-use modifiés sans suivi de fond. Le flag natif SPM iOS `BYPASS_PERMISSION_LOCATION_ALWAYS=1` doit accompagner la compilation sur Mac ; voir README. Aucun essai GPS/permissions ou compilation iOS réalisé ici.

**Vérifications L4** : huit tests ciblés réussis, puis contrôle ciblé du geste sur profil long ; treize vérifications existantes de configuration réussies après abandon du modèle `.env`. Deux aperçus de feed simulé inspectés, analyse sans erreur, formatage et XML vérifiés ; APK Android debug compilé. Tests backend/Postman consultés uniquement. Validation entre deux comptes et sur Android/iOS physiques toujours ouverte ; ne pas annoncer ces fournisseurs validés. Aucun nouveau passage systématique de la suite entière.

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

**Implémentation L5** : `features/matches/{data,application,presentation}` relie les sept routes du lot. Accès depuis profil/feed/reçu ; aucun GET administratif pour ouvrir un match par ID : parcours de la collection mobile autorisée. Liste/dernier message/non-lus, profil partenaire textuel et historique paginé, ordre serveur et déduplication, reprise sans curseur invalide. L6 ajoute la vue photo distincte après révélation mutuelle ; aucun préchargement depuis le feed, la liste ou le profil textuel.

Une intention de message conserve texte normalisé ECMAScript et UUID v4 en mémoire, y compris après navigation ; après timeout, seule une reprise explicite identique est proposée. Limite de 2 000 points de code Unicode, aucune restriction de taille en octets inventée. Envoi/lecture selon l'état relu ; `awaiting_continuation` conserve l'historique et masque la composition. Échéance = gel des envois/relecture, aucune période fabriquée. `confirmed` ignore l'ancienne expiration. Lecture groupée seulement pour un message reçu visible dans le chat courant au premier plan ; pas de marquage sur événement, écran couvert ou suspension. Route unitaire disponible sans appel par bulle. Fin/blocage confirmés, résultat incertain mémorisé par conversation pour reprise identique, puis purge des données retirées et du reçu de découverte.

SSE envoie le Bearer en en-tête, sans URL de jeton ni Last-Event-ID supposant un replay. Une connexion dans l'espace rencontres, annulation à sa sortie/suspension, reconnexion progressive avec aléa et `Retry-After`, inactivité maximale 70 s. UTF-8 fragmenté, CR/LF, commentaires et données multilignes bornés ; fin de trame incomplète abandonnée. `connected`/reconnexion/événements/reprise relisent liste et historique chargé. Les événements ne fabriquent ni message privé ni accord du partenaire. Rotation d'accès sérialisée partagée avec JSON ; révocation ferme la session. Invalidation/consentements/logout purgent données et intentions ; réponses tardives ignorées. Référence : [format SSE WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html).

**Vérifications L5** : neuf tests ciblés réussis pour idempotence, curseurs/ordre, états, purge/réponses tardives, clôture/blocage, lecture visible, décodeur, rotation concurrente SSE/JSON et connexion unique annulable. Quatre aperçus simulés en mode nuit inspectés, dont grand texte/clavier ; retour de navigation corrigé et vérifié. Analyse sans problème, formatage et APK Android debug réussis. Pas de nouvelle exécution systématique de la suite entière. Deux comptes réels, réseau mobile, cycle de vie natif et iOS restent ouverts. Backend consulté uniquement ; aucun service/test/backend modifié.

**Ajout L6 — accords et crédits** : `features/continuation/{data,application,presentation}` fournit les accords séparés, l'écran crédits et la photo partenaire. Quota et rencontre relus avant une confirmation du coût maximal personnel `0` Premium / `1` Free. Après résultat incertain, coût immuable conservé par rencontre en mémoire pour reprise explicite ; aucune file persistante. Une nouvelle formule, semaine, lecture ou confirmation ancienne invalide l'offre présentée. `continuation_plan_changed` impose un nouvel accord ; un solde à zéro ne transforme pas une intention incertaine en nouvel envoi. Réponse/événement ne fabrique ni confirmation mutuelle ni choix du partenaire. Relecture après décision/SSE/reprise ; réservation, débit et plafond restent serveur. Perte d'accès/consentements/logout purge les intentions et ignore les réponses tardives.

La photo n'est retenue dans le DTO que si `photos_revealed` et l'accès à l'historique sont valides. Vue explicitement ouverte, nouvelle lecture, HTTPS sans Bearer/redirection/cache disque, maximum 5 Mo et 15 s. Place réservée pendant le décodage ; image mémoire réduite, cache évincé à la sortie/suspension/invalidation. Renouvellement avant cinq minutes et après retour au premier plan. Une URL reçue sans accord mutuel est ignorée, sans téléchargement anticipé.

## 11. Appareils et push

Demander l'autorisation au moment pertinent, puis enregistrer `{ push_token, platform, app_version? }`. Conserver l'UUID public d'appareil retourné et rafraîchir l'enregistrement lors d'une rotation du token. La session est liée par le Bearer, pas choisie par le client. Prévoir liste et suppression des appareils.

FCM est optionnel côté serveur et nécessite une configuration et des essais réels. Les notifications ne contiennent pas le texte privé d'un message. Dédupliquer leur `notification_id`, car un doublon fournisseur est possible. À l'ouverture, valider la session et relire la ressource avant navigation. Gérer premier plan, arrière-plan, application arrêtée, permission refusée et lien devenu inaccessible.

**Implémentation L8 — 17 octobre 2026** : `features/notifications/{data,application,presentation}`, liste/retrait depuis profil/confidentialité uniquement après onboarding. Projection publique exacte (`id`, `session_id?`, plateforme, version/dates), sans token ni pagination. Une suppression concerne le push, pas l'authentification. Réponse perdue : relire la liste et conserver la même cible si le retrait n'est pas confirmé.

Choix utilisateur : pas encore de projet Firebase, préparer `.env` et laisser les push désactivés. Huit clés publiques `PUSH_ENABLED=false`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_BUNDLE_ID` ; aucune clé privée serveur ni fichier modèle. Avec ce flag, aucun SDK Firebase initialisé par Dart, aucune permission et aucun POST d'enregistrement depuis le client livré.

`firebase_core ^5.0.0`, `firebase_messaging ^17.0.0`, `package_info_plus ^10.2.2`. Options publiques explicites, ressources natives Android conditionnelles depuis `.env`, auto-init Messaging/Analytics désactivées et identifiants d'installation SDK 17 (`register`/`onRegistered`, champ API `push_token`). Permission explicite avant enregistrement, plateforme et version installée transmises. Rotation sérialisée et ancien enregistrement retiré après acceptation du nouveau ; corps incertain repris seulement à l'identique. Préférence sécurisée supplémentaire, séparée de l'entrée L2 : origine, propriétaire, choix, UUID d'appareil et 64 IDs ouverts maximum, aucun identifiant FCM ni contenu de notification copié dans ce stockage Dart. Retrait distant ou absence de préférence après réinstallation ne réactive rien automatiquement. L'arrêt conserve un marqueur sécurisé si le nettoyage échoue ; une reprise ne crée pas de nouvel enregistrement.

Bandeau générique au premier plan, 128 IDs de présentations en mémoire ; titre/texte/liens/expéditeur distants ignorés. Ouverture froide ou reprise via les callbacks SDK : attente d'identité vérifiée, relecture de session et collection mobile autorisée puis historique avant chat, aucun GET administratif. Déduplication des ouvertures liée au propriétaire/origine. Un autre clic remplace le parcours temporaire de notification en gardant ses brouillons ; autres flux chat/SSE suspendus puis repris. Les types facturation ouvrent depuis L9 l’écran d’abonnement, qui relit la projection privée du serveur. Handler arrière-plan sans session/HTTP privé/navigation/log ; l'OS affiche les alertes génériques du serveur et ses éventuels doublons ne sont pas effacés par la déduplication Dart.

Android compile ; les deux plist iOS, délégation UIScene et bridge APNs sont préparés. Avant activation, créer/configurer Firebase et le fournisseur API, puis sur Mac finaliser Push Notifications, `aps-environment`, signature et clé APNs Firebase. Aucune capacité de production inventée, aucune réception réelle ni compilation iOS effectuée. Dix contrôles L8 ciblés + treize contrôles existants de configuration réussis ; sept aperçus simulés inspectés, analyse sans problème, formatage et APK Android debug vérifiés. Contrats/DTO/services/tests/Postman backend consultés seulement. Références : [client Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/client), [réception](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [canaux Flutter](https://docs.flutter.dev/platform-integration/platform-channels).

## 12. Récompenses publicitaires

Les vidéos sont volontaires et réservées aux comptes Free éligibles. Vérifier `rewarded_advertising_enabled` et les réponses serveur ; le fournisseur est désactivé par défaut. Aucun droit de suivi publicitaire ne découle des consentements de rencontre.

Créer ou reprendre une intention avec la plateforme, transmettre au SDK l'unité et `custom_data` retournés, puis suivre l'intention. États : `pending`, `credited`, `expired`, `cancelled`. Annuler une intention abandonnée lorsque pertinent ; l'annulation invalide les preuves ultérieures.

Seul le callback signé vérifié côté serveur crédite le compte. Le callback local du SDK ne modifie jamais le solde. Après crédit confirmé, relire le quota. Gérer stock plein, inéligibilité, intention expirée et vérification indisponible sans promettre un crédit immédiat.

**État livré L6** : repository POST/GET/DELETE et `RewardTracker` préparés, plateforme de reprise conservée, polling progressif borné avec `Retry-After`, annulation confirmée et protection d'une vidéo terminée en attente. `expired` peut encore devenir `credited` via preuve tardive ; seul un GET propriétaire `credited` déclenche une relecture de quota. Aucun lancement/création de vidéo exposé dans l'interface, à la demande explicite de l'utilisateur. **SDK natif et UMP non installés**, raccordement manifestes/plist et configuration API/SSV à effectuer avant activation. Les IDs Android reçus sont renseignés dans `.env` (`ADMOB_ANDROID_APP_ID`, `ADMOB_ANDROID_REWARDED_AD_UNIT`), les clés iOS correspondantes restent vides. Leur remplissage n'active rien et ne remplace jamais `ad_unit`/`custom_data` serveur ; aucune valeur copiée dans Dart ou les manifestes. Le backend reste inchangé. Références consultées : Google [initialisation](https://developers.google.com/admob/flutter/quick-start), [vidéo et SSV](https://developers.google.com/admob/flutter/rewarded), [UMP](https://developers.google.com/admob/flutter/privacy).

**Contrôles L6** : huit contrôles ciblés réussis, plus treize contrôles existants de configuration et sept de chat. Coût/reprise/changement de formule/semaine, confidentialité de révélation, téléchargement après accord/purge/réponse tardive, invalidation de session, crédit exclusivement serveur et champs AdMob vérifiés. Cinq aperçus simulés en mode nuit inspectés ; petit écran/grand texte et navigation vérifiés. Analyse sans problème, formatage et APK Android debug réussis. Aucun essai entre deux comptes réels, de photo/vidéo/SSV réel ou d'iOS. Contrats/DTO/services/tests/Postman backend consultés seulement, jamais exécutés ni modifiés.

## 13. Offres et abonnement

Le catalogue expose maintenant trois offres commerciales dans `offers` : Free, Premium Mensuel et
Premium Annuel (catalogue initial : 0 EUR, 5 EUR/mois, 48 EUR/an). Le client affiche une carte par
offre dans le catalogue public et l'abonnement, avec prix/devise/essai serveur, facturation annuelle
en une fois et bouton associé à la bonne périodicité. `plan_code` relie chaque offre aux fonctionnalités
et quotas des deux niveaux `plans` Free/Premium. Déployer l'API avec `offers` avant l'app ; aucun prix
ni droit n'est inventé si le catalogue est incomplet. La disponibilité des ventes reste contrôlée séparément.

Charger `/api/plans` et l'état d'abonnement. Les prix mensuel/annuel, devise, essai et fonctionnalités viennent du serveur, sans valeur de secours métier dans l'app. Ne pas promettre un nouvel essai à un compte l'ayant déjà consommé.

Le client choisit uniquement `monthly` ou `annual` pour Checkout, avec une clé d'idempotence. Aucun Product ID, Price ID, Customer ID, montant ou durée d'essai n'est envoyé. Ouvrir l'URL retournée dans un navigateur approprié et traiter retour, annulation et reprise après fermeture. Une création incertaine se reprend avec la même clé et les mêmes paramètres dans les conditions du contrat ; ne pas multiplier les tentatives d'achat.

L'URL de succès ne prouve pas le paiement. Relire la projection serveur et `access_granted` pour les droits Premium, notamment après `subscription.updated`. Des mises à jour proviennent de webhooks et de la réconciliation serveur ; aucun endpoint d'activation locale n'existe. Le portail est disponible selon `customer_portal_available` et sa configuration serveur.

Avant activation des ventes, vérifier la documentation officielle Apple/Google applicable aux plateformes et marchés visés ; ne pas supposer que le Checkout web actuel convient à toutes les distributions. Une adaptation du backend peut être nécessaire selon la stratégie retenue. La consultation du catalogue et de l'abonnement peut avancer indépendamment de cette décision.

**Livré L9** : `features/billing/{data,application,presentation}`, écran depuis profil et push de facturation, thème nuit conservé. `access_granted` et plan effectif du GET sont l'autorité, avec état/date/essai/résiliation. Relecture au retour du navigateur, sur `subscription.updated`/reconnexion et à la réouverture de l'écran après arrêt. Pas d'activation locale depuis un lien ni de donnée de paiement transmise par l'app.

Choix utilisateur : Android hors Play Store avec Stripe, paiements et portail désactivés en attendant publication des retours HTTPS et validation Stripe test sur téléphone. Cinq champs publics `.env` : `BILLING_ENABLED=false`, `BILLING_DISTRIBUTION=android_external`, `BILLING_SUCCESS_URL=https://www.histae.com/billing/success?session_id={CHECKOUT_SESSION_ID}`, `BILLING_CANCEL_URL=https://www.histae.com/billing/cancel`, `BILLING_PORTAL_RETURN_URL=https://www.histae.com/billing/return`. Les trois liens doivent correspondre à ceux du serveur, succès avec `{CHECKOUT_SESSION_ID}` ; aucune clé secrète ni référence de prix dans l'app. Configuration locale, aucun feature flag API inventé ; iOS/Web/bureau fermés aux paiements. [Règles Play](https://support.google.com/googleplay/android-developer/answer/9858738), [Apple 3.1](https://developer.apple.com/app-store/review/guidelines/#payments), consultées le 17 octobre 2026. Toute future distribution par les stores exige une intégration adaptée.

Confirmation des conditions et du prix catalogue avant ouverture externe ; liens HTTPS Stripe standards strictement validés, sans en-tête d'authentification envoyé au navigateur. Entrées `/billing/success`, `/billing/cancel` et `/billing/return` dans `histae-site` : première langue prise en charge dans les préférences du navigateur, français en secours, paramètres conservés sans interprétation et choix manuel sans JavaScript. Les pages localisées ne lisent pas la session et ne confirment pas de paiement. Publication sur `histae.com`, report des URL dans le `.env` API du serveur et nouvelle compilation mobile encore nécessaires ; retour manuel au premier plan suivi d'un GET authentifié, aucun app link/lien universel automatique revendiqué. Le client ne remplace pas les liens configurés côté API. Le paiement dépend des webhooks et de la projection serveur, conformément à la [confirmation Stripe](https://docs.stripe.com/payments/existing-customers?platform=web&ui=stripe-hosted).

Stockage sécurisé séparé `histae.checkout.v1` : origine/propriétaire/UUID v4/période uniquement, écriture vérifiée avant POST. Reprise explicite identique après timeout, arrêt ou panne ; période bloquée tant que l'intention est ouverte. Clé consommée : relire les droits avant nouvelle tentative. Aucune URL, donnée bancaire, référence fournisseur ou permission Premium persistée. Portail selon configuration et `customer_portal_available`, erreurs françaises, respect `Retry-After`, annulation sur suspension et purge au changement de session/propriétaire. Dix contrôles ciblés et six aperçus simulés, dont petit écran/grandes polices. Stripe test, SCA/refus/essai/renouvellement/résiliation et retours réels après arrêt restent à valider ; aucun paiement fournisseur exécuté.

Vérifications complémentaires : treize contrôles de configuration existants et une régression de navigation push réussis ; formatage vérifié (110 fichiers), analyse sans problème, APK Android debug compilé. Aucune compilation iOS ou validation Stripe sur téléphone revendiquée. Aucun changement ni test exécuté côté backend.

## 14. Sûreté, droits et suppression

Signalements : `inappropriate_content`, `fake_profile`, `harassment`, `spam`, `other`, avec description optionnelle. Blocage et fin de match sont distincts ; après blocage `204`, invalider les profils et conversations concernés. Lister les blocages et permettre leur retrait, sans supposer qu'un déblocage restaure un match.

Demandes RGPD : `access`, `erasure`, `portability`, `rectification`, `restriction`, `objection`. Consulter les demandes et leur statut ; un dépôt de demande n'est pas une exécution immédiate. L'export JSON doit être partagé/enregistré explicitement et son fichier temporaire nettoyé avec précaution.

La suppression du compte exige un jeton dédié, puis `DELETE /api/users/me` avec `{ confirmation_token }`. Le `202 { request_id, status: "in_progress" }` désactive immédiatement le compte : fermer la session et expliquer que le nettoyage continue en arrière-plan. Ne pas attendre un `204` ni annoncer un effacement déjà terminé. Une réponse perdue peut laisser le Bearer invalide ; le retry n'est pas un mécanisme public de suivi. Conserver une formulation honnête si le résultat reste incertain.

Les consentements, demandes de droits, export et suppression ne doivent pas devenir inaccessibles à cause d'un onboarding ou d'une découverte incomplète lorsque l'API les autorise.

**Implémentation L7** : `features/privacy/{data,application,presentation}`, espace depuis profil/consentements incomplets. Signalement feed/reçu/chat/profil partenaire : validation UTF-8 brute 2 000 octets, motifs fermés, intention immuable jusqu'à fermeture de l'écran. Réponse perdue = reprise identique explicite ; `409` déjà en attente et `429` temporisé. Blocage séparé confirmé, gestion liste/déblocage sans photo ni restauration de match. Sessions limit/curseur opaque ; droits sans pagination, six types/statuts serveur. Mutations incertaines : cible/type conservé et relecture des collections, sans auto-POST.

Export : flux authentifié sur fichier privé sans redirection ni JSON complet en mémoire, maximum local 512 Mio et longueur exacte vérifiée. En-têtes 2 min, inactivité 30 s, durée 10 min. `share_plus ^13.3.1` sur action confirmée, réception jamais supposée. Nettoyage sérialisé limité aux propres fichiers `histae-export-<uuid>.json[.part]` dans `histae_private_exports` et leur copie `share_plus`, sans liens symboliques. Nettoyage au démarrage/sortie/suspension/perte de session, différé au retour d'un partage actif. Échecs repris, copies tierces hors contrôle Histae.

Suppression : saisie SUPPRIMER et confirmation finale, POST jeton dédié seulement ensuite, jamais persisté/journalisé. `SessionController` possède la requête terminale indépendamment de l'écran : attend la rotation, remplace durablement l'entrée sécurisée par `closing` sans refresh, purge les ressources puis envoie une seule requête. Aucun replay/refresh/GET de suivi après la barrière. `202` = compte inaccessible et nettoyage en cours ; résultat perdu = fermeture locale, acceptation distante inconnue. Redémarrage `closing` : aucune restauration réseau. Révocation courante et logout global partagent la protection. Si le stockage échoue avant barrière, aucune mutation terminale n'est envoyée.

**Vérifications L7** : neuf contrôles ciblés + dix-huit contrôles existants session/SSE réussis, neuf aperçus simulés en mode nuit inspectés (avant onboarding, navigation, petit écran/grand texte et sortie après 202). Analyse/formatage et APK Android debug vérifiés. Contrat, DTO/services/routes et tests Rust consultés seulement ; aucun test ni changement backend. Partage/export/suppression avec compte réel, interruptions/stockage natifs et iOS à valider. Le SDK Google déjà présent n'est pas activé : fournisseur Android automatique exclu tant que IDs natifs/UMP ne sont pas raccordés. Aucun ID réel ajouté aux documents publics.

## 15. Organisation Flutter et direction artistique

Structure L1 : `app` (application/navigation/thème), `core` (configuration, réseau, textes français, composants) et `features/catalog/{data,application,presentation}`. `CatalogController` utilise `ChangeNotifier`, le repository décode les DTO, le client HTTP est injecté. Aucune couche vide ajoutée pour les lots futurs. Les widgets ne manipulent ni secrets ni JSON réseau directement.

L2 ajoute `features/auth/{data,application,presentation}`, `features/consents/{data,presentation}`, `SessionController`, `OtpController` et un stockage sécurisé injectable. Le transport accepte méthode/corps/Bearer/clé sans retry. La navigation retire les écrans précédents au changement de session ; le retour système ne rouvre pas un écran privé après logout.

Choix L1 après consultation des documentations officielles : `http` pour les requêtes annulables, `Navigator` / `MaterialPageRoute` pour les deux écrans publics, `ChangeNotifier` pour leur état, `flutter_localizations` pour les libellés Material français. Les textes applicatifs sont centralisés dans `AppStrings` et les textes par fonctionnalité ; ajouter un délégué de traduction à l'introduction d'une seconde langue. Le mode nuit est appliqué par défaut à toute l'app, indépendamment du système, à la demande de l'utilisateur pendant L5 ; le thème clair reste défini. Les grandes polices restent autorisées. Chargement, vide, erreur réseau, délai dépassé et nouvelle tentative sont explicites.

La navigation distingue restauration, inscription/connexion, synchronisation, consentements requis, espace personnel et erreur de session/stockage. Aucune session n'est simulée dans l'app. Une découverte non prête ne verrouillera pas les fonctions autorisées ; les liens entrants nécessiteront session et ressource accessibles.

La DA suit désormais [le site Histae](https://www.histae.com/fr/) et les sources de `histae-site` : bleu nuit `#0D1421`, lavande `#B69CFF`, texte ivoire `#F9F7F2`, touches abricot `#F09A82`, halos discrets, boutons dégradés et panneaux fins. Le mot-symbole et les deux lignes qui se rejoignent sont adaptés au mobile. Inter et Source Serif 4 sont embarquées sous SIL OFL ; cette dernière transpose l'esprit des titres Georgia du site. Les anciens fichiers de police sont conservés. L'ensemble des pages partage le thème et le fond commun ; accueil, feed, profil, matchs, chat et catalogue ont une composition revue. Les gestes du feed et les contrôles métier restent ceux des lots précédents. Voir [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

## Refactoring transversal avant L10

Le 17 octobre 2026, refonte de l'app par responsabilité : `bootstrap` et `AppDependencies`, accueil/état de session, coordinateur de notification et bandeau séparés ; neuf interfaces de dépôts avec implémentations API. Les autres fonctionnalités utilisent le contrat `AuthenticatedSession`, sans dépendre de son contrôleur concret. `core` ne dépend plus des fonctionnalités ; parseurs, modèles publics communs, annulation et types de flux y sont regroupés. `SerialExecutor` ordonne stockage, purge et export sans retry ; `RetryTicker` centralise uniquement le rafraîchissement des délais. `MessageOutbox` possède les brouillons et intentions stables. Collections des contrôleurs et listes des principaux DTO protégées contre les mutations externes.

Les formulaires de profil, détails de confidentialité, profil partenaire, carte de formule et composants d'abonnement sont extraits. Les exports d'origine restent disponibles ; aucun fichier source supprimé. Analyse avec casts/inférence/types bruts stricts, règles d'imports et de ressources asynchrones. Dépendances et plateformes natives conservées, aucune migration d'outil imposée. Configuration mobile invalide `BILLING_ENABLED=stripe` corrigée en `false` ; aucune fonction fournisseur activée. Voir [architecture](ARCHITECTURE.md) pour les règles de maintenance. L10 et les essais réels restent à effectuer.

Refonte achevée le 18 octobre 2026 : plus de mutation de dépôt directement depuis les formulaires, service de chargement photo partagé et annulable (5 Mo, quinze secondes, sans Bearer/redirection/cache disque). Vérifications : 166 contrôles globaux puis 39 ciblés, dont le troisième nouveau contrôle ; 167 contrôles distincts réussis. Analyse sans problème, 143 fichiers formatés, APK Android debug compilé. Quatre scénarios visuels, 22 aperçus simulés, planche d'ensemble et vues représentatives inspectées. Ces contrôles ne valident pas un fournisseur réel ou iOS sur Mac.

## 16. Stockage et validation

Persister le strict nécessaire : refresh sécurisé, préférences d'interface et identifiants publics utiles. Garder initialement profils, feed, matchs et messages en mémoire ou dans un cache effaçable. Toute persistance ultérieure doit être justifiée, protégée et invalidable. Ne pas persister durablement OTP, coordonnées exactes, exports ou URL photo signées par défaut.

L2 persiste une seule entrée sécurisée (origine, phase, refresh à l'état `ready`), sans access token, téléphone, OTP, identité ni consentements. Android : API 24 minimum réel du package, sauvegarde désactivée et préférences exclues des transferts. iOS : Keychain `unlocked_this_device`, entitlements sur les trois configurations. Une erreur ou relecture incohérente du stockage ferme l'accès ; comportement natif encore à éprouver sur appareils.

Aucun jeton, téléphone, position exacte, message privé ou URL signée dans les logs ou rapports de crash. Au changement de compte, empêcher tout mélange des caches, requêtes et connexions en cours.

Les tests Flutter pertinents couvrent sérialisation, erreurs, rotation concurrente, idempotence, navigation, consentements et états critiques. Les tests ordinaires n'envoient aucun SMS réel, ne créditent aucune publicité réelle et n'effectuent aucun paiement. Les essais de fournisseur utilisent les environnements dédiés. Documenter séparément analyse/tests automatisés, intégration API et validation sur appareils Android/iOS.

## 17. Vérifications et limites restantes

L1 est implémenté : accueil/catalogue, origine configurable, thèmes et erreurs typées. Le client envoie un UUID v4 `X-Request-ID`, ne suit pas les redirections et n'effectue aucun retry ni refresh automatique. Timeout couvrant en-têtes et corps ; annulation à la fermeture/suspension, réponses tardives ignorées, reprise de la seule lecture interrompue. `Retry-After` en secondes ou date interdit la nouvelle tentative avant échéance. Les erreurs conservent seulement statut, code, identifiant de demande validé et délai ; aucun corps, message anglais ou URL n'est journalisé. Le catalogue reste en mémoire, sans persistance et sans action d'achat.

Les fixtures suivent les DTO Rust ; valeurs et identifiants sont simulés. Historique L3 : suite de 107 puis 23 contrôles ciblés réussis (110 présents fin L3). L4 a ajouté huit contrôles, L5 neuf, L6 huit, L7 neuf, L8 dix et L9 dix ; exécutions ciblées sur les risques. Seul le catalogue a été validé en réseau réel ; aucun SMS, compte privé, upload, échange, export/suppression ou SSV réel testé. Prochain lot : **L10**, qualité et bêta ; activation paiements, push et vidéos suivie séparément.

L10 reste à construire ; L9 attend Stripe test et les retours HTTPS pour activer les ventes. Le raccordement natif/UMP publicitaire reste à construire. Les capacités serveur photo, SMS, push, publicité et Stripe nécessitent configuration et validations réelles ; leur présence dans le code ne prouve pas leur disponibilité. Signatures mobiles, liens de retour, permissions métier, règles de distribution et déclarations de confidentialité restent à préparer. Les deux plist iOS sont à maintenir ensemble et à compiler sur Mac ; aucune validation iOS sur cet hôte Windows. Consulter la roadmap production API sans masquer ses limites par une simulation mobile.




## 18. Logo et ouverture

Le 18 octobre 2026, application du livre ouvert original **02 / Les pages** : logo autonome ; nom Histae en accompagnement facultatif. Les en-têtes mobiles et ceux du site, son pied de page et ses icônes utilisent cette identité. Les icônes Android/iOS affichent uniquement le livre, avec calques adaptatifs et monochrome sur Android. Les anciennes recherches sont conservées.

Ouverture de 1,48 s : H. collés, écartement et révélation de istae, livre au-dessus, puis fondu. Elle laisse la restauration et la navigation vivantes, ignore la présentation si les animations sont désactivées et ne se rejoue pas au retour d'arrière-plan. 21 contrôles ciblés, analyse et APK Android vérifiés ; export et contrôles du site réussis. Icônes iOS générées, compilation/essais natifs sur Mac encore à faire. Aucun déploiement du site ni activation fournisseur. Prochain lot : L10.

## 19. Ajustements et activation Stripe — 19 octobre 2026

Boutons Premium et Vidéos ajoutés sur feed/profil, navigation suspendant la découverte et protégée par la session. Fond de navigation coloré jusque sous l’inset et style système racine. Icône Android adaptative réduite de 20 % ; PNG Android/iOS réduits d’environ 15 %. Logo accompagnant le nom conservé.

L’utilisateur a demandé `BILLING_ENABLED=true` : activation dans le `.env` mobile local pour Android externe avec les URL HTTPS déjà présentes, sans clé secrète côté client. La configuration API locale contient les paramètres requis, dont une clé Stripe live et les deux blocs AdMob ; les blocs et retours correspondent à l’app. Le catalogue en ligne confirme les vidéos pour Free et les retours Stripe répondent 200. Aucun changement de code/configuration de l’API. Aucune transaction réelle ni livraison de webhook vérifiée. Le blocage vidéo identifié se situe dans l’app : raccordement natif/SDK/UMP encore à construire ; bouton de lecture visible et désactivé en attendant.

16 contrôles ciblés et un nouveau parcours de navigation, analyse et APK debug ; six aperçus simulés dont texte à 200 % avec insets système. L10 et les essais fournisseur restent ouverts. Les anciennes mentions de paiements désactivés sont historiques.

## 20. Feed dégagé, formule dans le profil et crédits dans Matchs

Le 19 octobre 2026, à la demande utilisateur, retrait des boutons Premium/Vidéos du feed. Le profil affiche Premium pour Free et Mon abonnement pour Premium d’après la formule effective du quota serveur. En cas de lecture inconnue, le libellé neutre ouvre l’abonnement, sans présumer d’un besoin d’achat. Matchs expose séparément les crédits gratuits et publicitaires disponibles, via `free_remaining` et `advertising_remaining`, plus Vidéos pour Free. Premium n’affiche aucun bouton vidéo et annonce ses continuations sans crédit. Le suivi des anciennes récompenses reste consultable.

Retour des crédits/de l’abonnement, reprise et changement d’onglet relisent le quota ; les lectures périmées ne décident pas du libellé ou du solde. Les entrées des onglets activent leur lecture après démontage du précédent ; la suspension d’un ancien écran n’annule plus la lecture du nouveau. Reprise du chat préservée.

22 contrôles ciblés et dix aperçus simulés, analyse et APK debug vérifiés. Stripe reste activé localement pour Android externe ; lecture vidéo toujours en attente de SDK/UMP. Aucun changement API ni paiement, crédit publicitaire ou SMS réel. L10 et les essais iOS restent ouverts.


## 21. Vos crédits et vidéos raccordées

Le 19 octobre 2026 : refonte de Vos crédits autour du solde réellement disponible, des cartes Gratuits/Vidéos et de la progression de semaine. Détails repliables, panneau Premium sans vidéo, réserve pleine et erreur avec explication. La mention indisponible venait du bouton désactivé et du SDK non raccordé. Le catalogue public confirme les vidéos Free.

AdMob/UMP est maintenant raccordé : IDs natifs du `.env`, consentement publicitaire distinct, requête explicite, `ad_unit`/`custom_data` de l’intention, aucun identifiant utilisateur persistant. SDK sans pouvoir de crédit : seule la réponse serveur `credited` déclenche la relecture. Nettoyage des tentatives non visionnées, pas d’annulation implicite d’une vidéo terminée ou incertaine, callbacks tardifs ignorés après déconnexion. Le cycle de vie des surcouches natives ne suspend plus le suivi via le MatchesPage sous-jacent.

19 contrôles ciblés, analyse et APK Android debug ; six états visuels inspectés, dont grande police. Aucun appel publicitaire réel ni modification backend. Consoles UMP/SSV et diffusion réelle à vérifier sur appareil de test ; compilation/essais iOS restent à faire sur Mac. Aucun fichier supprimé ni commande Git exécutée.


## 22. Profil, réponses et retrait des consentements

Le 19 octobre 2026, refonte de Votre espace Histae et de l’éditeur des réponses. Aperçu des textes/modérations, recherche des questions, exclusion des doublons, ordre et retrait, limite de trois, compteur et pied d’enregistrement. Remplacement complet toujours confirmé et brouillon sans mutation implicite.

Le retrait existait sous Retirer mon accord ; son libellé est maintenant Retirer mon consentement. Pour un compte à jour, les choix sensibles/localisation apparaissent avant les documents nécessaires. CGU et notice sans retrait selon le contrat API, avec explication et accès à la gestion du compte.

Journaux UMP lus sur l’émulateur : `no form(s) configured for the input app ID`, avec ID correspondant au `.env`. Réponse à la question utilisateur : aucune modification API pour Réglementations européennes ; créer/associer/publier le message dans AdMob avec la politique de confidentialité. Erreurs d’app plus précises, reprise sur consentement antérieur uniquement si `canRequestAds` le permet, quota préservé pendant les surcouches natives depuis Profil aussi. Aucun identifiant réel copié dans les documents.

25 contrôles ciblés, analyse sans problème, 12 captures dont grandes polices/clavier et APK Android debug. Aucun appel publicitaire nouveau ou changement backend ; publication du message AdMob et validation réelle SSV restent à effectuer. Aucun fichier supprimé ou commande Git exécutée.


## 23. Barre de progression de Matchs

Le 19 octobre 2026, correction de l’alternance bas/haut signalée dans Matchs. La liste et les crédits possédaient deux barres ; leurs lectures successives et la connexion au temps réel les faisaient se relayer. MatchesPage affiche maintenant une seule barre fixe, dans une zone de hauteur constante sous l’en-tête. Les opérations d’aperçu regroupent leurs phases et une traction pendant le démarrage ne relance pas celui-ci. Les retours de chat/crédits conservent leurs lectures ; l’ouverture d’une conversation entrante n’attend pas le quota.

12 contrôles ciblés réussis, dont un nouveau vérifiant l’unique position pendant des réponses différées puis une panne, et analyse Flutter propre. Aucun changement API, fichier supprimé ou commande Git. Rendu réel à confirmer sur l’émulateur après mise à jour de l’APK.

## 24. Libellé de l’abonnement pendant l’actualisation

Le 19 octobre 2026, le profil conserve le dernier statut reçu pendant la relecture du quota : Premium ne devient plus temporairement Mon abonnement. Le résultat serveur met toujours à jour le bouton ; une lecture en échec ou une invalidation de session conserve le traitement neutre existant. Aucun cache supplémentaire ni changement API.

Trois contrôles ciblés réussis, dont une réponse différée vérifiant les transitions Free/Premium et l’échec de lecture ; analyse Flutter sans problème.

## 25. Interrupteurs des consentements

Le 19 octobre 2026, remplacement des cases et boutons de retrait par un interrupteur par carte. CGU/notice verrouillées une fois acceptées, selon le contrat API lu sans modification. Sensible/localisation nécessaires au feed mais retirables ; confirmation de l’effacement conservée. Réactivation immédiate pour un compte à jour, sans afficher de succès avant la réponse serveur. Inscription toujours explicite et groupée par Enregistrer mes choix.

Suppression des numéros de version, de la mention d’accord enregistré et des explications sous les cartes. Versions toujours vérifiées avant mutation, anciens accords retirables sans accepter leur remplacement. Mise en page adaptée à 200 %. Huit contrôles ciblés réussis, analyse propre, aperçus visuels vérifiés et APK Android debug compilé ; aucun appel réel ni changement backend.

## 26. Distinction documents et consentements

Le 19 octobre 2026, remplacement des interrupteurs CGU/notice acceptées par les mentions CGU acceptées et Notice consultée, avec liens documentaires. Cases à cocher pour l’acceptation initiale ou le renouvellement, sans présélection ; seuls les véritables accords sensibles/localisation gardent un interrupteur. Introduction simplifiée sans mention de verrouillage. Les validations exigées par le contrat API sont conservées sans en déduire une conformité RGPD globale.

Huit contrôles ciblés réussis, analyse Flutter propre et aperçus vérifiés à taille normale et 200 %. Aucun changement backend ni appel réel.
