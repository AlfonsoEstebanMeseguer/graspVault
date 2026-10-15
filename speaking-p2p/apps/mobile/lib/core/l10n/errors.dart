import '../../domain/account/account.dart';
import 'l10n.dart';

/// Server and auth error codes -> user text. Unknown codes never leak raw.
String errorText(AppLocalizations l, Object error) {
  final code = error is AppFailure ? error.code : '';
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
    'window_too_short' || 'window_out_of_range' => l.errorWindow,
    'too_early' => l.errorTooEarly,
    'too_late' => l.errorTooLate,
    'not_pending' || 'not_confirmed' => l.errorNotPending,
    'partner_gone' => l.errorPartnerGone,
    'send_failed' => l.errorSendFailed,
    _ => l.errorGeneric,
  };
}
