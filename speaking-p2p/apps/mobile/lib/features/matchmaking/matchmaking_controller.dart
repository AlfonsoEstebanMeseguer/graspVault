// Live search, app-wide: it keeps searching while the user looks at the Agenda
// ("Seguiremos buscando mientras tanto"). Heartbeat every 10 s (D-009);
// the 15 s prompt appears only if the user has no open meeting (CLAUDE.md §7).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/content_repository.dart';
import '../../data/matchmaking/matchmaking_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';

class MatchState {
  const MatchState({
    this.searching = false,
    this.level,
    this.startedAt,
    this.matchedSessionId,
    this.showPrompt = false,
    this.promptDismissed = false,
    this.hasOpenMeeting = false,
    this.error,
  });

  final bool searching;
  final Level? level;
  final DateTime? startedAt;
  final String? matchedSessionId;
  final bool showPrompt;
  final bool promptDismissed;
  final bool hasOpenMeeting;
  final String? error;

  MatchState copyWith({
    bool? searching,
    Level? level,
    DateTime? startedAt,
    String? matchedSessionId,
    bool? showPrompt,
    bool? promptDismissed,
    bool? hasOpenMeeting,
    String? error,
  }) =>
      MatchState(
        searching: searching ?? this.searching,
        level: level ?? this.level,
        startedAt: startedAt ?? this.startedAt,
        matchedSessionId: matchedSessionId ?? this.matchedSessionId,
        showPrompt: showPrompt ?? this.showPrompt,
        promptDismissed: promptDismissed ?? this.promptDismissed,
        hasOpenMeeting: hasOpenMeeting ?? this.hasOpenMeeting,
        error: error,
      );
}

class MatchmakingController extends Notifier<MatchState> {
  static const heartbeat = Duration(seconds: 10);
  static const promptAfter = Duration(seconds: 15);

  Timer? _beat;
  Timer? _prompt;
  DateTime Function() now = DateTime.now;

  @override
  MatchState build() {
    ref.onDispose(_stopTimers);
    return const MatchState();
  }

  MatchmakingRepository? get _repo => ref.read(matchmakingRepositoryProvider);

  Future<void> start(Level level) async {
    if (state.searching) return;
    state = MatchState(searching: true, level: level, startedAt: now());
    _beat = Timer.periodic(heartbeat, (_) => _enqueue());
    _prompt = Timer(promptAfter, _maybePrompt);
    await _enqueue();
  }

  Future<void> _enqueue() async {
    final repo = _repo;
    final level = state.level;
    if (repo == null || level == null || !state.searching) return;
    try {
      final version = (await ref.read(contentIndexProvider.future)).version;
      final r = await repo.enqueue(level, version);
      if (!state.searching) return;
      if (r.matchedSessionId != null) {
        _stopTimers();
        state = state.copyWith(searching: false, matchedSessionId: r.matchedSessionId, showPrompt: false);
      } else {
        state = state.copyWith(hasOpenMeeting: r.hasOpenMeeting);
      }
    } on AppFailure catch (e) {
      _stopTimers();
      state = state.copyWith(searching: false, error: e.code);
    } catch (_) {
      // Network blip: the next heartbeat retries; the server forgets us after 25 s.
    }
  }

  void _maybePrompt() {
    if (state.searching && !state.hasOpenMeeting && !state.promptDismissed) {
      state = state.copyWith(showPrompt: true);
    }
  }

  void dismissPrompt() => state = state.copyWith(showPrompt: false, promptDismissed: true);

  Future<void> cancel() async {
    _stopTimers();
    state = const MatchState();
    await _repo?.cancel().catchError((Object _) {});
  }

  /// The session screen took over.
  void consumeMatch() => state = const MatchState();

  void _stopTimers() {
    _beat?.cancel();
    _prompt?.cancel();
  }
}

final matchmakingProvider = NotifierProvider<MatchmakingController, MatchState>(MatchmakingController.new);
