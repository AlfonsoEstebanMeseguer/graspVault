import '../../domain/account/account.dart';
import '../../domain/exam/control.dart';
import 'l10n.dart';

/// Server and auth error codes -> user text. Unknown codes never leak raw.
String errorText(AppLocalizations l, Object error) {
  final code = switch (error) { AppFailure(:final code) => code, ControlError(:final code) => code, _ => '' };
  return switch (code) {
    'invalid_credentials' => l.errorInvalidCredentials,
    'email_not_confirmed' => l.errorEmailNotConfirmed,
    'email_exists' => l.errorEmailExists,
    'weak_password' => l.errorWeakPassword,
    'rate_limited' => l.errorRateLimited,
    'username_taken' || 'conflict' => l.errorUsernameTaken,
    'underage' => l.errorUnderage,
    'not_eligible' => l.errorNotEligible,
    'overlap' => l.errorOverlap,
    'too_many_offers' => l.errorTooManyOffers,
    'offer_unavailable' || 'own_offer' => l.errorOfferUnavailable,
    'bad_time' || 'in_the_past' => l.errorBadTime,
    'already_accepted' => l.errorAlreadyAccepted,
    'slot_taken' => l.errorSlotTaken,
    'not_companion' => l.errorNotCompanion,
    'too_many_invites' => l.errorTooManyInvites,
    'too_many_companions' => l.errorTooManyCompanions,
    'session_not_ended' => l.errorSessionNotEnded,
    'window_too_short' || 'window_out_of_range' => l.errorWindow,
    'too_early' => l.errorTooEarly,
    'too_late' => l.errorTooLate,
    'not_pending' || 'not_confirmed' => l.errorNotPending,
    'partner_gone' => l.errorPartnerGone,
    'send_failed' => l.errorSendFailed,
    'bad_confirmation' => l.errorBadConfirmation,
    'upload_failed' || 'not_uploaded' || 'invalid_image' || 'image_unreadable' => l.errorPhotoUpload,
    'reader_speaking' => l.controlPauseReader,
    'not_leader' || 'not_pro' => l.errorNotLeader,
    'stale_control' => l.errorStaleControl,
    'partner_not_pro' => l.errorPartnerNotPro,
    'content_missing_partner' => l.errorContentMissingPartner,
    'out_of_range' || 'bad_delta' => l.errorControlRange,
    _ => l.errorGeneric,
  };
}
