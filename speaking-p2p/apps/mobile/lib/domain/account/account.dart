// Account-level domain types. No Flutter, no Supabase.
import '../exam/models.dart';

/// How the account was created (Supabase `app_metadata.provider`, D-062).
/// Decides how an irreversible action re-authenticates.
enum SignInMethod {
  email,
  google,
  apple;

  /// Unknown or missing providers fall back to email (the password path).
  static SignInMethod fromProvider(String? provider) => switch (provider) {
        'google' => SignInMethod.google,
        'apple' => SignInMethod.apple,
        _ => SignInMethod.email,
      };

  /// Brand name shown in the UI (not translated).
  String get label => switch (this) { email => 'email', google => 'Google', apple => 'Apple' };
}

class AuthUser {
  const AuthUser({required this.id, required this.email, this.method = SignInMethod.email});
  final String id;
  final String? email;
  final SignInMethod method;
}

class MyProfile {
  const MyProfile({
    required this.id,
    required this.username,
    required this.languages,
    required this.targetLevel,
    this.avatarKey,
    this.acceptedTermsVersion,
  });
  final String id;
  final String username;
  final List<String> languages;
  final Level targetLevel;

  /// R2 key of the profile photo (never a URL); null = initial letter.
  final String? avatarKey;

  /// Version of the Terms + Privacy Policy last accepted (profiles_private);
  /// null = unknown, which never blocks.
  final String? acceptedTermsVersion;

  /// The app ships newer documents than the ones accepted (§11 of
  /// docs/legal/ASPECTOS_A_COMPLETAR.md). Versions are ISO dates, so a plain
  /// string comparison orders them; an OLDER app never asks to go back.
  bool get needsTermsUpdate {
    final v = acceptedTermsVersion;
    return v != null && isIsoVersion(v) && v.compareTo(termsVersion) < 0;
  }
}

bool isIsoVersion(String v) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v);

/// Everything the onboarding collects (CLAUDE.md §3, steps 2-8).
class OnboardingData {
  const OnboardingData({
    required this.username,
    required this.languages,
    required this.targetLevel,
    required this.birthDate,
    required this.termsVersion,
  });

  final String username;
  final List<String> languages;
  final Level targetLevel;
  final DateTime birthDate;
  final String termsVersion;

  Map<String, Object?> toJson() => {
        'username': username,
        'languages': languages,
        'targetLevel': targetLevel.code,
        'birthDate': '${birthDate.year.toString().padLeft(4, '0')}-'
            '${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'termsVersion': termsVersion,
      };
}

/// Version of the Terms + Privacy Policy (assets/legal) the user accepts. Bump it
/// when they change: the accepted version and date are stored with the profile.
const termsVersion = '2026-11-19';

/// Business error coming back from the server (stable code -> i18n key).
class AppFailure implements Exception {
  const AppFailure(this.code);
  final String code;
  @override
  String toString() => 'AppFailure($code)';
}

/// Validation shared by the form and the tests. Mirrors the DB constraints.
abstract final class Validators {
  static final username = RegExp(r'^[a-z0-9_.]{3,20}$');
  static const minAge = 16; // D-066

  static bool isOldEnough(DateTime birth, DateTime today) {
    final limit = DateTime(today.year - minAge, today.month, today.day);
    return !birth.isAfter(limit);
  }

  /// Builds a real date or null (rejects 31/02 instead of rolling over to March).
  static DateTime? date(int? day, int? month, int? year) {
    if (day == null || month == null || year == null || year < 1900 || month < 1 || month > 12 || day < 1) return null;
    final d = DateTime(year, month, day);
    return d.month == month && d.day == day ? d : null;
  }
}
