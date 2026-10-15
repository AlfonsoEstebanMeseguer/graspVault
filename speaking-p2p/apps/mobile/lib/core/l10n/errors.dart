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
    _ => l.errorGeneric,
  };
}
