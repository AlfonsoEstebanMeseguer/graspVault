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

  @override
  String get loginHeadline =>
      'Practise the Cambridge Speaking test with another student.';

  @override
  String get loginSubtitle =>
      'A virtual examiner keeps the turns and the time. You just talk.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get noAccountYet => 'No account yet? Create one';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get checkYourEmail =>
      'We\'ve sent you an email to confirm your account. Open it and sign in again.';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get errorInvalidCredentials => 'Wrong email or password';

  @override
  String get errorEmailNotConfirmed => 'Confirm your email before signing in';

  @override
  String get errorEmailExists => 'An account with that email already exists';

  @override
  String get errorWeakPassword => 'The password is too weak';

  @override
  String get errorRateLimited => 'Too many attempts. Please wait a moment';

  @override
  String get errorUsernameTaken => 'That username is already taken';

  @override
  String get errorUnderage => 'You must be at least 14';

  @override
  String get errorGeneric => 'Something went wrong. Please try again';

  @override
  String stepOf(int n) {
    return 'Step $n of 3';
  }

  @override
  String get visibleToOthers => 'Visible to other users';

  @override
  String get privateOnlyYou => 'Private, only you can see it';

  @override
  String get canChangeLater => 'You can change it at any time';

  @override
  String get publicProfileTitle => 'Your public profile';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameAvailable => 'Available';

  @override
  String get usernameRules =>
      '3–20 characters: lowercase letters, numbers, _ and .';

  @override
  String get languagesYouSpeak => 'Languages you speak';

  @override
  String get otherLanguage => '+ Other';

  @override
  String get accountDataTitle => 'Your account details';

  @override
  String get birthDate => 'Date of birth';

  @override
  String get dayLabel => 'Day';

  @override
  String get monthLabel => 'Month';

  @override
  String get yearLabel => 'Year';

  @override
  String get minAgeHint => 'You must be at least 14.';

  @override
  String get invalidDate => 'Invalid date';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get invalidPhone => 'Invalid number';

  @override
  String get linkedToAccount => 'Linked to your account';

  @override
  String get whichExamTitle => 'Which exam are you preparing?';

  @override
  String speakingMinutes(String minutes) {
    return '$minutes-minute Speaking';
  }

  @override
  String get acceptTerms =>
      'I have read and accept the Terms of use and the Privacy policy.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get backLabel => 'Back';

  @override
  String get startLabel => 'Start';

  @override
  String get langEs => 'Spanish';

  @override
  String get langEn => 'English';

  @override
  String get langCa => 'Catalan';

  @override
  String get langFr => 'French';

  @override
  String get langIt => 'Italian';

  @override
  String get langDe => 'German';

  @override
  String get langPt => 'Portuguese';

  @override
  String get langEu => 'Basque';

  @override
  String get langGl => 'Galician';

  @override
  String get langZh => 'Chinese';

  @override
  String get langAr => 'Arabic';

  @override
  String get langRu => 'Russian';

  @override
  String get langUk => 'Ukrainian';

  @override
  String get langRo => 'Romanian';

  @override
  String roomTitle(String level) {
    return 'ROOM · $level';
  }

  @override
  String get meetBeforeStart => 'Get to know each other first';

  @override
  String get examStartsIn => 'The exam starts automatically in';

  @override
  String get waitingPartner => 'Waiting for your partner…';

  @override
  String candidateLine(String role, String langs) {
    return 'Candidate $role · $langs';
  }

  @override
  String get notConfirmed => 'Not ready';

  @override
  String get readyBadge => '✓ Ready';

  @override
  String get recordSession => 'Record the session';

  @override
  String recordOnlyIfBoth(String name, String state) {
    return 'Only if you both turn it on · $name: $state';
  }

  @override
  String get switchedOn => 'on';

  @override
  String get switchedOff => 'off';

  @override
  String get materialDownloaded => 'Exam material downloaded';

  @override
  String get materialDownloading => 'Downloading the exam material…';

  @override
  String get imReady => 'I\'m ready';

  @override
  String get notReadyYet => 'Not ready yet';

  @override
  String get leaveRoom => 'Leave the room';

  @override
  String get connecting => 'Connecting…';

  @override
  String get sessionError => 'Could not join the room.';

  @override
  String get contentMissing =>
      'Update the app: this exam is not in your version.';

  @override
  String get sessionClosed => 'The session has ended.';

  @override
  String get partnerNoShow => 'Your partner did not connect.';

  @override
  String get micOnShort => 'Mic on';

  @override
  String get micOffShort => 'Mic off';

  @override
  String get searchingPartner => 'Looking for a partner…';

  @override
  String get whileYouWait => 'WHILE YOU WAIT';

  @override
  String get tip1 =>
      'In Part 2 don\'t just describe the photos: compare them and answer the question.';

  @override
  String get tip2 =>
      'In Part 3 ask for your partner\'s opinion: “What do you think?”.';

  @override
  String get tip3 =>
      'If you don\'t know a word, explain it with others. Don\'t go silent.';

  @override
  String get tip4 =>
      'In Part 1 give short answers, but add a reason or an example.';

  @override
  String get cancelSearch => 'Cancel search';

  @override
  String get nobodySearchingTitle => 'It looks like nobody is searching';

  @override
  String get nobodySearchingBody =>
      'Would you like to schedule a meeting with someone? We\'ll keep searching meanwhile.';

  @override
  String get noLabel => 'No';

  @override
  String get yesSchedule => 'Yes, schedule';

  @override
  String get errorNotEligible =>
      'You need an active subscription to find a partner.';

  @override
  String searchingBanner(String time) {
    return 'Looking for a partner · $time';
  }
}
