# Résumé fonctionnel et règles d’intégration

Ce document décrit les parcours mobiles et leurs contraintes. Le [README](README.md) couvre le lancement, l’[architecture](ARCHITECTURE.md) les responsabilités du code, et la [roadmap](roadmap.md) l’avancement.

Le backend de référence est [histae-api-rust](../histae-api-rust/docs/README.md). Les DTO, erreurs, limites et autorisations détaillées viennent de son [contrat HTTP](../histae-api-rust/docs/http-contract.md). Le mobile ne contient ni administration ni appels à `/api/admin/*`.

## Accès au compte et consentements

Créer un compte et se reconnecter utilisent le même parcours OTP : téléphone français normalisé en `+33`, code SMS, puis lecture de l’identité et des consentements. Aucun mot de passe ou endpoint d’inscription distinct n’est ajouté. Une demande de SMS acceptée ne prouve pas sa livraison ; une vérification dont le résultat est perdu exige un nouveau code.

L’accès privé dépend des documents courants exigés par l’API. Les CGU sont acceptées et la notice de confidentialité est reconnue comme consultée. Les nouveaux choix ne sont pas présélectionnés. Les accords sensibles et de localisation sont distincts et modifiables ; leur retrait est confirmé en expliquant ses effets. La permission native de localisation ne remplace pas cet accord.

Le retrait sensible efface les données concernées, dont sexe et préférences ; le retrait de localisation efface la présence. Ces retraits peuvent rendre le feed indisponible sans fermer tous les réglages du compte. Déconnexion, droits, export et suppression restent accessibles quand l’API les autorise avant la fin de l’onboarding.

Avant un enregistrement, l’app compare version, URL et langue du document à ceux réellement présentés. Le PUT actuel n’envoie pas de version attendue : le précontrôle mobile ne garantit donc pas l’atomicité si le document change entre lecture et écriture. Cette limite doit être traitée côté API pour une garantie complète.

## Profil, réponses et photo

Le profil est réservé aux majeurs. Les modifications envoient explicitement l’état voulu de la bio et du sexe ; les préférences sont enregistrées ensemble. Traits et questions viennent des catalogues de l’API.

Le propriétaire peut gérer zéro à trois réponses ordonnées. L’enregistrement remplace la liste complète et demande confirmation, y compris pour un effacement. Chaque réponse respecte les limites du modèle et du contrat. Le propriétaire voit les états de modération ; les projections publiques ne montrent que les textes approuvés.

Une seule photo privée peut être choisie, remplacée ou retirée. L’app prépare un JPEG sans EXIF, corrige son orientation et limite l’envoi à 500 000 octets. Une reprise conserve les mêmes octets et la même clé d’idempotence. Les URL signées restent temporaires, sans cache disque ni téléchargement partenaire anticipé.

L’aperçu de son profil réutilise les composants du feed avec les textes publics approuvés. Il n’invente ni distance ni photo et ne permet pas de swiper son propre profil.

## Feed, localisation et pause

Le diagnostic serveur guide les étapes nécessaires à la découverte. La position est demandée ponctuellement, après accord métier et permission système ; l’app ne suit pas les déplacements en arrière-plan et ne réutilise pas une ancienne mesure native. Une présence expirée masque le lot localement jusqu’à l’actualisation ou une action appropriée.

Le feed présente prénom, âge, distance reçue, bio, traits et réponses sans photo. Un double appui permet d’aimer ; le geste de passage commence en fin de lecture pour préserver les profils longs. Des boutons offrent les mêmes actions. Une intention incertaine ne peut être reprise qu’avec la même cible et la même décision.

Deux likes réciproques peuvent créer un match, confirmé par la réponse serveur. Le mode pause est un réglage du compte partagé entre appareils : il masque les nouvelles découvertes et suspend les nouveaux likes/matchs, tout en conservant les conversations existantes. Son déploiement serveur est nécessaire à son fonctionnement.

## Matchs et messages

Les états `active` et `confirmed` permettent l’envoi selon les droits reçus ; `awaiting_continuation` conserve l’historique et suspend la composition. Les échéances locales désactivent les actions sans fabriquer un nouvel état serveur.

