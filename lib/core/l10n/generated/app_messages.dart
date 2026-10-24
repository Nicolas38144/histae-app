import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_messages_en.dart';
import 'app_messages_es.dart';
import 'app_messages_fr.dart';
import 'app_messages_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppMessages
/// returned by `AppMessages.of(context)`.
///
/// Applications need to include `AppMessages.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_messages.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppMessages.localizationsDelegates,
///   supportedLocales: AppMessages.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppMessages.supportedLocales
/// property.
abstract class AppMessages {
  AppMessages(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppMessages of(BuildContext context) {
    return Localizations.of<AppMessages>(context, AppMessages)!;
  }

  static const LocalizationsDelegate<AppMessages> delegate =
      _AppMessagesDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
    Locale('es'),
    Locale('it'),
  ];

  /// Interface: lib/app/app_opening.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae'**
  String get appOpeningHistae;

  /// Interface: lib/app/main_navigation_bar.dart
  ///
  /// In fr, this message translates to:
  /// **'Feed'**
  String get mainNavigationBarFeed;

  /// Interface: lib/app/main_navigation_bar.dart
  ///
  /// In fr, this message translates to:
  /// **'Matchs'**
  String get mainNavigationBarMatches;

  /// Interface: lib/app/main_navigation_bar.dart
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get mainNavigationBarProfile;

  /// Interface: lib/app/notification_overlay.dart
  ///
  /// In fr, this message translates to:
  /// **'Une mise à jour Histae est disponible.'**
  String get notificationOverlayAHistaeUpdateIsAvailable;

  /// Interface: lib/app/notification_overlay.dart
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get notificationOverlayLater;

  /// Interface: lib/app/welcome_page.dart
  ///
  /// In fr, this message translates to:
  /// **'D’ABORD, UNE CONVERSATION'**
  String get welcomePageAnotherWayToMeet;

  /// Interface: lib/app/welcome_page.dart
  ///
  /// In fr, this message translates to:
  /// **'À votre rythme. Et toujours à deux.'**
  String get welcomePageTimeReciprocityConsent;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'LES MOTS D’ABORD'**
  String get appStringsWordsFirst;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Faisons connaissance.'**
  String get appStringsLetSGetToKnowYou;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Heureux de vous retrouver.'**
  String get appStringsGoodToSeeYouAgain;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'En toute confiance.'**
  String get appStringsWithConfidence;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get appStringsSignIn;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get appStringsCreateMyAccount;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'J’ai déjà un compte'**
  String get appStringsIAlreadyHaveAnAccount;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Mon espace'**
  String get appStringsMySpace;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro reste privé. Un code reçu par SMS vous permettra de créer votre compte ou de vous reconnecter.'**
  String get appStringsVerifyYourNumberWithACode;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Avant de continuer, prenez le temps de lire les documents et de compléter les choix nécessaires.'**
  String get appStringsCompleteTheRequiredChoicesIndicatedBy;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Un instant…'**
  String get appStringsWorking;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Numéro français au format +33'**
  String get appStringsFrenchPhoneNumberStartingWith33;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Saisissez +33 suivi des 9 chiffres, sans le zéro initial.'**
  String get appStringsEnter33FollowedBy9Digits;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Demander un code'**
  String get appStringsRequestACode;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Demander un nouveau code'**
  String get appStringsRequestANewCode;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre l’envoi du code'**
  String get appStringsResumeThePreviousRequest;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification à 6 chiffres'**
  String get appStrings6DigitVerificationCode;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifier le code'**
  String get appStringsVerifyCode;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Changer de numéro'**
  String get appStringsChangeNumber;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre demande est prise en compte. Saisissez le code dès que vous le recevez.'**
  String get appStringsYourRequestWasAcceptedThisDoes;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu terminer la connexion. Demandez un nouveau code pour réessayer.'**
  String get appStringsVerificationCouldNotBeConfirmedRequest;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous vous retrouvons…'**
  String get appStringsCheckingYourSession;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre session n’est pas accessible'**
  String get appStringsYourSessionIsUnavailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get appStringsSignOut;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes déconnecté.'**
  String get appStringsYouAreSignedOut;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes déconnecté sur cet appareil. La révocation de la session sur le serveur n’a pas pu être confirmée.'**
  String get appStringsYouAreSignedOutOnThis;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos choix et votre vie privée'**
  String get appStringsYourChoicesAndPrivacy;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos consentements'**
  String get appStringsYourConsents;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez ici les conditions d’utilisation et la notice de confidentialité. Vous pouvez modifier séparément vos accords sur les données sensibles et la localisation.'**
  String get appStringsFindTheTermsOfUseAnd;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer mes choix'**
  String get appStringsSaveMyChoices;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser mes consentements'**
  String get appStringsRefreshMyConsents;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer mon consentement'**
  String get appStringsWithdrawMyConsent;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le retrait'**
  String get appStringsConfirmWithdrawal;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get appStringsCancel;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le document n’a pas pu être ouvert. Vérifiez votre connexion et réessayez.'**
  String get appStringsTheDocumentCouldNotBeOpened;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Lire le document'**
  String get appStringsReadDocument;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les documents ont changé. Relisez les nouvelles versions avant de confirmer vos choix.'**
  String get appStringsTheDocumentsHaveChangedReadThe;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos choix ont été enregistrés.'**
  String get appStringsYourChoicesHaveBeenSaved;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get appStringsYourHistaeSpace;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est créé et vos consentements obligatoires sont à jour. Vous pourrez compléter votre profil lors de la prochaine mise à jour.'**
  String get appStringsYourAccountIsCreatedAndYour;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez consulter vos documents, gérer vos consentements ou vous déconnecter ici, même si votre parcours n’est pas terminé.'**
  String get appStringsYouCanViewYourDocumentsManage;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un numéro français valide au format +33.'**
  String get appStringsEnterAValidFrenchPhoneNumber;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Saisissez les six chiffres du code reçu.'**
  String get appStringsEnterTheSixDigitsOfThe;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le code est invalide ou a expiré.'**
  String get appStringsTheCodeIsInvalidOrHas;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le SMS n’a pas pu partir. Vous pouvez reprendre l’envoi.'**
  String get appStringsTheSmsCouldNotBeSent;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu vérifier l’envoi. Le code peut encore arriver : vous pouvez le saisir ou reprendre l’envoi.'**
  String get appStringsSmsDeliveryIsUncertainTheCode;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette demande ne peut plus être reprise. Demandez un nouveau code.'**
  String get appStringsThisRequestNoLongerMatchesIts;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n’est pas disponible.'**
  String get appStringsThisAccountIsUnavailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Prendre le temps de se rencontrer.'**
  String get appStringsTakeYourTimeToMeet;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Un détail qui fait sourire. Une réponse qui donne envie d’en savoir plus. Ici, les mots passent avant les photos, que vous choisissez de dévoiler à deux.'**
  String get appStringsDiscoverSomeoneThroughTheirWordsPhotos;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Découvrir les formules'**
  String get appStringsExplorePlans;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les formules Histae'**
  String get appStringsHistaePlans;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Consultez les formules et leurs conditions. La révélation des photos demande toujours votre accord mutuel.'**
  String get appStringsExplorePlansAndTheirConditionsRevealing;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez votre abonnement et les possibilités de souscription depuis votre profil.'**
  String get appStringsViewYourSubscriptionAndSignUp;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Chargement des formules…'**
  String get appStringsLoadingPlans;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune formule disponible'**
  String get appStringsNoPlansAvailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les formules ne sont pas disponibles pour le moment.'**
  String get appStringsPlansAreCurrentlyUnavailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get appStringsTryAgain;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Service non configuré'**
  String get appStringsServiceNotConfigured;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le service n’est pas encore configuré pour cette version de l’application.'**
  String get appStringsTheServiceIsNotYetConfigured;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les formules'**
  String get appStringsUnableToLoadPlans;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Connexion indisponible'**
  String get appStringsConnectionUnavailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nouvel essai possible dans {arg0} s'**
  String appStringsTryAgainInS(Object arg0);

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Référence de la demande : {arg0}'**
  String appStringsRequestReference(Object arg0);

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Crédits inclus par semaine : {arg0}'**
  String appStringsCreditsIncludedPerWeek(Object arg0);

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Continuations par semaine : {arg0} maximum'**
  String appStringsContinuationsPerWeekUpTo(Object arg0);

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Continuations sans plafond hebdomadaire'**
  String get appStringsNoWeeklyLimitOnContinuations;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Stock maximal de crédits publicitaires : {arg0}'**
  String appStringsMaximumVideoCreditBalance(Object arg0);

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Publicités retirées'**
  String get appStringsAdsRemoved;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Publicités non retirées'**
  String get appStringsAdsNotRemoved;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Récompenses publicitaires activées pour cette formule'**
  String get appStringsVideoRewardsEnabledForThisPlan;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Récompenses publicitaires indisponibles pour cette formule'**
  String get appStringsVideoRewardsUnavailableForThisPlan;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Révélation mutuelle des photos'**
  String get appStringsMutualPhotoReveal;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Poursuivre une conversation'**
  String get appStringsContinueAConversation;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Récompenses vidéo volontaires'**
  String get appStringsOptionalVideoRewards;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Sans publicité'**
  String get appStringsAdFree;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Échangez pendant la période initiale, puis après votre accord mutuel de continuation.'**
  String get appStringsChatDuringTheInitialPeriodThen;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les photos se révèlent après votre accord à tous les deux.'**
  String get appStringsPhotosAreRevealedAfterYouBoth;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Chaque personne donne son accord et utilise ses propres droits.'**
  String get appStringsEachPersonAgreesSeparatelyAndUses;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre crédit s’ajoute après la validation de la vidéo.'**
  String get appStringsTheServerValidatesTheRewardBefore;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette formule retire les publicités.'**
  String get appStringsThisPlanRemovesAds;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le stockage sécurisé est indisponible. Déverrouillez votre appareil et réessayez. La connexion reste fermée.'**
  String get appStringsSecureStorageIsUnavailableUnlockYour;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La session ne peut pas être restaurée avec certitude. Reconnectez-vous avec un nouveau code.'**
  String get appStringsYourSessionCannotBeRestoredWith;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’arrivons pas à joindre Histae. Vérifiez votre connexion et réessayez.'**
  String get appStringsTheServiceCannotBeReachedCheck;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cela prend plus de temps que prévu. Vous pouvez réessayer.'**
  String get appStringsTheServiceIsTakingTooLong;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu lire la réponse. Vérifiez le résultat avant de réessayer.'**
  String get appStringsTheServiceResponseCouldNotBe;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette action n’a pas pu aboutir. Vérifiez vos informations et réessayez.'**
  String get appStringsTheServiceDidNotAcceptThe;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une connexion au compte est nécessaire.'**
  String get appStringsPleaseSignInToYourAccount;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les consentements requis doivent être complétés.'**
  String get appStringsCompleteTheRequiredConsents;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Encore quelques mots sur vous avant de découvrir les autres.'**
  String get appStringsCompleteYourProfileToDiscoverPeople;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le quota disponible ne permet pas cette action.'**
  String get appStringsYourAvailableAllowanceDoesNotPermit;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette action n’est pas autorisée actuellement.'**
  String get appStringsThisActionIsCurrentlyNotAllowed;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le contenu demandé n’est plus accessible.'**
  String get appStringsTheRequestedContentIsNoLonger;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La situation a changé. Actualisez avant de réessayer.'**
  String get appStringsThingsHaveChangedRefreshBeforeTrying;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu a expiré.'**
  String get appStringsThisContentHasExpired;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le contenu envoyé dépasse la taille autorisée.'**
  String get appStringsTheSubmittedContentExceedsTheAllowed;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes ont été envoyées. Patientez avant de réessayer.'**
  String get appStringsTooManyRequestsWaitBeforeTrying;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le service est temporairement indisponible.'**
  String get appStringsTheServiceIsTemporarilyUnavailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le chargement a été interrompu.'**
  String get appStringsLoadingWasInterrupted;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu vérifier le résultat. Actualisez avant de réessayer.'**
  String get appStringsTheServiceReturnedAnUnexpectedResponse;

  /// Interface: lib/core/widgets/account_benefits_actions.dart
  ///
  /// In fr, this message translates to:
  /// **'Premium'**
  String get accountBenefitsActionsPremium;

  /// Interface: lib/core/widgets/account_benefits_actions.dart
  ///
  /// In fr, this message translates to:
  /// **'Mon abonnement'**
  String get accountBenefitsActionsMySubscription;

