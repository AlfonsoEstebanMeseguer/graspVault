// Account-level domain types. No Flutter, no Supabase.
import '../exam/models.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email});
  final String id;
  final String? email;
}

class MyProfile {
  const MyProfile({required this.id, required this.username, required this.languages, required this.targetLevel});
  final String id;
  final String username;
  final List<String> languages;
  final Level targetLevel;
}

/// Everything the onboarding collects (CLAUDE.md §3, steps 2-8).
class OnboardingData {
  const OnboardingData({
    required this.username,
    required this.languages,
    required this.targetLevel,
    required this.birthDate,
    required this.phone,
    required this.termsVersion,
  });

  final String username;
  final List<String> languages;
  final Level targetLevel;
  final DateTime birthDate;
  final String? phone;
  final String termsVersion;

  Map<String, Object?> toJson() => {
        'username': username,
        'languages': languages,
        'targetLevel': targetLevel.code,
        'birthDate': '${birthDate.year.toString().padLeft(4, '0')}-'
            '${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'phone': phone,
        'termsVersion': termsVersion,
      };
}

/// Current version of the Terms + Privacy Policy. Bump it when they change:
/// the accepted version and date are stored with the profile.
const termsVersion = '2026-10-15';

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
  static final phone = RegExp(r'^\+[0-9]{7,15}$');
  static const minAge = 14;

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
