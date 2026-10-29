// Agenda domain: offers, meetings, chat. Pure rules mirrored from SQL
// (svc_offer_*, svc_meeting_*) so the UI never offers what the server rejects.
import '../exam/models.dart';

enum OfferStatus { open, filled, cancelled, expired }

enum MeetingStatus { pending, confirmed, cancelled, closed, done, noShow }

/// How a meeting was born: booking a slot of an offer, or inviting a companion (D-046).
enum MeetingOrigin { offer, invite }

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
    this.creatorAvatarKey,
    this.interested = 0,
    this.taken = const [],
  });
  final String id;
  final String creatorId;
  final Level level;
  final DateTime windowStart;
  final DateTime windowEnd;
  final OfferStatus status;
  final String? creatorName;
  final List<String> creatorLanguages;
  final String? creatorAvatarKey;
  /// Live bookings of my own offer.
  final int interested;

  /// Board only: start times already booked in this offer (the creator is busy then).
  final List<DateTime> taken;
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
    this.origin = MeetingOrigin.offer,
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
  final MeetingOrigin origin;

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
        origin: j['origin'] == 'invite' ? MeetingOrigin.invite : MeetingOrigin.offer,
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
  const ChatSummary({required this.chatId, required this.meeting, required this.partnerId, this.partnerName, this.partnerLanguages = const [], this.partnerAvatarKey, this.lastMessage});
  final String chatId;
  final Meeting meeting;
  final String? partnerId;
  final String? partnerName;
  final List<String> partnerLanguages;
  final String? partnerAvatarKey;
  final ChatMessage? lastMessage;
}

/// Someone I finished an exam with. Only mutual companions can invite each other.
class Companion {
  const Companion({
    required this.partnerId,
    required this.iAdded,
    required this.theyAdded,
    this.name,
    this.avatarKey,
    this.languages = const [],
    this.sessionsTogether = 0,
    this.lastSessionId,
  });
  final String partnerId;
  final bool iAdded;
  final bool theyAdded;
  final String? name;
  final String? avatarKey;
  final List<String> languages;
  final int sessionsTogether;

  /// The last exam we finished together: proves we met, to add someone back.
  final String? lastSessionId;

  bool get mutual => iAdded && theyAdded;
}

/// Where I stand with the partner of an exam: not added, waiting for them, or companions.
enum CompanionLink { none, waiting, mutual }

/// "Mis exámenes": what waits for me, what is coming, and the rest.
class AgendaBuckets {
  const AgendaBuckets({required this.needsMe, required this.upcoming, required this.past});
  final List<ChatSummary> needsMe;
  final List<ChatSummary> upcoming;
  final List<ChatSummary> past;

  bool get isEmpty => needsMe.isEmpty && upcoming.isEmpty;

  factory AgendaBuckets.of(List<ChatSummary> chats, String me) {
    final needsMe = <ChatSummary>[], upcoming = <ChatSummary>[], past = <ChatSummary>[];
    for (final c in chats) {
      final m = c.meeting;
      if (m.status == MeetingStatus.pending && !m.confirmedBy(me) && c.partnerId != null) {
        needsMe.add(c);
      } else if (m.status == MeetingStatus.pending || m.status == MeetingStatus.confirmed) {
        upcoming.add(c);
      } else {
        past.add(c);
      }
    }
    int byTime(ChatSummary a, ChatSummary b) => a.meeting.scheduledAt.compareTo(b.meeting.scheduledAt);
    needsMe.sort(byTime);
    upcoming.sort(byTime);
    past.sort((a, b) => byTime(b, a));
    return AgendaBuckets(needsMe: needsMe, upcoming: upcoming, past: past);
  }
}

enum SlotState { free, busy, taken }

abstract final class AgendaRules {
  static const meetingBlock = Duration(minutes: 30);
  static const maxOpenOffers = 2;
  static const horizon = Duration(days: 7);
  static const enterBefore = Duration(minutes: 5);
  static const courtesy = Duration(minutes: 10);

  /// The chat stays writable until 2 h after the meeting's time (chat_messages_meeting_alive).
  static const chatAfter = Duration(hours: 2);
  static const maxMessage = 500;
  static const maxInvites = 3;

  /// B1<->B2, B2<->C1 (board filter only; live matching is exact level).
  static List<Level> adjacent(Level l) => switch (l) {
        Level.b1 => [Level.b2],
        Level.b2 => [Level.b1, Level.c1],
        Level.c1 => [Level.b2],
      };

  static bool overlaps(DateTime a, DateTime b) => a.isBefore(b.add(meetingBlock)) && b.isBefore(a.add(meetingBlock));

  /// Start times inside a window: every 30 min on the UTC grid, the whole 30-min
  /// meeting must fit, not in the past. `busy` = my confirmed meetings, `taken` =
  /// already booked in this offer (same checks as svc_offer_accept).
  static List<({DateTime at, SlotState state})> slots(DateTime windowStart, DateTime windowEnd, DateTime now, List<DateTime> busy,
      [List<DateTime> taken = const []]) {
    final out = <({DateTime at, SlotState state})>[];
    var t = _ceilTo30(windowStart);
    while (!t.add(meetingBlock).isAfter(windowEnd)) {
      if (t.isAfter(now)) {
        final state = taken.any((b) => overlaps(b, t))
            ? SlotState.taken
            : (busy.any((b) => overlaps(b, t)) ? SlotState.busy : SlotState.free);
        out.add((at: t, state: state));
      }
      t = t.add(meetingBlock);
    }
    return out;
  }

  /// Half-hour start times of one local day that are still ahead (invitations, changing the time).
  static List<DateTime> dayGrid(DateTime localMidnight, DateTime now) => [
        for (var t = _ceilTo30(localMidnight); t.isBefore(localMidnight.add(const Duration(days: 1))); t = t.add(meetingBlock))
          if (t.isAfter(now) && !t.isAfter(now.add(horizon))) t,
      ];

  static bool onGrid(DateTime t) {
    final u = t.toUtc();
    return u.second == 0 && u.millisecond == 0 && (u.minute == 0 || u.minute == 30);
  }

  /// Can I still write in this chat? (mirrors the RLS policy)
  static bool chatOpen(Meeting m, DateTime now) =>
      const {MeetingStatus.pending, MeetingStatus.confirmed, MeetingStatus.done, MeetingStatus.noShow}.contains(m.status) &&
      now.isBefore(m.scheduledAt.add(chatAfter));

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