  /// Interface: lib/core/widgets/confirmation_dialog.dart
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirmationDialogConfirm;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Période d’essai'**
  String get billingStringsTrialPeriod;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Abonnement actif'**
  String get billingStringsActiveSubscription;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Paiement à régulariser'**
  String get billingStringsPaymentNeedsAttention;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Paiement à terminer'**
  String get billingStringsCompletePayment;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Souscription expirée'**
  String get billingStringsSubscriptionExpired;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Abonnement résilié'**
  String get billingStringsSubscriptionCanceled;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Paiement impayé'**
  String get billingStringsUnpaid;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Abonnement en pause'**
  String get billingStringsSubscriptionPaused;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre formule actuelle'**
  String get billingStringsYourCurrentPlan;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos droits ont été confirmés par Histae.'**
  String get billingStringsYourEntitlementsHaveBeenConfirmedBy;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Un abonnement existe déjà. Actualisez votre situation avant de poursuivre.'**
  String get billingStringsASubscriptionAlreadyExistsRefreshYour;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le paiement est temporairement indisponible. Votre tentative est conservée.'**
  String get billingStringsPaymentIsTemporarilyUnavailableYourAttempt;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Connexion interrompue. Le résultat reste à vérifier ; votre tentative est conservée.'**
  String get billingStringsConnectionInterruptedTheResultStillNeeds;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Veuillez patienter avant de réessayer.'**
  String get billingStringsPleaseWaitBeforeTryingAgain;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le stockage sécurisé est indisponible. Aucun nouveau paiement ne peut être ouvert.'**
  String get billingStringsSecureStorageIsUnavailableNoNew;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La réponse ne permet pas de confirmer votre situation. Actualisez avant de poursuivre.'**
  String get billingStringsTheResponseDoesNotConfirmYour;

  /// Interface: lib/features/billing/presentation/billing_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement ne peut pas être vérifié pour le moment. Réessayez plus tard.'**
  String get billingStringsYourSubscriptionCannotBeCheckedRight;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Poursuivre avec {arg0}'**
  String subscriptionPageContinueWith(Object arg0);

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez votre formule et ce qu’elle vous permet de vivre. La révélation des photos demande toujours votre accord mutuel.'**
  String get subscriptionPageFindYourPlanAndWhatIt;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre session doit être vérifiée pour consulter votre abonnement.'**
  String get subscriptionPageYourSessionMustBeVerifiedTo;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérification de votre abonnement'**
  String get subscriptionPageCheckingYourSubscription;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Dernière situation connue. Actualisez pour confirmer vos droits actuels.'**
  String get subscriptionPageLastKnownStatusRefreshToConfirm;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifier mon abonnement'**
  String get subscriptionPageCheckMySubscription;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La souscription et la gestion des paiements ne sont pas encore disponibles dans cette version. Votre formule et vos droits existants restent consultables.'**
  String get subscriptionPageSignUpAndPaymentManagementAre;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Gérer mon abonnement'**
  String get subscriptionPageManageMySubscription;

  /// Interface: lib/features/billing/presentation/subscription_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les formules'**
  String get subscriptionPagePlans;

  /// Interface: lib/features/billing/presentation/subscription_plans.dart
  ///
  /// In fr, this message translates to:
  /// **'Chargement des formules'**
  String get subscriptionPlansLoadingPlans;

  /// Interface: lib/features/billing/presentation/subscription_plans.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune formule disponible.'**
  String get subscriptionPlansNoPlansAvailable;

  /// Interface: lib/features/billing/presentation/subscription_plans.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les formules'**
  String get subscriptionPlansRefreshPlans;

  /// Interface: lib/features/billing/presentation/subscription_plans.dart
  ///
  /// In fr, this message translates to:
  /// **'Paiement indisponible'**
  String get subscriptionPlansPaymentUnavailable;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae Premium'**
  String get subscriptionSummaryHistaePremium;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae Gratuit'**
  String get subscriptionSummaryHistaeFree;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Accès Premium confirmé lors de la dernière vérification.'**
  String get subscriptionSummaryPremiumAccessConfirmedAtTheLast;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre accès actuel correspond à la formule gratuite.'**
  String get subscriptionSummaryYouCurrentlyHaveTheFreePlan;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Rythme mensuel'**
  String get subscriptionSummaryMonthlyPlan;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Rythme annuel'**
  String get subscriptionSummaryAnnualPlan;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Fin de l’essai : {arg0}'**
  String subscriptionSummaryTrialEnds(Object arg0);

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Début de période : {arg0}'**
  String subscriptionSummaryPeriodStarts(Object arg0);

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Fin de période : {arg0}'**
  String subscriptionSummaryPeriodEnds(Object arg0);

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Résiliation prévue à la fin de la période en cours.'**
  String get subscriptionSummaryCancellationScheduledForTheEndOf;

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Résiliation enregistrée le {arg0}'**
  String subscriptionSummaryCancellationRecordedOn(Object arg0);

  /// Interface: lib/features/billing/presentation/subscription_summary.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre paiement demande une régularisation. Les droits affichés sont ceux confirmés par Histae.'**
  String get subscriptionSummaryYourPaymentNeedsAttentionTheEntitlements;

  /// Interface: lib/features/catalog/presentation/catalog_page.dart
  ///
  /// In fr, this message translates to:
  /// **'DES FORMULES SIMPLES'**
  String get catalogPageSimplePlans;

  /// Interface: lib/features/catalog/presentation/catalog_page.dart
  ///
  /// In fr, this message translates to:
  /// **'À votre rythme. Au prix juste.'**
  String get catalogPageAtYourPaceAtAFair;

  /// Interface: lib/features/catalog/presentation/plan_card.dart
  ///
  /// In fr, this message translates to:
  /// **'PRENDRE LE TEMPS, LIBREMENT'**
  String get planCardTakeYourTimeFreely;

  /// Interface: lib/features/catalog/presentation/plan_card.dart
  ///
  /// In fr, this message translates to:
  /// **'POUR FAIRE CONNAISSANCE'**
  String get planCardToGetToKnowEachOther;

  /// Interface: lib/features/catalog/presentation/plan_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Facturé chaque mois. Renouvellement automatique.'**
  String get planCardBilledMonthlyAutomaticRenewal;

  /// Interface: lib/features/catalog/presentation/plan_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Facturé en une fois chaque année. Renouvellement automatique.'**
  String get planCardBilledInFullEachYearAutomatic;

  /// Interface: lib/features/catalog/presentation/plan_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Sans abonnement payant.'**
  String get planCardNoPaidSubscription;

  /// Interface: lib/features/catalog/presentation/plan_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Équivalent à environ {arg0}.'**
  String planCardEquivalentToAbout(Object arg0);

  /// Interface: lib/features/consents/presentation/consents_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos consentements modifiables'**
  String get consentsPageYourOptionalConsents;

  /// Interface: lib/features/consents/presentation/consents_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos documents nécessaires'**
  String get consentsPageYourRequiredDocuments;

  /// Interface: lib/features/consents/presentation/consents_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer mon consentement précédent'**
  String get consentsPageWithdrawMyPreviousConsent;

  /// Interface: lib/features/consents/presentation/consents_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Sessions, données et suppression du compte'**
  String get consentsPageSessionsDataAndAccountDeletion;

  /// Interface: lib/features/consents/presentation/consent_control.dart
  ///
  /// In fr, this message translates to:
  /// **'CGU acceptées'**
  String get consentControlTermsAccepted;

  /// Interface: lib/features/consents/presentation/consent_control.dart
  ///
  /// In fr, this message translates to:
  /// **'Notice consultée'**
  String get consentControlPrivacyNoticeRead;

  /// Interface: lib/features/consents/presentation/consent_control.dart
  ///
  /// In fr, this message translates to:
  /// **'À renouveler'**
  String get consentControlRenewalNeeded;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'J’accepte les conditions d’utilisation'**
  String get consentStringsIAcceptTheTermsOfUse;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'J’ai pris connaissance de la notice de confidentialité'**
  String get consentStringsIHaveReadThePrivacyNotice;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'J’accepte explicitement que Histae traite mon sexe déclaré et mes préférences sur les personnes recherchées pour me proposer des rencontres compatibles, selon ce document. Je sais que je peux retirer cet accord à tout moment et que la découverte ne sera alors plus disponible.'**
  String get consentStringsIConsentToTheProcessingOf;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'J’accepte que Histae utilise la position que je transmets pour calculer des distances et me proposer des profils compatibles. Je sais que je peux retirer cet accord à tout moment et que la découverte nécessitera alors un nouvel accord et une nouvelle position.'**
  String get consentStringsIConsentToTheProcessingOf198;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Conditions d’utilisation'**
  String get consentStringsTermsOfUse;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Notice de confidentialité'**
  String get consentStringsPrivacyNotice;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Données sensibles'**
  String get consentStringsSensitiveData;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce retrait efface votre sexe et vos préférences sur le serveur. La découverte pourra devenir indisponible. Confirmer ce retrait ?'**
  String get consentStringsWithdrawingDeletesYourSexAndPreferences;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce retrait efface votre présence sur le serveur. La découverte pourra devenir indisponible. Il ne change pas la permission système. Confirmer ce retrait ?'**
  String get consentStringsWithdrawingDeletesYourLocationPresenceFrom;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisez votre solde pour accéder aux vidéos.'**
  String get rewardedVideoControllerRefreshYourBalanceToAccessVideos;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Premium vous permet de continuer sans crédit.'**
  String get rewardedVideoControllerPremiumLetsYouContinueWithoutCredits;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'La disponibilité des vidéos n’a pas pu être vérifiée.'**
  String get rewardedVideoControllerVideoAvailabilityCouldNotBeChecked;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos sont momentanément désactivées pour votre formule.'**
  String get rewardedVideoControllerVideosAreTemporarilyDisabledForYour;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre réserve vidéo est pleine. Utilisez un crédit pour libérer une place.'**
  String get rewardedVideoControllerYourVideoReserveIsFullUse;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos ne sont pas configurées pour cette version.'**
  String get rewardedVideoControllerVideosAreNotConfiguredForThis;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'La vidéo a été fermée avant la fin. Vous pouvez réessayer.'**
  String get rewardedVideoControllerTheVideoWasClosedBeforeThe;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu vérifier vos choix de confidentialité. Réessayez, ou ouvrez les préférences des vidéos.'**
  String get rewardedVideoControllerYourAdvertisingPreferencesCouldNotBe;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Le formulaire de confidentialité des vidéos n’est pas encore disponible. Vos crédits gratuits restent accessibles.'**
  String get rewardedVideoControllerTheVideoPrivacyFormIsNot;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Les préférences publicitaires n’ont pas pu être chargées. Vérifiez votre connexion puis réessayez.'**
  String get rewardedVideoControllerAdvertisingPreferencesCouldNotBeLoaded;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Le chargement des préférences publicitaires prend trop de temps. Réessayez dans un instant.'**
  String get rewardedVideoControllerLoadingAdvertisingPreferencesIsTakingToo;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune vidéo disponible pour le moment. Réessayez un peu plus tard.'**
  String get rewardedVideoControllerNoVideoIsAvailableRightNow;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'La vidéo n’a pas pu être chargée. Vérifiez votre connexion.'**
  String get rewardedVideoControllerTheVideoCouldNotBeLoaded;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette demande a expiré. Annulez-la avant de regarder une nouvelle vidéo.'**
  String get rewardedVideoControllerThisRequestHasExpiredCancelIt;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'La vidéo n’a pas pu être chargée. Réessayez plus tard.'**
  String get rewardedVideoControllerTheVideoCouldNotBeLoaded218;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'La vidéo n’a pas pu être affichée. Vous pouvez réessayer.'**
  String get rewardedVideoControllerTheVideoCouldNotBeShown;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'La vidéo est momentanément indisponible. Vous pouvez réessayer.'**
  String get rewardedVideoControllerVideosAreTemporarilyUnavailableYouCan;

  /// Interface: lib/features/continuation/application/rewarded_video_controller.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos préférences ne sont pas accessibles pour le moment.'**
  String get rewardedVideoControllerYourPreferencesAreCurrentlyUnavailable;

  /// Interface: lib/features/continuation/data/rewarded_video_gateway.dart
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos sont disponibles sur Android et iOS.'**
  String get rewardedVideoGatewayVideosAreAvailableOnAndroidAnd;

  /// Interface: lib/features/continuation/data/rewarded_video_gateway.dart
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos ne sont pas encore configurées pour cet appareil.'**
  String get rewardedVideoGatewayVideosAreNotYetConfiguredFor;