Les messages et curseurs suivent l’ordre du serveur. Un envoi conserve texte et UUID après réponse perdue ; sa reprise reste explicite. Les accusés de lecture concernent uniquement les messages reçus visibles au premier plan. Le temps réel est partagé entre parcours ; une notification vérifie les autorisations avant d’ouvrir une conversation.

Terminer un match et bloquer une personne sont des actions distinctes, confirmées. Débloquer ne restaure pas automatiquement une rencontre. Les données devenues inaccessibles sont purgées et les réponses tardives ignorées.

## Révélation, continuations et crédits

La photo du partenaire ne devient affichable qu’après révélation mutuelle confirmée par l’API. Les liens et octets sont évincés à la perte d’accès, à la fermeture ou à leur échéance d’affichage ; réouvrir la vue ne renouvelle pas cette échéance.

Avant une continuation, l’app relit la rencontre et le quota puis présente le coût personnel à accepter. Elle envoie `credit_cost` sans calculer le débit localement. Un changement de formule ou une offre devenue trop ancienne exige une nouvelle présentation ; une reprise incertaine garde le coût accepté.

Matchs distingue les crédits gratuits disponibles, les crédits publicitaires disponibles et le plafond hebdomadaire. Les réservations ne sont pas affichées comme disponibles. Premium dispose de continuations sans crédit ; une erreur de lecture ne produit pas un faux zéro.

## Vidéos, notifications et abonnement

Les vidéos récompensées sont volontaires et réservées aux comptes Free éligibles. L’intention API fournit l’unité et `custom_data` ; UMP gère les préférences publicitaires indépendamment des consentements Histae. Le rappel du SDK déclenche le suivi, jamais un crédit local. Seule la validation serveur autorise la mise à jour du quota.

Les push nécessitent configuration Firebase, activation volontaire, permission native et enregistrement auprès de l’API. Le bandeau de l’app reste générique et les ouvertures sont dédupliquées. Retirer un appareil push ne révoque pas sa session de connexion.

Les offres et leurs prix proviennent de `plans` et `offers`. Les niveaux de droits restent Free/Premium, avec périodicité mensuelle ou annuelle pour Checkout. L’intégration de paiement actuelle vise Android hors Play Store ; les versions stores nécessitent une intégration adaptée. Une URL de succès ou l’ouverture du navigateur ne prouve jamais un accès Premium : seule la projection de l’API le confirme.

## Vie privée et suppression

L’espace Vie privée regroupe documents, accords modifiables, sessions, appareils, blocages, demandes de droits, export et suppression. Une demande de droits déposée n’est pas une exécution immédiate.

L’export est téléchargé dans un fichier privé temporaire puis partagé sur action explicite. Son nettoyage reste limité aux fichiers appartenant à l’app ; les copies enregistrées ailleurs échappent à ce nettoyage.

La suppression nécessite une confirmation et un jeton dédié. Un `202` ferme l’accès au compte et annonce un nettoyage en cours. Une réponse perdue entraîne une fermeture locale avec un résultat distant incertain, sans affirmer que l’effacement est terminé.

## Règles communes

Les onglets et lectures déjà obtenues restent en mémoire pendant la session. Actualisation manuelle, action métier, changement de langue et événement pertinent peuvent imposer de nouvelles lectures. Les règles du cache et de sa purge sont détaillées dans l’[architecture](ARCHITECTURE.md).

Les curseurs sont opaques, les dates métier sont traitées avec leur fuseau et les erreurs par code. Respecter `Retry-After` ; ne pas ajouter de retry universel sur les mutations. Les secrets restent côté serveur et les données privées hors des logs.

L’interface est disponible en quatre langues. Les bios, réponses et messages des personnes ne sont jamais traduits automatiquement ; la langue des catalogues et documents dépend du contrat décrit dans le [guide API](docs/api-languages.md).

Les tests et aperçus utilisent des données simulées. La livraison du code, la disponibilité de l’API et la validation sur appareils/fournisseurs sont suivies séparément dans la [roadmap](roadmap.md).
