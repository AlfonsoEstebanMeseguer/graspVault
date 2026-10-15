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

  @override
  String get createMeeting => 'Create meeting';

  @override
  String get agendaChats => 'Chats';

  @override
  String get agendaBoard => 'Meetings';

  @override
  String get agendaMine => 'My schedule';

  @override
  String get noChats =>
      'No chats yet. Pick an offer in Meetings or create your own.';

  @override
  String get noOffers => 'No offers match this filter.';

  @override
  String get noMeetings => 'You have no confirmed meetings.';

  @override
  String myOffersCount(int n) {
    return 'MY OFFERS · $n OF 2';
  }

  @override
  String interestedCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n interested',
      one: '1 interested',
      zero: 'Nobody interested yet',
    );
    return '$_temp0';
  }

  @override
  String includeLevel(String level) {
    return '+ Include $level';
  }

  @override
  String get anyDay => 'Any day';

  @override
  String get todayLabel => 'Today';

  @override
  String get tomorrowLabel => 'Tomorrow';

  @override
  String get otherDay => 'Other';

  @override
  String speaksLangs(String langs) {
    return 'Speaks $langs';
  }

  @override
  String get availableLabel => 'Available';

  @override
  String get chooseTime => 'Choose time';

  @override
  String get withdrawOffer => 'Withdraw offer';

  @override
  String get statusConfirmed => 'Confirmed ✓✓';

  @override
  String get statusAwaitingYou => 'Waiting for your confirmation';

  @override
  String statusAwaitingPartner(String name) {
    return 'Waiting for $name';
  }

  @override
  String get statusClosed => 'Closed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDone => 'Done';

  @override
  String get statusNoShow => 'No-show';

  @override
  String get meetingLength => '30 min';

  @override
  String examWith(String level, String name) {
    return '$level exam with $name';
  }

  @override
  String startsInMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Starts in $n min',
      one: 'Starts in 1 min',
      zero: 'Starting now',
    );
    return '$_temp0';
  }

  @override
  String startedMinutesAgo(int n) {
    return 'Started $n min ago';
  }

  @override
  String get enterRoom => 'Enter the room';

  @override
  String get remindBefore => 'We\'ll remind you 10 min before';

  @override
  String get dayField => 'Day';

  @override
  String get windowField => 'When you\'re available';

  @override
  String get fromField => 'From';

  @override
  String get toField => 'To';

  @override
  String get windowHint =>
      'Whoever accepts picks an exact time inside this window.';

  @override
  String get examLevelField => 'Exam level';

  @override
  String offersLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'You can have 2 active offers · $n left',
      one: 'You can have 2 active offers · 1 left',
      zero: 'You can have 2 active offers · none left',
    );
    return '$_temp0';
  }

  @override
  String get publishOffer => 'Publish offer';

  @override
  String examWithTitle(String name) {
    return 'Exam with $name';
  }

  @override
  String get chooseStart => 'Choose when you start';

  @override
  String get busyLabel => 'Busy';

  @override
  String get busyHint =>
      'Times that clash with your confirmed meetings are blocked.';

  @override
  String proposeAndChat(String time) {
    return 'Propose $time and open chat';
  }

  @override
  String get pickATime => 'Pick a time';

  @override
  String get noSlots => 'No free times left in this window.';

  @override
  String get modifyLabel => 'Change';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get confirmLabel => 'Confirm';

  @override
  String get messageHint => 'Message';

  @override
  String get sendLabel => 'Send';

  @override
  String sysProposed(String name, String when) {
    return '$name proposed $when';
  }

  @override
  String sysModified(String name, String when) {
    return '$name changed the time to $when · confirmations reset';
  }

  @override
  String sysConfirmedBy(String name) {
    return '$name confirmed ✓';
  }

  @override
  String get sysConfirmed => 'Meeting confirmed. It\'s in My schedule.';

  @override
  String sysPartnerOverlap(String name) {
    return '$name already has a meeting at that time. Pick another one.';
  }

  @override
  String get sysUnavailable => 'This meeting is no longer available';

  @override
  String sysCancelled(String name) {
    return '$name cancelled the meeting';
  }

  @override
  String get sysExpired => 'The time passed without both confirmations';

  @override
  String get sysPartnerDeleted => 'Your partner deleted their account';

  @override
  String get sysUpdate => 'The meeting changed';

  @override
  String get deletedUser => 'Deleted user';

  @override
  String get modifyTitle => 'Change time or level';

  @override
  String get saveLabel => 'Save';

  @override
  String get cancelMeetingTitle => 'Cancel the meeting?';

  @override
  String cancelMeetingBody(String name) {
    return '$name will be told in the chat.';
  }

  @override
  String get keepMeeting => 'No, keep it';

  @override
  String get roomOpensBefore => 'The room opens 5 min before';

  @override
  String meetingWith(String name, String level) {
    return 'Meeting with $name · $level';
  }

  @override
  String get viewLabel => 'View';

  @override
  String get errorOverlap =>
      'You already have a confirmed meeting at that time';

  @override
  String get errorTooManyOffers => 'You already have 2 active offers';

  @override
  String get errorOfferUnavailable => 'This offer is no longer available';

  @override
  String get errorBadTime => 'That time isn\'t valid';

  @override
  String get errorAlreadyAccepted => 'You already picked this offer: see Chats';

  @override
  String get errorWindow =>
      'The window must last at least 30 min and be within the next 7 days';

  @override
  String get errorTooEarly => 'The room opens 5 min before';

  @override
  String get errorTooLate => 'The grace period is over';

  @override
  String get errorNotPending => 'The meeting can no longer be changed';

  @override
  String get errorPartnerGone => 'Your partner is no longer available';

  @override
  String get errorSendFailed => 'The message couldn\'t be sent';

  @override
  String sysProposedByMe(String when) {
    return 'You proposed $when';
  }

  @override
  String sysModifiedByMe(String when) {
    return 'You changed the time to $when · confirmations reset';
  }

  @override
  String get sysConfirmedByMe => 'You confirmed ✓';

  @override
  String get sysCancelledByMe => 'You cancelled the meeting';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get preparing => 'Preparing for';

  @override
  String get examsDone => 'Exams done';

  @override
  String get recordingsTitle => 'RECORDINGS';

  @override
  String recordingWith(String level, String name) {
    return '$level with $name';
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
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get recordingsDeleted => 'Recordings are deleted after 30 days.';

  @override
  String get noRecordings =>
      'No recordings yet. They\'re saved when both of you turn on “Record the session”.';

  @override
  String get playbackSoon => 'Playback is coming in the next version.';

  @override
  String get planMonthly => 'Monthly plan';

  @override
  String get subActive => 'Active';

  @override
  String get subInactive => 'No subscription';

  @override
  String get trialAvailable => 'Trial test available';

  @override
  String get nextPayment => 'Next payment';

  @override
  String get storeLater => 'Store management arrives with payments.';

  @override
  String get deleteAccountBody =>
      'Your profile, private data and the recordings with your voice will be deleted. Your chat messages will be anonymised. This can\'t be undone.';

  @override
  String get deletePhrase => 'DELETE';

  @override
  String deletePhraseHint(String phrase) {
    return 'Type $phrase to confirm';
  }

  @override
  String get yourPassword => 'Your password';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get errorBadConfirmation => 'The phrase doesn\'t match';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get targetLevelField => 'Exam you\'re preparing';
}
