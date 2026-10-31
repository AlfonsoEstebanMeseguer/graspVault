// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'MirloTalk';

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
  String get cuesMute => 'Silenciar pitidos';

  @override
  String get cuesUnmute => 'Activar pitidos';

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
      'Practica el Speaking en pareja, con un examinador virtual.';

  @override
  String get loginSubtitle =>
      'Él marca los turnos y el tiempo. Vosotros solo habláis.';

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
    return 'Sala de espera · $level';
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
  String get debugEnterNow => 'Crear sala ahora (debug)';

  @override
  String get debugSkip => 'Saltar al siguiente tramo (debug)';

  @override
  String get muteMe => 'Silenciar mi micro';

  @override
  String get unmuteMe => 'Activar mi micro';

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

  @override
  String get createMeeting => 'Proponer horario';

  @override
  String get agendaBoard => 'Buscar horario';

  @override
  String get agendaMine => 'Mis exámenes';

  @override
  String get noOffers => 'Nadie ha propuesto horario con este filtro.';

  @override
  String myOffersCount(int n) {
    return 'MIS PROPUESTAS · $n DE 2';
  }

  @override
  String interestedCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n interesados',
      one: '1 interesado',
      zero: 'Nadie interesado aún',
    );
    return '$_temp0';
  }

  @override
  String get todayLabel => 'Hoy';

  @override
  String get tomorrowLabel => 'Mañana';

  @override
  String get otherDay => 'Otro';

  @override
  String speaksLangs(String langs) {
    return 'Habla $langs';
  }

  @override
  String get availableLabel => 'Disponible';

  @override
  String get withdrawOffer => 'Retirar';

  @override
  String get statusConfirmed => 'Confirmada ✓✓';

  @override
  String get statusAwaitingYou => 'Falta tu confirmación';

  @override
  String statusAwaitingPartner(String name) {
    return 'Esperando a $name';
  }

  @override
  String get statusClosed => 'Cerrada';

  @override
  String get statusCancelled => 'Cancelada';

  @override
  String get statusDone => 'Hecha';

  @override
  String get statusNoShow => 'Ausencia';

  @override
  String get meetingLength => '30 min';

  @override
  String examWith(String level, String name) {
    return 'Examen $level con $name';
  }

  @override
  String startsInMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Empieza en $n min',
      one: 'Empieza en 1 min',
      zero: 'Empieza ya',
    );
    return '$_temp0';
  }

  @override
  String startedMinutesAgo(int n) {
    return 'Empezó hace $n min';
  }

  @override
  String get enterRoom => 'Entrar a la sala';

  @override
  String get remindBefore => 'Te avisaremos 10 min antes';

  @override
  String get dayField => 'Día';

  @override
  String get windowField => '¿Cuándo estás libre?';

  @override
  String get fromField => 'Desde';

  @override
  String get toField => 'Hasta';

  @override
  String get windowHint =>
      'Otros estudiantes reservarán un hueco de 30 min dentro de tu franja. Puede salir más de un examen.';

  @override
  String get examLevelField => 'Nivel del examen';

  @override
  String offersLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Puedes tener 2 propuestas abiertas · te quedan $n',
      one: 'Puedes tener 2 propuestas abiertas · te queda 1',
      zero: 'Puedes tener 2 propuestas abiertas · no te quedan',
    );
    return '$_temp0';
  }

  @override
  String get publishOffer => 'Publicar propuesta';

  @override
  String get busyLabel => 'Ocupado';

  @override
  String get modifyLabel => 'Cambiar hora';

  @override
  String get cancelLabel => 'Cancelar';

  @override
  String get confirmLabel => 'Confirmar';

  @override
  String get messageHint => 'Mensaje';

  @override
  String get sendLabel => 'Enviar';

  @override
  String sysModified(String name, String when) {
    return '$name propone cambiar a $when';
  }

  @override
  String sysConfirmedBy(String name) {
    return '$name ha confirmado ✓';
  }

  @override
  String get sysConfirmed => 'Reunión confirmada.';

  @override
  String sysPartnerOverlap(String name) {
    return '$name ya tiene otra reunión a esa hora. Proponed otra.';
  }

  @override
  String get sysUnavailable => 'Esta reunión ya no está disponible';

  @override
  String sysCancelled(String name) {
    return '$name ha cancelado la reunión';
  }

  @override
  String get sysExpired => 'La hora pasó sin confirmar el cambio';

  @override
  String get sysPartnerDeleted => 'Tu compañero ha eliminado su cuenta';

  @override
  String get sysUpdate => 'La reunión ha cambiado';

  @override
  String get deletedUser => 'Usuario eliminado';

  @override
  String get modifyTitle => 'Proponer otra hora';

  @override
  String get saveLabel => 'Guardar';

  @override
  String get cancelMeetingTitle => '¿Cancelar la reunión?';

  @override
  String cancelMeetingBody(String name) {
    return 'Se avisará a $name en el chat.';
  }

  @override
  String get keepMeeting => 'No, mantener';

  @override
  String get roomOpensBefore => 'La sala se abre 5 min antes';

  @override
  String meetingWith(String name, String level) {
    return 'Reunión con $name · $level';
  }

  @override
  String get viewLabel => 'Ver';

  @override
  String get errorOverlap => 'Ya tienes otra reunión confirmada a esa hora';

  @override
  String get errorTooManyOffers => 'Ya tienes 2 ofertas activas';

  @override
  String get errorOfferUnavailable => 'Esta propuesta ya no está disponible';

  @override
  String get errorBadTime => 'Esa hora no es válida';

  @override
  String get errorAlreadyAccepted =>
      'Ya tienes un hueco reservado en esta propuesta';

  @override
  String get errorWindow =>
      'La franja debe durar al menos 30 min y estar dentro de los próximos 7 días';

  @override
  String get errorTooEarly => 'La sala se abre 5 min antes';

  @override
  String get errorTooLate => 'Ya pasó el tiempo de cortesía';

  @override
  String get errorNotPending => 'La reunión ya no se puede cambiar';

  @override
  String get errorPartnerGone => 'Tu compañero ya no está disponible';

  @override
  String get errorSendFailed => 'No se ha podido enviar el mensaje';

  @override
  String sysModifiedByMe(String when) {
    return 'Propusiste cambiar a $when · falta que confirme';
  }

  @override
  String get sysConfirmedByMe => 'Has confirmado ✓';

  @override
  String get sysCancelledByMe => 'Has cancelado la reunión';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get preparing => 'Preparando';

  @override
  String get examsDone => 'Exámenes hechos';

  @override
  String get recordingsTitle => 'GRABACIONES';

  @override
  String recordingWith(String level, String name) {
    return '$level con $name';
  }

  @override
  String recordingMeta(String date, int minutes) {
    return '$date · $minutes min';
  }

  @override
  String daysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get recordingsDeleted => 'Las grabaciones se borran a los 30 días.';

  @override
  String get noRecordings =>
      'Aún no hay grabaciones. Se guardan si los dos activáis «Grabar la sesión».';

  @override
  String get playbackSoon => 'La reproducción llegará en la próxima versión.';

  @override
  String get planMonthly => 'Plan mensual';

  @override
  String get subActive => 'Activo';

  @override
  String get subInactive => 'Sin suscripción';

  @override
  String get trialAvailable => 'Test de prueba disponible';

  @override
  String get nextPayment => 'Próximo pago';

  @override
  String get storeLater => 'La gestión en la tienda llegará con los pagos.';

  @override
  String get deleteAccountBody =>
      'Se borrarán tu perfil, tus datos privados y las grabaciones en las que aparece tu voz. Tus mensajes de chat quedarán anónimos. No se puede deshacer.';

  @override
  String get deletePhrase => 'ELIMINAR';

  @override
  String deletePhraseHint(String phrase) {
    return 'Escribe $phrase para confirmar';
  }

  @override
  String get yourPassword => 'Tu contraseña';

  @override
  String get deleteForever => 'Eliminar para siempre';

  @override
  String get errorBadConfirmation => 'La frase no coincide';

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String get targetLevelField => 'Examen que preparas';

  @override
  String get avatarTitle => 'Foto de perfil';

  @override
  String get avatarFromGallery => 'Elegir de la galería';

  @override
  String get avatarFromCamera => 'Hacer una foto';

  @override
  String get avatarRemove => 'Quitar foto';

  @override
  String get avatarUpdated => 'Foto actualizada';

  @override
  String get avatarRemoved => 'Foto eliminada';

  @override
  String get avatarCropTitle => 'Ajusta tu foto';

  @override
  String get avatarCropHelp => 'Arrastra y pellizca para encuadrarla';

  @override
  String get avatarCropUse => 'Usar esta foto';

  @override
  String get errorPhotoUpload =>
      'No se pudo subir la foto. Prueba con otra imagen o inténtalo de nuevo';

  @override
  String get practiceVip => 'Practicar con compañero VIP simulado';

  @override
  String get simulatedVipHint =>
      'Modo desarrollo: compañero VIP simulado. Tú diriges el examen.';

  @override
  String get controlPanel => 'Control del examen';

  @override
  String get controlTime => 'Tiempo';

  @override
  String get controlNavigation => 'Navegación';

  @override
  String get controlExam => 'Examen';

  @override
  String get controlLeadership => 'Quién dirige';

  @override
  String get controlPause => 'Pausar';

  @override
  String get controlResume => 'Reanudar';

  @override
  String get controlPauseReader =>
      'No se puede pausar mientras habla el examinador';

  @override
  String get controlSkipReader => 'Saltar al examinador';

  @override
  String get controlRepeat => 'Repetir pregunta';

  @override
  String get controlNextStep => 'Siguiente pregunta';

  @override
  String get controlNextPart => 'Siguiente parte';

  @override
  String get controlGoToPart => 'Ir a la parte';

  @override
  String get controlEndExam => 'Terminar examen';

  @override
  String get controlEndExamConfirm =>
      '¿Terminar el examen y pasar al feedback?';

  @override
  String get controlTurnLength => 'Duración de los turnos de esta parte';

  @override
  String get controlFeedbackTime => 'Tiempo de feedback';

  @override
  String get controlSwitchExam => 'Cambiar de examen';

  @override
  String get controlSwitchConfirm =>
      'El examen nuevo empieza desde la Parte 1.';

  @override
  String get controlRandom => 'Aleatorio';

  @override
  String get controlCurrent => 'Actual';

  @override
  String get controlSearch => 'Buscar tema';

  @override
  String controlTransfer(String name) {
    return 'Ceder el control a $name';
  }

  @override
  String controlTransferNoPro(String name) {
    return '$name no tiene Pro';
  }

  @override
  String get leaderYou => 'Diriges tú';

  @override
  String leaderOther(String name) {
    return 'Dirige: $name';
  }

  @override
  String get pausedTitle => 'Examen en pausa';

  @override
  String pausedBy(String name) {
    return 'Lo ha pausado $name · micros abiertos';
  }

  @override
  String get switchingExam => 'Cambiando de examen… descargando material';

  @override
  String noticePause(String name) {
    return '$name ha pausado el examen';
  }

  @override
  String noticeResume(String name) {
    return '$name ha reanudado el examen';
  }

  @override
  String noticeSkipReader(String name) {
    return '$name ha saltado al examinador';
  }

  @override
  String noticeNextStep(String name) {
    return '$name ha pasado a la siguiente pregunta';
  }

  @override
  String noticeNextPart(String name) {
    return '$name ha pasado a la siguiente parte';
  }

  @override
  String noticeEndExam(String name) {
    return '$name ha terminado el examen';
  }

  @override
  String noticeRepeat(String name) {
    return '$name ha repetido la pregunta';
  }

  @override
  String noticeGoToPart(String name) {
    return '$name ha ido a otra parte';
  }

  @override
  String noticeTime(String name) {
    return '$name ha cambiado el tiempo';
  }

  @override
  String noticeSwitchExam(String name) {
    return '$name ha cambiado de examen';
  }

  @override
  String noticeLeader(String name) {
    return '$name dirige ahora el examen';
  }

  @override
  String get noticeLeaderYou => 'Ahora diriges tú el examen';

  @override
  String get errorNotLeader => 'Ahora mismo no diriges el examen';

  @override
  String get errorStaleControl =>
      'El examen acaba de cambiar; inténtalo otra vez';

  @override
  String get errorPartnerNotPro => 'Tu compañero no tiene Pro';

  @override
  String get errorContentMissingPartner =>
      'Tu compañero no tiene ese examen en su versión de la app';

  @override
  String get errorControlRange => 'Ese cambio se sale de los límites';

  @override
  String get planStandard => 'Plan Estándar';

  @override
  String get planPro => 'Plan Pro';

  @override
  String get upgradePro => 'Mejorar a Pro';

  @override
  String get proTitle => 'Pro: tú diriges el examen';

  @override
  String get proPrice => '10,00 € al mes · incluye todo lo del plan Estándar';

  @override
  String get proFeature1 => 'Pausar el examen y añadir o quitar minutos';

  @override
  String get proFeature2 =>
      'Saltar al examinador y pasar de pregunta o de parte';

  @override
  String get proFeature3 =>
      'Cambiar de examen cuando quieras, desde el catálogo o al azar';

  @override
  String get proFeature4 =>
      'Si los dos tenéis Pro, uno dirige y puede cederle el control al otro';

  @override
  String get proStoreSoon => 'Disponible cuando se active la tienda';

  @override
  String get dockTitle => 'Diriges el examen';

  @override
  String get dockPrev => 'Anterior';

  @override
  String get dockNext => 'Siguiente';

  @override
  String get dockNextPart => 'Sig. parte';

  @override
  String get dockMore => 'Más';

  @override
  String get dockLess => 'Menos';

  @override
  String get dockSkip => 'Saltar';

  @override
  String get dockPaused => 'En pausa';

  @override
  String get controlPrevStep => 'Pregunta anterior';

  @override
  String get controlTurnTime => 'Tiempo de este turno';

  @override
  String get controlBackToExam => 'Volver a la última pregunta';

  @override
  String noticePrevStep(String name) {
    return '$name ha vuelto a la pregunta anterior';
  }

  @override
  String get tabPractice => 'Practicar';

  @override
  String providerSoon(String provider) {
    return 'Entrar con $provider llegará pronto. De momento, usa tu email.';
  }

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get signUpWithEmail => 'Crear cuenta con email';

  @override
  String get haveAccountQuestion => '¿Ya tienes cuenta?';

  @override
  String get notAffiliated =>
      'App independiente, sin afiliación con Cambridge University Press & Assessment.';

  @override
  String get createAccountTitle => 'Crea tu cuenta';

  @override
  String get createAccountSubtitle =>
      'Con tu email y una contraseña. Después elegirás tu nombre y tu nivel.';

  @override
  String get welcomeBack => 'Hola de nuevo';

  @override
  String get welcomeBackSubtitle =>
      'Entra con tu email para seguir practicando.';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get orContinueWith => 'o continúa con';

  @override
  String get practiceSoloTitle => 'Practicar solo';

  @override
  String get practiceSoloBody =>
      'Con un compañero simulado, para cuando no hay nadie.';

  @override
  String get practiceVipBody =>
      'Solo en desarrollo: diriges el examen con los controles Pro.';

  @override
  String meetingWithName(String name) {
    return 'Reunión con $name';
  }

  @override
  String get aPartner => 'un compañero';

  @override
  String fullExamOf(String level) {
    return '$level · examen completo';
  }

  @override
  String get searchKeepsGoing => 'Seguimos buscando aunque cambies de pestaña.';

  @override
  String get tipLabel => 'Consejo';

  @override
  String tipForPart(int n) {
    return 'Consejo · Parte $n';
  }

  @override
  String get timeUp => 'Tiempo';

  @override
  String get statusListening => 'Escucha';

  @override
  String get micListening => 'Escuchando';

  @override
  String get yourTurnNow => 'Te toca a ti';

  @override
  String listeningTo(String name) {
    return 'Escuchando a $name';
  }

  @override
  String get textHidden => 'Texto oculto';

  @override
  String questionsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Quedan $n preguntas',
      one: 'Queda 1 pregunta',
      zero: 'Última pregunta',
    );
    return '$_temp0';
  }

  @override
  String examSummaryLine(String level, String topic, int minutes) {
    return '$level · $topic · $minutes min';
  }

  @override
  String get feedbackIdeasTitle => 'Ideas para empezar';

  @override
  String get criterionGrammar => 'Gramática y vocabulario';

  @override
  String get criterionDiscourse => 'Gestión del discurso';

  @override
  String get criterionPronunciation => 'Pronunciación';

  @override
  String get criterionInteraction => 'Comunicación interactiva';

  @override
  String ratePartner(String name) {
    return 'Valora a $name';
  }

  @override
  String onlyTheySee(String name) {
    return 'Solo lo verá $name';
  }

  @override
  String get endFeedback => 'Terminar';

  @override
  String partN(int n) {
    return 'Parte $n';
  }

  @override
  String get leaderYouLong => 'Diriges tú el examen';

  @override
  String get changeLabel => 'Cambiar';

  @override
  String candidateRole(String role) {
    return 'Candidato $role';
  }

  @override
  String get readyLabel => 'Listo';

  @override
  String get offerSlot => 'Proponer';

  @override
  String deletesIn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se borra en $n días',
      one: 'Se borra en 1 día',
    );
    return '$_temp0';
  }

  @override
  String get feedbackReceived => 'Lo que dicen de ti';

  @override
  String get feedbackReceivedEmpty =>
      'Cuando tus compañeros te valoren al final de un examen, lo verás aquí. Solo lo ves tú.';

  @override
  String ratingsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n valoraciones',
      one: '1 valoración',
    );
    return '$_temp0';
  }

  @override
  String perMonth(String price) {
    return '$price al mes';
  }

  @override
  String get planStandardShort => 'Estándar';

  @override
  String get planProShort => 'Pro';

  @override
  String get planStdFeature1 => 'Exámenes sin límite';

  @override
  String get planStdFeature2 => 'Matchmaking y agenda';

  @override
  String get planProFeature1 => 'Todo lo de Estándar';

  @override
  String get planProFeature2 => 'Diriges el examen: pausa, tiempo y partes';

  @override
  String get readTerms => 'Leer los Términos';

  @override
  String get readPrivacy => 'Leer la Política de privacidad';

  @override
  String get signUpLegalNote =>
      'Antes de empezar a usar la app te pediremos que aceptes los Términos de uso y la Política de privacidad.';

  @override
  String get legalSection => 'LEGAL';

  @override
  String get legalSpanishOnly => '';

  @override
  String get blockedUsers => 'Usuarios bloqueados';

  @override
  String get noBlockedUsers => 'No has bloqueado a nadie.';

  @override
  String get unblockAction => 'Desbloquear';

  @override
  String get reportOrBlock => 'Reportar o bloquear';

  @override
  String reportPartner(String name) {
    return 'Reportar a $name';
  }

  @override
  String reportTitle(String name) {
    return 'Reportar a $name';
  }

  @override
  String reportIntro(String name) {
    return 'Lo revisaremos lo antes posible. $name no sabrá quién le ha reportado.';
  }

  @override
  String get reportDetailsHint => 'Cuéntanos qué ha pasado (opcional)';

  @override
  String alsoBlock(String name) {
    return 'Bloquear también a $name';
  }

  @override
  String get reportSend => 'Enviar reporte';

  @override
  String get reportSent => 'Reporte enviado. Gracias por avisarnos.';

  @override
  String blockOnly(String name) {
    return 'Solo bloquear a $name';
  }

  @override
  String blockTitle(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get blockBody =>
      'No volveréis a coincidir en el emparejamiento, no veréis vuestras ofertas, no podréis escribiros y se cancelarán vuestras reuniones pendientes. Puedes desbloquear en Ajustes.';

  @override
  String get blockAction => 'Bloquear';

  @override
  String blockedDone(String name) {
    return 'Has bloqueado a $name.';
  }

  @override
  String get reasonHarassment => 'Acoso o insultos';

  @override
  String get reasonSexual => 'Contenido sexual';

  @override
  String get reasonHate => 'Odio o discriminación';

  @override
  String get reasonMinor => 'Riesgo para un menor';

  @override
  String get reasonSpam => 'Spam o publicidad';

  @override
  String get reasonNoShow => 'No se presentó';

  @override
  String get reasonOther => 'Otro motivo';

  @override
  String get countdownLabel => 'El examen empieza en';

  @override
  String buildLine(String label) {
    return 'Compilación $label';
  }

  @override
  String get reasonSilent => 'No habla en sus turnos';

  @override
  String get reasonMocking => 'Se burla o lo ridiculiza';

  @override
  String get reasonNoise => 'Ruido, música o habla encima';

  @override
  String get reasonQuit => 'Abandona a propósito';

  @override
  String get reasonControlAbuse => 'Abusa de los controles del examen';

  @override
  String get errorNotInSession =>
      'Solo puedes reportar a tu compañero de esta sesión';

  @override
  String agendaMineCount(int n) {
    return 'Mis exámenes · $n';
  }

  @override
  String get sectionNeedsYou => 'TE TOCA';

  @override
  String get sectionUpcoming => 'PRÓXIMOS';

  @override
  String pastCount(int n) {
    return 'Anteriores ($n)';
  }

  @override
  String get statusGone => 'Ya no va';

  @override
  String get noBookingsYet => 'Nadie ha reservado todavía';

  @override
  String get emptyMine => 'Aún no tienes exámenes agendados.';

  @override
  String get proposeMine => 'Proponer el mío';

  @override
  String get companionsTitle => 'COMPAÑEROS';

  @override
  String get companionsEmpty =>
      'Al terminar un examen podéis añadiros como compañeros y repetir con una invitación.';

  @override
  String get inviteLabel => 'Invitar';

  @override
  String get companionAddedYou => 'Te ha añadido';

  @override
  String get addBack => 'Añadir también';

  @override
  String get companionPendingShort => 'Falta que te añada';

  @override
  String examsTogether(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n exámenes juntos',
      one: '1 examen juntos',
      zero: 'Sin exámenes juntos',
    );
    return '$_temp0';
  }

  @override
  String get removeCompanion => 'Quitar de compañeros';

  @override
  String get allDays => 'Todos';

  @override
  String seeAlsoLevel(String level) {
    return 'Ver también $level';
  }

  @override
  String freeFromTo(String from, String to) {
    return 'Libre de $from a $to';
  }

  @override
  String bookTitle(String level, String name) {
    return 'Examen $level con $name';
  }

  @override
  String get bookThisSlot => 'Reservar este hueco';

  @override
  String get bookHint =>
      'Quedará confirmado para los dos. Tendréis un chat para organizaros.';

  @override
  String get stepProposed => 'Propuesta';

  @override
  String get chatClosed =>
      'Este chat ya se cerró: solo sirve para organizar su reunión.';

  @override
  String get qrLate => 'Llego 5 min tarde';

  @override
  String get qrOtherTime => '¿Cambiamos la hora?';

  @override
  String get qrSeeYou => '¡Nos vemos!';

  @override
  String sysBookedByMe(String when) {
    return 'Reservaste $when';
  }

  @override
  String sysBooked(String name, String when) {
    return '$name reservó $when';
  }

  @override
  String sysInvitedByMe(String when) {
    return 'Invitaste para $when';
  }

  @override
  String sysInvited(String name, String when) {
    return '$name te invita: $when';
  }

  @override
  String inviteTitle(String name) {
    return 'Invitar a $name';
  }

  @override
  String get timeField => 'Hora';

  @override
  String get sendInvite => 'Enviar invitación';

  @override
  String inviteHint(String name) {
    return '$name lo confirmará con un toque.';
  }

  @override
  String get noTimesLeft => 'No quedan horas libres este día.';

  @override
  String companionPrompt(String name) {
    return '¿Repetiríais? Añade a $name a tus compañeros para invitaros directamente.';
  }

  @override
  String get addCompanion => 'Añadir a compañeros';

  @override
  String companionAdded(String name) {
    return 'Añadido. Cuando $name también te añada, podréis invitaros.';
  }

  @override
  String companionMutual(String name) {
    return '$name y tú ya sois compañeros.';
  }

  @override
  String repeatWith(String name) {
    return 'Repetir con $name';
  }

  @override
  String get errorSlotTaken => 'Ese hueco ya está reservado';

  @override
  String get errorNotCompanion => 'Solo puedes invitar a tus compañeros';

  @override
  String get errorTooManyInvites => 'Ya tienes 3 invitaciones sin confirmar';

  @override
  String get errorTooManyCompanions => 'Ya tienes 20 compañeros';

  @override
  String get errorSessionNotEnded => 'Podrás añadirle al terminar el examen';
}
