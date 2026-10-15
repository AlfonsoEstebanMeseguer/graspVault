// Agenda domain: offers, meetings, chat. Pure rules mirrored from SQL
// (svc_offer_*, svc_meeting_*) so the UI never offers what the server rejects.
import '../exam/models.dart';

enum OfferStatus { open, filled, cancelled, expired }

enum MeetingStatus { pending, confirmed, cancelled, closed, done, noShow }

MeetingStatus meetingStatusFrom(String v) => v == 'no_show' ? MeetingStatus.noShow : MeetingStatus.values.byName(v);

class Offer {
  const Offer({
    required this.id,
    required this.creatorId,
    required this.level,
    required this.windowStart,
    required this.windowEnd,
    required this.status,
    this.creatorName,
    this.creatorLanguages = const [],
    this.interested = 0,
  });
  final String id;
  final String creatorId;
  final Level level;
  final DateTime windowStart;
  final DateTime windowEnd;
  final OfferStatus status;
  final String? creatorName;
  final List<String> creatorLanguages;
  final int interested;
}

class Meeting {
  const Meeting({
    required this.id,
    required this.offerId,
    required this.creatorId,
    required this.acceptorId,
    required this.level,
    required this.scheduledAt,
    required this.creatorConfirmed,
    required this.acceptorConfirmed,
    required this.status,
  });
  final String id;
  final String? offerId;
  final String? creatorId;
  final String? acceptorId;
  final Level level;
  final DateTime scheduledAt;
  final bool creatorConfirmed;
  final bool acceptorConfirmed;
  final MeetingStatus status;

  String? partnerOf(String me) => me == creatorId ? acceptorId : creatorId;
  bool confirmedBy(String? user) => user == creatorId ? creatorConfirmed : (user == acceptorId ? acceptorConfirmed : false);

  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
        id: j['id'] as String,
        offerId: j['offer_id'] as String?,
        creatorId: j['creator_id'] as String?,
        acceptorId: j['acceptor_id'] as String?,
        level: LevelCode.parse(j['level'] as String),
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        creatorConfirmed: j['creator_confirmed'] as bool? ?? false,
        acceptorConfirmed: j['acceptor_confirmed'] as bool? ?? false,
        status: meetingStatusFrom(j['status'] as String),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.createdAt,
    this.body,
    this.systemCode,
    this.systemArgs = const {},
  });
  final String id;
  final String? senderId;
  final String kind; // 'user' | 'system'
  final DateTime createdAt;
  final String? body;
  final String? systemCode;
  final Map<String, dynamic> systemArgs;

  bool get isSystem => kind == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderId: j['sender_id'] as String?,
        kind: j['kind'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        body: j['body'] as String?,
        systemCode: j['system_code'] as String?,
        systemArgs: (j['system_args'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class ChatSummary {
  const ChatSummary({required this.chatId, required this.meeting, required this.partnerId, this.partnerName, this.partnerLanguages = const [], this.lastMessage});
  final String chatId;
  final Meeting meeting;
  final String? partnerId;
  final String? partnerName;
  final List<String> partnerLanguages;
  final ChatMessage? lastMessage;
}

abstract final class AgendaRules {
  static const meetingBlock = Duration(minutes: 30);
  static const maxOpenOffers = 2;
  static const horizon = Duration(days: 7);
  static const enterBefore = Duration(minutes: 5);
  static const courtesy = Duration(minutes: 10);

  /// B1<->B2, B2<->C1 (board filter only; live matching is exact level).
  static List<Level> adjacent(Level l) => switch (l) {
        Level.b1 => [Level.b2],
        Level.b2 => [Level.b1, Level.c1],
        Level.c1 => [Level.b2],
      };

  static bool overlaps(DateTime a, DateTime b) => a.isBefore(b.add(meetingBlock)) && b.isBefore(a.add(meetingBlock));

  /// Start times the acceptor can pick: every 30 min inside the window,
  /// the whole 30-min meeting must fit, not in the past. `busy` = my confirmed meetings.
  static List<({DateTime at, bool busy})> slots(DateTime windowStart, DateTime windowEnd, DateTime now, List<DateTime> busy) {
    final out = <({DateTime at, bool busy})>[];
    var t = _ceilTo30(windowStart);
    while (!t.add(meetingBlock).isAfter(windowEnd)) {
      if (t.isAfter(now)) out.add((at: t, busy: busy.any((b) => overlaps(b, t))));
      t = t.add(meetingBlock);
    }
    return out;
  }

  static DateTime _ceilTo30(DateTime t) {
    final u = t.toUtc(); // never reinterpret a local wall time as UTC
    var c = DateTime.utc(u.year, u.month, u.day, u.hour);
    while (c.isBefore(u)) {
      c = c.add(meetingBlock);
    }
    return c;
  }

  /// "Entrar a la sala": from 5 min before until the end of the 10-min courtesy.
  static bool canEnter(Meeting m, DateTime now) =>
      m.status == MeetingStatus.confirmed &&
      !now.isBefore(m.scheduledAt.subtract(enterBefore)) &&
      !now.isAfter(m.scheduledAt.add(courtesy));

  static int offersLeft(int openOffers) => (maxOpenOffers - openOffers).clamp(0, maxOpenOffers);

  /// Window validity, same as svc_offer_create.
  static String? offerWindowError(DateTime start, DateTime end, DateTime now) {
    if (end.isBefore(start.add(meetingBlock))) return 'window_too_short';
    if (start.isBefore(now.subtract(const Duration(minutes: 1))) || end.isAfter(now.add(horizon))) return 'window_out_of_range';
    return null;
  }
}