  /// Action visible ouvrant le détail des crédits depuis la carte dans Matchs.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes crédits'**
  String get continuationBalanceCardViewCredits;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisation de vos crédits…'**
  String get continuationBalanceCardRefreshingYourCredits;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre solde ne peut pas être vérifié pour le moment.'**
  String get continuationBalanceCardYourBalanceCannotBeCheckedRight;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Réessayer dans {arg0} s'**
  String continuationBalanceCardTryAgainInS(Object arg0);

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les crédits'**
  String get continuationBalanceCardRefreshCredits;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos continuations ne nécessitent aucun crédit.'**
  String get continuationBalanceCardNoCreditsAreNeededForYour;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Gratuits restants'**
  String get continuationBalanceCardFreeRemaining;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Crédits gratuits restants'**
  String get continuationBalanceCardFreeCreditsRemaining;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Publicitaires restants'**
  String get continuationBalanceCardVideoRemaining;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Crédits publicitaires restants'**
  String get continuationBalanceCardVideoCreditsRemaining;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get continuationBalanceCardVideos;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Poursuivre cette rencontre ?'**
  String get continuationPageContinueThisMatch;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre accord ne nécessite aucun crédit avec votre formule actuelle. Chacun fait son propre choix. La conversation reprend après deux accords valides.'**
  String get continuationPageYourCurrentPlanRequiresNoCredit;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous acceptez un coût maximal de 1 crédit pour votre propre accord. Le serveur réserve ce crédit et le débite après deux accords valides. Une clôture ultérieure ne rembourse pas un crédit déjà débité.'**
  String get continuationPageYouAcceptAMaximumCostOf;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans crédit'**
  String get continuationPageContinueWithoutCredits;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Accepter 1 crédit maximum'**
  String get continuationPageAcceptUpTo1Credit;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Révéler vos photos ?'**
  String get continuationPageRevealYourPhotos;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre photo pourra être visible dans cette rencontre après un accord mutuel. Ce choix est indépendant de la continuation et ne rend pas votre photo visible dans le feed.'**
  String get continuationPageYourPhotoMayBecomeVisibleIn;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Donner mon accord'**
  String get continuationPageGiveMyConsent;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre rencontre'**
  String get continuationPageYourMatch;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette rencontre\nn’est plus disponible.'**
  String get continuationPageThisMatchIsNoLongerAvailable;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Revenez à vos rencontres pour relire leur état.'**
  String get continuationPageReturnToYourMatchesToCheck;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La suite\ns’écrit à deux.'**
  String get continuationPageTheNextChapterIsWrittenTogether;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisation de la rencontre'**
  String get continuationPageRefreshingMatch;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Le coût doit être relu et présenté à nouveau avant votre accord.'**
  String get continuationPageTheCostMustBeCheckedAnd;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Se voir, à deux.'**
  String get continuationPageSeeEachOtherTogether;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La révélation des photos demande un accord distinct de chaque personne. Votre formule ne remplace jamais ces accords.'**
  String get continuationPageRevealingPhotosRequiresSeparateConsentFrom;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre accord de révélation est enregistré.'**
  String get continuationPageYourPhotoRevealConsentHasBeen;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La révélation mutuelle est confirmée.'**
  String get continuationPageMutualPhotoRevealIsConfirmed;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La photo n’est pas disponible actuellement.'**
  String get continuationPageThePhotoIsCurrentlyUnavailable;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Voir sa photo'**
  String get continuationPageViewTheirPhoto;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre demande de révélation reste à confirmer.'**
  String get continuationPageYourPhotoRevealRequestStillNeeds;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le même accord de révélation'**
  String get continuationPageResumeTheSamePhotoRevealConsent;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir de révéler les photos'**
  String get continuationPageChooseToRevealPhotos;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Continuer cette conversation'**
  String get continuationPageContinueThisConversation;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre période de décision s’ouvrira après les premiers échanges. Échéance actuelle : {arg0}.'**
  String continuationPageYourDecisionPeriodOpensAfterThe(Object arg0);

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre conversation est ouverte. Les conditions de continuation sont réunies.'**
  String get continuationPageYourConversationIsOpenContinuationConditions;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Décision possible jusqu’au {arg0}. Vous pouvez toujours relire vos échanges.'**
  String continuationPageYouCanDecideUntilYouCan(Object arg0);

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre choix de continuer est enregistré. La conversation reprend lorsque les conditions de continuation sont réunies.'**
  String get continuationPageYourChoiceToContinueHasBeen;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette demande reste à confirmer, avec un coût maximal accepté de {count, plural, one {{count} crédit} other {{count} crédits}}. Aucun nouvel accord avec un autre coût ne sera envoyé.'**
  String continuationPageThisRequestStillNeedsConfirmationWith(num count);

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le même accord'**
  String get continuationPageResumeTheSameAgreement;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre formule actuelle : aucun crédit nécessaire pour votre accord.'**
  String get continuationPageYourCurrentPlanNoCreditNeeded;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one {{count} nouvelle continuation disponible} other {{count} nouvelles continuations disponibles}}. Votre accord coûte au maximum 1 crédit.'**
  String continuationsAndCost(num count);

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Lire le coût et choisir de continuer'**
  String get continuationPageReadTheCostAndChooseTo;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre quota ne permet pas de nouvelle continuation actuellement.'**
  String get continuationPageYourAllowanceDoesNotPermitAnother;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Voir mes crédits'**
  String get continuationPageViewMyCredits;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Chaque personne choisit indépendamment. Le choix de l’autre personne reste privé. Vous pouvez terminer la rencontre depuis les options de la conversation.'**
  String get continuationPageEachPersonChoosesIndependentlyTheOther;

  /// Interface: lib/features/continuation/presentation/continuation_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser la rencontre et mes crédits'**
  String get continuationPageRefreshMatchAndMyCredits;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre formule a changé. Relisez vos crédits et confirmez à nouveau le coût présenté.'**
  String get continuationStringsYourPlanHasChangedCheckYour;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune nouvelle continuation n’est disponible dans votre quota actuel.'**
  String get continuationStringsNoNewContinuationIsAvailableWithin;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La période de décision n’est pas encore ouverte. Actualisez la rencontre.'**
  String get continuationStringsTheDecisionPeriodIsNotOpen;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos récompensées sont actuellement indisponibles.'**
  String get continuationStringsRewardedVideosAreCurrentlyUnavailable;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune nouvelle vidéo récompensée n’est disponible pour votre compte actuellement.'**
  String get continuationStringsNoNewRewardedVideoIsCurrently;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre stock de crédits publicitaires est plein, réservations comprises.'**
  String get continuationStringsYourVideoCreditReserveIsFull;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette récompense n’est plus accessible. Vérifiez vos crédits.'**
  String get continuationStringsThisRewardIsNoLongerAccessible;

  /// Interface: lib/features/continuation/presentation/continuation_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La vérification de la récompense est temporairement indisponible. Aucun crédit n’est confirmé pour le moment.'**
  String get continuationStringsRewardVerificationIsTemporarilyUnavailableNo;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'VOTRE SOLDE'**
  String get creditsBalancePanelYourBalance;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae Free'**
  String get creditsBalancePanelHistaeFree;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Le temps de vous découvrir.'**
  String get creditsBalancePanelTimeToDiscoverEachOther;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos continuations ne nécessitent aucun crédit. Chacun reste libre de poursuivre la rencontre.'**
  String get creditsBalancePanelNoCreditsAreNeededToContinue;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one {{count} nouvelle continuation disponible} other {{count} nouvelles continuations disponibles}}'**
  String availableContinuations(num count);

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Soldes disponibles, hors crédits réservés.'**
  String get creditsBalancePanelAvailableBalancesExcludingReservedCredits;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get creditsBalancePanelThisWeek;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} / {arg1} continuations confirmées'**
  String creditsBalancePanelContinuationsConfirmed(Object arg0, Object arg1);

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Continuations confirmées cette semaine : {arg0} sur {arg1}'**
  String creditsBalancePanelContinuationsConfirmedThisWeekOf(
    Object arg0,
    Object arg1,
  );

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} crédits gratuits renouvelés le lundi à 00 h UTC.'**
  String creditsBalancePanelFreeCreditsRenewedOnMondaysAt(Object arg0);

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune nouvelle continuation disponible actuellement. Le solde tient compte du plafond de la semaine et des réservations.'**
  String get creditsBalancePanelNoNewContinuationAvailableRightNow;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Comprendre mes crédits'**
  String get creditsBalancePanelUnderstandingMyCredits;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one {{count} crédit réservé} other {{count} crédits réservés}}'**
  String reservedCredits(num count);

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Un crédit est réservé lorsque vous choisissez de continuer. Il est débité une fois les deux accords confirmés. Un crédit déjà débité n’est pas remboursé à la clôture.'**
  String get creditsBalancePanelACreditIsReservedWhenYou;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Réserve vidéo : {arg0} / {arg1}'**
  String creditsBalancePanelVideoReserve(Object arg0, Object arg1);

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Les crédits vidéo sont conservés, réservations comprises. Les crédits gratuits sont renouvelés chaque semaine, sans cumul. Une réservation peut rester rattachée à la semaine de votre accord.'**
  String get creditsBalancePanelVideoCreditsAreKeptIncludingReserved;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette demande ?'**
  String get creditsPageCancelThisRequest;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'L’annulation empêchera toute validation ultérieure, même si une vidéo déjà terminée est encore en cours de vérification.'**
  String get creditsPageCancellationPreventsAnyLaterValidationEven;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get creditsPageCancelRequest;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos crédits'**
  String get creditsPageYourCredits;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser mes crédits'**
  String get creditsPageRefreshMyCredits;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'LE TEMPS DE CONTINUER'**
  String get creditsPageTimeToContinue;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La suite commence\nici.'**
  String get creditsPageTheNextChapterStartsHere;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Des crédits pour les rencontres que vous avez envie de poursuivre.'**
  String get creditsPageCreditsForTheConnectionsYouWant;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Lecture de vos crédits'**
  String get creditsPageCheckingYourCredits;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre solde reste à vérifier'**
  String get creditsPageYourBalanceStillNeedsChecking;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisez vos crédits pour retrouver votre solde.'**
  String get creditsPageRefreshYourCreditsToViewYour;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une rencontre se poursuit à deux. Chacun confirme son propre choix.'**
  String get creditsPageAMatchContinuesTogetherEachPerson;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La photo temporaire n’est pas disponible. Actualisez pour obtenir un nouveau lien.'**
  String get partnerPhotoPageTheTemporaryPhotoIsUnavailableRefresh;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une photo, à deux'**
  String get partnerPhotoPageAPhotoTogether;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette photo n’est pas disponible actuellement.'**
  String get partnerPhotoPageThisPhotoIsCurrentlyUnavailable;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la photo'**
  String get partnerPhotoPageLoadingPhoto;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Photo de votre rencontre'**
  String get partnerPhotoPageYourMatchSPhoto;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La photo ne peut pas être affichée. Actualisez le lien temporaire.'**
  String get partnerPhotoPageThePhotoCannotBeShownRefresh;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos accords de révélation sont mutuels. Les photos restent absentes du feed.'**
  String get partnerPhotoPageYouBothAgreedToRevealPhotos;

  /// Interface: lib/features/continuation/presentation/partner_photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser la photo'**
  String get partnerPhotoPageRefreshPhoto;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Regarder une vidéo'**
  String get rewardVideoCardWatchAVideo;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get rewardVideoCardChecking;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos préférences…'**
  String get rewardVideoCardYourPreferences;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la vidéo…'**
  String get rewardVideoCardLoadingVideo;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vidéo en cours…'**
  String get rewardVideoCardVideoPlaying;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'UN COUP DE POUCE'**
  String get rewardVideoCardAHelpingHand;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Une vidéo pour\nla suite de l’histoire.'**
  String get rewardVideoCardAVideoForTheNextChapter;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'+ {count, plural, one {{count} crédit de continuation} other {{count} crédits de continuation}}'**
  String videoCreditReward(num count);

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Si vous le souhaitez, regardez une vidéo jusqu’au bout pour compléter votre réserve de crédits.'**
  String get rewardVideoCardIfYouWishWatchAVideo;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Toujours facultatif. Le crédit apparaît après validation de la récompense.'**
  String get rewardVideoCardAlwaysOptionalTheCreditAppearsAfter;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vidéo terminée. Votre récompense est en cours de validation.'**
  String get rewardVideoCardVideoCompletedYourRewardIsBeing;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre demande est prête. Vous pouvez reprendre le visionnage.'**
  String get rewardVideoCardYourRequestIsReadyYouCan;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Récompense validée : {count, plural, one {{count} crédit} other {{count} crédits}}.'**
  String videoRewardConfirmed(num count);

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'La demande a expiré. Une vidéo terminée à temps peut encore être validée.'**
  String get rewardVideoCardTheRequestExpiredAVideoCompleted;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette demande a été annulée.'**
  String get rewardVideoCardThisRequestWasCanceled;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifier la récompense'**
  String get rewardVideoCardCheckReward;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette demande'**
  String get rewardVideoCardCancelThisRequest;

  /// Interface: lib/features/continuation/presentation/reward_video_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Mes choix publicitaires'**
  String get rewardVideoCardMyAdvertisingChoices;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La reprise n’a pas pu être confirmée. Actualisez votre visibilité depuis votre profil.'**
  String get discoveryPageResumingCouldNotBeConfirmedRefresh;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre profil n’a pas pu être relu. Revenez à votre espace personnel pour le reprendre.'**
  String get discoveryPageYourProfileCouldNotBeRefreshed;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Utiliser votre position ?'**
  String get discoveryPageUseYourLocation;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae utilisera une mesure ponctuelle pour les rencontres à proximité. Aucun suivi en arrière-plan. Votre position exacte ne sera pas montrée aux autres personnes.'**
  String get discoveryPageHistaeWillTakeAOneOff;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Localiser cet appareil'**
  String get discoveryPageLocateThisDevice;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloquer ce profil ?'**
  String get discoveryPageBlockThisProfile;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pourrez plus vous découvrir ni échanger. Toute rencontre déjà créée avec cette personne sera terminée.'**
  String get discoveryPageYouWillNoLongerDiscoverOr;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get discoveryPageBlock;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'PRENDRE LE TEMPS'**
  String get discoveryPageTakeYourTime;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous avez fait le tour, pour l’instant.'**
  String get discoveryPageAQuietMomentForNow;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Encore un instant.'**
  String get discoveryPageJustAMoment;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous avez découvert les profils disponibles pour vos envies de rencontre. Revenez plus tard, ou ajustez vos préférences si vous le souhaitez.'**
  String get discoveryPageYouHaveSeenTheAvailableProfiles;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La recherche peut se poursuivre. Chargez la suite lorsque vous le souhaitez.'**
  String get discoveryPageTheSearchCanContinueLoadMore;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la découverte'**
  String get discoveryPageLoadingDiscovery;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous cherchons les rencontres près de vous…'**
  String get discoveryPageFindingARecentLocation;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous transmettons votre choix…'**
  String get discoveryPageSavingYourChoice;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'À la découverte de nouvelles personnes…'**
  String get discoveryPagePreparingEncounters;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez les réglages de localisation de votre appareil, puis revenez dans Histae.'**
  String get discoveryPageOpenYourDeviceSLocationSettings;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get discoveryPageOpenSettings;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les rencontres'**
  String get discoveryPageRefreshEncounters;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser ma position'**
  String get discoveryPageRefreshMyLocation;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre rencontre avec {arg0}'**
  String discoveryPageYourMatchWith(Object arg0);

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos préférences'**
  String get discoveryPageYourPreferences;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Options de découverte'**
  String get discoveryPageDiscoveryOptions;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les profils'**
  String get discoveryPageRefreshProfiles;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce profil'**
  String get discoveryPageReportThisProfile;

  /// Interface: lib/features/discovery/presentation/discovery_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloquer ce profil'**
  String get discoveryPageBlockThisProfile372;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Mode pause'**
  String get discoveryPauseCardPauseMode;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre visibilité reste à vérifier. Actualisez son état avant de modifier ce choix.'**
  String get discoveryPauseCardYourVisibilityStillNeedsCheckingRefresh;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre profil est masqué des nouvelles découvertes. Vos matchs et vos conversations restent accessibles.'**
  String get discoveryPauseCardYourProfileIsHiddenFromNew;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Envie de souffler ? Masquez votre profil tout en gardant vos conversations.'**
  String get discoveryPauseCardTakeABreakFromNewEncounters;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérification de votre visibilité…'**
  String get discoveryPauseCardCheckingYourVisibility;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre visibilité ne peut pas être vérifiée pour le moment.'**
  String get discoveryPauseCardYourVisibilityCannotBeCheckedRight;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisation de votre visibilité'**
  String get discoveryPauseCardRefreshingYourVisibility;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'La visibilité n’a pas pu être confirmée.'**
  String get discoveryPauseCardVisibilityCouldNotBeConfirmed;

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Réessayez dans {arg0} s'**
  String discoveryPauseCardTryAgainInS(Object arg0);

  /// Interface: lib/features/discovery/presentation/discovery_pause_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser ma visibilité'**
  String get discoveryPauseCardRefreshMyVisibility;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'AVANT LA RENCONTRE'**
  String get discoveryStatusSectionsBeforeYouMeet;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Prenez votre temps.'**
  String get discoveryStatusSectionsTakeYourTime;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Un peu de vous.\nPuis les autres.'**
  String get discoveryStatusSectionsALittleAboutYouThenThe;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Les nouvelles rencontres attendront. Vos matchs et vos conversations restent accessibles.'**
  String get discoveryStatusSectionsNewEncountersCanWaitYourMatches;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Complétez ces étapes à votre rythme. Vos choix de vie privée restent accessibles.'**
  String get discoveryStatusSectionsCompleteTheseStepsAtYourOwn;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la découverte'**
  String get discoveryStatusSectionsResumeDiscovery;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Compléter cette étape'**
  String get discoveryStatusSectionsCompleteThisStep;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre choix pour {arg0}'**
  String discoveryStatusSectionsYourChoiceFor(Object arg0);

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre choix est gardé ici, mais nous n’avons pas pu vérifier sa réception. Vous pouvez reprendre ce même choix.'**
  String get discoveryStatusSectionsTheResponseIsUnconfirmedYourChoice;

  /// Interface: lib/features/discovery/presentation/discovery_status_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous attendons la confirmation de votre choix avant de passer à la suite.'**
  String get discoveryStatusSectionsYourRequestIsAwaitingConfirmationNo;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos conditions de découverte ont changé. Actualisez les étapes ci-dessous.'**
  String get discoveryStringsYourDiscoveryConditionsHaveChangedRefresh;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La découverte est temporairement indisponible.'**
  String get discoveryStringsDiscoveryIsTemporarilyUnavailable;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette page a expiré. Actualisez les profils.'**
  String get discoveryStringsThisPageHasExpiredRefreshProfiles;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les profils ne peuvent pas être chargés pour le moment.'**
  String get discoveryStringsProfilesCannotBeLoadedRightNow;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Un choix existe déjà pour ce profil. Il ne peut pas être modifié.'**
  String get discoveryStringsAChoiceIsAlreadyRecordedFor;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce profil n’est plus disponible.'**
  String get discoveryStringsThisProfileIsNoLongerAvailable;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La localisation de l’appareil est désactivée. Activez-la dans les réglages, puis réessayez.'**
  String get discoveryStringsDeviceLocationIsDisabledEnableIt;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'L’accès à la position a été refusé. Vous pourrez le redemander lorsque vous le souhaitez.'**
  String get discoveryStringsLocationAccessWasDeniedYouCan;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'L’accès à la position doit être autorisé dans les réglages de l’appareil.'**
  String get discoveryStringsAllowLocationAccessInYourDevice;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La position n’a pas été trouvée à temps. Réessayez dans un endroit mieux couvert.'**
  String get discoveryStringsYourLocationWasNotFoundIn;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette position est trop ancienne ou invalide pour être utilisée. Demandez une nouvelle mesure.'**
  String get discoveryStringsThisLocationIsTooOldOr;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La position ne peut pas être obtenue pour le moment.'**
  String get discoveryStringsYourLocationCannotBeObtainedRight;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La localisation a été interrompue. Vous pouvez la redemander.'**
  String get discoveryStringsLocationWasInterruptedYouCanRequest;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre présentation'**
  String get discoveryStringsYourIntroduction;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre profil est en pause'**
  String get discoveryStringsYourProfileIsPaused;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le sexe de votre profil'**
  String get discoveryStringsYourProfileSSex;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos envies de rencontre'**
  String get discoveryStringsYourDatingPreferences;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les données sensibles'**
  String get discoveryStringsSensitiveData;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre choix de localisation'**
  String get discoveryStringsYourLocationChoice;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une position récente'**
  String get discoveryStringsARecentLocation;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre prénom, votre date de naissance et votre présentation.'**
  String get discoveryStringsAddYourFirstNameDateOf;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre profil est masqué des nouvelles découvertes. Vous pouvez poursuivre vos conversations et reprendre les rencontres à votre rythme.'**
  String get discoveryStringsYourProfileIsHiddenFromNew;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Renseignez ce champ pour permettre les critères réciproques de rencontre.'**
  String get discoveryStringsFillInThisFieldToEnable;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez les personnes, les âges et la distance qui vous correspondent.'**
  String get discoveryStringsChooseThePeopleAgesAndDistance;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'L’utilisation du sexe et des préférences demande votre accord distinct.'**
  String get discoveryStringsUsingSexAndPreferencesRequiresYour;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Décidez si Histae peut utiliser votre position pour les rencontres à proximité.'**
  String get discoveryStringsDecideWhetherHistaeCanUseYour;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une mesure ponctuelle suffit. Votre position exacte n’apparaît pas sur les profils.'**
  String get discoveryStringsOneLocationReadingIsEnoughYour;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Position approximative utilisée. Les distances peuvent être moins précises.'**
  String get discoveryStringsApproximateLocationUsedDistancesMayBe;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre position a été actualisée.'**
  String get discoveryStringsYourLocationHasBeenUpdated;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'L’envoi de la position reste incertain. Son état est relu auprès de Histae ; aucun renvoi automatique.'**
  String get discoveryStringsLocationSubmissionIsUncertainItsStatus;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre « J’aime » a bien été transmis.'**
  String get discoveryStringsYourInterestHasBeenRecorded;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous avez passé ce profil.'**
  String get discoveryStringsYouPassedOnThisProfile;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce profil est bloqué. Vous ne pourrez plus vous rencontrer ni échanger.'**
  String get discoveryStringsThisProfileIsBlockedYouCan;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce profil a été retiré de votre découverte. Aucun autre choix n’a été envoyé.'**
  String get discoveryStringsThisProfileWasRemovedFromDiscovery;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le même « J’aime »'**
  String get discoveryStringsResumeTheSameLike;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le même passage'**
  String get discoveryStringsResumeTheSamePass;

  /// Interface: lib/features/discovery/presentation/discovery_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le blocage'**
  String get discoveryStringsResumeBlocking;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette rencontre n’est plus disponible ici.'**
  String get encounterPageThisMatchIsNoLongerAvailable;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une rencontre'**
  String get encounterPageAMatch;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'UN INTÉRÊT RÉCIPROQUE'**
  String get encounterPageMutualInterest;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les mots vous\nont rapprochés.'**
  String get encounterPageWordsBroughtYouTogether;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous et {arg0} vous êtes choisis. Une rencontre a été créée dans Histae.'**
  String encounterPageYouAndChoseEachOtherA(Object arg0);

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos photos restent privées. Cette rencontre ne vaut pas accord pour les révéler.'**
  String get encounterPageYourPhotosStayPrivateThisMatch;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la conversation'**
  String get encounterPageOpenConversation;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Revenir aux découvertes'**
  String get encounterPageBackToDiscovery;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloquer cette personne ?'**
  String get encounterPageBlockThisPerson;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre rencontre sera terminée et vous ne pourrez plus échanger.'**
  String get encounterPageYourMatchWillEndAndYou;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloquer cette personne'**
  String get encounterPageBlockThisPerson447;

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Signaler cette personne'**
  String get encounterPageReportThisPerson;

  /// Interface: lib/features/discovery/presentation/feed_profile_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Relâchez pour passer'**
  String get feedProfileCardReleaseToPass;

  /// Interface: lib/features/discovery/presentation/feed_profile_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Double appui pour aimer.\nEn fin de lecture, glissez vers le haut pour passer.'**
  String get feedProfileCardDoubleTapToLikeAtThe;

  /// Interface: lib/features/discovery/presentation/feed_profile_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get feedProfileCardPass;

  /// Interface: lib/features/discovery/presentation/feed_profile_card.dart
  ///
  /// In fr, this message translates to:
  /// **'J’aime'**
  String get feedProfileCardLike;

  /// Interface: lib/features/discovery/presentation/feed_profile_content.dart
  ///
  /// In fr, this message translates to:
  /// **'AU FIL DES MOTS'**
  String get feedProfileContentThroughWords;

  /// Interface: lib/features/discovery/presentation/feed_profile_content.dart
  ///
  /// In fr, this message translates to:
  /// **'Quelques traits'**
  String get feedProfileContentAFewTraits;

  /// Interface: lib/features/matches/data/match_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre message dépasse 2 000 caractères.'**
  String get messageTooLong;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Terminer cette rencontre ?'**
  String get chatPageEndThisMatch;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La rencontre sera terminée et vous ne pourrez plus vous découvrir ni échanger.'**
  String get chatPageTheMatchWillEndAndYou;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La conversation ne sera plus accessible. Cette action ne bloque pas cette personne. Un crédit déjà débité ne sera pas remboursé.'**
  String get chatPageTheConversationWillNoLongerBe;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get chatPageEnd;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser la conversation'**
  String get chatPageRefreshConversation;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Options de la rencontre'**
  String get chatPageMatchOptions;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Photos et continuation'**
  String get chatPagePhotosAndContinuation;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Voir son profil'**
  String get chatPageViewTheirProfile;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Terminer la rencontre'**
  String get chatPageEndMatch;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette rencontre\nest terminée.'**
  String get chatPageThisMatchHasEnded;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La rencontre doit être relue pour ouvrir la conversation.'**
  String get chatPageRefreshTheMatchToOpenThe;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La conversation n’est plus disponible.'**
  String get chatPageTheConversationIsNoLongerAvailable;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Relire mes rencontres'**
  String get chatPageRefreshMyMatches;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Messages plus anciens'**
  String get chatPageOlderMessages;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Quelques mots pour commencer ?'**
  String get chatPageAFewWordsToStart;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Le début de votre conversation'**
  String get chatPageTheStartOfYourConversation;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **' · Envoyé'**
  String get chatPageSent;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la confirmation de lecture'**
  String get chatPageResumeReadConfirmation;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La clôture reste à confirmer. Aucun nouveau message ne sera envoyé.'**
  String get chatPageClosingStillNeedsConfirmationNoNew;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la même demande'**
  String get chatPageResumeTheSameRequest;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas encore pu confirmer l’envoi. Reprendre renverra ce même message.'**
  String get chatPageThisMessageIsAwaitingConfirmationResuming;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours…'**
  String get chatPageSending;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le même envoi'**
  String get chatPageResumeTheSameMessage;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre message'**
  String get chatPageYourMessage;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} / 2 000 caractères'**
  String chatPage2000Characters(Object arg0);

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'\n\nConnexion en reprise. Vous pouvez actualiser la conversation manuellement.'**
  String get conversationHeaderReconnectingYouCanRefreshTheConversation;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir la suite'**
  String get conversationHeaderChooseWhatComesNext;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'État de la conversation'**
  String get conversationHeaderConversationStatus;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get conversationHeaderPaused;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos choix'**
  String get conversationHeaderYourChoices;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'Connexion en reprise · actualisation manuelle disponible.'**
  String get conversationHeaderReconnectingManualRefreshAvailable;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation de la conversation'**
  String get conversationHeaderSyncingConversation;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos rencontres'**
  String get matchesPageYourMatches;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisation des rencontres et des crédits'**
  String get matchesPageRefreshingMatchesAndCredits;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une conversation à la fois.'**
  String get matchesPageWordsContinue;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un premier bonjour, puis le plaisir de se découvrir. Retrouvez vos échanges ici.'**
  String get matchesPageMutualInterestThenASpaceTo;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La connexion reprend. Actualisez si vos derniers échanges n’apparaissent pas.'**
  String get matchesPageReconnectingUpdatesYouCanRefreshYour;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette rencontre est terminée.'**
  String get matchesPageThisMatchHasEnded;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Quand l’envie de se connaître est partagée, vous pouvez échanger ici. En attendant, laissez-vous surprendre par les mots du feed.'**
  String get matchesPageNoMatchesYetTheyWillAppear;

  /// Interface: lib/features/matches/presentation/matches_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Voir les rencontres suivantes'**
  String get matchesPageViewMoreMatches;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette rencontre n’est plus disponible.'**
  String get matchesStringsThisMatchIsNoLongerAvailable;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas envoyer de message pour le moment. Actualisez la conversation pour savoir où elle en est.'**
  String get matchesStringsSendingIsUnavailableInThisMatch;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Écrivez un message non vide de 2 000 caractères maximum.'**
  String get matchesStringsWriteANonEmptyMessageOf;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce message ne peut plus être renvoyé. Actualisez la conversation avant de continuer.'**
  String get matchesStringsThisSendRequestNoLongerMatches;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce message n’est plus disponible. Actualisez la conversation.'**
  String get matchesStringsThisMessageIsNoLongerAvailable;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette page ne peut plus être utilisée. L’historique va être relu.'**
  String get matchesStringsThisPageCanNoLongerBe;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les rencontres sont temporairement indisponibles. Réessayez plus tard.'**
  String get matchesStringsMatchesAreTemporarilyUnavailableTryAgain;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les premiers mots'**
  String get matchesStringsTheFirstWords;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Envois suspendus'**
  String get matchesStringsSendingPaused;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Conversation ouverte'**
  String get matchesStringsConversationOpen;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Rencontre terminée'**
  String get matchesStringsMatchEnded;

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Première période jusqu’au {arg0}.'**
  String matchesStringsInitialPeriodUntil(Object arg0);

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'L’envoi est suspendu pendant la décision de continuation, jusqu’au {arg0}. L’historique reste accessible.'**
  String matchesStringsSendingIsPausedDuringTheContinuation(Object arg0);

  /// Interface: lib/features/matches/presentation/matches_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez poursuivre votre conversation.'**
  String get matchesStringsYouCanContinueYourConversation;

  /// Interface: lib/features/matches/presentation/partner_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Découvrez cette personne au fil de vos échanges.'**
  String get partnerPageDiscoverThisPersonThroughYourConversations;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les réglages sécurisés ne sont pas accessibles. L’activation reste en attente.'**
  String get devicesPageSecureSettingsAreUnavailableActivationRemains;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes. Patientez avant de réessayer.'**
  String get devicesPageTooManyRequestsWaitBeforeTrying;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La réponse n’a pas été confirmée. Actualisez la liste avant de reprendre la même action.'**
  String get devicesPageTheResponseWasNotConfirmedRefresh;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Appareils et notifications'**
  String get devicesPageDevicesAndNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'GARDER LE LIEN, À VOTRE RYTHME'**
  String get devicesPageStayInTouchAtYourPace;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un signe,\nsi vous le souhaitez.'**
  String get devicesPageASignIfYouWish;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez de recevoir des notifications sur cet appareil. Les alertes Histae ne contiennent pas le texte privé de vos messages.'**
  String get devicesPageChooseToReceiveNotificationsOnThis;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Sur cet appareil'**
  String get devicesPageOnThisDevice;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les notifications push sont désactivées dans cette version, en attendant leur configuration. Vous pouvez gérer les appareils déjà enregistrés ci-dessous.'**
  String get devicesPagePushNotificationsAreDisabledInThis;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'L’arrêt des notifications reste à confirmer.'**
  String get devicesPageStoppingNotificationsStillNeedsConfirmation;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'L’enregistrement de cet appareil reste à confirmer.'**
  String get devicesPageThisDeviceSRegistrationStillNeeds;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les notifications sont activées ici. Leur réception dépend aussi des réglages de votre appareil.'**
  String get devicesPageThisDeviceIsRegisteredForNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Notifications non activées pour cet appareil.'**
  String get devicesPageNotificationsAreNotEnabledForThis;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les notifications sont autorisées discrètement par le système.'**
  String get devicesPageTheSystemAllowsQuietNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Le système n’a pas autorisé les notifications. Vous pourrez modifier cette permission dans les réglages de l’appareil.'**
  String get devicesPageTheSystemDidNotAllowNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil a été retiré de votre compte. Il ne sera pas réenregistré automatiquement.'**
  String get devicesPageThisDeviceWasRemovedFromYour;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des notifications ?'**
  String get devicesPageReceiveNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Autorisez Histae à vous prévenir sur cet appareil. Vous pourrez désactiver les notifications ici à tout moment.'**
  String get devicesPageHistaeWillAskForSystemPermission;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get devicesPageContinue;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre cet enregistrement'**
  String get devicesPageResumeThisRegistration;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get devicesPageEnableNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Arrêter les notifications ici ?'**
  String get devicesPageStopNotificationsHere;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil sera retiré du service de notification. Votre session de connexion reste ouverte.'**
  String get devicesPageThisDeviceWillBeRemovedFrom;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get devicesPageStop;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Arrêter les notifications sur cet appareil'**
  String get devicesPageStopNotificationsOnThisDevice;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos appareils enregistrés'**
  String get devicesPageYourRegisteredDevices;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette liste concerne les notifications. Retirer un appareil ne ferme pas sa session de connexion ; les sessions se gèrent séparément.'**
  String get devicesPageThisListIsForNotificationsRemoving;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisation des appareils'**
  String get devicesPageRefreshingDevices;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cet enregistrement a été retiré de votre compte.'**
  String get devicesPageThisRegistrationWasRemovedFromYour;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un retrait reste à confirmer. Actualisez la liste, puis reprenez le même appareil s’il est encore présent.'**
  String get devicesPageARemovalStillNeedsConfirmationRefresh;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil enregistré pour les notifications.'**
  String get devicesPageNoDevicesRegisteredForNotifications;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'iOS'**
  String get devicesPageIos;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Android'**
  String get devicesPageAndroid;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **' · cet appareil'**
  String get devicesPageThisDevice;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Enregistré le {arg0}'**
  String devicesPageRegisteredOn(Object arg0);

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Dernière actualisation le {arg0}'**
  String devicesPageLastRefreshedOn(Object arg0);

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet appareil ?'**
  String get devicesPageRemoveThisDevice;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les futures notifications ne seront plus envoyées à cet enregistrement. Sa session de connexion restera ouverte.'**
  String get devicesPageFutureNotificationsWillNoLongerBe;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre ce retrait'**
  String get devicesPageResumeThisRemoval;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet appareil'**
  String get devicesPageRemoveThisDevice573;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les appareils'**
  String get devicesPageRefreshDevices;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mes sessions'**
  String get privacyDetailPageMySessions;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Personnes bloquées'**
  String get privacyDetailPageBlockedPeople;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mes demandes de données'**
  String get privacyDetailPageMyDataRequests;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get privacyDetailPageExportMyData;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get privacyDetailPageDeleteMyAccount;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Opération en cours'**
  String get privacyDetailPageOperationInProgress;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer une session retire son accès à votre compte. Les dates sont affichées dans l’heure de cet appareil.'**
  String get privacyDetailPageClosingASessionRemovesItsAccess;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une révocation reste à confirmer. Actualisez la liste, puis reprenez la même session si elle est toujours présente.'**
  String get privacyDetailPageARevocationStillNeedsConfirmationRefresh;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil'**
  String get privacyDetailPageThisDevice;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Autre session'**
  String get privacyDetailPageOtherSession;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Créée le {arg0}'**
  String privacyDetailPageCreatedOn(Object arg0);

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Dernier renouvellement le {arg0}'**
  String privacyDetailPageLastRenewedOn(Object arg0);

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Expire le {arg0}'**
  String privacyDetailPageExpiresOn(Object arg0);

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer cette session ?'**
  String get privacyDetailPageCloseThisSession;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous serez déconnecté sur cet appareil.'**
  String get privacyDetailPageYouWillBeSignedOutOn;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Cet accès sera révoqué. L’appareil concerné devra se reconnecter.'**
  String get privacyDetailPageThisAccessWillBeRevokedThe;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la révocation'**
  String get privacyDetailPageResumeRevocation;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer cette session'**
  String get privacyDetailPageCloseThisSession594;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune session chargée.'**
  String get privacyDetailPageNoSessionsLoaded;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les sessions'**
  String get privacyDetailPageRefreshSessions;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Charger la suite'**
  String get privacyDetailPageLoadMore;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer toutes les sessions ?'**
  String get privacyDetailPageCloseAllSessions;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous serez également déconnecté sur cet appareil.'**
  String get privacyDetailPageYouWillAlsoBeSignedOut;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Tout fermer'**
  String get privacyDetailPageCloseAll;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer toutes mes sessions'**
  String get privacyDetailPageCloseAllMySessions;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Débloquer une personne ne rétablit aucune ancienne rencontre ni conversation.'**
  String get privacyDetailPageUnblockingSomeoneDoesNotRestoreAny;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un déblocage reste à confirmer. Actualisez avant de reprendre la même demande.'**
  String get privacyDetailPageUnblockingStillNeedsConfirmationRefreshBefore;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Profil bloqué'**
  String get privacyDetailPageBlockedProfile;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloqué le {arg0}'**
  String privacyDetailPageBlockedOn(Object arg0);

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Débloquer cette personne ?'**
  String get privacyDetailPageUnblockThisPerson;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez à nouveau vous découvrir selon vos préférences. Les anciens échanges restent fermés.'**
  String get privacyDetailPageYouMayDiscoverEachOtherAgain;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Débloquer'**
  String get privacyDetailPageUnblock;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le déblocage'**
  String get privacyDetailPageResumeUnblocking;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune personne bloquée dans cette liste.'**
  String get privacyDetailPageNoBlockedPeopleInThisList;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les blocages'**
  String get privacyDetailPageRefreshBlocks;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Ces demandes sont transmises pour traitement. Une demande d’effacement ici ne ferme pas immédiatement votre compte. Pour le fermer dès maintenant, utilisez « Supprimer mon compte » dans votre espace de confidentialité.'**
  String get privacyDetailPageTheseRequestsAreSubmittedForProcessing;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre démarche'**
  String get privacyDetailPageYourRequest;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La réponse reste à confirmer. Actualisez le suivi avant de reprendre cette même démarche.'**
  String get privacyDetailPageTheResponseStillNeedsConfirmationRefresh;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Transmettre cette demande ?'**
  String get privacyDetailPageSubmitThisRequest;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} : cette démarche sera enregistrée pour traitement. Son état sera visible dans le suivi.'**
  String privacyDetailPageThisRequestWillBeRecordedFor(Object arg0);

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Transmettre ma demande'**
  String get privacyDetailPageSubmitMyRequest;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre cette demande'**
  String get privacyDetailPageResumeThisRequest;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Le suivi de vos demandes'**
  String get privacyDetailPageTrackYourRequests;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'\nTerminée le {arg0}'**
  String privacyDetailPageCompletedOn(Object arg0);

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande dans votre suivi.'**
  String get privacyDetailPageNoRequestsToTrack;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser le suivi'**
  String get privacyDetailPageRefreshTracking;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'UNE COPIE POUR VOUS'**
  String get privacyDetailPageACopyForYou;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos données,\nà portée de main.'**
  String get privacyDetailPageYourDataWithinReach;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre export contient des informations personnelles. Il est téléchargé dans un espace temporaire privé. Vous choisissez ensuite où le partager.'**
  String get privacyDetailPageYourExportContainsPersonalInformationIt;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La préparation peut prendre quelques minutes. Le fichier temporaire est nettoyé à la sortie ou en arrière-plan. Pendant un partage, il est conservé jusqu’au retour dans Histae. Une copie enregistrée par la destination dépend de celle-ci.'**
  String get privacyDetailPagePreparationMayTakeAFewMinutes;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Télécharger mon export'**
  String get privacyDetailPageDownloadMyExport;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Télécharger à nouveau'**
  String get privacyDetailPageDownloadAgain;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Partager votre export ?'**
  String get privacyDetailPageShareYourExport;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une destination de confiance pour ce fichier personnel.'**
  String get privacyDetailPageChooseATrustedDestinationForThis;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir une destination'**
  String get privacyDetailPageChooseADestination;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mon export Histae'**
  String get privacyDetailPageMyHistaeExport;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir où partager le fichier'**
  String get privacyDetailPageChooseWhereToShareTheFile;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Effacer le fichier temporaire'**
  String get privacyDetailPageEraseTemporaryFile;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'UNE DÉCISION PERSONNELLE'**
  String get privacyDetailPageAPersonalDecision;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Clore ce\nchapitre.'**
  String get privacyDetailPageCloseThisChapter;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La suppression ferme votre compte et vos sessions. Vos rencontres et vos échanges deviennent inaccessibles. Cette action est irréversible.'**
  String get privacyDetailPageDeletionClosesYourAccountAndSessions;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une fois la demande acceptée, le nettoyage de vos données continue en arrière-plan. Vous pouvez exporter vos données avant de poursuivre. En cas de réponse perdue, l’app fermera la session locale sans annoncer une suppression confirmée.'**
  String get privacyDetailPageOnceAcceptedYourDataContinuesTo;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Écrivez SUPPRIMER pour confirmer'**
  String get privacyDetailPageTypeDeleteToConfirm;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement votre compte ?'**
  String get privacyDetailPagePermanentlyDeleteYourAccount;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre compte sera fermé dès l’acceptation de la demande. Le nettoyage continuera ensuite en arrière-plan.'**
  String get privacyDetailPageYourAccountClosesAsSoonAs;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Demande en cours…'**
  String get privacyDetailPageRequestInProgress;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement mon compte'**
  String get privacyDetailPagePermanentlyDeleteMyAccount;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos préférences publicitaires ne sont pas accessibles pour le moment.'**
  String get privacyHubPageYourAdvertisingPreferencesAreCurrentlyUnavailable;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Vie privée et sécurité'**
  String get privacyHubPagePrivacyAndSecurity;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'VOTRE ESPACE, VOS CHOIX'**
  String get privacyHubPageYourSpaceYourChoices;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'En toute\nconfiance.'**
  String get privacyHubPageWithConfidence;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez vos choix, vos accès et vos données. Ces démarches restent disponibles avant la fin de votre inscription.'**
  String get privacyHubPageFindYourChoicesAccessAndData;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mes consentements'**
  String get privacyHubPageMyConsents;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Consulter ou modifier mes choix'**
  String get privacyHubPageViewOrChangeMyChoices;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Consulter et révoquer les accès'**
  String get privacyHubPageViewAndRevokeAccess;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Revoir mes préférences pour les vidéos'**
  String get privacyHubPageReviewMyVideoPreferences;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir les alertes et gérer les appareils'**
  String get privacyHubPageChooseAlertsAndManageDevices;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Gérer les blocages'**
  String get privacyHubPageManageBlocks;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Exercer mes droits et suivre mes demandes'**
  String get privacyHubPageExerciseMyRightsAndTrackRequests;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Télécharger puis choisir un partage'**
  String get privacyHubPageDownloadThenChooseWhereToShare;

  /// Interface: lib/features/privacy/presentation/privacy_hub_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer mon compte et demander son nettoyage'**
  String get privacyHubPageCloseMyAccountAndRequestCleanup;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Accès à mes données'**
  String get privacyStringsAccessToMyData;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Demande d’effacement'**
  String get privacyStringsErasureRequest;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Portabilité'**
  String get privacyStringsPortability;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Limitation du traitement'**
  String get privacyStringsRestrictionOfProcessing;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Opposition au traitement'**
  String get privacyStringsObjectionToProcessing;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Reçue'**
  String get privacyStringsReceived;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get privacyStringsInProgress;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get privacyStringsCompleted;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Rejetée'**
  String get privacyStringsRejected;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get privacyStringsInappropriateContent;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Faux profil'**
  String get privacyStringsFakeProfile;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Harcèlement'**
  String get privacyStringsHarassment;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Autre motif'**
  String get privacyStringsOtherReason;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette session a été révoquée.'**
  String get privacyStringsThisSessionWasRevoked;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette personne est débloquée. Les anciennes rencontres ne sont pas rétablies.'**
  String get privacyStringsThisPersonIsUnblockedPreviousMatches;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une demande de ce type est déjà ouverte. Son suivi est disponible ci-dessous.'**
  String get privacyStringsARequestOfThisTypeIs;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre demande a été reçue. Son traitement sera suivi ici.'**
  String get privacyStringsYourRequestWasReceivedProcessingWill;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre export est prêt sur cet appareil. Vous pouvez choisir où le partager.'**
  String get privacyStringsYourExportIsReadyOnThis;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La feuille de partage est fermée. Cela ne confirme pas la réception du fichier.'**
  String get privacyStringsTheShareSheetIsClosedThis;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le nettoyage du fichier temporaire n’a pas abouti. Réessayez de l’effacer.'**
  String get privacyStringsTemporaryFileCleanupFailedTryErasing;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le partage n’a pas pu être ouvert. Téléchargez à nouveau votre export pour réessayer.'**
  String get privacyStringsSharingCouldNotBeOpenedDownload;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n’a pas pu être enregistré. Vérifiez l’espace disponible.'**
  String get privacyStringsTheFileCouldNotBeSaved;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre export dépasse la taille autorisée. Vous pouvez déposer une demande d’accès à vos données.'**
  String get privacyStringsYourExportExceedsTheAllowedSize;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une demande de ce type est déjà ouverte.'**
  String get privacyStringsARequestOfThisTypeIs692;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Un signalement de cette personne est déjà en attente de traitement.'**
  String get privacyStringsAReportAboutThisPersonIs;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La confirmation a expiré. Recommencez la suppression si vous le souhaitez.'**
  String get privacyStringsConfirmationExpiredRestartDeletionIfYou;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'L’opération a été interrompue.'**
  String get privacyStringsTheOperationWasInterrupted;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La réponse n’a pas pu être confirmée. Actualisez le suivi avant de reprendre la même demande.'**
  String get privacyStringsTheResponseCouldNotBeConfirmed;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre demande de suppression a été acceptée. Votre compte est inaccessible ; le nettoyage de vos données continue en arrière-plan.'**
  String get privacyStringsYourDeletionRequestWasAcceptedYour;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La réponse à la suppression n’a pas été reçue. La session de cet appareil est fermée ; l’acceptation de la demande reste à confirmer.'**
  String get privacyStringsNoDeletionResponseWasReceivedThe;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La suppression du compte n’a pas été acceptée. La session de cet appareil est fermée. Reconnectez-vous si vous souhaitez recommencer.'**
  String get privacyStringsAccountDeletionWasNotAcceptedThis;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une fermeture de session ou de compte a été interrompue. La session locale est fermée ; le résultat sur le serveur n’est pas confirmé.'**
  String get privacyStringsSessionOrAccountClosureWasInterrupted;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos sessions ont été révoquées.'**
  String get privacyStringsAllYourSessionsWereRevoked;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes déconnecté sur cet appareil. La révocation sur le serveur n’a pas pu être confirmée.'**
  String get privacyStringsYouAreSignedOutOnThis;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Signaler un profil'**
  String get reportPageReportAProfile;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'PRENDRE SOIN DES ÉCHANGES'**
  String get reportPageCaringForConversations;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un espace\noù se sentir bien.'**
  String get reportPageASpaceToFeelAtEase;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre signalement sera transmis pour examen. Le blocage est un choix distinct, disponible après l’envoi.'**
  String get reportPageYourReportWillBeReviewedBlocking;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un court récit des faits suffit.'**
  String get reportPageABriefAccountOfWhatHappened;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La réponse reste à confirmer. Seul ce même signalement pourra être renvoyé. Revenir en arrière abandonne le brouillon local, sans annuler un éventuel envoi.'**
  String get reportPageTheResponseIsUnconfirmedOnlyThis;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Reprendre ce signalement'**
  String get reportPageResumeThisReport;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get reportPageSubmitReport;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre signalement a été reçu. Merci de nous avoir alertés.'**
  String get reportPageYourReportWasReceivedThankYou;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les échanges seront terminés. Vos anciennes rencontres ne seront pas rétablies après un déblocage.'**
  String get reportPageConversationsWillEndPreviousMatchesWill;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Bloquer aussi cette personne'**
  String get reportPageAlsoBlockThisPerson;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae est réservé aux personnes de 18 ans et plus.'**
  String get underage;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Le prénom est obligatoire (100 octets maximum).'**
  String get firstnameInvalid;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une valeur proposée.'**
  String get sexInvalid;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'La présentation dépasse 2 000 octets.'**
  String get bioTooLong;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Les âges doivent aller de 18 à 99 ans, dans cet ordre.'**
  String get ageRangeInvalid;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'La distance doit aller de 1 à 500 km.'**
  String get distanceInvalid;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Chaque réponse doit contenir de 10 à 300 caractères, sur une ligne (1 000 octets maximum).'**
  String get answerInvalid;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos réponses'**
  String get answersEditorYourAnswers;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'VOS MOTS, VOTRE HISTOIRE'**
  String get answersEditorYourWordsYourStory;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Trois questions.\nMille façons d’être vous.'**
  String get answersEditorThreeQuestionsAThousandWaysTo;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ce que vous souhaitez raconter. Vous décidez aussi de l’ordre de vos réponses.'**
  String get answersEditorChooseWhatYouWantToShare;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre sélection'**
  String get answersEditorYourSelection;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} / 3 réponses'**
  String answersEditor3Answers(Object arg0);

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre premier mot.'**
  String get answersEditorYourFirstWord;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Une habitude, une envie, une petite chose qui vous rend heureux. Commencez par une question.'**
  String get answersEditorAHabitAWishALittle;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'RÉPONSE {arg0}'**
  String answersEditorAnswer(Object arg0);

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Réponse {arg0}'**
  String answersEditorAnswer737(Object arg0);

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'10 à 300 caractères'**
  String get answersEditor10To300Characters;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette question n’est plus dans le catalogue. Retirez-la pour enregistrer une nouvelle sélection.'**
  String get answersEditorThisQuestionIsNoLongerIn;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Monter la réponse {arg0}'**
  String answersEditorMoveAnswerUp(Object arg0);

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Descendre la réponse {arg0}'**
  String answersEditorMoveAnswerDown(Object arg0);

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une question'**
  String get answersEditorAddAQuestion;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre sélection est complète. Retirez une question pour en choisir une autre.'**
  String get answersEditorYourSelectionIsCompleteRemoveA;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos réponses seront visibles sur votre profil après validation. Évitez les coordonnées personnelles.'**
  String get answersEditorYourAnswersWillAppearOnYour;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer mes réponses'**
  String get answersEditorSaveMyAnswers;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirez la question indisponible avant d’enregistrer.'**
  String get answersEditorRemoveTheUnavailableQuestionBeforeSaving;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Effacer toutes vos réponses ?'**
  String get answersEditorEraseAllYourAnswers;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer cette sélection ?'**
  String get answersEditorSaveThisSelection;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette sélection remplacera toutes vos réponses actuelles, dans cet ordre.'**
  String get answersEditorThisSelectionWillReplaceAllYour;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get answersEditorEraseAll;

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get answersEditorSave;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'À votre façon.'**
  String get identityEditorYourOwnWay;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Les détails du quotidien font souvent les plus belles conversations.'**
  String get identityEditorEverydayDetailsOftenMakeTheBest;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get identityEditorFirstName;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get identityEditorDateOfBirth;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'AAAA-MM-JJ · Vous devez avoir 18 ans ou plus.'**
  String get identityEditorYyyyMmDdYouMustBe;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Sexe'**
  String get identityEditorSex;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Le sexe est facultatif pour enregistrer ce profil. Son utilisation demande votre consentement aux données sensibles, accessible depuis vos choix de vie privée.'**
  String get identityEditorSexIsOptionalWhenSavingThis;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Quelques mots sur vous'**
  String get identityEditorAFewWordsAboutYou;

  /// Interface: lib/features/profile/presentation/identity_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'2 000 octets maximum · Évitez vos coordonnées.'**
  String get identityEditor2000BytesMaximumAvoidContact;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une sélection a été interrompue. Choisissez à nouveau votre photo pour ce compte.'**
  String get photoPageSelectionWasInterruptedChooseYourPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'L’aperçu temporaire n’est pas disponible. Actualisez pour obtenir un nouveau lien.'**
  String get photoPageTheTemporaryPreviewIsUnavailableRefresh;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Changer la sélection ?'**
  String get photoPageChangeSelection;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La demande photo en mémoire sera abandonnée.'**
  String get photoPageTheSavedPhotoRequestWillBe;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir une autre photo'**
  String get photoPageChooseAnotherPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Photo reçue. Son état de vérification est affiché ci-dessous.'**
  String get photoPagePhotoReceivedItsReviewStatusIs;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre photo'**
  String get photoPageYourPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un visage,\nau bon moment.'**
  String get photoPageAFaceAtTheRightTime;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une seule photo personnelle. Elle n’apparaît pas dans le feed et sa révélation demandera votre accord mutuel.'**
  String get photoPageOnePersonalPhotoItDoesNot;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre photo actuelle'**
  String get photoPageYourCurrentPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre sélection, pas encore enregistrée'**
  String get photoPageYourSelectionNotYetConfirmedBy;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Aperçu non disponible'**
  String get photoPagePreviewUnavailable;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Préparation ou chargement de la photo'**
  String get photoPagePreparingOrLoadingPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Photo actuelle : {arg0}'**
  String photoPageCurrentPhoto(Object arg0);

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Sélection préparée : {arg0} octets. Elle remplacera votre photo actuelle après envoi.'**
  String photoPagePreparedSelectionBytesItWillReplace(Object arg0);

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'L’envoi peut avoir abouti. Reprendre conserve exactement la même photo et la même demande. Aucun renvoi automatique.'**
  String get photoPageTheUploadMayHaveSucceededResuming;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get photoPageChooseAPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ou reprendre cette photo'**
  String get photoPageSendOrResumeThisPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser la photo et son état'**
  String get photoPageRefreshPhotoAndStatus;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer votre photo ?'**
  String get photoPageRemoveYourPhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'La photo ne sera plus disponible. Le nettoyage du stockage se poursuivra en arrière-plan.'**
  String get photoPageThePhotoWillNoLongerBe;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get photoPageRemovePhoto;

  /// Interface: lib/features/profile/presentation/photo_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer ma photo'**
  String get photoPageRemoveMyPhoto;

  /// Interface: lib/features/profile/presentation/preferences_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez vos quatre préférences. Elles seront enregistrées ensemble.'**
  String get preferencesEditorChooseYourFourPreferencesTheyWill;

  /// Interface: lib/features/profile/presentation/preferences_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Je souhaite rencontrer'**
  String get preferencesEditorIWantToMeet;

  /// Interface: lib/features/profile/presentation/preferences_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Âge minimum'**
  String get preferencesEditorMinimumAge;

  /// Interface: lib/features/profile/presentation/preferences_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Âge maximum'**
  String get preferencesEditorMaximumAge;

  /// Interface: lib/features/profile/presentation/preferences_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Distance maximale (km)'**
  String get preferencesEditorMaximumDistanceKm;

  /// Interface: lib/features/profile/presentation/profile_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans enregistrer ?'**
  String get profileEditorLeaveWithoutSaving;

  /// Interface: lib/features/profile/presentation/profile_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Les mots que vous venez d’écrire ne seront pas conservés.'**
  String get profileEditorYourDraftWillBeDiscarded;

  /// Interface: lib/features/profile/presentation/profile_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get profileEditorLeave;

  /// Interface: lib/features/profile/presentation/profile_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement ou relecture en cours'**
  String get profileEditorSavingOrRefreshing;

  /// Interface: lib/features/profile/presentation/profile_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu vérifier l’enregistrement. Vos mots sont conservés ici. Actualisez avant de réessayer.'**
  String get profileEditorTheResultIsUncertainRefreshThe;

  /// Interface: lib/features/profile/presentation/profile_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifier l’enregistrement'**
  String get profileEditorRefreshServerData;

  /// Interface: lib/features/profile/presentation/profile_feed_preview_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mon profil dans le feed'**
  String get profileFeedPreviewPageMyProfileInTheFeed;

  /// Interface: lib/features/profile/presentation/profile_feed_preview_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Comme au fil des mots.'**
  String get profileFeedPreviewPageThroughYourWords;

  /// Interface: lib/features/profile/presentation/profile_feed_preview_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Voici les éléments de votre profil présentés aux autres. Seuls les textes approuvés sont affichés. Votre photo reste absente du feed.'**
  String get profileFeedPreviewPageTheseAreThePartsOfYour;

  /// Interface: lib/features/profile/presentation/profile_feed_preview_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualisation de votre aperçu'**
  String get profileFeedPreviewPageRefreshingYourPreview;

  /// Interface: lib/features/profile/presentation/profile_feed_preview_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre aperçu ne peut pas être affiché. Revenez à votre profil pour le compléter ou actualisez vos informations.'**
  String get profileFeedPreviewPageYourPreviewCannotBeShownReturn;

  /// Interface: lib/features/profile/presentation/profile_feed_preview_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Distance selon la personne'**
  String get profileFeedPreviewPageDistanceDependsOnTheViewer;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'VOTRE HISTOIRE'**
  String get profilePageYourProfile;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Une rencontre\ncommence par vous.'**
  String get profilePageAMeetingStartsWithYou;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0}, à votre façon.'**
  String profilePageTheWordsOf(Object arg0);

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Un souvenir, une envie, un petit bonheur. Offrez un point de départ à la conversation.'**
  String get profilePageAWayToTellYourStory;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de mon profil'**
  String get profilePagePreviewMyProfile;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Chargement du profil'**
  String get profilePageLoadingProfile;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Nous n’avons pas pu vérifier l’enregistrement. Actualisez votre profil avant de réessayer ; votre photo peut être renvoyée à l’identique.'**
  String get profilePageSavingIsUncertainRefreshTheData;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser mon profil'**
  String get profilePageRefreshMyProfile;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Les détails qui comptent.'**
  String get profilePageTheDetailsThatMatter;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mes réglages'**
  String get profilePageYourAccount;

  /// Interface: lib/features/profile/presentation/profile_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Mes crédits'**
  String get profilePageMyContinuationCredits;

  /// Interface: lib/features/profile/presentation/profile_panels.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos réponses n’ont pas pu être relues. Actualisez votre profil pour les retrouver.'**
  String get profilePanelsYourAnswersCouldNotBeRefreshed;

  /// Interface: lib/features/profile/presentation/profile_panels.dart
  ///
  /// In fr, this message translates to:
  /// **'Un dimanche parfait, une chanson en boucle, une passion inattendue…'**
  String get profilePanelsLittleDetailsMakeGreatConversations;

  /// Interface: lib/features/profile/presentation/profile_panels.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez jusqu’à trois questions. Pas besoin d’une réponse parfaite, juste de la vôtre.'**
  String get profilePanelsChooseUpToThreeQuestionsTo;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Créer mon profil'**
  String get profileSectionsCreateMyProfile;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Modifier ma présentation'**
  String get profileSectionsEditMyIntroduction;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre présentation n’a pas pu être relue.'**
  String get profileSectionsYourIntroductionCouldNotBeRefreshed;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce qui vous fait rire, ce qui vous anime, ce que vous aimeriez partager… Quelques mots suffisent pour commencer.'**
  String get profileSectionsBooksYouLovePlacesYouFeel;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Des débuts de conversation'**
  String get profileSectionsConversationStarters;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'À actualiser'**
  String get profileSectionsRefreshNeeded;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Écrire mes réponses'**
  String get profileSectionsWriteMyAnswers;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos préférences n’ont pas pu être relues.'**
  String get profileSectionsYourPreferencesCouldNotBeRefreshed;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Les personnes, les âges et la distance qui vous correspondent.'**
  String get profileSectionsThePeopleAgesAndDistanceThat;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Modifier mes préférences'**
  String get profileSectionsEditMyPreferences;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir mes consentements'**
  String get profileSectionsChooseMyConsents;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce qui vous ressemble'**
  String get profileSectionsWhatMakesYouYou;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos traits n’ont pas pu être relus.'**
  String get profileSectionsYourTraitsCouldNotBeRefreshed;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Quelques traits pour donner un aperçu de votre personnalité.'**
  String get profileSectionsAFewTraitsToShowYour;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos petites touches personnelles.'**
  String get profileSectionsTheTraitsYouChoseToTell;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir mes traits'**
  String get profileSectionsChooseMyTraits;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Une photo, pour plus tard'**
  String get profileSectionsAPhotoForLater;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre photo n’a pas pu être vérifiée.'**
  String get profileSectionsYourPhotoCouldNotBeChecked;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Une seule photo, révélée après votre accord mutuel.'**
  String get profileSectionsOnePhotoRevealedAfterMutualConsent;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'Gérer ma photo'**
  String get profileSectionsManageMyPhoto;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez le prénom, la date de naissance, le sexe et la présentation.'**
  String get profileStringsCheckYourFirstNameDateOf;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez les quatre préférences et leurs limites.'**
  String get profileStringsCheckAllFourPreferencesAndTheir;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez vos réponses : trois questions distinctes maximum, de 10 à 300 caractères chacune.'**
  String get profileStringsCheckYourAnswersUpToThree;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une question n’est plus disponible. Relisez le catalogue avant de modifier votre sélection ; votre brouillon reste affiché.'**
  String get profileStringsAQuestionIsNoLongerAvailable;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce trait n’est plus disponible. Actualisez les traits.'**
  String get profileStringsThisTraitIsNoLongerAvailable;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Créez d’abord votre profil.'**
  String get profileStringsCreateYourProfileFirst;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La photo n’a pas pu être préparée. Vérifiez l’accès aux photos dans les réglages, ou choisissez une autre image.'**
  String get profileStringsThePhotoCouldNotBePrepared;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette photo n’est pas reconnue. Choisissez une autre image.'**
  String get profileStringsThisPhotoIsNotRecognizedChoose;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'La photo doit faire au maximum 500 000 octets après préparation.'**
  String get profileStringsThePreparedPhotoMustBeNo;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Les photos sont temporairement indisponibles.'**
  String get profileStringsPhotosAreTemporarilyUnavailable;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Une mise à jour photo est en cours. Relisez le profil puis reprenez la même demande.'**
  String get profileStringsAPhotoUpdateIsInProgress;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Cette demande photo ne peut plus être reprise. Relisez votre profil avant de choisir une nouvelle photo.'**
  String get profileStringsThisPhotoRequestCanNoLonger;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune analyse disponible.'**
  String get profileStringsNoAnalysisAvailable;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'En cours de vérification'**
  String get profileStringsUnderReview;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Approuvé'**
  String get profileStringsApproved;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'À modifier'**
  String get profileStringsNeedsEditing;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'contenu répétitif ou promotionnel'**
  String get profileStringsRepetitiveOrPromotionalContent;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'propos insultants'**
  String get profileStringsInsultingLanguage;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'coordonnées personnelles'**
  String get profileStringsPersonalContactDetails;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'contenu explicite'**
  String get profileStringsExplicitContent;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'visage non détecté'**
  String get profileStringsNoFaceDetected;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'plusieurs visages'**
  String get profileStringsMultipleFaces;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'image floue'**
  String get profileStringsBlurryImage;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'analyse temporairement indisponible'**
  String get profileStringsAnalysisTemporarilyUnavailable;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'contenu à revérifier'**
  String get profileStringsContentNeedsRechecking;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'vérification nécessaire'**
  String get profileStringsReviewNeeded;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get profileStringsNotProvided;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Des femmes'**
  String get profileStringsWomen;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Des hommes'**
  String get profileStringsMen;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Des femmes et des hommes'**
  String get profileStringsWomenAndMen;

  /// Interface: lib/features/profile/presentation/question_picker.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisir une question'**
  String get questionPickerChooseAQuestion;

  /// Interface: lib/features/profile/presentation/question_picker.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer les questions'**
  String get questionPickerCloseQuestions;

  /// Interface: lib/features/profile/presentation/question_picker.dart
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get questionPickerSearch;

  /// Interface: lib/features/profile/presentation/question_picker.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre question n’est proposée pour le moment.'**
  String get questionPickerNoOtherQuestionsAreCurrentlyAvailable;

  /// Interface: lib/features/profile/presentation/question_picker.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucune question ne correspond à votre recherche.'**
  String get questionPickerNoQuestionsMatchYourSearch;

  /// Interface: lib/features/profile/presentation/traits_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Vos traits'**
  String get traitsEditorYourTraits;

  /// Interface: lib/features/profile/presentation/traits_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Ce qui vous ressemble. Chaque choix est enregistré immédiatement.'**
  String get traitsEditorWhatMakesYouYouEachChoice;

  /// Interface: lib/features/profile/presentation/traits_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'Aucun trait n’est proposé pour le moment.'**
  String get traitsEditorNoTraitsAreCurrentlyAvailable;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'+33 6 12 34 56 78'**
  String get appStrings33612345678;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get appStringsRefresh;

  /// Interface: lib/core/l10n/app_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Messagerie'**
  String get appStringsMessaging;

  /// Interface: lib/features/consents/presentation/consent_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get consentStringsLocation;

  /// Interface: lib/features/continuation/presentation/credits_balance_panel.dart
  ///
  /// In fr, this message translates to:
  /// **'Gratuits'**
  String get creditsBalancePanelFree;

  /// Interface: lib/features/continuation/presentation/credits_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Conserver'**
  String get creditsPageKeep;

  /// Interface: lib/features/matches/data/match_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Écrivez quelques mots avant d’envoyer.'**
  String get messageEmpty;

  /// Interface: lib/features/matches/presentation/chat_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get chatPageSend;

  /// Interface: lib/features/matches/presentation/conversation_header.dart
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get conversationHeaderClose;

  /// Interface: lib/features/matches/presentation/match_preview_card.dart
  ///
  /// In fr, this message translates to:
  /// **'Vous : '**
  String get matchPreviewCardYou;

  /// Interface: lib/features/notifications/presentation/devices_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get devicesPageRemove;

  /// Interface: lib/features/privacy/data/privacy_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Votre description est trop longue. Raccourcissez-la avant de l’envoyer.'**
  String get reportTooLong;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Transmettre'**
  String get privacyDetailPageSubmit;

  /// Interface: lib/features/privacy/presentation/privacy_detail_page.dart
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get privacyDetailPageDelete;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Rectification'**
  String get privacyStringsRectification;

  /// Interface: lib/features/privacy/presentation/privacy_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Spam'**
  String get privacyStringsSpam;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get reportPageReason;

  /// Interface: lib/features/privacy/presentation/report_page.dart
  ///
  /// In fr, this message translates to:
  /// **'Description (facultative)'**
  String get reportPageDescriptionOptional;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Indiquez une date valide au format AAAA-MM-JJ.'**
  String get birthdateInvalid;

  /// Interface: lib/features/profile/data/profile_models.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez les personnes que vous souhaitez rencontrer.'**
  String get peopleRequired;

  /// Interface: lib/features/profile/presentation/profile_sections.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} · {arg1}–{arg2} ans · {arg3} km'**
  String profileSectionsAgesKm(
    Object arg0,
    Object arg1,
    Object arg2,
    Object arg3,
  );

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get profileStringsWoman;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get profileStringsMan;

  /// Interface: lib/features/profile/presentation/profile_strings.dart
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get profileStringsOther;

  /// Interface: lib/features/continuation/presentation/continuation_balance_card.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} : {arg1}'**
  String continuationBalanceCard(Object arg0, Object arg1);

  /// Interface: lib/features/discovery/presentation/encounter_page.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0}, {arg1}'**
  String encounterPage(Object arg0, Object arg1);

  /// Interface: lib/features/matches/presentation/match_preview_card.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0}{arg1}'**
  String matchPreviewCard(Object arg0, Object arg1);

  /// Interface: lib/features/matches/presentation/match_preview_card.dart
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one {{count} message non lu} other {{count} messages non lus}}'**
  String unreadMessages(num count);

  /// Interface: lib/features/profile/presentation/answers_editor.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0} / 300'**
  String answersEditor300(Object arg0);

  /// Interface: lib/features/profile/presentation/profile_panels.dart
  ///
  /// In fr, this message translates to:
  /// **'{arg0}  /  {arg1}'**
  String profilePanels(Object arg0, Object arg1);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'{price} / mois'**
  String priceMonthly(String price);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'{price} / an'**
  String priceAnnual(String price);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'À {distance} km'**
  String distanceKm(String distance);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Rencontre créée le {date}.'**
  String matchCreatedOn(String date);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Choisir {name}'**
  String chooseOffer(String name);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one {continuation disponible} other {continuations disponibles}}'**
  String creditsAvailable(num count);

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageTitle;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Langue de l’appareil'**
  String get languageSystem;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'La langue n’a pas pu être enregistrée. Réessayez.'**
  String get languageSaveFailure;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement de la langue…'**
  String get languageSaving;

  /// Localized interface copy
  ///
  /// In fr, this message translates to:
  /// **'La langue choisie s’applique à l’interface, aux catalogues et aux notifications de cet appareil. Un choix connecté met aussi à jour la préférence du compte. Les messages, bios et réponses des personnes conservent leur langue d’origine.'**
  String get languageDescription;

  /// iOS permission copy; regenerate native resources with tool/generate_native_localizations.dart
  ///
  /// In fr, this message translates to:
  /// **'Histae utilise une position ponctuelle pour proposer des rencontres à proximité. Votre position exacte reste privée, sans suivi en arrière-plan.'**
  String get iosLocationPermission;

  /// iOS permission copy; regenerate native resources with tool/generate_native_localizations.dart
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre unique photo de profil Histae. Elle sera révélée uniquement après un accord mutuel.'**
  String get iosPhotoPermission;

  /// iOS permission copy; regenerate native resources with tool/generate_native_localizations.dart
  ///
  /// In fr, this message translates to:
  /// **'En développement, Histae se connecte au serveur de test sur votre réseau local.'**
  String get iosLocalNetworkPermission;

  /// Open the foreground notification
  ///
  /// In fr, this message translates to:
  /// **'Consulter'**
  String get viewNotification;

  /// Friendly interface copy for the profile or matches screen.
  ///
  /// In fr, this message translates to:
  /// **'À votre rythme.'**
  String get profileAtYourPace;

  /// Friendly interface copy for the profile or matches screen.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de rencontre'**
  String get matchesEmptyTitle;

  /// No description provided for @billingRestorePurchases.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer mes achats'**
  String get billingRestorePurchases;

  /// No description provided for @billingStorePriceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Prix du store indisponible'**
  String get billingStorePriceUnavailable;

  /// No description provided for @billingStoreManagedWeb.
  ///
  /// In fr, this message translates to:
  /// **'Cet abonnement a été souscrit sur le site. Sa gestion s’effectue sur le site Histae.'**
  String get billingStoreManagedWeb;

  /// No description provided for @billingStorePending.
  ///
  /// In fr, this message translates to:
  /// **'Achat en attente de confirmation par le store.'**
  String get billingStorePending;

  /// No description provided for @billingStorePurchaseFailed.
  ///
  /// In fr, this message translates to:
  /// **'L’achat ne peut pas être confirmé pour ce compte.'**
  String get billingStorePurchaseFailed;

  /// No description provided for @billingStoreVerifying.
  ///
  /// In fr, this message translates to:
  /// **'Vérification de l’achat…'**
  String get billingStoreVerifying;

  /// No description provided for @billingStoreGrace.
  ///
  /// In fr, this message translates to:
  /// **'Délai de grâce de paiement'**
  String get billingStoreGrace;

  /// No description provided for @billingStoreRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement révoqué'**
  String get billingStoreRevoked;

  /// No description provided for @billingStoreOnHold.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement suspendu pour incident de paiement'**
  String get billingStoreOnHold;

  /// No description provided for @billingStorePricePerMonth.
  ///
  /// In fr, this message translates to:
  /// **'{price} par mois'**
  String billingStorePricePerMonth(String price);

  /// No description provided for @billingStorePricePerYear.
  ///
  /// In fr, this message translates to:
  /// **'{price} par an'**
  String billingStorePricePerYear(String price);

  /// No description provided for @billingStoreContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer dans le store'**
  String get billingStoreContinue;

  /// No description provided for @billingStoreConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement à renouvellement automatique, sans période d’essai : {price}. Le store confirmera le montant avant le paiement.'**
  String billingStoreConfirm(String price);

  /// No description provided for @billingStorePriceInSubscription.
  ///
  /// In fr, this message translates to:
  /// **'Le prix de cette offre est affiché dans Mon abonnement.'**
  String get billingStorePriceInSubscription;

  /// No description provided for @billingStoreDeletionNotice.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer votre compte Histae ne résilie pas un abonnement App Store ou Google Play. Gérez ou annulez cet abonnement dans le store avant de supprimer le compte.'**
  String get billingStoreDeletionNotice;

  /// No description provided for @accountIdentifierTitle.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant de mon compte'**
  String get accountIdentifierTitle;

  /// No description provided for @accountIdentifierCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier mon identifiant'**
  String get accountIdentifierCopy;

  /// No description provided for @accountIdentifierCopied.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant copié'**
  String get accountIdentifierCopied;

  /// No description provided for @accountIdentifierCopyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de copier l’identifiant'**
  String get accountIdentifierCopyFailed;

  /// No description provided for @subscriptionPreviousOffer.
  ///
  /// In fr, this message translates to:
  /// **'Offre précédente'**
  String get subscriptionPreviousOffer;

  /// No description provided for @subscriptionNextOffer.
  ///
  /// In fr, this message translates to:
  /// **'Offre suivante'**
  String get subscriptionNextOffer;

  /// Position of the selected subscription offer in the carousel.
  ///
  /// In fr, this message translates to:
  /// **'Offre {current} sur {total}'**
  String subscriptionOfferPosition(int current, int total);

  /// No description provided for @subscriptionFreeOffer.
  ///
  /// In fr, this message translates to:
  /// **'Gratuit'**
  String get subscriptionFreeOffer;

  /// No description provided for @subscriptionMonthlyOffer.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get subscriptionMonthlyOffer;

  /// No description provided for @subscriptionAnnualOffer.
  ///
  /// In fr, this message translates to:
  /// **'Annuel'**
  String get subscriptionAnnualOffer;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get registrationProfileStep;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Vos préférences'**
  String get registrationPreferencesStep;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Vos consentements'**
  String get registrationConsentsStep;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro'**
  String get registrationPhoneStep;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Étape {step} sur 4 · {title}'**
  String registrationStep(int step, String title);

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get registrationContinue;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Prenez le temps de vous présenter. Vos informations restent sur cet appareil pendant ce parcours et ne seront envoyées qu’après la vérification de votre numéro.'**
  String get registrationLocalDraft;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Votre sexe et vos préférences ne seront transmis qu’avec votre accord à l’étape suivante, après la vérification de votre numéro.'**
  String get registrationSensitiveDraft;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Vos choix seront enregistrés après la vérification de votre numéro. Vous pouvez refuser les données sensibles et la localisation ; la découverte restera alors indisponible.'**
  String get registrationConsentIntro;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Un dernier pas, et vous y êtes.'**
  String get registrationPhoneTitle;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre numéro par SMS pour créer votre compte et enregistrer votre présentation. Votre numéro n’apparaîtra pas sur votre profil.'**
  String get registrationPhoneIntro;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Quitter cette inscription ?'**
  String get registrationLeaveTitle;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Les informations de ce parcours qui n’ont pas été enregistrées seront perdues.'**
  String get registrationLeaveBody;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est déjà lié à un compte Histae. Retrouvez votre espace : votre profil existant sera conservé.'**
  String get registrationExistingAccount;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Finaliser votre inscription'**
  String get registrationSaving;

  /// Registration flow before phone verification
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro est vérifié. Vos informations sont conservées pendant ce parcours : vous pouvez reprendre l’enregistrement sans demander un nouveau code.'**
  String get registrationRetrySave;
}

class _AppMessagesDelegate extends LocalizationsDelegate<AppMessages> {
  const _AppMessagesDelegate();

  @override
  Future<AppMessages> load(Locale locale) {
    return SynchronousFuture<AppMessages>(lookupAppMessages(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppMessagesDelegate old) => false;
}

AppMessages lookupAppMessages(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppMessagesEn();
    case 'es':
      return AppMessagesEs();
    case 'fr':
      return AppMessagesFr();
    case 'it':
      return AppMessagesIt();
  }

  throw FlutterError(
    'AppMessages.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
