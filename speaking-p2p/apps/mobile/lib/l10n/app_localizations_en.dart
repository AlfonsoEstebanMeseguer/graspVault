// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Speaking P2P';

  @override
  String get tabExam => 'Exam';

  @override
  String get tabAgenda => 'Agenda';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabSettings => 'Settings';

  @override
  String get homeHello => 'Hello,';

  @override
  String get searchPartner => 'Find a partner';

  @override
  String examOfLevel(String level) {
    return '$level Speaking exam';
  }

  @override
  String examSummary(int minutes) {
    return '4 parts · ~$minutes min + 5 min feedback';
  }

  @override
  String get offlineBanner =>
      'Offline mode: practise with a simulated partner.';

  @override
  String get practiceSimulated => 'Practise with a simulated partner';

  @override
  String get levelB1 => 'B1 Preliminary';

  @override
  String get levelB2 => 'B2 First';

  @override
  String get levelC1 => 'C1 Advanced';

  @override
  String partOf(int n) {
    return 'PART $n OF 4';
  }

  @override
  String get examiner => 'Examiner';

  @override
  String get examinerQuestion => 'Examiner\'s question';

  @override
  String get hideText => 'Hide text';

  @override
  String get showText => 'Show text';

  @override
  String get hideTimer => 'Hide timer';

  @override
  String get showTimer => 'Show timer';

  @override
  String get yourTurn => 'Your turn to answer';

  @override
  String partnerTurn(String name) {
    return '$name\'s turn';
  }

  @override
  String get micOpen => 'Your microphone is on';

  @override
  String get micMuted => 'Your microphone is muted';

  @override
  String get examinerSpeaking => 'The examiner is speaking';

  @override
  String get bothMuted => 'Both microphones muted';

  @override
  String get addressedToBoth => 'To: both of you';

  @override
  String get addressedToYou => 'To: you';

  @override
  String addressedTo(String name) {
    return 'To: $name';
  }

  @override
  String get you => 'You';

  @override
  String roleLabel(String name, String role) {
    return '$name · $role';
  }

  @override
  String get statusMuted => 'Muted';

  @override
  String get statusSpeaking => 'Speaking';

  @override
  String get statusMicOpen => 'Mic on';

  @override
  String choosesTwoPhotos(String name) {
    return '$name chooses two of these photos';
  }

  @override
  String describesPhoto(String name) {
    return '$name describes this photo';
  }

  @override
  String comparesPhotos(String name) {
    return '$name compares these photos';
  }

  @override
  String photoPlaceholder(String id) {
    return 'Photo · $id';
  }

  @override
  String discussionPhase(int minutes) {
    return 'Discussion · $minutes min';
  }

  @override
  String decisionPhase(int minutes) {
    return 'Decision · $minutes min';
  }

  @override
  String startingIn(int seconds) {
    return 'The exam starts in $seconds';
  }

  @override
  String get abandon => 'Leave';

  @override
  String get abandonTitle => 'Are you sure you want to leave?';

  @override
  String abandonBody(String name) {
    return 'The exam will end for both of you and $name will go back to the start. If you are using your free trial, it will count as used.';
  }

  @override
  String get keepGoing => 'Stay in the exam';

  @override
  String get leaveExam => 'Leave the exam';

  @override
  String leaveExamIn(int seconds) {
    return 'Leave the exam ($seconds)';
  }

  @override
  String get partnerLeft => 'Your partner has left';

  @override
  String get backHome => 'Back to start';

  @override
  String get examFinished => 'Exam finished';

  @override
  String get feedbackSubtitle =>
      'Now you have time to give each other feedback.';

  @override
  String get feedbackTime => 'FEEDBACK TIME';

  @override
  String get micsOpenBoth => 'Microphones on for both';

  @override
  String get feedbackIdeas => 'IDEAS TO GET STARTED';

  @override
  String get feedbackIdea1 =>
      'Which expression or word of your partner\'s did you like?';

  @override
  String get feedbackIdea2 => 'Was there any repeated mistake?';

  @override
  String get feedbackIdea3 =>
      'In Part 3, did you let each other speak and reach a decision?';

  @override
  String get endCall => 'End call';

  @override
  String get simulatedPartner => 'sim_partner';

  @override
  String get simulatedPartnerHint =>
      'Development mode: the partner is simulated and silent.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'APPEARANCE';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get appLanguage => 'APP LANGUAGE';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get subscription => 'SUBSCRIPTION';

  @override
  String get account => 'ACCOUNT';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get needsBackend =>
      'Available once the app is connected to the server.';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get profileTitle => 'Profile';
}
