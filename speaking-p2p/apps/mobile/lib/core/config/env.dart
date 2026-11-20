// Build-time configuration (--dart-define-from-file=env/dev.json). No secrets:
// only public identifiers. Refuses to start with a service_role key pasted by
// mistake, or a dashboard URL instead of the API URL (vault: core/config/env.dart).
class Env {
  const Env({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.contentCdnUrl,
    this.googleWebClientId = '',
    this.googleIosClientId = '',
    this.appleSignIn = false,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String contentCdnUrl;

  /// Google OAuth client IDs (public, D-062). The web one is the
  /// `serverClientId`: the ID token's audience that Supabase verifies.
  final String googleWebClientId;
  final String googleIosClientId;

  /// Sign in with Apple needs the paid Apple Developer capability; off until
  /// the build is signed with it (APPLE_SIGN_IN=true).
  final bool appleSignIn;

  static const fromDefines = Env(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    contentCdnUrl: String.fromEnvironment('CONTENT_CDN_URL'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    appleSignIn: bool.fromEnvironment('APPLE_SIGN_IN'),
  );

  /// Without backend config the app runs in offline mode (exam engine with a
  /// simulated partner) instead of crashing.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Google needs the web client everywhere and, on iOS, its own client too.
  bool googleConfigured({required bool ios}) => hasBackend && googleWebClientId.isNotEmpty && (!ios || googleIosClientId.isNotEmpty);

  /// Apple is iOS-only (D-062): Android would need the web flow + Services ID.
  bool appleConfigured({required bool ios}) => hasBackend && ios && appleSignIn;

  void assertSafe() {
    if (!hasBackend) return;
    if (supabaseAnonKey.startsWith('sb_secret_') || _jwtRole(supabaseAnonKey) == 'service_role') {
      throw StateError('SUPABASE_ANON_KEY is a service_role key. Never ship it in the app.');
    }
    final u = Uri.tryParse(supabaseUrl);
    if (u == null || u.scheme != 'https' && u.host != 'localhost' && u.host != '10.0.2.2' ||
        u.host.contains('supabase.com')) {
      throw StateError('SUPABASE_URL must be the project API URL (https://<ref>.supabase.co), not the dashboard.');
    }
    // A client SECRET (GOCSPX-…) pasted instead of the client ID must never ship.
    for (final id in [googleWebClientId, googleIosClientId]) {
      if (id.isNotEmpty && !id.endsWith('.apps.googleusercontent.com')) {
        throw StateError('GOOGLE_*_CLIENT_ID must be a client ID (…apps.googleusercontent.com), never the client secret.');
      }
    }
  }

  static String? _jwtRole(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = String.fromCharCodes(_b64(parts[1]));
      final m = RegExp(r'"role"\s*:\s*"([^"]+)"').firstMatch(payload);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  static List<int> _b64(String s) {
    var t = s.replaceAll('-', '+').replaceAll('_', '/');
    while (t.length % 4 != 0) {
      t += '=';
    }
    return Uri.parse('data:;base64,$t').data!.contentAsBytes();
  }
}

/// Which build this is (D-054), set by the iOS workflow: the run number and the
/// commit. Shown at the bottom of Settings so a sideloaded .ipa can be told
/// from an older one (they all share the same file name and version).
abstract final class BuildInfo {
  static const number = String.fromEnvironment('BUILD_NUMBER');
  static const commit = String.fromEnvironment('GIT_COMMIT');

  /// "#42 · 2998e0c", or "local" for a build from this computer.
  static String get label => number.isEmpty && commit.isEmpty ? 'local' : ['#$number', commit].where((s) => s != '#' && s.isNotEmpty).join(' · ');
}
