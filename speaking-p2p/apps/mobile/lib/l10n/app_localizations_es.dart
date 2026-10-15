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
}
