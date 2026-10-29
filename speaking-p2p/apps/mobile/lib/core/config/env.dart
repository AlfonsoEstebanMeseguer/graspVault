// Build-time configuration (--dart-define-from-file=env/dev.json). No secrets:
// only public identifiers. Refuses to start with a service_role key pasted by
// mistake, or a dashboard URL instead of the API URL (vault: core/config/env.dart).
class Env {
  const Env({required this.supabaseUrl, required this.supabaseAnonKey, required this.contentCdnUrl});

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String contentCdnUrl;

  static const fromDefines = Env(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    contentCdnUrl: String.fromEnvironment('CONTENT_CDN_URL'),
  );

  /// Without backend config the app runs in offline mode (exam engine with a
  /// simulated partner) instead of crashing.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

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
