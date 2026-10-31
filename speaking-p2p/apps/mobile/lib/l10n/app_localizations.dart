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
  /// **'MirloTalk'**
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

  /// No description provided for @cuesMute.
  ///
  /// In es, this message translates to:
  /// **'Silenciar pitidos'**
  String get cuesMute;

  /// No description provided for @cuesUnmute.
  ///
  /// In es, this message translates to:
  /// **'Activar pitidos'**
  String get cuesUnmute;

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

  /// No description provided for @loginHeadline.
  ///
  /// In es, this message translates to:
  /// **'Practica el Speaking en pareja, con un examinador virtual.'**
  String get loginHeadline;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Él marca los turnos y el tiempo. Vosotros solo habláis.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @noAccountYet.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Crear una'**
  String get noAccountYet;

  /// No description provided for @haveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo cuenta'**
  String get haveAccount;

  /// No description provided for @checkYourEmail.
  ///
  /// In es, this message translates to:
  /// **'Te hemos enviado un correo para confirmar la cuenta. Ábrelo y vuelve a entrar.'**
  String get checkYourEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Escribe un email válido'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get passwordTooShort;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Email o contraseña incorrectos'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu email antes de entrar'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorEmailExists.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese email'**
  String get errorEmailExists;

  /// No description provided for @errorWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña es demasiado débil'**
  String get errorWeakPassword;

  /// No description provided for @errorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Espera un poco'**
  String get errorRateLimited;

  /// No description provided for @errorUsernameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ese nombre de usuario ya está cogido'**
  String get errorUsernameTaken;

  /// No description provided for @errorUnderage.
  ///
  /// In es, this message translates to:
  /// **'Debes tener al menos 14 años'**
  String get errorUnderage;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado. Inténtalo de nuevo'**
  String get errorGeneric;

  /// No description provided for @stepOf.
  ///
  /// In es, this message translates to:
  /// **'Paso {n} de 3'**
  String stepOf(int n);

  /// No description provided for @visibleToOthers.
  ///
  /// In es, this message translates to:
  /// **'Visible para otros usuarios'**
  String get visibleToOthers;

  /// No description provided for @privateOnlyYou.
  ///
  /// In es, this message translates to:
  /// **'Privado, solo lo ves tú'**
  String get privateOnlyYou;

  /// No description provided for @canChangeLater.
  ///
  /// In es, this message translates to:
  /// **'Podrás cambiarlo cuando quieras'**
  String get canChangeLater;

  /// No description provided for @publicProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu perfil público'**
  String get publicProfileTitle;

  /// No description provided for @usernameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get usernameLabel;

  /// No description provided for @usernameAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get usernameAvailable;

  /// No description provided for @usernameRules.
  ///
  /// In es, this message translates to:
  /// **'3–20 caracteres: minúsculas, números, _ y .'**
  String get usernameRules;

  /// No description provided for @languagesYouSpeak.
  ///
  /// In es, this message translates to:
  /// **'Idiomas que hablas'**
  String get languagesYouSpeak;

  /// No description provided for @otherLanguage.
  ///
  /// In es, this message translates to:
  /// **'+ Otro'**
  String get otherLanguage;

  /// No description provided for @accountDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos de tu cuenta'**
  String get accountDataTitle;

  /// No description provided for @birthDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get birthDate;

  /// No description provided for @dayLabel.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get dayLabel;

  /// No description provided for @monthLabel.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get monthLabel;

  /// No description provided for @yearLabel.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get yearLabel;

  /// No description provided for @minAgeHint.
  ///
  /// In es, this message translates to:
  /// **'Debes tener al menos 14 años.'**
  String get minAgeHint;

  /// No description provided for @invalidDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha no válida'**
  String get invalidDate;

  /// No description provided for @phoneOptional.
  ///
  /// In es, this message translates to:
  /// **'Teléfono (opcional)'**
  String get phoneOptional;

  /// No description provided for @invalidPhone.
  ///
  /// In es, this message translates to:
  /// **'Número no válido'**
  String get invalidPhone;

  /// No description provided for @linkedToAccount.
  ///
  /// In es, this message translates to:
  /// **'Vinculado a tu cuenta'**
  String get linkedToAccount;

  /// No description provided for @whichExamTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué examen preparas?'**
  String get whichExamTitle;

  /// No description provided for @speakingMinutes.
  ///
  /// In es, this message translates to:
  /// **'Speaking de {minutes} min'**
  String speakingMinutes(String minutes);

  /// No description provided for @acceptTerms.
  ///
  /// In es, this message translates to:
  /// **'He leído y acepto los Términos de uso y la Política de privacidad.'**
  String get acceptTerms;

  /// No description provided for @continueLabel.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueLabel;

  /// No description provided for @backLabel.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get backLabel;

  /// No description provided for @startLabel.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get startLabel;

  /// No description provided for @langEs.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get langEs;

  /// No description provided for @langEn.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get langEn;

  /// No description provided for @langCa.
  ///
  /// In es, this message translates to:
  /// **'Catalán'**
  String get langCa;

  /// No description provided for @langFr.
  ///
  /// In es, this message translates to:
  /// **'Francés'**
  String get langFr;

  /// No description provided for @langIt.
  ///
  /// In es, this message translates to:
  /// **'Italiano'**
  String get langIt;

  /// No description provided for @langDe.
  ///
  /// In es, this message translates to:
  /// **'Alemán'**
  String get langDe;

  /// No description provided for @langPt.
  ///
  /// In es, this message translates to:
  /// **'Portugués'**
  String get langPt;

  /// No description provided for @langEu.
  ///
  /// In es, this message translates to:
  /// **'Euskera'**
  String get langEu;

  /// No description provided for @langGl.
  ///
  /// In es, this message translates to:
  /// **'Gallego'**
  String get langGl;

  /// No description provided for @langZh.
  ///
  /// In es, this message translates to:
  /// **'Chino'**
  String get langZh;

  /// No description provided for @langAr.
  ///
  /// In es, this message translates to:
  /// **'Árabe'**
  String get langAr;

  /// No description provided for @langRu.
  ///
  /// In es, this message translates to:
  /// **'Ruso'**
  String get langRu;

  /// No description provided for @langUk.
  ///
  /// In es, this message translates to:
  /// **'Ucraniano'**
  String get langUk;

  /// No description provided for @langRo.
  ///
  /// In es, this message translates to:
  /// **'Rumano'**
  String get langRo;

  /// No description provided for @roomTitle.
  ///
  /// In es, this message translates to:
  /// **'Sala de espera · {level}'**
  String roomTitle(String level);

  /// No description provided for @meetBeforeStart.
  ///
  /// In es, this message translates to:
  /// **'Conoceos antes de empezar'**
  String get meetBeforeStart;

  /// No description provided for @examStartsIn.
  ///
  /// In es, this message translates to:
  /// **'El examen empieza solo en'**
  String get examStartsIn;

  /// No description provided for @waitingPartner.
  ///
  /// In es, this message translates to:
  /// **'Esperando a tu compañero…'**
  String get waitingPartner;

  /// No description provided for @candidateLine.
  ///
  /// In es, this message translates to:
  /// **'Candidato {role} · {langs}'**
  String candidateLine(String role, String langs);

  /// No description provided for @notConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Sin confirmar'**
  String get notConfirmed;

  /// No description provided for @readyBadge.
  ///
  /// In es, this message translates to:
  /// **'✓ Listo'**
  String get readyBadge;

  /// No description provided for @recordSession.
  ///
  /// In es, this message translates to:
  /// **'Grabar la sesión'**
  String get recordSession;

  /// No description provided for @recordOnlyIfBoth.
  ///
  /// In es, this message translates to:
  /// **'Solo si los dos lo activáis · {name}: {state}'**
  String recordOnlyIfBoth(String name, String state);

  /// No description provided for @switchedOn.
  ///
  /// In es, this message translates to:
  /// **'activado'**
  String get switchedOn;

  /// No description provided for @switchedOff.
  ///
  /// In es, this message translates to:
  /// **'desactivado'**
  String get switchedOff;

  /// No description provided for @materialDownloaded.
  ///
  /// In es, this message translates to:
  /// **'Material del examen descargado'**
  String get materialDownloaded;

  /// No description provided for @materialDownloading.
  ///
  /// In es, this message translates to:
  /// **'Descargando el material del examen…'**
  String get materialDownloading;

  /// No description provided for @imReady.
  ///
  /// In es, this message translates to:
  /// **'Estoy listo'**
  String get imReady;

  /// No description provided for @notReadyYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no estoy listo'**
  String get notReadyYet;

  /// No description provided for @leaveRoom.
  ///
  /// In es, this message translates to:
  /// **'Salir de la sala'**
  String get leaveRoom;

  /// No description provided for @connecting.
  ///
  /// In es, this message translates to:
  /// **'Conectando…'**
  String get connecting;

  /// No description provided for @sessionError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido entrar en la sala.'**
  String get sessionError;

  /// No description provided for @debugEnterNow.
  ///
  /// In es, this message translates to:
  /// **'Crear sala ahora (debug)'**
  String get debugEnterNow;

  /// No description provided for @debugSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar al siguiente tramo (debug)'**
  String get debugSkip;

  /// No description provided for @muteMe.
  ///
  /// In es, this message translates to:
  /// **'Silenciar mi micro'**
  String get muteMe;

  /// No description provided for @unmuteMe.
  ///
  /// In es, this message translates to:
  /// **'Activar mi micro'**
  String get unmuteMe;

  /// No description provided for @contentMissing.
  ///
  /// In es, this message translates to:
  /// **'Actualiza la app: este examen no está en tu versión.'**
  String get contentMissing;

  /// No description provided for @sessionClosed.
  ///
  /// In es, this message translates to:
  /// **'La sesión ha terminado.'**
  String get sessionClosed;

  /// No description provided for @partnerNoShow.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero no se ha conectado.'**
  String get partnerNoShow;

  /// No description provided for @micOnShort.
  ///
  /// In es, this message translates to:
  /// **'Micro abierto'**
  String get micOnShort;

  /// No description provided for @micOffShort.
  ///
  /// In es, this message translates to:
  /// **'Micro cerrado'**
  String get micOffShort;

  /// No description provided for @searchingPartner.
  ///
  /// In es, this message translates to:
  /// **'Buscando compañero…'**
  String get searchingPartner;

  /// No description provided for @whileYouWait.
  ///
  /// In es, this message translates to:
  /// **'MIENTRAS ESPERAS'**
  String get whileYouWait;

  /// No description provided for @tip1.
  ///
  /// In es, this message translates to:
  /// **'En la Parte 2 no describas las fotos: compáralas y responde a la pregunta.'**
  String get tip1;

  /// No description provided for @tip2.
  ///
  /// In es, this message translates to:
  /// **'En la Parte 3 pregunta la opinión del otro: «What do you think?».'**
  String get tip2;

  /// No description provided for @tip3.
  ///
  /// In es, this message translates to:
  /// **'Si no sabes una palabra, explícala con otras. No te quedes callado.'**
  String get tip3;

  /// No description provided for @tip4.
  ///
  /// In es, this message translates to:
  /// **'En la Parte 1 da respuestas cortas pero con un motivo o un ejemplo.'**
  String get tip4;

  /// No description provided for @cancelSearch.
  ///
  /// In es, this message translates to:
  /// **'Cancelar búsqueda'**
  String get cancelSearch;

  /// No description provided for @nobodySearchingTitle.
  ///
  /// In es, this message translates to:
  /// **'Parece que no hay nadie buscando'**
  String get nobodySearchingTitle;

  /// No description provided for @nobodySearchingBody.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres agendar una reunión con alguien? Seguiremos buscando mientras tanto.'**
  String get nobodySearchingBody;

  /// No description provided for @noLabel.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get noLabel;

  /// No description provided for @yesSchedule.
  ///
  /// In es, this message translates to:
  /// **'Sí, agendar'**
  String get yesSchedule;

  /// No description provided for @errorNotEligible.
  ///
  /// In es, this message translates to:
  /// **'Necesitas una suscripción activa para buscar pareja.'**
  String get errorNotEligible;

  /// No description provided for @searchingBanner.
  ///
  /// In es, this message translates to:
  /// **'Buscando compañero · {time}'**
  String searchingBanner(String time);

  /// No description provided for @createMeeting.
  ///
  /// In es, this message translates to:
  /// **'Proponer horario'**
  String get createMeeting;

  /// No description provided for @agendaBoard.
  ///
  /// In es, this message translates to:
  /// **'Buscar horario'**
  String get agendaBoard;

  /// No description provided for @agendaMine.
  ///
  /// In es, this message translates to:
  /// **'Mis exámenes'**
  String get agendaMine;

  /// No description provided for @noOffers.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha propuesto horario con este filtro.'**
  String get noOffers;

  /// No description provided for @myOffersCount.
  ///
  /// In es, this message translates to:
  /// **'MIS PROPUESTAS · {n} DE 2'**
  String myOffersCount(int n);

  /// No description provided for @interestedCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Nadie interesado aún} =1{1 interesado} other{{n} interesados}}'**
  String interestedCount(int n);

  /// No description provided for @todayLabel.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get todayLabel;

  /// No description provided for @tomorrowLabel.
  ///
  /// In es, this message translates to:
  /// **'Mañana'**
  String get tomorrowLabel;

  /// No description provided for @otherDay.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get otherDay;

  /// No description provided for @speaksLangs.
  ///
  /// In es, this message translates to:
  /// **'Habla {langs}'**
  String speaksLangs(String langs);

  /// No description provided for @availableLabel.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get availableLabel;

  /// No description provided for @withdrawOffer.
  ///
  /// In es, this message translates to:
  /// **'Retirar'**
  String get withdrawOffer;

  /// No description provided for @statusConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmada ✓✓'**
  String get statusConfirmed;

  /// No description provided for @statusAwaitingYou.
  ///
  /// In es, this message translates to:
  /// **'Falta tu confirmación'**
  String get statusAwaitingYou;

  /// No description provided for @statusAwaitingPartner.
  ///
  /// In es, this message translates to:
  /// **'Esperando a {name}'**
  String statusAwaitingPartner(String name);

  /// No description provided for @statusClosed.
  ///
  /// In es, this message translates to:
  /// **'Cerrada'**
  String get statusClosed;

  /// No description provided for @statusCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelada'**
  String get statusCancelled;

  /// No description provided for @statusDone.
  ///
  /// In es, this message translates to:
  /// **'Hecha'**
  String get statusDone;

  /// No description provided for @statusNoShow.
  ///
  /// In es, this message translates to:
  /// **'Ausencia'**
  String get statusNoShow;

  /// No description provided for @meetingLength.
  ///
  /// In es, this message translates to:
  /// **'30 min'**
  String get meetingLength;

  /// No description provided for @examWith.
  ///
  /// In es, this message translates to:
  /// **'Examen {level} con {name}'**
  String examWith(String level, String name);

  /// No description provided for @startsInMinutes.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Empieza ya} =1{Empieza en 1 min} other{Empieza en {n} min}}'**
  String startsInMinutes(int n);

  /// No description provided for @startedMinutesAgo.
  ///
  /// In es, this message translates to:
  /// **'Empezó hace {n} min'**
  String startedMinutesAgo(int n);

  /// No description provided for @enterRoom.
  ///
  /// In es, this message translates to:
  /// **'Entrar a la sala'**
  String get enterRoom;

  /// No description provided for @remindBefore.
  ///
  /// In es, this message translates to:
  /// **'Te avisaremos 10 min antes'**
  String get remindBefore;

  /// No description provided for @dayField.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get dayField;

  /// No description provided for @windowField.
  ///
  /// In es, this message translates to:
  /// **'¿Cuándo estás libre?'**
  String get windowField;

  /// No description provided for @fromField.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get fromField;

  /// No description provided for @toField.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get toField;

  /// No description provided for @windowHint.
  ///
  /// In es, this message translates to:
  /// **'Otros estudiantes reservarán un hueco de 30 min dentro de tu franja. Puede salir más de un examen.'**
  String get windowHint;

  /// No description provided for @examLevelField.
  ///
  /// In es, this message translates to:
  /// **'Nivel del examen'**
  String get examLevelField;

  /// No description provided for @offersLeft.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Puedes tener 2 propuestas abiertas · no te quedan} =1{Puedes tener 2 propuestas abiertas · te queda 1} other{Puedes tener 2 propuestas abiertas · te quedan {n}}}'**
  String offersLeft(int n);

  /// No description provided for @publishOffer.
  ///
  /// In es, this message translates to:
  /// **'Publicar propuesta'**
  String get publishOffer;

  /// No description provided for @busyLabel.
  ///
  /// In es, this message translates to:
  /// **'Ocupado'**
  String get busyLabel;

  /// No description provided for @modifyLabel.
  ///
  /// In es, this message translates to:
  /// **'Cambiar hora'**
  String get modifyLabel;

  /// No description provided for @cancelLabel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelLabel;

  /// No description provided for @confirmLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirmLabel;

  /// No description provided for @messageHint.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get messageHint;

  /// No description provided for @sendLabel.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get sendLabel;

  /// No description provided for @sysModified.
  ///
  /// In es, this message translates to:
  /// **'{name} propone cambiar a {when}'**
  String sysModified(String name, String when);

  /// No description provided for @sysConfirmedBy.
  ///
  /// In es, this message translates to:
  /// **'{name} ha confirmado ✓'**
  String sysConfirmedBy(String name);

  /// No description provided for @sysConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Reunión confirmada.'**
  String get sysConfirmed;

  /// No description provided for @sysPartnerOverlap.
  ///
  /// In es, this message translates to:
  /// **'{name} ya tiene otra reunión a esa hora. Proponed otra.'**
  String sysPartnerOverlap(String name);

  /// No description provided for @sysUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta reunión ya no está disponible'**
  String get sysUnavailable;

  /// No description provided for @sysCancelled.
  ///
  /// In es, this message translates to:
  /// **'{name} ha cancelado la reunión'**
  String sysCancelled(String name);

  /// No description provided for @sysExpired.
  ///
  /// In es, this message translates to:
  /// **'La hora pasó sin confirmar el cambio'**
  String get sysExpired;

  /// No description provided for @sysPartnerDeleted.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero ha eliminado su cuenta'**
  String get sysPartnerDeleted;

  /// No description provided for @sysUpdate.
  ///
  /// In es, this message translates to:
  /// **'La reunión ha cambiado'**
  String get sysUpdate;

  /// No description provided for @deletedUser.
  ///
  /// In es, this message translates to:
  /// **'Usuario eliminado'**
  String get deletedUser;

  /// No description provided for @modifyTitle.
  ///
  /// In es, this message translates to:
  /// **'Proponer otra hora'**
  String get modifyTitle;

  /// No description provided for @saveLabel.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get saveLabel;

  /// No description provided for @cancelMeetingTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar la reunión?'**
  String get cancelMeetingTitle;

  /// No description provided for @cancelMeetingBody.
  ///
  /// In es, this message translates to:
  /// **'Se avisará a {name} en el chat.'**
  String cancelMeetingBody(String name);

  /// No description provided for @keepMeeting.
  ///
  /// In es, this message translates to:
  /// **'No, mantener'**
  String get keepMeeting;

  /// No description provided for @roomOpensBefore.
  ///
  /// In es, this message translates to:
  /// **'La sala se abre 5 min antes'**
  String get roomOpensBefore;

  /// No description provided for @meetingWith.
  ///
  /// In es, this message translates to:
  /// **'Reunión con {name} · {level}'**
  String meetingWith(String name, String level);

  /// No description provided for @viewLabel.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get viewLabel;

  /// No description provided for @errorOverlap.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes otra reunión confirmada a esa hora'**
  String get errorOverlap;

  /// No description provided for @errorTooManyOffers.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes 2 ofertas activas'**
  String get errorTooManyOffers;

  /// No description provided for @errorOfferUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta propuesta ya no está disponible'**
  String get errorOfferUnavailable;

  /// No description provided for @errorBadTime.
  ///
  /// In es, this message translates to:
  /// **'Esa hora no es válida'**
  String get errorBadTime;

  /// No description provided for @errorAlreadyAccepted.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un hueco reservado en esta propuesta'**
  String get errorAlreadyAccepted;

  /// No description provided for @errorWindow.
  ///
  /// In es, this message translates to:
  /// **'La franja debe durar al menos 30 min y estar dentro de los próximos 7 días'**
  String get errorWindow;

  /// No description provided for @errorTooEarly.
  ///
  /// In es, this message translates to:
  /// **'La sala se abre 5 min antes'**
  String get errorTooEarly;

  /// No description provided for @errorTooLate.
  ///
  /// In es, this message translates to:
  /// **'Ya pasó el tiempo de cortesía'**
  String get errorTooLate;

  /// No description provided for @errorNotPending.
  ///
  /// In es, this message translates to:
  /// **'La reunión ya no se puede cambiar'**
  String get errorNotPending;

  /// No description provided for @errorPartnerGone.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero ya no está disponible'**
  String get errorPartnerGone;

  /// No description provided for @errorSendFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido enviar el mensaje'**
  String get errorSendFailed;

  /// No description provided for @sysModifiedByMe.
  ///
  /// In es, this message translates to:
  /// **'Propusiste cambiar a {when} · falta que confirme'**
  String sysModifiedByMe(String when);

  /// No description provided for @sysConfirmedByMe.
  ///
  /// In es, this message translates to:
  /// **'Has confirmado ✓'**
  String get sysConfirmedByMe;

  /// No description provided for @sysCancelledByMe.
  ///
  /// In es, this message translates to:
  /// **'Has cancelado la reunión'**
  String get sysCancelledByMe;

  /// No description provided for @editProfile.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get editProfile;

  /// No description provided for @preparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando'**
  String get preparing;

  /// No description provided for @examsDone.
  ///
  /// In es, this message translates to:
  /// **'Exámenes hechos'**
  String get examsDone;

  /// No description provided for @recordingsTitle.
  ///
  /// In es, this message translates to:
  /// **'GRABACIONES'**
  String get recordingsTitle;

  /// No description provided for @recordingWith.
  ///
  /// In es, this message translates to:
  /// **'{level} con {name}'**
  String recordingWith(String level, String name);

  /// No description provided for @recordingMeta.
  ///
  /// In es, this message translates to:
  /// **'{date} · {minutes} min'**
  String recordingMeta(String date, int minutes);

  /// No description provided for @daysLeft.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 día} other{{n} días}}'**
  String daysLeft(int n);

  /// No description provided for @recordingsDeleted.
  ///
  /// In es, this message translates to:
  /// **'Las grabaciones se borran a los 30 días.'**
  String get recordingsDeleted;

  /// No description provided for @noRecordings.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay grabaciones. Se guardan si los dos activáis «Grabar la sesión».'**
  String get noRecordings;

  /// No description provided for @playbackSoon.
  ///
  /// In es, this message translates to:
  /// **'La reproducción llegará en la próxima versión.'**
  String get playbackSoon;

  /// No description provided for @planMonthly.
  ///
  /// In es, this message translates to:
  /// **'Plan mensual'**
  String get planMonthly;

  /// No description provided for @subActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get subActive;

  /// No description provided for @subInactive.
  ///
  /// In es, this message translates to:
  /// **'Sin suscripción'**
  String get subInactive;

  /// No description provided for @trialAvailable.
  ///
  /// In es, this message translates to:
  /// **'Test de prueba disponible'**
  String get trialAvailable;

  /// No description provided for @nextPayment.
  ///
  /// In es, this message translates to:
  /// **'Próximo pago'**
  String get nextPayment;

  /// No description provided for @storeLater.
  ///
  /// In es, this message translates to:
  /// **'La gestión en la tienda llegará con los pagos.'**
  String get storeLater;

  /// No description provided for @deleteAccountBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán tu perfil, tus datos privados y las grabaciones en las que aparece tu voz. Tus mensajes de chat quedarán anónimos. No se puede deshacer.'**
  String get deleteAccountBody;

  /// No description provided for @deletePhrase.
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR'**
  String get deletePhrase;

  /// No description provided for @deletePhraseHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe {phrase} para confirmar'**
  String deletePhraseHint(String phrase);

  /// No description provided for @yourPassword.
  ///
  /// In es, this message translates to:
  /// **'Tu contraseña'**
  String get yourPassword;

  /// No description provided for @deleteForever.
  ///
  /// In es, this message translates to:
  /// **'Eliminar para siempre'**
  String get deleteForever;

  /// No description provided for @errorBadConfirmation.
  ///
  /// In es, this message translates to:
  /// **'La frase no coincide'**
  String get errorBadConfirmation;

  /// No description provided for @profileSaved.
  ///
  /// In es, this message translates to:
  /// **'Perfil guardado'**
  String get profileSaved;

  /// No description provided for @targetLevelField.
  ///
  /// In es, this message translates to:
  /// **'Examen que preparas'**
  String get targetLevelField;

  /// No description provided for @avatarTitle.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil'**
  String get avatarTitle;

  /// No description provided for @avatarFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get avatarFromGallery;

  /// No description provided for @avatarFromCamera.
  ///
  /// In es, this message translates to:
  /// **'Hacer una foto'**
  String get avatarFromCamera;

  /// No description provided for @avatarRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar foto'**
  String get avatarRemove;

  /// No description provided for @avatarUpdated.
  ///
  /// In es, this message translates to:
  /// **'Foto actualizada'**
  String get avatarUpdated;

  /// No description provided for @avatarRemoved.
  ///
  /// In es, this message translates to:
  /// **'Foto eliminada'**
  String get avatarRemoved;

  /// No description provided for @avatarCropTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajusta tu foto'**
  String get avatarCropTitle;

  /// No description provided for @avatarCropHelp.
  ///
  /// In es, this message translates to:
  /// **'Arrastra y pellizca para encuadrarla'**
  String get avatarCropHelp;

  /// No description provided for @avatarCropUse.
  ///
  /// In es, this message translates to:
  /// **'Usar esta foto'**
  String get avatarCropUse;

  /// No description provided for @errorPhotoUpload.
  ///
  /// In es, this message translates to:
  /// **'No se pudo subir la foto. Prueba con otra imagen o inténtalo de nuevo'**
  String get errorPhotoUpload;

  /// No description provided for @practiceVip.
  ///
  /// In es, this message translates to:
  /// **'Practicar con compañero VIP simulado'**
  String get practiceVip;

  /// No description provided for @simulatedVipHint.
  ///
  /// In es, this message translates to:
  /// **'Modo desarrollo: compañero VIP simulado. Tú diriges el examen.'**
  String get simulatedVipHint;

  /// No description provided for @controlPanel.
  ///
  /// In es, this message translates to:
  /// **'Control del examen'**
  String get controlPanel;

  /// No description provided for @controlTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo'**
  String get controlTime;

  /// No description provided for @controlNavigation.
  ///
  /// In es, this message translates to:
  /// **'Navegación'**
  String get controlNavigation;

  /// No description provided for @controlExam.
  ///
  /// In es, this message translates to:
  /// **'Examen'**
  String get controlExam;

  /// No description provided for @controlLeadership.
  ///
  /// In es, this message translates to:
  /// **'Quién dirige'**
  String get controlLeadership;

  /// No description provided for @controlPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get controlPause;

  /// No description provided for @controlResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get controlResume;

  /// No description provided for @controlPauseReader.
  ///
  /// In es, this message translates to:
  /// **'No se puede pausar mientras habla el examinador'**
  String get controlPauseReader;

  /// No description provided for @controlSkipReader.
  ///
  /// In es, this message translates to:
  /// **'Saltar al examinador'**
  String get controlSkipReader;

  /// No description provided for @controlRepeat.
  ///
  /// In es, this message translates to:
  /// **'Repetir pregunta'**
  String get controlRepeat;

  /// No description provided for @controlNextStep.
  ///
  /// In es, this message translates to:
  /// **'Siguiente pregunta'**
  String get controlNextStep;

  /// No description provided for @controlNextPart.
  ///
  /// In es, this message translates to:
  /// **'Siguiente parte'**
  String get controlNextPart;

  /// No description provided for @controlGoToPart.
  ///
  /// In es, this message translates to:
  /// **'Ir a la parte'**
  String get controlGoToPart;

  /// No description provided for @controlEndExam.
  ///
  /// In es, this message translates to:
  /// **'Terminar examen'**
  String get controlEndExam;

  /// No description provided for @controlEndExamConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Terminar el examen y pasar al feedback?'**
  String get controlEndExamConfirm;

  /// No description provided for @controlTurnLength.
  ///
  /// In es, this message translates to:
  /// **'Duración de los turnos de esta parte'**
  String get controlTurnLength;

  /// No description provided for @controlFeedbackTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de feedback'**
  String get controlFeedbackTime;

  /// No description provided for @controlSwitchExam.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de examen'**
  String get controlSwitchExam;

  /// No description provided for @controlSwitchConfirm.
  ///
  /// In es, this message translates to:
  /// **'El examen nuevo empieza desde la Parte 1.'**
  String get controlSwitchConfirm;

  /// No description provided for @controlRandom.
  ///
  /// In es, this message translates to:
  /// **'Aleatorio'**
  String get controlRandom;

  /// No description provided for @controlCurrent.
  ///
  /// In es, this message translates to:
  /// **'Actual'**
  String get controlCurrent;

  /// No description provided for @controlSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar tema'**
  String get controlSearch;

  /// No description provided for @controlTransfer.
  ///
  /// In es, this message translates to:
  /// **'Ceder el control a {name}'**
  String controlTransfer(String name);

  /// No description provided for @controlTransferNoPro.
  ///
  /// In es, this message translates to:
  /// **'{name} no tiene Pro'**
  String controlTransferNoPro(String name);

  /// No description provided for @leaderYou.
  ///
  /// In es, this message translates to:
  /// **'Diriges tú'**
  String get leaderYou;

  /// No description provided for @leaderOther.
  ///
  /// In es, this message translates to:
  /// **'Dirige: {name}'**
  String leaderOther(String name);

  /// No description provided for @pausedTitle.
  ///
  /// In es, this message translates to:
  /// **'Examen en pausa'**
  String get pausedTitle;

  /// No description provided for @pausedBy.
  ///
  /// In es, this message translates to:
  /// **'Lo ha pausado {name} · micros abiertos'**
  String pausedBy(String name);

  /// No description provided for @switchingExam.
  ///
  /// In es, this message translates to:
  /// **'Cambiando de examen… descargando material'**
  String get switchingExam;

  /// No description provided for @noticePause.
  ///
  /// In es, this message translates to:
  /// **'{name} ha pausado el examen'**
  String noticePause(String name);

  /// No description provided for @noticeResume.
  ///
  /// In es, this message translates to:
  /// **'{name} ha reanudado el examen'**
  String noticeResume(String name);

  /// No description provided for @noticeSkipReader.
  ///
  /// In es, this message translates to:
  /// **'{name} ha saltado al examinador'**
  String noticeSkipReader(String name);

  /// No description provided for @noticeNextStep.
  ///
  /// In es, this message translates to:
  /// **'{name} ha pasado a la siguiente pregunta'**
  String noticeNextStep(String name);

  /// No description provided for @noticeNextPart.
  ///
  /// In es, this message translates to:
  /// **'{name} ha pasado a la siguiente parte'**
  String noticeNextPart(String name);

  /// No description provided for @noticeEndExam.
  ///
  /// In es, this message translates to:
  /// **'{name} ha terminado el examen'**
  String noticeEndExam(String name);

  /// No description provided for @noticeRepeat.
  ///
  /// In es, this message translates to:
  /// **'{name} ha repetido la pregunta'**
  String noticeRepeat(String name);

  /// No description provided for @noticeGoToPart.
  ///
  /// In es, this message translates to:
  /// **'{name} ha ido a otra parte'**
  String noticeGoToPart(String name);

  /// No description provided for @noticeTime.
  ///
  /// In es, this message translates to:
  /// **'{name} ha cambiado el tiempo'**
  String noticeTime(String name);

  /// No description provided for @noticeSwitchExam.
  ///
  /// In es, this message translates to:
  /// **'{name} ha cambiado de examen'**
  String noticeSwitchExam(String name);

  /// No description provided for @noticeLeader.
  ///
  /// In es, this message translates to:
  /// **'{name} dirige ahora el examen'**
  String noticeLeader(String name);

  /// No description provided for @noticeLeaderYou.
  ///
  /// In es, this message translates to:
  /// **'Ahora diriges tú el examen'**
  String get noticeLeaderYou;

  /// No description provided for @errorNotLeader.
  ///
  /// In es, this message translates to:
  /// **'Ahora mismo no diriges el examen'**
  String get errorNotLeader;

  /// No description provided for @errorStaleControl.
  ///
  /// In es, this message translates to:
  /// **'El examen acaba de cambiar; inténtalo otra vez'**
  String get errorStaleControl;

  /// No description provided for @errorPartnerNotPro.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero no tiene Pro'**
  String get errorPartnerNotPro;

  /// No description provided for @errorContentMissingPartner.
  ///
  /// In es, this message translates to:
  /// **'Tu compañero no tiene ese examen en su versión de la app'**
  String get errorContentMissingPartner;

  /// No description provided for @errorControlRange.
  ///
  /// In es, this message translates to:
  /// **'Ese cambio se sale de los límites'**
  String get errorControlRange;

  /// No description provided for @planStandard.
  ///
  /// In es, this message translates to:
  /// **'Plan Estándar'**
  String get planStandard;

  /// No description provided for @planPro.
  ///
  /// In es, this message translates to:
  /// **'Plan Pro'**
  String get planPro;

  /// No description provided for @upgradePro.
  ///
  /// In es, this message translates to:
  /// **'Mejorar a Pro'**
  String get upgradePro;

  /// No description provided for @proTitle.
  ///
  /// In es, this message translates to:
  /// **'Pro: tú diriges el examen'**
  String get proTitle;

  /// No description provided for @proPrice.
  ///
  /// In es, this message translates to:
  /// **'10,00 € al mes · incluye todo lo del plan Estándar'**
  String get proPrice;

  /// No description provided for @proFeature1.
  ///
  /// In es, this message translates to:
  /// **'Pausar el examen y añadir o quitar minutos'**
  String get proFeature1;

  /// No description provided for @proFeature2.
  ///
  /// In es, this message translates to:
  /// **'Saltar al examinador y pasar de pregunta o de parte'**
  String get proFeature2;

  /// No description provided for @proFeature3.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de examen cuando quieras, desde el catálogo o al azar'**
  String get proFeature3;

  /// No description provided for @proFeature4.
  ///
  /// In es, this message translates to:
  /// **'Si los dos tenéis Pro, uno dirige y puede cederle el control al otro'**
  String get proFeature4;

  /// No description provided for @proStoreSoon.
  ///
  /// In es, this message translates to:
  /// **'Disponible cuando se active la tienda'**
  String get proStoreSoon;

  /// No description provided for @dockTitle.
  ///
  /// In es, this message translates to:
  /// **'Diriges el examen'**
  String get dockTitle;

  /// No description provided for @dockPrev.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get dockPrev;

  /// No description provided for @dockNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get dockNext;

  /// No description provided for @dockNextPart.
  ///
  /// In es, this message translates to:
  /// **'Sig. parte'**
  String get dockNextPart;

  /// No description provided for @dockMore.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get dockMore;

  /// No description provided for @dockLess.
  ///
  /// In es, this message translates to:
  /// **'Menos'**
  String get dockLess;

  /// No description provided for @dockSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get dockSkip;

  /// No description provided for @dockPaused.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get dockPaused;

  /// No description provided for @controlPrevStep.
  ///
  /// In es, this message translates to:
  /// **'Pregunta anterior'**
  String get controlPrevStep;

  /// No description provided for @controlTurnTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo de este turno'**
  String get controlTurnTime;

  /// No description provided for @controlBackToExam.
  ///
  /// In es, this message translates to:
  /// **'Volver a la última pregunta'**
  String get controlBackToExam;

  /// No description provided for @noticePrevStep.
  ///
  /// In es, this message translates to:
  /// **'{name} ha vuelto a la pregunta anterior'**
  String noticePrevStep(String name);

  /// No description provided for @tabPractice.
  ///
  /// In es, this message translates to:
  /// **'Practicar'**
  String get tabPractice;

  /// No description provided for @providerSoon.
  ///
  /// In es, this message translates to:
  /// **'Entrar con {provider} llegará pronto. De momento, usa tu email.'**
  String providerSoon(String provider);

  /// No description provided for @continueWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @signUpWithEmail.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta con email'**
  String get signUpWithEmail;

  /// No description provided for @haveAccountQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta?'**
  String get haveAccountQuestion;

  /// No description provided for @notAffiliated.
  ///
  /// In es, this message translates to:
  /// **'App independiente, sin afiliación con Cambridge University Press & Assessment.'**
  String get notAffiliated;

  /// No description provided for @createAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta'**
  String get createAccountTitle;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Con tu email y una contraseña. Después elegirás tu nombre y tu nivel.'**
  String get createAccountSubtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In es, this message translates to:
  /// **'Hola de nuevo'**
  String get welcomeBack;

  /// No description provided for @welcomeBackSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Entra con tu email para seguir practicando.'**
  String get welcomeBackSubtitle;

  /// No description provided for @showPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get hidePassword;

  /// No description provided for @orContinueWith.
  ///
  /// In es, this message translates to:
  /// **'o continúa con'**
  String get orContinueWith;

  /// No description provided for @practiceSoloTitle.
  ///
  /// In es, this message translates to:
  /// **'Practicar solo'**
  String get practiceSoloTitle;

  /// No description provided for @practiceSoloBody.
  ///
  /// In es, this message translates to:
  /// **'Con un compañero simulado, para cuando no hay nadie.'**
  String get practiceSoloBody;

  /// No description provided for @practiceVipBody.
  ///
  /// In es, this message translates to:
  /// **'Solo en desarrollo: diriges el examen con los controles Pro.'**
  String get practiceVipBody;

  /// No description provided for @meetingWithName.
  ///
  /// In es, this message translates to:
  /// **'Reunión con {name}'**
  String meetingWithName(String name);

  /// No description provided for @aPartner.
  ///
  /// In es, this message translates to:
  /// **'un compañero'**
  String get aPartner;

  /// No description provided for @fullExamOf.
  ///
  /// In es, this message translates to:
  /// **'{level} · examen completo'**
  String fullExamOf(String level);

  /// No description provided for @searchKeepsGoing.
  ///
  /// In es, this message translates to:
  /// **'Seguimos buscando aunque cambies de pestaña.'**
  String get searchKeepsGoing;

  /// No description provided for @tipLabel.
  ///
  /// In es, this message translates to:
  /// **'Consejo'**
  String get tipLabel;

  /// No description provided for @tipForPart.
  ///
  /// In es, this message translates to:
  /// **'Consejo · Parte {n}'**
  String tipForPart(int n);

  /// No description provided for @timeUp.
  ///
  /// In es, this message translates to:
  /// **'Tiempo'**
  String get timeUp;

  /// No description provided for @statusListening.
  ///
  /// In es, this message translates to:
  /// **'Escucha'**
  String get statusListening;

  /// No description provided for @micListening.
  ///
  /// In es, this message translates to:
  /// **'Escuchando'**
  String get micListening;

  /// No description provided for @yourTurnNow.
  ///
  /// In es, this message translates to:
  /// **'Te toca a ti'**
  String get yourTurnNow;

  /// No description provided for @listeningTo.
  ///
  /// In es, this message translates to:
  /// **'Escuchando a {name}'**
  String listeningTo(String name);

  /// No description provided for @textHidden.
  ///
  /// In es, this message translates to:
  /// **'Texto oculto'**
  String get textHidden;

  /// No description provided for @questionsLeft.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Última pregunta} =1{Queda 1 pregunta} other{Quedan {n} preguntas}}'**
  String questionsLeft(int n);

  /// No description provided for @examSummaryLine.
  ///
  /// In es, this message translates to:
  /// **'{level} · {topic} · {minutes} min'**
  String examSummaryLine(String level, String topic, int minutes);

  /// No description provided for @feedbackIdeasTitle.
  ///
  /// In es, this message translates to:
  /// **'Ideas para empezar'**
  String get feedbackIdeasTitle;

  /// No description provided for @criterionGrammar.
  ///
  /// In es, this message translates to:
  /// **'Gramática y vocabulario'**
  String get criterionGrammar;

  /// No description provided for @criterionDiscourse.
  ///
  /// In es, this message translates to:
  /// **'Gestión del discurso'**
  String get criterionDiscourse;

  /// No description provided for @criterionPronunciation.
  ///
  /// In es, this message translates to:
  /// **'Pronunciación'**
  String get criterionPronunciation;

  /// No description provided for @criterionInteraction.
  ///
  /// In es, this message translates to:
  /// **'Comunicación interactiva'**
  String get criterionInteraction;

  /// No description provided for @ratePartner.
  ///
  /// In es, this message translates to:
  /// **'Valora a {name}'**
  String ratePartner(String name);

  /// No description provided for @onlyTheySee.
  ///
  /// In es, this message translates to:
  /// **'Solo lo verá {name}'**
  String onlyTheySee(String name);

  /// No description provided for @endFeedback.
  ///
  /// In es, this message translates to:
  /// **'Terminar'**
  String get endFeedback;

  /// No description provided for @partN.
  ///
  /// In es, this message translates to:
  /// **'Parte {n}'**
  String partN(int n);

  /// No description provided for @leaderYouLong.
  ///
  /// In es, this message translates to:
  /// **'Diriges tú el examen'**
  String get leaderYouLong;

  /// No description provided for @changeLabel.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get changeLabel;

  /// No description provided for @candidateRole.
  ///
  /// In es, this message translates to:
  /// **'Candidato {role}'**
  String candidateRole(String role);

  /// No description provided for @readyLabel.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get readyLabel;

  /// No description provided for @offerSlot.
  ///
  /// In es, this message translates to:
  /// **'Proponer'**
  String get offerSlot;

  /// No description provided for @deletesIn.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{Se borra en 1 día} other{Se borra en {n} días}}'**
  String deletesIn(int n);

  /// No description provided for @feedbackReceived.
  ///
  /// In es, this message translates to:
  /// **'Lo que dicen de ti'**
  String get feedbackReceived;

  /// No description provided for @feedbackReceivedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Cuando tus compañeros te valoren al final de un examen, lo verás aquí. Solo lo ves tú.'**
  String get feedbackReceivedEmpty;

  /// No description provided for @ratingsCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 valoración} other{{n} valoraciones}}'**
  String ratingsCount(int n);

  /// No description provided for @perMonth.
  ///
  /// In es, this message translates to:
  /// **'{price} al mes'**
  String perMonth(String price);

  /// No description provided for @planStandardShort.
  ///
  /// In es, this message translates to:
  /// **'Estándar'**
  String get planStandardShort;

  /// No description provided for @planProShort.
  ///
  /// In es, this message translates to:
  /// **'Pro'**
  String get planProShort;

  /// No description provided for @planStdFeature1.
  ///
  /// In es, this message translates to:
  /// **'Exámenes sin límite'**
  String get planStdFeature1;

  /// No description provided for @planStdFeature2.
  ///
  /// In es, this message translates to:
  /// **'Matchmaking y agenda'**
  String get planStdFeature2;

  /// No description provided for @planProFeature1.
  ///
  /// In es, this message translates to:
  /// **'Todo lo de Estándar'**
  String get planProFeature1;

  /// No description provided for @planProFeature2.
  ///
  /// In es, this message translates to:
  /// **'Diriges el examen: pausa, tiempo y partes'**
  String get planProFeature2;

  /// No description provided for @readTerms.
  ///
  /// In es, this message translates to:
  /// **'Leer los Términos'**
  String get readTerms;

  /// No description provided for @readPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Leer la Política de privacidad'**
  String get readPrivacy;

  /// No description provided for @signUpLegalNote.
  ///
  /// In es, this message translates to:
  /// **'Antes de empezar a usar la app te pediremos que aceptes los Términos de uso y la Política de privacidad.'**
  String get signUpLegalNote;

  /// No description provided for @legalSection.
  ///
  /// In es, this message translates to:
  /// **'LEGAL'**
  String get legalSection;

  /// No description provided for @legalSpanishOnly.
  ///
  /// In es, this message translates to:
  /// **''**
  String get legalSpanishOnly;

  /// No description provided for @blockedUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios bloqueados'**
  String get blockedUsers;

  /// No description provided for @noBlockedUsers.
  ///
  /// In es, this message translates to:
  /// **'No has bloqueado a nadie.'**
  String get noBlockedUsers;

  /// No description provided for @unblockAction.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get unblockAction;

  /// No description provided for @reportOrBlock.
  ///
  /// In es, this message translates to:
  /// **'Reportar o bloquear'**
  String get reportOrBlock;

  /// No description provided for @reportPartner.
  ///
  /// In es, this message translates to:
  /// **'Reportar a {name}'**
  String reportPartner(String name);

  /// No description provided for @reportTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportar a {name}'**
  String reportTitle(String name);

  /// No description provided for @reportIntro.
  ///
  /// In es, this message translates to:
  /// **'Lo revisaremos lo antes posible. {name} no sabrá quién le ha reportado.'**
  String reportIntro(String name);

  /// No description provided for @reportDetailsHint.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos qué ha pasado (opcional)'**
  String get reportDetailsHint;

  /// No description provided for @alsoBlock.
  ///
  /// In es, this message translates to:
  /// **'Bloquear también a {name}'**
  String alsoBlock(String name);

  /// No description provided for @reportSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar reporte'**
  String get reportSend;

  /// No description provided for @reportSent.
  ///
  /// In es, this message translates to:
  /// **'Reporte enviado. Gracias por avisarnos.'**
  String get reportSent;

  /// No description provided for @blockOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo bloquear a {name}'**
  String blockOnly(String name);

  /// No description provided for @blockTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Bloquear a {name}?'**
  String blockTitle(String name);

  /// No description provided for @blockBody.
  ///
  /// In es, this message translates to:
  /// **'No volveréis a coincidir en el emparejamiento, no veréis vuestras ofertas, no podréis escribiros y se cancelarán vuestras reuniones pendientes. Puedes desbloquear en Ajustes.'**
  String get blockBody;

  /// No description provided for @blockAction.
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get blockAction;

  /// No description provided for @blockedDone.
  ///
  /// In es, this message translates to:
  /// **'Has bloqueado a {name}.'**
  String blockedDone(String name);

  /// No description provided for @reasonHarassment.
  ///
  /// In es, this message translates to:
  /// **'Acoso o insultos'**
  String get reasonHarassment;

  /// No description provided for @reasonSexual.
  ///
  /// In es, this message translates to:
  /// **'Contenido sexual'**
  String get reasonSexual;

  /// No description provided for @reasonHate.
  ///
  /// In es, this message translates to:
  /// **'Odio o discriminación'**
  String get reasonHate;

  /// No description provided for @reasonMinor.
  ///
  /// In es, this message translates to:
  /// **'Riesgo para un menor'**
  String get reasonMinor;

  /// No description provided for @reasonSpam.
  ///
  /// In es, this message translates to:
  /// **'Spam o publicidad'**
  String get reasonSpam;

  /// No description provided for @reasonNoShow.
  ///
  /// In es, this message translates to:
  /// **'No se presentó'**
  String get reasonNoShow;

  /// No description provided for @reasonOther.
  ///
  /// In es, this message translates to:
  /// **'Otro motivo'**
  String get reasonOther;

  /// No description provided for @countdownLabel.
  ///
  /// In es, this message translates to:
  /// **'El examen empieza en'**
  String get countdownLabel;

  /// No description provided for @buildLine.
  ///
  /// In es, this message translates to:
  /// **'Compilación {label}'**
  String buildLine(String label);

  /// No description provided for @reasonSilent.
  ///
  /// In es, this message translates to:
  /// **'No habla en sus turnos'**
  String get reasonSilent;

  /// No description provided for @reasonMocking.
  ///
  /// In es, this message translates to:
  /// **'Se burla o lo ridiculiza'**
  String get reasonMocking;

  /// No description provided for @reasonNoise.
  ///
  /// In es, this message translates to:
  /// **'Ruido, música o habla encima'**
  String get reasonNoise;

  /// No description provided for @reasonQuit.
  ///
  /// In es, this message translates to:
  /// **'Abandona a propósito'**
  String get reasonQuit;

  /// No description provided for @reasonControlAbuse.
  ///
  /// In es, this message translates to:
  /// **'Abusa de los controles del examen'**
  String get reasonControlAbuse;

  /// No description provided for @errorNotInSession.
  ///
  /// In es, this message translates to:
  /// **'Solo puedes reportar a tu compañero de esta sesión'**
  String get errorNotInSession;

  /// No description provided for @agendaMineCount.
  ///
  /// In es, this message translates to:
  /// **'Mis exámenes · {n}'**
  String agendaMineCount(int n);

  /// No description provided for @sectionNeedsYou.
  ///
  /// In es, this message translates to:
  /// **'TE TOCA'**
  String get sectionNeedsYou;

  /// No description provided for @sectionUpcoming.
  ///
  /// In es, this message translates to:
  /// **'PRÓXIMOS'**
  String get sectionUpcoming;

  /// No description provided for @pastCount.
  ///
  /// In es, this message translates to:
  /// **'Anteriores ({n})'**
  String pastCount(int n);

  /// No description provided for @statusGone.
  ///
  /// In es, this message translates to:
  /// **'Ya no va'**
  String get statusGone;

  /// No description provided for @noBookingsYet.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha reservado todavía'**
  String get noBookingsYet;

  /// No description provided for @emptyMine.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes exámenes agendados.'**
  String get emptyMine;

  /// No description provided for @proposeMine.
  ///
  /// In es, this message translates to:
  /// **'Proponer el mío'**
  String get proposeMine;

  /// No description provided for @companionsTitle.
  ///
  /// In es, this message translates to:
  /// **'COMPAÑEROS'**
  String get companionsTitle;

  /// No description provided for @companionsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Al terminar un examen podéis añadiros como compañeros y repetir con una invitación.'**
  String get companionsEmpty;

  /// No description provided for @inviteLabel.
  ///
  /// In es, this message translates to:
  /// **'Invitar'**
  String get inviteLabel;

  /// No description provided for @companionAddedYou.
  ///
  /// In es, this message translates to:
  /// **'Te ha añadido'**
  String get companionAddedYou;

  /// No description provided for @addBack.
  ///
  /// In es, this message translates to:
  /// **'Añadir también'**
  String get addBack;

  /// No description provided for @companionPendingShort.
  ///
  /// In es, this message translates to:
  /// **'Falta que te añada'**
  String get companionPendingShort;

  /// No description provided for @examsTogether.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Sin exámenes juntos} =1{1 examen juntos} other{{n} exámenes juntos}}'**
  String examsTogether(int n);

  /// No description provided for @removeCompanion.
  ///
  /// In es, this message translates to:
  /// **'Quitar de compañeros'**
  String get removeCompanion;

  /// No description provided for @allDays.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get allDays;

  /// No description provided for @seeAlsoLevel.
  ///
  /// In es, this message translates to:
  /// **'Ver también {level}'**
  String seeAlsoLevel(String level);

  /// No description provided for @freeFromTo.
  ///
  /// In es, this message translates to:
  /// **'Libre de {from} a {to}'**
  String freeFromTo(String from, String to);

  /// No description provided for @bookTitle.
  ///
  /// In es, this message translates to:
  /// **'Examen {level} con {name}'**
  String bookTitle(String level, String name);

  /// No description provided for @bookThisSlot.
  ///
  /// In es, this message translates to:
  /// **'Reservar este hueco'**
  String get bookThisSlot;

  /// No description provided for @bookHint.
  ///
  /// In es, this message translates to:
  /// **'Quedará confirmado para los dos. Tendréis un chat para organizaros.'**
  String get bookHint;

  /// No description provided for @stepProposed.
  ///
  /// In es, this message translates to:
  /// **'Propuesta'**
  String get stepProposed;

  /// No description provided for @chatClosed.
  ///
  /// In es, this message translates to:
  /// **'Este chat ya se cerró: solo sirve para organizar su reunión.'**
  String get chatClosed;

  /// No description provided for @qrLate.
  ///
  /// In es, this message translates to:
  /// **'Llego 5 min tarde'**
  String get qrLate;

  /// No description provided for @qrOtherTime.
  ///
  /// In es, this message translates to:
  /// **'¿Cambiamos la hora?'**
  String get qrOtherTime;

  /// No description provided for @qrSeeYou.
  ///
  /// In es, this message translates to:
  /// **'¡Nos vemos!'**
  String get qrSeeYou;

  /// No description provided for @sysBookedByMe.
  ///
  /// In es, this message translates to:
  /// **'Reservaste {when}'**
  String sysBookedByMe(String when);

  /// No description provided for @sysBooked.
  ///
  /// In es, this message translates to:
  /// **'{name} reservó {when}'**
  String sysBooked(String name, String when);

  /// No description provided for @sysInvitedByMe.
  ///
  /// In es, this message translates to:
  /// **'Invitaste para {when}'**
  String sysInvitedByMe(String when);

  /// No description provided for @sysInvited.
  ///
  /// In es, this message translates to:
  /// **'{name} te invita: {when}'**
  String sysInvited(String name, String when);

  /// No description provided for @inviteTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitar a {name}'**
  String inviteTitle(String name);

  /// No description provided for @timeField.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get timeField;

  /// No description provided for @sendInvite.
  ///
  /// In es, this message translates to:
  /// **'Enviar invitación'**
  String get sendInvite;

  /// No description provided for @inviteHint.
  ///
  /// In es, this message translates to:
  /// **'{name} lo confirmará con un toque.'**
  String inviteHint(String name);

  /// No description provided for @noTimesLeft.
  ///
  /// In es, this message translates to:
  /// **'No quedan horas libres este día.'**
  String get noTimesLeft;

  /// No description provided for @companionPrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Repetiríais? Añade a {name} a tus compañeros para invitaros directamente.'**
  String companionPrompt(String name);

  /// No description provided for @addCompanion.
  ///
  /// In es, this message translates to:
  /// **'Añadir a compañeros'**
  String get addCompanion;

  /// No description provided for @companionAdded.
  ///
  /// In es, this message translates to:
  /// **'Añadido. Cuando {name} también te añada, podréis invitaros.'**
  String companionAdded(String name);

  /// No description provided for @companionMutual.
  ///
  /// In es, this message translates to:
  /// **'{name} y tú ya sois compañeros.'**
  String companionMutual(String name);

  /// No description provided for @repeatWith.
  ///
  /// In es, this message translates to:
  /// **'Repetir con {name}'**
  String repeatWith(String name);

  /// No description provided for @errorSlotTaken.
  ///
  /// In es, this message translates to:
  /// **'Ese hueco ya está reservado'**
  String get errorSlotTaken;

  /// No description provided for @errorNotCompanion.
  ///
  /// In es, this message translates to:
  /// **'Solo puedes invitar a tus compañeros'**
  String get errorNotCompanion;

  /// No description provided for @errorTooManyInvites.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes 3 invitaciones sin confirmar'**
  String get errorTooManyInvites;

  /// No description provided for @errorTooManyCompanions.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes 20 compañeros'**
  String get errorTooManyCompanions;

  /// No description provided for @errorSessionNotEnded.
  ///
  /// In es, this message translates to:
  /// **'Podrás añadirle al terminar el examen'**
  String get errorSessionNotEnded;
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
