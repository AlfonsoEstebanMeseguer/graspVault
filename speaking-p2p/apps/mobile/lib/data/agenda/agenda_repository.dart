// Agenda data: reads through RLS (+ Realtime for the chat), every write except
// sending a chat message goes through `meeting-actions` (CLAUDE.md §8).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../session/session_repository.dart' show PublicProfile;

abstract class AgendaRepository {
  String get me;
  Future<List<Offer>> myOffers();
  Future<List<Offer>> board(List<Level> levels);
  Future<List<ChatSummary>> chats({String? chatId});
  Future<List<Meeting>> myMeetings();
  Stream<Meeting> watchMeeting(String meetingId);
  Stream<List<ChatMessage>> watchMessages(String chatId);
  Future<void> send(String chatId, String body, String clientId);
  Future<PublicProfile?> profile(String userId);

  Future<String> createOffer(Level level, DateTime start, DateTime end);
  Future<void> cancelOffer(String offerId);
  Future<({String meetingId, String chatId})> accept(String offerId, DateTime at);
  Future<void> modify(String meetingId, DateTime at, Level level);
  Future<String> confirm(String meetingId);
  Future<void> cancel(String meetingId);
  Future<String> enter(String meetingId, int contentVersion);
}

class SupabaseAgendaRepository implements AgendaRepository {
  SupabaseAgendaRepository(this._c);
  final sb.SupabaseClient _c;

