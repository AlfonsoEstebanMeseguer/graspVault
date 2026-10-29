import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/exam/models.dart';
import '../../features/auth/login_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/matchmaking/matchmaking_controller.dart';
import '../../features/matchmaking/search_screen.dart';
import '../../features/session/session_screen.dart';
import '../../features/exam/widgets/exam_widgets.dart' show formatMs;
import '../theming/palette.dart';
import '../theming/tokens.dart';
import '../ui/kit.dart';
import '../config/env.dart';
import '../../features/agenda/agenda_screen.dart';
import '../../features/agenda/chat_screen.dart';
import '../../features/exam/practice_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/safety/safety_sheet.dart';
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
  // The Terms and the Privacy Policy are readable by anyone, signed in or not.
  if (location.startsWith('/legal/')) return null;
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
          StatefulShellBranch(routes: [GoRoute(
              path: '/agenda',
              builder: (_, state) => AgendaScreen(
                openCreate: state.uri.queryParameters['create'] == '1',
                invite: state.uri.queryParameters['invite'],
              ),
            )]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      // Full screen, outside the tabs: no bottom bar and no ads during the exam.
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: '/legal/:doc',
        builder: (_, state) => LegalScreen(doc: state.pathParameters['doc'] == 'privacy' ? LegalDoc.privacy : LegalDoc.terms),
      ),
      GoRoute(path: '/blocked', builder: (_, _) => const BlockedUsersScreen()),
      GoRoute(path: '/chat/:id', builder: (_, state) => ChatScreen(chatId: state.pathParameters['id']!)),
      GoRoute(path: '/session/:id', builder: (_, state) => SessionScreen(sessionId: state.pathParameters['id']!)),
      GoRoute(
        path: '/practice/:level',
        builder: (_, state) => PracticeScreen(
          level: LevelCode.parse(state.pathParameters['level']!),
          role: state.uri.queryParameters['role'] == 'B' ? Role.b : Role.a,
          skipToMs: int.tryParse(state.uri.queryParameters['at'] ?? '') ?? 0,
          vip: state.uri.queryParameters['vip'] == '1',
        ),
      ),
    ],
  );
});

class _TabsScaffold extends ConsumerWidget {
  const _TabsScaffold({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final m = ref.watch(matchmakingProvider);
    return Scaffold(
      // The tab bar floats (glass) over the content, which scrolls under it.
      extendBody: true,
      body: Column(children: [
        // Still searching while browsing the tabs ("Seguiremos buscando mientras tanto").
        if (m.searching)
          Material(
            color: p.brand,
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () => context.go('/search'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.onBrand)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.searchingBanner(formatMs(DateTime.now().difference(m.startedAt ?? DateTime.now()).inMilliseconds)),
                        style: AppType.headline.copyWith(color: p.onBrand, fontSize: 15),
                      ),
                    ),
                    Icon(AppIcons.caretRight, color: p.onBrand, size: 18),
                  ]),
                ),
              ),
            ),
          ),
        Expanded(child: shell),
      ]),
      bottomNavigationBar: GlassTabBar(
        index: shell.currentIndex,
        onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          (AppIcons.practice, AppIcons.practiceOn, l.tabPractice),
          (AppIcons.agenda, AppIcons.agendaOn, l.tabAgenda),
          (AppIcons.profile, AppIcons.profileOn, l.tabProfile),
          (AppIcons.settings, AppIcons.settingsOn, l.tabSettings),
        ],
      ),
    );
  }
}

/// Floating glass tab bar (spec §10): a capsule with the selected tab raised.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.index, required this.onSelect, required this.items});
  final int index;
  final ValueChanged<int> onSelect;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Glass(
          radius: 36,
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            for (final (i, (icon, iconOn, label)) in items.indexed)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: AppMotion.smooth,
                      curve: AppMotion.curve,
                      height: 60,
                      decoration: BoxDecoration(
                        color: i == index ? p.brandSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(i == index ? iconOn : icon, size: 24, color: i == index ? p.textPrimary : p.textSecondary),
                        const SizedBox(height: 2),
                        FittedBox(
                          child: Text(label,
                              style: AppType.footnote.copyWith(
                                  fontWeight: FontWeight.w600, color: i == index ? p.textPrimary : p.textSecondary)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
