import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Speaking P2P'**
  String get appName;

  /// No description provided for @tabExam.
  ///
  /// In es, this message translates to:
  /// **'Examen'**
  String get tabExam;

  /// No description provided for @tabAgenda.
  ///
  /// In es, this message translates to:
  /// **'Agenda'**
  String get tabAgenda;

  /// No description provided for @tabProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get tabProfile;

  /// No description provided for @tabSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get tabSettings;

  /// No description provided for @homeHello.
  ///
  /// In es, this message translates to:
  /// **'Hola,'**
  String get homeHello;

  /// No description provided for @searchPartner.
  ///
  /// In es, this message translates to:
  /// **'Buscar pareja'**
  String get searchPartner;

  /// No description provided for @examOfLevel.
  ///
  /// In es, this message translates to:
  /// **'Examen de Speaking {level}'**
  String examOfLevel(String level);

  /// No description provided for @examSummary.
  ///
  /// In es, this message translates to:
  /// **'4 partes · ~{minutes} min + 5 min de feedback'**
  String examSummary(int minutes);

  /// No description provided for @offlineBanner.
  ///
  /// In es, this message translates to:
  /// **'Modo sin conexión: practica con un compañero simulado.'**
  String get offlineBanner;

  /// No description provided for @practiceSimulated.
  ///
  /// In es, this message translates to:
  /// **'Practicar con compañero simulado'**
  String get practiceSimulated;

  /// No description provided for @levelB1.
  ///
  /// In es, this message translates to:
  /// **'B1 Preliminary'**
  String get levelB1;

  /// No description provided for @levelB2.
  ///
  /// In es, this message translates to:
  /// **'B2 First'**
  String get levelB2;

  /// No description provided for @levelC1.
  ///
  /// In es, this message translates to:
  /// **'C1 Advanced'**
  String get levelC1;

  /// No description provided for @partOf.
  ///
  /// In es, this message translates to:
  /// **'PARTE {n} DE 4'**
  String partOf(int n);

  /// No description provided for @examiner.
  ///
  /// In es, this message translates to:
  /// **'Examinador'**
  String get examiner;

  /// No description provided for @examinerQuestion.
  ///
  /// In es, this message translates to:
  /// **'Pregunta del examinador'**
  String get examinerQuestion;

  /// No description provided for @hideText.
  ///
  /// In es, this message translates to:
  /// **'Ocultar texto'**
  String get hideText;

  /// No description provided for @showText.
  ///
  /// In es, this message translates to:
  /// **'Ver texto'**
  String get showText;

  /// No description provided for @hideTimer.
  ///
  /// In es, this message translates to:
  /// **'Ocultar cronómetro'**
  String get hideTimer;

  /// No description provided for @showTimer.
  ///
  /// In es, this message translates to:
  /// **'Mostrar cronómetro'**
  String get showTimer;

  /// No description provided for @yourTurn.
  ///
  /// In es, this message translates to:
  /// **'Te toca responder a ti'**
  String get yourTurn;

  /// No description provided for @partnerTurn.
  ///
  /// In es, this message translates to:
  /// **'Le toca a {name}'**
  String partnerTurn(String name);

  /// No description provided for @micOpen.
  ///
  /// In es, this message translates to:
  /// **'Tu micro está abierto'**
  String get micOpen;

  /// No description provided for @micMuted.
  ///
  /// In es, this message translates to:
  /// **'Tu micro está silenciado'**
  String get micMuted;

  /// No description provided for @examinerSpeaking.
  ///
  /// In es, this message translates to:
  /// **'El examinador está hablando'**
  String get examinerSpeaking;

  /// No description provided for @bothMuted.
  ///
  /// In es, this message translates to:
  /// **'Micros de los dos silenciados'**
  String get bothMuted;

  /// No description provided for @addressedToBoth.
  ///
  /// In es, this message translates to:
  /// **'Para: los dos'**
  String get addressedToBoth;

  /// No description provided for @addressedToYou.
  ///
  /// In es, this message translates to:
  /// **'Para: ti'**
  String get addressedToYou;

  /// No description provided for @addressedTo.
  ///
  /// In es, this message translates to:
  /// **'Para: {name}'**
  String addressedTo(String name);

  /// No description provided for @you.
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get you;

  /// No description provided for @roleLabel.
  ///
  /// In es, this message translates to:
  /// **'{name} · {role}'**
  String roleLabel(String name, String role);

  /// No description provided for @statusMuted.
  ///
  /// In es, this message translates to:
  /// **'Silenciado'**
  String get statusMuted;

  /// No description provided for @statusSpeaking.
  ///
  /// In es, this message translates to:
  /// **'Hablando'**
  String get statusSpeaking;

  /// No description provided for @statusMicOpen.
  ///
  /// In es, this message translates to:
  /// **'Micro abierto'**
  String get statusMicOpen;

  /// No description provided for @choosesTwoPhotos.
  ///
  /// In es, this message translates to:
  /// **'{name} elige dos de estas fotos'**
  String choosesTwoPhotos(String name);

  /// No description provided for @describesPhoto.
  ///
  /// In es, this message translates to:
  /// **'{name} describe esta foto'**
  String describesPhoto(String name);

  /// No description provided for @comparesPhotos.
  ///
  /// In es, this message translates to:
  /// **'{name} compara estas fotos'**
  String comparesPhotos(String name);

  /// No description provided for @photoPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Foto · {id}'**
  String photoPlaceholder(String id);

  /// No description provided for @discussionPhase.
  ///
  /// In es, this message translates to:
  /// **'Discusión · {minutes} min'**
  String discussionPhase(int minutes);

  /// No description provided for @decisionPhase.
  ///
  /// In es, this message translates to:
  /// **'Decisión · {minutes} min'**
  String decisionPhase(int minutes);

  /// No description provided for @startingIn.
  ///
  /// In es, this message translates to:
  /// **'El examen empieza en {seconds}'**
  String startingIn(int seconds);

  /// No description provided for @abandon.
  ///
  /// In es, this message translates to:
  /// **'Abandonar'**
  String get abandon;

  /// No description provided for @abandonTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres salir?'**
  String get abandonTitle;

  /// No description provided for @abandonBody.
  ///
  /// In es, this message translates to:
  /// **'El examen terminará para los dos y {name} volverá al inicio. Si estás usando tu test de prueba, se dará por consumido.'**
  String abandonBody(String name);

  /// No description provided for @keepGoing.
  ///
  /// In es, this message translates to:
  /// **'Seguir en el examen'**
  String get keepGoing;

  /// No description provided for @leaveExam.
  ///
  /// In es, this message translates to:
  /// **'Salir del examen'**
  String get leaveExam;

  /// No description provided for @leaveExamIn.
  ///
  /// In es, this message translates to:
  /// **'Salir del examen ({seconds})'**
  String leaveExamIn(int seconds);

  /// No description provided for @partnerLeft.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero ha salido'**
  String get partnerLeft;

  /// No description provided for @backHome.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get backHome;

  /// No description provided for @examFinished.
  ///
  /// In es, this message translates to:
  /// **'Examen terminado'**
  String get examFinished;

  /// No description provided for @feedbackSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ahora tenéis tiempo para daros feedback.'**
  String get feedbackSubtitle;

  /// No description provided for @feedbackTime.
  ///
  /// In es, this message translates to:
  /// **'TIEMPO DE FEEDBACK'**
  String get feedbackTime;

  /// No description provided for @micsOpenBoth.
  ///
  /// In es, this message translates to:
  /// **'Micros abiertos para los dos'**
  String get micsOpenBoth;

  /// No description provided for @feedbackIdeas.
  ///
  /// In es, this message translates to:
  /// **'IDEAS PARA EMPEZAR'**
  String get feedbackIdeas;

  /// No description provided for @feedbackIdea1.
  ///
  /// In es, this message translates to:
  /// **'¿Qué expresión o palabra del otro te ha gustado?'**
  String get feedbackIdea1;

  /// No description provided for @feedbackIdea2.
  ///
  /// In es, this message translates to:
  /// **'¿Hay algún error que se haya repetido?'**
  String get feedbackIdea2;

  /// No description provided for @feedbackIdea3.
  ///
  /// In es, this message translates to:
  /// **'En la Parte 3, ¿habéis dejado hablar al otro y llegado a una decisión?'**
  String get feedbackIdea3;

  /// No description provided for @endCall.
  ///
  /// In es, this message translates to:
  /// **'Terminar llamada'**
  String get endCall;

  /// No description provided for @simulatedPartner.
  ///
  /// In es, this message translates to:
  /// **'compañero_sim'**
  String get simulatedPartner;

  /// No description provided for @simulatedPartnerHint.
  ///
  /// In es, this message translates to:
  /// **'Modo desarrollo: el compañero es simulado y no habla.'**
  String get simulatedPartnerHint;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In es, this message translates to:
  /// **'APARIENCIA'**
  String get appearance;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @appLanguage.
  ///
  /// In es, this message translates to:
  /// **'IDIOMA DE LA APP'**
  String get appLanguage;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @subscription.
  ///
  /// In es, this message translates to:
  /// **'SUSCRIPCIÓN'**
  String get subscription;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'CUENTA'**
  String get account;

  /// No description provided for @termsOfUse.
  ///
  /// In es, this message translates to:
  /// **'Términos de uso'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicy;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccount;

  /// No description provided for @needsBackend.
  ///
  /// In es, this message translates to:
  /// **'Disponible cuando la app esté conectada al servidor.'**
  String get needsBackend;

  /// No description provided for @agendaTitle.
  ///
  /// In es, this message translates to:
  /// **'Agenda'**
  String get agendaTitle;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
