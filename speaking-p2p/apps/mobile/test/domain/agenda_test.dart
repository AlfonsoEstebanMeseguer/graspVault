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
    final byHour = {for (final x in s) '${x.at.hour}:${x.at.minute}': x.busy};
    expect(byHour['18:30'], isFalse, reason: '18:30-19:00 toca pero no solapa');
    expect(byHour['19:0'], isTrue);
    expect(byHour['19:30'], isFalse);
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
