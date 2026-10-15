import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/exam/models.dart';
import '../../features/auth/login_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../config/env.dart';
import '../../features/agenda/agenda_screen.dart';
import '../../features/exam/practice_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../l10n/l10n.dart';

/// Where the session says the user must be, or null to stay. Pure: tested
/// without widgets. `hasBackend == false` is offline practice: no gate at all.
String? gateRedirect({
  required bool hasBackend,
  required AsyncValue<Object?> user,
  required AsyncValue<Object?> profile,
  required String location,
}) {
  if (!hasBackend) return null;
  const gateRoutes = {'/login', '/onboarding', '/loading'};
  if (user.isLoading && !user.hasValue) return location == '/loading' ? null : '/loading';
  if (user.value == null) return location == '/login' ? null : '/login';
  if (profile.isLoading && !profile.hasValue) return location == '/loading' ? null : '/loading';
  if (profile.hasError) return null; // keep the user where they are; the screen shows the error
  if (profile.value == null) return location == '/onboarding' ? null : '/onboarding';
  return gateRoutes.contains(location) ? '/' : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authUserProvider, (_, _) => refresh.value++);
  ref.listen(myProfileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => gateRedirect(
      hasBackend: Env.fromDefines.hasBackend,
      user: ref.read(authUserProvider),
      profile: ref.read(myProfileProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/loading', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      // Tabs keep their state (StatefulShellRoute, as in the vault).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabsScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/agenda', builder: (_, _) => const AgendaScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      // Full screen, outside the tabs: no bottom bar and no ads during the exam.
      GoRoute(
        path: '/practice/:level',
        builder: (_, state) => PracticeScreen(
          level: LevelCode.parse(state.pathParameters['level']!),
          role: state.uri.queryParameters['role'] == 'B' ? Role.b : Role.a,
          skipToMs: int.tryParse(state.uri.queryParameters['at'] ?? '') ?? 0,
        ),
      ),
    ],
  );
});

class _TabsScaffold extends StatelessWidget {
  const _TabsScaffold({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.mic_none), label: l.tabExam),
          NavigationDestination(icon: const Icon(Icons.calendar_today_outlined), label: l.tabAgenda),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: l.tabProfile),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: l.tabSettings),
        ],
      ),
    );
  }
}
