import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/domain/agenda/agenda.dart';
import 'package:speaking_p2p/domain/exam/models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 16, 10);

  test('huecos de 30 min: la reunion entera cabe en la franja y nunca en el pasado', () {
    final s = AgendaRules.slots(DateTime.utc(2026, 10, 15, 16), DateTime.utc(2026, 10, 15, 18), now, const []);
    expect(s.map((x) => x.at.hour * 60 + x.at.minute), [16 * 60 + 30, 17 * 60, 17 * 60 + 30]);
  });

  test('franja que empieza a deshora se alinea a la media hora', () {
    final s = AgendaRules.slots(DateTime.utc(2026, 10, 16, 17, 10), DateTime.utc(2026, 10, 16, 18, 30), now, const []);
    expect(s.map((x) => x.at.toIso8601String()), ['2026-10-16T17:30:00.000Z', '2026-10-16T18:00:00.000Z']);
  });

  test('"Ocupado": choca con una reunion confirmada (bloque de 30 min)', () {
    final busy = [DateTime.utc(2026, 10, 16, 19)];
    final s = AgendaRules.slots(DateTime.utc(2026, 10, 16, 18), DateTime.utc(2026, 10, 16, 21), now, busy);
    final byHour = {for (final x in s) '${x.at.hour}:${x.at.minute}': x.state};
    expect(byHour['18:30'], SlotState.free, reason: '18:30-19:00 toca pero no solapa');
    expect(byHour['19:0'], SlotState.busy);
    expect(byHour['19:30'], SlotState.free);
  });

  test('huecos ya reservados en la propuesta: "taken" gana a "busy"', () {
    final s = AgendaRules.slots(DateTime.utc(2026, 10, 16, 18), DateTime.utc(2026, 10, 16, 20), now,
        [DateTime.utc(2026, 10, 16, 18)], [DateTime.utc(2026, 10, 16, 18), DateTime.utc(2026, 10, 16, 19)]);
    expect(s.map((x) => x.state), [SlotState.taken, SlotState.free, SlotState.taken, SlotState.free]);
  });

  test('rejilla de un dia: medias horas que quedan por delante, dentro de 7 dias', () {
    final day = DateTime.utc(2026, 10, 15);
    final g = AgendaRules.dayGrid(day, now);
    expect(g.first, DateTime.utc(2026, 10, 15, 16, 30));
    expect(g.last, DateTime.utc(2026, 10, 15, 23, 30));
    expect(g.every(AgendaRules.onGrid), isTrue);
    expect(AgendaRules.dayGrid(DateTime.utc(2026, 10, 23), now), isEmpty, reason: 'mas alla del horizonte de 7 dias');
    expect(AgendaRules.onGrid(DateTime.utc(2026, 10, 15, 16, 35)), isFalse);
  });

  Meeting mt(MeetingStatus st, {String? creator = 'a', bool a = false, bool b = false, DateTime? at}) => Meeting(
      id: 'm-$st', offerId: null, creatorId: creator, acceptorId: 'b', level: Level.c1,
      scheduledAt: at ?? DateTime.utc(2026, 10, 15, 19), creatorConfirmed: a, acceptorConfirmed: b, status: st);

  test('el chat se puede escribir hasta 2 h despues de la hora y nunca en canceladas', () {
    final m = mt(MeetingStatus.confirmed, a: true, b: true);
    expect(AgendaRules.chatOpen(m, DateTime.utc(2026, 10, 15, 20, 59)), isTrue);
    expect(AgendaRules.chatOpen(m, DateTime.utc(2026, 10, 15, 21)), isFalse);
    expect(AgendaRules.chatOpen(mt(MeetingStatus.done), DateTime.utc(2026, 10, 15, 20)), isTrue);
    expect(AgendaRules.chatOpen(mt(MeetingStatus.cancelled), DateTime.utc(2026, 10, 15, 17)), isFalse);
    expect(AgendaRules.chatOpen(mt(MeetingStatus.closed), DateTime.utc(2026, 10, 15, 17)), isFalse);
  });

  test('"Mis examenes": te toca / proximos / anteriores', () {
    ChatSummary c(Meeting m, {String? partner = 'a'}) => ChatSummary(chatId: m.id, meeting: m, partnerId: partner);
    final waitsForMe = mt(MeetingStatus.pending, a: true, at: DateTime.utc(2026, 10, 16, 10));
    final waitsForThem = mt(MeetingStatus.pending, b: true, at: DateTime.utc(2026, 10, 15, 20));
    final confirmed = mt(MeetingStatus.confirmed, a: true, b: true, at: DateTime.utc(2026, 10, 15, 18));
    final gone = mt(MeetingStatus.cancelled);
    final orphan = Meeting(id: 'orphan', offerId: null, creatorId: null, acceptorId: 'b', level: Level.b2,
        scheduledAt: DateTime.utc(2026, 10, 17), creatorConfirmed: false, acceptorConfirmed: false, status: MeetingStatus.pending);
    final b = AgendaBuckets.of([c(gone), c(waitsForThem), c(waitsForMe), c(confirmed), c(orphan, partner: null)], 'b');
    expect(b.needsMe.map((x) => x.meeting), [waitsForMe]);
    expect(b.upcoming.map((x) => x.meeting), [confirmed, waitsForThem, orphan], reason: 'por hora; sin compañero no se le pide confirmar');
    expect(b.past.map((x) => x.meeting), [gone]);
  });

  test('compañero mutuo solo si los dos se han añadido', () {
    expect(const Companion(partnerId: 'x', iAdded: true, theyAdded: true).mutual, isTrue);
    expect(const Companion(partnerId: 'x', iAdded: true, theyAdded: false).mutual, isFalse);
  });

  test('niveles adyacentes del tablon', () {
    expect(AgendaRules.adjacent(Level.b2), [Level.b1, Level.c1]);
    expect(AgendaRules.adjacent(Level.c1), [Level.b2]);
  });

  test('entrar a la sala: desde 5 min antes hasta 10 min despues', () {
    Meeting m(MeetingStatus st) => Meeting(id: 'm', offerId: null, creatorId: 'a', acceptorId: 'b', level: Level.c1,
        scheduledAt: DateTime.utc(2026, 10, 15, 19), creatorConfirmed: true, acceptorConfirmed: true, status: st);
    expect(AgendaRules.canEnter(m(MeetingStatus.confirmed), DateTime.utc(2026, 10, 15, 18, 54)), isFalse);
    expect(AgendaRules.canEnter(m(MeetingStatus.confirmed), DateTime.utc(2026, 10, 15, 18, 55)), isTrue);
    expect(AgendaRules.canEnter(m(MeetingStatus.confirmed), DateTime.utc(2026, 10, 15, 19, 10)), isTrue);
    expect(AgendaRules.canEnter(m(MeetingStatus.confirmed), DateTime.utc(2026, 10, 15, 19, 11)), isFalse);
    expect(AgendaRules.canEnter(m(MeetingStatus.pending), DateTime.utc(2026, 10, 15, 19)), isFalse);
  });

  test('validacion de franja igual que el servidor', () {
    expect(AgendaRules.offerWindowError(now, now.add(const Duration(minutes: 20)), now), 'window_too_short');
    expect(AgendaRules.offerWindowError(now, now.add(const Duration(days: 8)), now), 'window_out_of_range');
    expect(AgendaRules.offerWindowError(now, now.add(const Duration(hours: 2)), now), isNull);
    expect(AgendaRules.offersLeft(1), 1);
    expect(AgendaRules.offersLeft(3), 0);
  });
}
