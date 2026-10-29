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
      'Practise Speaking in pairs, with a virtual examiner.';

  @override
  String get loginSubtitle =>
      'It runs the turns and the clock. You two just talk.';

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
      'I have read and accept the Terms of Use and the Privacy Policy.';

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
    return 'Waiting room · $level';
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
  String get debugEnterNow => 'Create room now (debug)';

  @override
  String get debugSkip => 'Skip to next part (debug)';

  @override
  String get muteMe => 'Mute my mic';

  @override
  String get unmuteMe => 'Unmute my mic';

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
  String get createMeeting => 'Offer a time slot';

  @override
  String get agendaBoard => 'Find a slot';

  @override
  String get agendaMine => 'My exams';

  @override
  String get noOffers => 'Nobody has offered a time with this filter.';

  @override
  String myOffersCount(int n) {
    return 'MY PROPOSALS · $n OF 2';
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
  String get withdrawOffer => 'Withdraw';

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
  String get windowField => 'When are you free?';

  @override
  String get fromField => 'From';

  @override
  String get toField => 'To';

  @override
  String get windowHint =>
      'Other students will book a 30-min slot inside your window. It can fit more than one exam.';

  @override
  String get examLevelField => 'Exam level';

  @override
  String offersLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'You can have 2 open proposals · $n left',
      one: 'You can have 2 open proposals · 1 left',
      zero: 'You can have 2 open proposals · none left',
    );
    return '$_temp0';
  }

  @override
  String get publishOffer => 'Publish proposal';

  @override
  String get busyLabel => 'Busy';

  @override
  String get modifyLabel => 'Change time';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get confirmLabel => 'Confirm';

  @override
  String get messageHint => 'Message';

  @override
  String get sendLabel => 'Send';

  @override
  String sysModified(String name, String when) {
    return '$name suggests $when';
  }

  @override
  String sysConfirmedBy(String name) {
    return '$name confirmed ✓';
  }

  @override
  String get sysConfirmed => 'Meeting confirmed.';

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
  String get sysExpired => 'The time passed without confirming the change';

  @override
  String get sysPartnerDeleted => 'Your partner deleted their account';

  @override
  String get sysUpdate => 'The meeting changed';

  @override
  String get deletedUser => 'Deleted user';

  @override
  String get modifyTitle => 'Suggest another time';

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
  String get errorOfferUnavailable => 'This proposal is no longer available';

  @override
  String get errorBadTime => 'That time isn\'t valid';

  @override
  String get errorAlreadyAccepted =>
      'You already booked a slot in this proposal';

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
  String sysModifiedByMe(String when) {
    return 'You suggested $when · waiting for confirmation';
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

  @override
  String get avatarTitle => 'Profile photo';

  @override
  String get avatarFromGallery => 'Choose from gallery';

  @override
  String get avatarFromCamera => 'Take a photo';

  @override
  String get avatarRemove => 'Remove photo';

  @override
  String get avatarUpdated => 'Photo updated';

  @override
  String get avatarRemoved => 'Photo removed';

  @override
  String get avatarCropTitle => 'Adjust your photo';

  @override
  String get avatarCropHelp => 'Drag and pinch to frame it';

  @override
  String get avatarCropUse => 'Use this photo';

  @override
  String get errorPhotoUpload =>
      'Couldn\'t upload the photo. Try another image or try again';

  @override
  String get practiceVip => 'Practise with a simulated VIP partner';

  @override
  String get simulatedVipHint =>
      'Development mode: simulated VIP partner. You run the exam.';

  @override
  String get controlPanel => 'Exam control';

  @override
  String get controlTime => 'Time';

  @override
  String get controlNavigation => 'Navigation';

  @override
  String get controlExam => 'Exam';

  @override
  String get controlLeadership => 'Who leads';

  @override
  String get controlPause => 'Pause';

  @override
  String get controlResume => 'Resume';

  @override
  String get controlPauseReader =>
      'You can\'t pause while the examiner is speaking';

  @override
  String get controlSkipReader => 'Skip the examiner';

  @override
  String get controlRepeat => 'Repeat question';

  @override
  String get controlNextStep => 'Next question';

  @override
  String get controlNextPart => 'Next part';

  @override
  String get controlGoToPart => 'Go to part';

  @override
  String get controlEndExam => 'End exam';

  @override
  String get controlEndExamConfirm => 'End the exam and go to feedback?';

  @override
  String get controlTurnLength => 'Turn length in this part';

  @override
  String get controlFeedbackTime => 'Feedback time';

  @override
  String get controlSwitchExam => 'Change exam';

  @override
  String get controlSwitchConfirm => 'The new exam starts from Part 1.';

  @override
  String get controlRandom => 'Random';

  @override
  String get controlCurrent => 'Current';

  @override
  String get controlSearch => 'Search topic';

  @override
  String controlTransfer(String name) {
    return 'Hand control to $name';
  }

  @override
  String controlTransferNoPro(String name) {
    return '$name doesn\'t have Pro';
  }

  @override
  String get leaderYou => 'You lead';

  @override
  String leaderOther(String name) {
    return 'Led by $name';
  }

  @override
  String get pausedTitle => 'Exam paused';

  @override
  String pausedBy(String name) {
    return 'Paused by $name · mics open';
  }

  @override
  String get switchingExam => 'Changing exam… downloading material';

  @override
  String noticePause(String name) {
    return '$name paused the exam';
  }

  @override
  String noticeResume(String name) {
    return '$name resumed the exam';
  }

  @override
  String noticeSkipReader(String name) {
    return '$name skipped the examiner';
  }

  @override
  String noticeNextStep(String name) {
    return '$name moved to the next question';
  }

  @override
  String noticeNextPart(String name) {
    return '$name moved to the next part';
  }

  @override
  String noticeEndExam(String name) {
    return '$name ended the exam';
  }

  @override
  String noticeRepeat(String name) {
    return '$name repeated the question';
  }

  @override
  String noticeGoToPart(String name) {
    return '$name jumped to another part';
  }

  @override
  String noticeTime(String name) {
    return '$name changed the time';
  }

  @override
  String noticeSwitchExam(String name) {
    return '$name changed the exam';
  }

  @override
  String noticeLeader(String name) {
    return '$name now leads the exam';
  }

  @override
  String get noticeLeaderYou => 'You now lead the exam';

  @override
  String get errorNotLeader => 'You\'re not leading the exam right now';

  @override
  String get errorStaleControl => 'The exam just changed; try again';

  @override
  String get errorPartnerNotPro => 'Your partner doesn\'t have Pro';

  @override
  String get errorContentMissingPartner =>
      'Your partner\'s app doesn\'t have that exam';

  @override
  String get errorControlRange => 'That change is out of range';

  @override
  String get planStandard => 'Standard plan';

  @override
  String get planPro => 'Pro plan';

  @override
  String get upgradePro => 'Upgrade to Pro';

  @override
  String get proTitle => 'Pro: you run the exam';

  @override
  String get proPrice => '€10.00 a month · includes everything in Standard';

  @override
  String get proFeature1 => 'Pause the exam and add or remove minutes';

  @override
  String get proFeature2 =>
      'Skip the examiner and move to the next question or part';

  @override
  String get proFeature3 =>
      'Change exam whenever you like, from the catalogue or at random';

  @override
  String get proFeature4 =>
      'If you both have Pro, one leads and can hand control to the other';

  @override
  String get proStoreSoon => 'Available once the store is live';

  @override
  String get dockTitle => 'You\'re running the exam';

  @override
  String get dockPrev => 'Previous';

  @override
  String get dockNext => 'Next';

  @override
  String get dockNextPart => 'Next part';

  @override
  String get dockMore => 'More';

  @override
  String get dockLess => 'Less';

  @override
  String get dockSkip => 'Skip';

  @override
  String get dockPaused => 'Paused';

  @override
  String get controlPrevStep => 'Previous question';

  @override
  String get controlTurnTime => 'Time for this turn';

  @override
  String get controlBackToExam => 'Back to the last question';

  @override
  String noticePrevStep(String name) {
    return '$name went back to the previous question';
  }

  @override
  String get tabPractice => 'Practise';

  @override
  String providerSoon(String provider) {
    return 'Signing in with $provider is coming soon. For now, use your email.';
  }

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signUpWithEmail => 'Sign up with email';

  @override
  String get haveAccountQuestion => 'Already have an account?';

  @override
  String get notAffiliated =>
      'Independent app, not affiliated with Cambridge University Press & Assessment.';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get createAccountSubtitle =>
      'With your email and a password. Then you\'ll pick your name and level.';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get welcomeBackSubtitle =>
      'Sign in with your email to keep practising.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get practiceSoloTitle => 'Practise alone';

  @override
  String get practiceSoloBody =>
      'With a simulated partner, for when nobody is around.';

  @override
  String get practiceVipBody =>
      'Development only: you run the exam with the Pro controls.';

  @override
  String meetingWithName(String name) {
    return 'Meeting with $name';
  }

  @override
  String get aPartner => 'a partner';

  @override
  String fullExamOf(String level) {
    return '$level · full exam';
  }

  @override
  String get searchKeepsGoing => 'We keep searching even if you switch tabs.';

  @override
  String get tipLabel => 'Tip';

  @override
  String tipForPart(int n) {
    return 'Tip · Part $n';
  }

  @override
  String get timeUp => 'Time';

  @override
  String get statusListening => 'Listening';

  @override
  String get micListening => 'Listening';

  @override
  String get yourTurnNow => 'Your turn';

  @override
  String listeningTo(String name) {
    return 'Listening to $name';
  }

  @override
  String get textHidden => 'Text hidden';

  @override
  String questionsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n questions left',
      one: '1 question left',
      zero: 'Last question',
    );
    return '$_temp0';
  }

  @override
  String examSummaryLine(String level, String topic, int minutes) {
    return '$level · $topic · $minutes min';
  }

  @override
  String get feedbackIdeasTitle => 'Ideas to get started';

  @override
  String get criterionGrammar => 'Grammar and vocabulary';

  @override
  String get criterionDiscourse => 'Discourse management';

  @override
  String get criterionPronunciation => 'Pronunciation';

  @override
  String get criterionInteraction => 'Interactive communication';

  @override
  String ratePartner(String name) {
    return 'Rate $name';
  }

  @override
  String onlyTheySee(String name) {
    return 'Only $name will see it';
  }

  @override
  String get endFeedback => 'Finish';

  @override
  String partN(int n) {
    return 'Part $n';
  }

  @override
  String get leaderYouLong => 'You run the exam';

  @override
  String get changeLabel => 'Change';

  @override
  String candidateRole(String role) {
    return 'Candidate $role';
  }

  @override
  String get readyLabel => 'Ready';

  @override
  String get offerSlot => 'Propose';

  @override
  String deletesIn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Deleted in $n days',
      one: 'Deleted in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get feedbackReceived => 'What partners say';

  @override
  String get feedbackReceivedEmpty =>
      'When partners rate you after an exam, you\'ll see it here. Only you can see it.';

  @override
  String ratingsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ratings',
      one: '1 rating',
    );
    return '$_temp0';
  }

  @override
  String perMonth(String price) {
    return '$price a month';
  }

  @override
  String get planStandardShort => 'Standard';

  @override
  String get planProShort => 'Pro';

  @override
  String get planStdFeature1 => 'Unlimited exams';

  @override
  String get planStdFeature2 => 'Matchmaking and agenda';

  @override
  String get planProFeature1 => 'Everything in Standard';

  @override
  String get planProFeature2 => 'Run the exam: pause, time and parts';

  @override
  String get readTerms => 'Read the Terms';

  @override
  String get readPrivacy => 'Read the Privacy Policy';

  @override
  String get signUpLegalNote =>
      'Before you start using the app we will ask you to accept the Terms of Use and the Privacy Policy.';

  @override
  String get legalSection => 'LEGAL';

  @override
  String get legalSpanishOnly =>
      'These documents are currently available in Spanish only.';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get noBlockedUsers => 'You haven\'t blocked anyone.';

  @override
  String get unblockAction => 'Unblock';

  @override
  String get reportOrBlock => 'Report or block';

  @override
  String reportPartner(String name) {
    return 'Report $name';
  }

  @override
  String reportTitle(String name) {
    return 'Report $name';
  }

  @override
  String reportIntro(String name) {
    return 'We will review it as soon as possible. They won\'t know who reported them.';
  }

  @override
  String get reportDetailsHint => 'Tell us what happened (optional)';

  @override
  String alsoBlock(String name) {
    return 'Also block $name';
  }

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSent => 'Report sent. Thanks for letting us know.';

  @override
  String blockOnly(String name) {
    return 'Only block $name';
  }

  @override
  String blockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockBody =>
      'You won\'t be matched again, you won\'t see each other\'s offers, you can\'t message each other and your pending meetings will be cancelled. You can unblock in Settings.';

  @override
  String get blockAction => 'Block';

  @override
  String blockedDone(String name) {
    return 'You blocked $name.';
  }

  @override
  String get reasonHarassment => 'Harassment or insults';

  @override
  String get reasonSexual => 'Sexual content';

  @override
  String get reasonHate => 'Hate or discrimination';

  @override
  String get reasonMinor => 'Risk to a minor';

  @override
  String get reasonSpam => 'Spam or advertising';

  @override
  String get reasonNoShow => 'Didn\'t show up';

  @override
  String get reasonOther => 'Something else';

  @override
  String get reasonSilent => 'Doesn\'t speak in their turns';

  @override
  String get reasonMocking => 'Mocks or ridicules';

  @override
  String get reasonNoise => 'Noise, music or talking over';

  @override
  String get reasonQuit => 'Quits on purpose';

  @override
  String get reasonControlAbuse => 'Misuses the exam controls';

  @override
  String get errorNotInSession =>
      'You can only report your partner in this session';

  @override
  String agendaMineCount(int n) {
    return 'My exams · $n';
  }

  @override
  String get sectionNeedsYou => 'YOUR TURN';

  @override
  String get sectionUpcoming => 'COMING UP';

  @override
  String pastCount(int n) {
    return 'Past ($n)';
  }

  @override
  String get statusGone => 'Off';

  @override
  String get noBookingsYet => 'No bookings yet';

  @override
  String get emptyMine => 'No exams scheduled yet.';

  @override
  String get proposeMine => 'Offer mine';

  @override
  String get companionsTitle => 'PARTNERS';

  @override
  String get companionsEmpty =>
      'After an exam you can add each other as partners and repeat with an invitation.';

  @override
  String get inviteLabel => 'Invite';

  @override
  String get companionAddedYou => 'Added you';

  @override
  String get addBack => 'Add back';

  @override
  String get companionPendingShort => 'Not added you yet';

  @override
  String examsTogether(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n exams together',
      one: '1 exam together',
      zero: 'No exams together',
    );
    return '$_temp0';
  }

  @override
  String get removeCompanion => 'Remove from partners';

  @override
  String get allDays => 'All';

  @override
  String seeAlsoLevel(String level) {
    return 'Also show $level';
  }

  @override
  String freeFromTo(String from, String to) {
    return 'Free $from–$to';
  }

  @override
  String bookTitle(String level, String name) {
    return '$level exam with $name';
  }

  @override
  String get bookThisSlot => 'Book this slot';

  @override
  String get bookHint =>
      'It will be confirmed for both of you, with a chat to organise it.';

  @override
  String get stepProposed => 'Proposed';

  @override
  String get chatClosed =>
      'This chat is closed: it is only for organising its meeting.';

  @override
  String get qrLate => 'I\'ll be 5 min late';

  @override
  String get qrOtherTime => 'Can we change the time?';

  @override
  String get qrSeeYou => 'See you then!';

  @override
  String sysBookedByMe(String when) {
    return 'You booked $when';
  }

  @override
  String sysBooked(String name, String when) {
    return '$name booked $when';
  }

  @override
  String sysInvitedByMe(String when) {
    return 'You invited for $when';
  }

  @override
  String sysInvited(String name, String when) {
    return '$name invites you: $when';
  }

  @override
  String inviteTitle(String name) {
    return 'Invite $name';
  }

  @override
  String get timeField => 'Time';

  @override
  String get sendInvite => 'Send invitation';

  @override
  String inviteHint(String name) {
    return '$name confirms it with one tap.';
  }

  @override
  String get noTimesLeft => 'No times left on this day.';

  @override
  String companionPrompt(String name) {
    return 'Would you repeat? Add $name to your partners to invite each other directly.';
  }

  @override
  String get addCompanion => 'Add to partners';

  @override
  String companionAdded(String name) {
    return 'Added. Once $name adds you too, you can invite each other.';
  }

  @override
  String companionMutual(String name) {
    return 'You and $name are partners.';
  }

  @override
  String repeatWith(String name) {
    return 'Repeat with $name';
  }

  @override
  String get errorSlotTaken => 'That slot is already booked';

  @override
  String get errorNotCompanion => 'You can only invite your partners';

  @override
  String get errorTooManyInvites =>
      'You already have 3 unconfirmed invitations';

  @override
  String get errorTooManyCompanions => 'You already have 20 partners';

  @override
  String get errorSessionNotEnded => 'You can add them when the exam is over';
}
