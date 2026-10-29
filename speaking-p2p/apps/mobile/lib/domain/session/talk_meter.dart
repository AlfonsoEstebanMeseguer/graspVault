// Speaking time per stretch of a live session (D-051, moderation evidence,
// phase 1). The input is LiveKit's active speakers, computed by the media
// server from the published audio, so both phones should report the same
// figures. Only numbers leave the phone: never audio, never words.
import 'dart:math' as math;

/// Where the session was and who the server let speak.
class TalkStretch {
  const TalkStretch({
    required this.seg,
    required this.state,
    required this.phase,
    required this.paused,
    required this.micA,
    required this.micB,
  });

  /// Segment of the timeline; -1 in the lobby and the feedback.
  final int seg;

  /// lobby, part1..part4 or feedback.
  final String state;

  /// reader or speak (null outside the exam's segments).
  final String? phase;
  final bool paused;
  final bool micA;
  final bool micB;

  bool sameAs(TalkStretch o) =>
      seg == o.seg && state == o.state && phase == o.phase && paused == o.paused && micA == o.micA && micB == o.micB;
}

/// One measured stretch, as session-actions `talk_stats` expects it.
class TalkWindow {
  const TalkWindow({
    required this.stretch,
    required this.startedAtMs,
    required this.windowMs,
    required this.speechAMs,
    required this.speechBMs,
    required this.overlapMs,
  });

  final TalkStretch stretch;
  final int startedAtMs;
  final int windowMs;
  final int speechAMs;
  final int speechBMs;
  final int overlapMs;

  Map<String, Object?> toJson() => {
        'seg': stretch.seg,
        'startedAtMs': startedAtMs,
        'state': stretch.state,
        'phase': stretch.phase,
        'paused': stretch.paused,
        'micA': stretch.micA,
        'micB': stretch.micB,
        'windowMs': windowMs,
        'speechAMs': speechAMs,
        'speechBMs': speechBMs,
        'overlapMs': overlapMs,
      };
}

class TalkMeter {
  /// Shorter stretches carry no evidence (a jump, a double tick).
  static const minWindowMs = 1000;

  /// The server's cap: the longest stretch is a 20 min feedback.
  static const maxWindowMs = 1200000;

  /// Identities of candidates A and B (LiveKit identity = user id).
  String? userA;
  String? userB;

  TalkStretch? _current;
  int _startedAt = 0;
  int _since = 0;
  bool _a = false;
  bool _b = false;
  int _speechA = 0;
  int _speechB = 0;
  int _overlap = 0;

  /// Who is talking now.
  void speakers(Set<String> ids, int nowMs) {
    _account(nowMs);
    _a = userA != null && ids.contains(userA);
    _b = userB != null && ids.contains(userB);
  }

  /// Moves to [next] (null = stop measuring). Returns the stretch just closed,
  /// or null when it did not change or was too short to count.
  TalkWindow? enter(TalkStretch? next, int nowMs) {
    final current = _current;
    if (current != null && next != null && current.sameAs(next)) return null;
    _account(nowMs);
    TalkWindow? done;
    if (current != null) {
      final window = math.min(nowMs - _startedAt, maxWindowMs);
      if (window >= minWindowMs) {
        final a = math.min(_speechA, window), b = math.min(_speechB, window);
        done = TalkWindow(
          stretch: current,
          startedAtMs: _startedAt,
          windowMs: window,
          speechAMs: a,
          speechBMs: b,
          overlapMs: math.min(_overlap, math.min(a, b)),
        );
      }
    }
    _current = next;
    _startedAt = _since = nowMs;
    _speechA = _speechB = _overlap = 0;
    return done;
  }

  void _account(int nowMs) {
    if (_current == null) return;
    final d = math.max(0, nowMs - _since);
    if (_a) _speechA += d;
    if (_b) _speechB += d;
    if (_a && _b) _overlap += d;
    _since = nowMs;
  }
}
