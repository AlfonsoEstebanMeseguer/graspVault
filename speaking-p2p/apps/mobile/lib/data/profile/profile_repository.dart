import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../auth/auth_repository.dart';

abstract class ProfileRepository {
  /// Null = signed in but onboarding not completed yet.
  Future<MyProfile?> loadMine(String userId);
  Future<bool> isUsernameAvailable(String username);
  Future<void> completeOnboarding(OnboardingData data);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final sb.SupabaseClient _client;

  @override
  Future<MyProfile?> loadMine(String userId) async {
    final row = await _client.from('profiles').select('id, username, languages, target_level, avatar_key').eq('id', userId).maybeSingle();
    if (row == null) return null;
    return MyProfile(
      id: row['id'] as String,
      username: row['username'] as String,
      languages: (row['languages'] as List<dynamic>).cast<String>(),
      targetLevel: LevelCode.parse(row['target_level'] as String),
      avatarKey: row['avatar_key'] as String?,
    );
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final row = await _client.from('public_profiles').select('id').eq('username', username).maybeSingle();
    return row == null;
  }

  @override
  Future<void> completeOnboarding(OnboardingData data) async {
    try {
      await _client.functions.invoke('onboarding-complete', body: data.toJson());
    } on sb.FunctionException catch (e) {
      final details = e.details;
      final code = details is Map && details['error'] is String ? details['error'] as String : 'server_error';
      throw AppFailure(code);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  return Env.fromDefines.hasBackend ? SupabaseProfileRepository(sb.Supabase.instance.client) : null;
});

/// The signed-in user's profile; rebuilt when the user changes.
final myProfileProvider = FutureProvider<MyProfile?>((ref) async {
  final user = ref.watch(authUserProvider).value;
  final repo = ref.watch(profileRepositoryProvider);
  if (user == null || repo == null) return null;
  return repo.loadMine(user.id);
});