  @override
  String get me => _c.auth.currentUser!.id;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    try {
      final r = await _c.functions.invoke('meeting-actions', body: body);
      return (r.data as Map).cast<String, dynamic>();
    } on sb.FunctionException catch (e) {
      final d = e.details;
      throw AppFailure(d is Map && d['error'] is String ? d['error'] as String : 'server_error');
    }
  }

  static String _iso(DateTime t) => t.toUtc().toIso8601String();

  Future<Map<String, PublicProfile>> _profiles(Iterable<String?> ids) async {
    final wanted = ids.whereType<String>().toSet().toList();
    if (wanted.isEmpty) return const {};
    final rows = await _c.from('public_profiles').select('id, username, languages, avatar_key').inFilter('id', wanted);
    return {
      for (final r in rows)
        r['id'] as String: PublicProfile(
          id: r['id'] as String,
          username: r['username'] as String,
          languages: (r['languages'] as List<dynamic>).cast<String>(),
          avatarKey: r['avatar_key'] as String?,
        ),
    };
  }

  Offer _offer(Map<String, dynamic> r, {PublicProfile? creator, int interested = 0}) => Offer(
        id: r['id'] as String,
        creatorId: r['creator_id'] as String,
        level: LevelCode.parse(r['level'] as String),
        windowStart: DateTime.parse(r['window_start'] as String),
        windowEnd: DateTime.parse(r['window_end'] as String),
        status: OfferStatus.values.byName(r['status'] as String),
        creatorName: creator?.username,
        creatorLanguages: creator?.languages ?? const [],
        interested: interested,
      );

  @override
  Future<List<Offer>> myOffers() async {
    final rows = await _c
        .from('meeting_offers')
        .select('id, creator_id, level, window_start, window_end, status')
        .eq('creator_id', me)
        .eq('status', 'open')
        .gt('window_end', DateTime.now().toUtc().toIso8601String())
        .order('window_start');
    if (rows.isEmpty) return const [];
    // The creator is a participant of every acceptance, so RLS lets us count them.
    final pending = await _c
        .from('meetings')
        .select('offer_id')
        .inFilter('offer_id', [for (final r in rows) r['id'] as String])
        .eq('status', 'pending');
    final counts = <String, int>{};
    for (final m in pending) {
      counts.update(m['offer_id'] as String, (v) => v + 1, ifAbsent: () => 1);
    }
    return [for (final r in rows) _offer(r, interested: counts[r['id']] ?? 0)];
  }

  @override
  Future<List<Offer>> board(List<Level> levels) async {
    final rows = await _c
        .from('meeting_offers')
        .select('id, creator_id, level, window_start, window_end, status')
        .eq('status', 'open')
        .neq('creator_id', me)
        .inFilter('level', [for (final l in levels) l.code])
        .gt('window_end', DateTime.now().toUtc().toIso8601String())
        .order('window_start')
        .limit(100);
    final people = await _profiles(rows.map((r) => r['creator_id'] as String));
    // An offer whose creator has no public profile (deleted account) is not shown.
    return [
      for (final r in rows)
        if (people[r['creator_id']] != null) _offer(r, creator: people[r['creator_id']]),
    ];
  }

  static const _meetingCols = 'id, offer_id, creator_id, acceptor_id, level, scheduled_at, creator_confirmed, acceptor_confirmed, status';

  @override
  Future<List<ChatSummary>> chats({String? chatId}) async {
    var q = _c.from('chats').select('id, meeting_id, user_a, user_b, last_message_at, meetings($_meetingCols)');
    if (chatId != null) q = q.eq('id', chatId);
    final rows = await q.order('last_message_at', ascending: false).limit(100);
    if (rows.isEmpty) return const [];
    final meetings = {for (final r in rows) r['id'] as String: Meeting.fromJson((r['meetings'] as Map).cast<String, dynamic>())};
    final people = await _profiles(meetings.values.map((m) => m.partnerOf(me)));
    // Last message per chat: one small query per page, newest first.
    final last = <String, ChatMessage>{};
    final msgs = await _c
        .from('chat_messages')
        .select('id, chat_id, sender_id, kind, body, system_code, system_args, created_at')
        .inFilter('chat_id', meetings.keys.toList())
        .order('created_at', ascending: false)
        .limit(400);
    for (final m in msgs) {
      last.putIfAbsent(m['chat_id'] as String, () => ChatMessage.fromJson(m));
    }
    return [
      for (final r in rows)
        ChatSummary(
          chatId: r['id'] as String,
          meeting: meetings[r['id']]!,
          partnerId: meetings[r['id']]!.partnerOf(me),
          partnerName: people[meetings[r['id']]!.partnerOf(me)]?.username,
          partnerLanguages: people[meetings[r['id']]!.partnerOf(me)]?.languages ?? const [],
          lastMessage: last[r['id']],
        ),
    ];
  }

  @override
  Future<List<Meeting>> myMeetings() async {
    final from = DateTime.now().toUtc().subtract(AgendaRules.courtesy);
    final rows = await _c
        .from('meetings')
        .select(_meetingCols)
        .eq('status', 'confirmed')
        .gte('scheduled_at', from.toIso8601String())
        .order('scheduled_at');
    return [for (final r in rows) Meeting.fromJson(r)];
  }

  @override
  Stream<Meeting> watchMeeting(String meetingId) => _c
      .from('meetings')
      .stream(primaryKey: ['id'])
      .eq('id', meetingId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => Meeting.fromJson(rows.first));

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) => _c
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('chat_id', chatId)
      .order('created_at')
      .map((rows) => [for (final r in rows) ChatMessage.fromJson(r)]);

  @override
  Future<void> send(String chatId, String body, String clientId) async {
    try {
      await _c.from('chat_messages').insert({'chat_id': chatId, 'body': body, 'client_id': clientId});
    } on sb.PostgrestException {
      throw const AppFailure('send_failed');
    }
  }

  @override
  Future<PublicProfile?> profile(String userId) async => (await _profiles([userId]))[userId];

  @override
  Future<String> createOffer(Level level, DateTime start, DateTime end) async =>
      (await _call({'action': 'create_offer', 'level': level.code, 'windowStart': _iso(start), 'windowEnd': _iso(end)}))['offerId'] as String;

  @override
  Future<void> cancelOffer(String offerId) => _call({'action': 'cancel_offer', 'offerId': offerId});

  @override
  Future<({String meetingId, String chatId})> accept(String offerId, DateTime at) async {
    final b = await _call({'action': 'accept', 'offerId': offerId, 'scheduledAt': _iso(at)});
    return (meetingId: b['meeting_id'] as String, chatId: b['chat_id'] as String);
  }

  @override
  Future<void> modify(String meetingId, DateTime at, Level level) =>
      _call({'action': 'modify', 'meetingId': meetingId, 'scheduledAt': _iso(at), 'level': level.code});

  @override
  Future<String> confirm(String meetingId) async => (await _call({'action': 'confirm', 'meetingId': meetingId}))['status'] as String;

  @override
  Future<void> cancel(String meetingId) => _call({'action': 'cancel', 'meetingId': meetingId});

  @override
  Future<String> enter(String meetingId, int contentVersion) async =>
      (await _call({'action': 'enter', 'meetingId': meetingId, 'contentVersion': contentVersion}))['sessionId'] as String;
}

final agendaRepositoryProvider = Provider<AgendaRepository?>((ref) {
  return Env.fromDefines.hasBackend ? SupabaseAgendaRepository(sb.Supabase.instance.client) : null;
});
