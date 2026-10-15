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

  /// No description provided for @loginHeadline.
  ///
  /// In es, this message translates to:
  /// **'Practica el Speaking de Cambridge con otro estudiante.'**
  String get loginHeadline;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Un examinador virtual marca los turnos y el tiempo. Tú solo hablas.'**
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
  /// **'SALA · {level}'**
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
  /// **'Crear reunión'**
  String get createMeeting;

  /// No description provided for @agendaChats.
  ///
  /// In es, this message translates to:
  /// **'Chats'**
  String get agendaChats;

  /// No description provided for @agendaBoard.
  ///
  /// In es, this message translates to:
  /// **'Reuniones'**
  String get agendaBoard;

  /// No description provided for @agendaMine.
  ///
  /// In es, this message translates to:
  /// **'Mi agenda'**
  String get agendaMine;

  /// No description provided for @noChats.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes chats. Elige una oferta en Reuniones o crea la tuya.'**
  String get noChats;

  /// No description provided for @noOffers.
  ///
  /// In es, this message translates to:
  /// **'No hay ofertas con este filtro.'**
  String get noOffers;

  /// No description provided for @noMeetings.
  ///
  /// In es, this message translates to:
  /// **'No tienes reuniones confirmadas.'**
  String get noMeetings;

  /// No description provided for @myOffersCount.
  ///
  /// In es, this message translates to:
  /// **'MIS OFERTAS · {n} DE 2'**
  String myOffersCount(int n);

  /// No description provided for @interestedCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Nadie interesado aún} =1{1 interesado} other{{n} interesados}}'**
  String interestedCount(int n);

  /// No description provided for @includeLevel.
  ///
  /// In es, this message translates to:
  /// **'+ Incluir {level}'**
  String includeLevel(String level);

  /// No description provided for @anyDay.
  ///
  /// In es, this message translates to:
  /// **'Cualquier día'**
  String get anyDay;

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

  /// No description provided for @chooseTime.
  ///
  /// In es, this message translates to:
  /// **'Elegir hora'**
  String get chooseTime;

  /// No description provided for @withdrawOffer.
  ///
  /// In es, this message translates to:
  /// **'Retirar oferta'**
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
  /// **'Franja en la que puedes'**
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
  /// **'Quien acepte elegirá una hora exacta dentro de esta franja.'**
  String get windowHint;

  /// No description provided for @examLevelField.
  ///
  /// In es, this message translates to:
  /// **'Nivel del examen'**
  String get examLevelField;

  /// No description provided for @offersLeft.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =0{Puedes tener 2 ofertas activas · no te quedan} =1{Puedes tener 2 ofertas activas · te queda 1} other{Puedes tener 2 ofertas activas · te quedan {n}}}'**
  String offersLeft(int n);

  /// No description provided for @publishOffer.
  ///
  /// In es, this message translates to:
  /// **'Publicar oferta'**
  String get publishOffer;

  /// No description provided for @examWithTitle.
  ///
  /// In es, this message translates to:
  /// **'Examen con {name}'**
  String examWithTitle(String name);

  /// No description provided for @chooseStart.
  ///
  /// In es, this message translates to:
  /// **'Elige a qué hora empezáis'**
  String get chooseStart;

  /// No description provided for @busyLabel.
  ///
  /// In es, this message translates to:
  /// **'Ocupado'**
  String get busyLabel;

  /// No description provided for @busyHint.
  ///
  /// In es, this message translates to:
  /// **'Las horas que chocan con tus reuniones confirmadas aparecen bloqueadas.'**
  String get busyHint;

  /// No description provided for @proposeAndChat.
  ///
  /// In es, this message translates to:
  /// **'Proponer {time} y abrir chat'**
  String proposeAndChat(String time);

  /// No description provided for @pickATime.
  ///
  /// In es, this message translates to:
  /// **'Elige una hora'**
  String get pickATime;

  /// No description provided for @noSlots.
  ///
  /// In es, this message translates to:
  /// **'No quedan horas libres en esta franja.'**
  String get noSlots;

  /// No description provided for @modifyLabel.
  ///
  /// In es, this message translates to:
  /// **'Modificar'**
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

  /// No description provided for @sysProposed.
  ///
  /// In es, this message translates to:
  /// **'{name} propuso {when}'**
  String sysProposed(String name, String when);

  /// No description provided for @sysModified.
  ///
  /// In es, this message translates to:
  /// **'{name} cambió la hora a {when} · confirmaciones reiniciadas'**
  String sysModified(String name, String when);

  /// No description provided for @sysConfirmedBy.
  ///
  /// In es, this message translates to:
  /// **'{name} ha confirmado ✓'**
  String sysConfirmedBy(String name);

  /// No description provided for @sysConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Reunión confirmada. Ya está en Mi agenda.'**
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
  /// **'La hora pasó sin que los dos confirmarais'**
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
  /// **'Cambiar hora o nivel'**
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
  /// **'Esta oferta ya no está disponible'**
  String get errorOfferUnavailable;

  /// No description provided for @errorBadTime.
  ///
  /// In es, this message translates to:
  /// **'Esa hora no es válida'**
  String get errorBadTime;

  /// No description provided for @errorAlreadyAccepted.
  ///
  /// In es, this message translates to:
  /// **'Ya elegiste esta oferta: búscala en Chats'**
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

  /// No description provided for @sysProposedByMe.
  ///
  /// In es, this message translates to:
  /// **'Propusiste {when}'**
  String sysProposedByMe(String when);

  /// No description provided for @sysModifiedByMe.
  ///
  /// In es, this message translates to:
  /// **'Cambiaste la hora a {when} · confirmaciones reiniciadas'**
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
