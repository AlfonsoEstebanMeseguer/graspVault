// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Speaking P2P';

  @override
  String get tabExam => 'Examen';

  @override
  String get tabAgenda => 'Agenda';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get homeHello => 'Hola,';

  @override
  String get searchPartner => 'Buscar pareja';

  @override
  String examOfLevel(String level) {
    return 'Examen de Speaking $level';
  }

  @override
  String examSummary(int minutes) {
    return '4 partes · ~$minutes min + 5 min de feedback';
  }

  @override
  String get offlineBanner =>
      'Modo sin conexión: practica con un compañero simulado.';

  @override
  String get practiceSimulated => 'Practicar con compañero simulado';

  @override
  String get levelB1 => 'B1 Preliminary';

  @override
  String get levelB2 => 'B2 First';

  @override
  String get levelC1 => 'C1 Advanced';

  @override
  String partOf(int n) {
    return 'PARTE $n DE 4';
  }

  @override
  String get examiner => 'Examinador';

  @override
  String get examinerQuestion => 'Pregunta del examinador';

  @override
  String get hideText => 'Ocultar texto';

  @override
  String get showText => 'Ver texto';

  @override
  String get hideTimer => 'Ocultar cronómetro';

  @override
  String get showTimer => 'Mostrar cronómetro';

  @override
  String get yourTurn => 'Te toca responder a ti';

  @override
  String partnerTurn(String name) {
    return 'Le toca a $name';
  }

  @override
  String get micOpen => 'Tu micro está abierto';

  @override
  String get micMuted => 'Tu micro está silenciado';

  @override
  String get examinerSpeaking => 'El examinador está hablando';

  @override
  String get bothMuted => 'Micros de los dos silenciados';

  @override
  String get addressedToBoth => 'Para: los dos';

  @override
  String get addressedToYou => 'Para: ti';

  @override
  String addressedTo(String name) {
    return 'Para: $name';
  }

  @override
  String get you => 'Tú';

  @override
  String roleLabel(String name, String role) {
    return '$name · $role';
  }

  @override
  String get statusMuted => 'Silenciado';

  @override
  String get statusSpeaking => 'Hablando';

  @override
  String get statusMicOpen => 'Micro abierto';

  @override
  String choosesTwoPhotos(String name) {
    return '$name elige dos de estas fotos';
  }

  @override
  String describesPhoto(String name) {
    return '$name describe esta foto';
  }

  @override
  String comparesPhotos(String name) {
    return '$name compara estas fotos';
  }

  @override
  String photoPlaceholder(String id) {
    return 'Foto · $id';
  }

  @override
  String discussionPhase(int minutes) {
    return 'Discusión · $minutes min';
  }

  @override
  String decisionPhase(int minutes) {
    return 'Decisión · $minutes min';
  }

  @override
  String startingIn(int seconds) {
    return 'El examen empieza en $seconds';
  }

  @override
  String get abandon => 'Abandonar';

  @override
  String get abandonTitle => '¿Seguro que quieres salir?';

  @override
  String abandonBody(String name) {
    return 'El examen terminará para los dos y $name volverá al inicio. Si estás usando tu test de prueba, se dará por consumido.';
  }

  @override
  String get keepGoing => 'Seguir en el examen';

  @override
  String get leaveExam => 'Salir del examen';

  @override
  String leaveExamIn(int seconds) {
    return 'Salir del examen ($seconds)';
  }

  @override
  String get partnerLeft => 'Tu compañero ha salido';

  @override
  String get backHome => 'Volver al inicio';

  @override
  String get examFinished => 'Examen terminado';

  @override
  String get feedbackSubtitle => 'Ahora tenéis tiempo para daros feedback.';

  @override
  String get feedbackTime => 'TIEMPO DE FEEDBACK';

  @override
  String get micsOpenBoth => 'Micros abiertos para los dos';

  @override
  String get feedbackIdeas => 'IDEAS PARA EMPEZAR';

  @override
  String get feedbackIdea1 =>
      '¿Qué expresión o palabra del otro te ha gustado?';

  @override
  String get feedbackIdea2 => '¿Hay algún error que se haya repetido?';

  @override
  String get feedbackIdea3 =>
      'En la Parte 3, ¿habéis dejado hablar al otro y llegado a una decisión?';

  @override
  String get endCall => 'Terminar llamada';

  @override
  String get simulatedPartner => 'compañero_sim';

  @override
  String get simulatedPartnerHint =>
      'Modo desarrollo: el compañero es simulado y no habla.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get appearance => 'APARIENCIA';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get appLanguage => 'IDIOMA DE LA APP';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get subscription => 'SUSCRIPCIÓN';

  @override
  String get account => 'CUENTA';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get needsBackend =>
      'Disponible cuando la app esté conectada al servidor.';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get loginHeadline =>
      'Practica el Speaking de Cambridge con otro estudiante.';

  @override
  String get loginSubtitle =>
      'Un examinador virtual marca los turnos y el tiempo. Tú solo hablas.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get signIn => 'Entrar';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get noAccountYet => '¿No tienes cuenta? Crear una';

  @override
  String get haveAccount => 'Ya tengo cuenta';

  @override
  String get checkYourEmail =>
      'Te hemos enviado un correo para confirmar la cuenta. Ábrelo y vuelve a entrar.';

  @override
  String get invalidEmail => 'Escribe un email válido';

  @override
  String get passwordTooShort => 'Mínimo 8 caracteres';

  @override
  String get errorInvalidCredentials => 'Email o contraseña incorrectos';

  @override
  String get errorEmailNotConfirmed => 'Confirma tu email antes de entrar';

  @override
  String get errorEmailExists => 'Ya existe una cuenta con ese email';

  @override
  String get errorWeakPassword => 'La contraseña es demasiado débil';

  @override
  String get errorRateLimited => 'Demasiados intentos. Espera un poco';

  @override
  String get errorUsernameTaken => 'Ese nombre de usuario ya está cogido';

  @override
  String get errorUnderage => 'Debes tener al menos 14 años';

  @override
  String get errorGeneric => 'Algo ha fallado. Inténtalo de nuevo';

  @override
  String stepOf(int n) {
    return 'Paso $n de 3';
  }

  @override
  String get visibleToOthers => 'Visible para otros usuarios';

  @override
  String get privateOnlyYou => 'Privado, solo lo ves tú';

  @override
  String get canChangeLater => 'Podrás cambiarlo cuando quieras';

  @override
  String get publicProfileTitle => 'Tu perfil público';

  @override
  String get usernameLabel => 'Nombre de usuario';

  @override
  String get usernameAvailable => 'Disponible';

  @override
  String get usernameRules => '3–20 caracteres: minúsculas, números, _ y .';

  @override
  String get languagesYouSpeak => 'Idiomas que hablas';

  @override
  String get otherLanguage => '+ Otro';

  @override
  String get accountDataTitle => 'Datos de tu cuenta';

  @override
  String get birthDate => 'Fecha de nacimiento';

  @override
  String get dayLabel => 'Día';

  @override
  String get monthLabel => 'Mes';

  @override
  String get yearLabel => 'Año';

  @override
  String get minAgeHint => 'Debes tener al menos 14 años.';

  @override
  String get invalidDate => 'Fecha no válida';

  @override
  String get phoneOptional => 'Teléfono (opcional)';

  @override
  String get invalidPhone => 'Número no válido';

  @override
  String get linkedToAccount => 'Vinculado a tu cuenta';

  @override
  String get whichExamTitle => '¿Qué examen preparas?';

  @override
  String speakingMinutes(String minutes) {
    return 'Speaking de $minutes min';
  }

  @override
  String get acceptTerms =>
      'He leído y acepto los Términos de uso y la Política de privacidad.';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get backLabel => 'Atrás';

  @override
  String get startLabel => 'Empezar';

  @override
  String get langEs => 'Español';

  @override
  String get langEn => 'Inglés';

  @override
  String get langCa => 'Catalán';

  @override
  String get langFr => 'Francés';

  @override
  String get langIt => 'Italiano';

  @override
  String get langDe => 'Alemán';

  @override
  String get langPt => 'Portugués';

  @override
  String get langEu => 'Euskera';

  @override
  String get langGl => 'Gallego';

  @override
  String get langZh => 'Chino';

  @override
  String get langAr => 'Árabe';

  @override
  String get langRu => 'Ruso';

  @override
  String get langUk => 'Ucraniano';

  @override
  String get langRo => 'Rumano';

  @override
  String roomTitle(String level) {
    return 'SALA · $level';
  }

  @override
  String get meetBeforeStart => 'Conoceos antes de empezar';

  @override
  String get examStartsIn => 'El examen empieza solo en';

  @override
  String get waitingPartner => 'Esperando a tu compañero…';

  @override
  String candidateLine(String role, String langs) {
    return 'Candidato $role · $langs';
  }

  @override
  String get notConfirmed => 'Sin confirmar';

  @override
  String get readyBadge => '✓ Listo';

  @override
  String get recordSession => 'Grabar la sesión';

  @override
  String recordOnlyIfBoth(String name, String state) {
    return 'Solo si los dos lo activáis · $name: $state';
  }

  @override
  String get switchedOn => 'activado';

  @override
  String get switchedOff => 'desactivado';

  @override
  String get materialDownloaded => 'Material del examen descargado';

  @override
  String get materialDownloading => 'Descargando el material del examen…';

  @override
  String get imReady => 'Estoy listo';

  @override
  String get notReadyYet => 'Aún no estoy listo';

  @override
  String get leaveRoom => 'Salir de la sala';

  @override
  String get connecting => 'Conectando…';

  @override
  String get sessionError => 'No se ha podido entrar en la sala.';

  @override
  String get contentMissing =>
      'Actualiza la app: este examen no está en tu versión.';

  @override
  String get sessionClosed => 'La sesión ha terminado.';

  @override
  String get partnerNoShow => 'Tu compañero no se ha conectado.';

  @override
  String get micOnShort => 'Micro abierto';

  @override
  String get micOffShort => 'Micro cerrado';

  @override
  String get searchingPartner => 'Buscando compañero…';

  @override
  String get whileYouWait => 'MIENTRAS ESPERAS';

  @override
  String get tip1 =>
      'En la Parte 2 no describas las fotos: compáralas y responde a la pregunta.';

  @override
  String get tip2 =>
      'En la Parte 3 pregunta la opinión del otro: «What do you think?».';

  @override
  String get tip3 =>
      'Si no sabes una palabra, explícala con otras. No te quedes callado.';

  @override
  String get tip4 =>
      'En la Parte 1 da respuestas cortas pero con un motivo o un ejemplo.';

  @override
  String get cancelSearch => 'Cancelar búsqueda';

  @override
  String get nobodySearchingTitle => 'Parece que no hay nadie buscando';

  @override
  String get nobodySearchingBody =>
      '¿Quieres agendar una reunión con alguien? Seguiremos buscando mientras tanto.';

  @override
  String get noLabel => 'No';

  @override
  String get yesSchedule => 'Sí, agendar';

  @override
  String get errorNotEligible =>
      'Necesitas una suscripción activa para buscar pareja.';

  @override
  String searchingBanner(String time) {
    return 'Buscando compañero · $time';
  }
}
