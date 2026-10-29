import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/domain/session/talk_meter.dart';

const _turnA = TalkStretch(seg: 3, state: 'part1', phase: 'speak', paused: false, micA: true, micB: false);
const _open = TalkStretch(seg: 9, state: 'part3', phase: 'speak', paused: false, micA: true, micB: true);

TalkMeter _meter() => TalkMeter()
  ..userA = 'ua'
  ..userB = 'ub';

void main() {
  test('cuenta la voz de A, de B y a la vez dentro de cada tramo', () {
    final m = _meter();
    expect(m.enter(_open, 0), isNull, reason: 'el primer tramo no cierra nada');
    m.speakers({'ua'}, 1000);
    m.speakers({'ua', 'ub'}, 4000);
    m.speakers({'ub'}, 6000);
    m.speakers({}, 9000);
    final w = m.enter(_turnA, 10000)!;
    expect(w.stretch, same(_open));
    expect(w.startedAtMs, 0);
    expect(w.windowMs, 10000);
    expect(w.speechAMs, 5000); // 1-6 s
    expect(w.speechBMs, 5000); // 4-9 s
    expect(w.overlapMs, 2000); // 4-6 s
  });

  test('quien sigue hablando al cambiar de tramo cuenta en los dos', () {
    final m = _meter()..enter(_open, 0);
    m.speakers({'ua'}, 2000);
    expect(m.enter(_turnA, 5000)!.speechAMs, 3000);
    expect(m.enter(null, 8000)!.speechAMs, 3000, reason: 'sigue hablando en el turno de A');
  });

  test('el mismo tramo no corta; los muy cortos no se envían', () {
    final m = _meter()..enter(_turnA, 0);
    expect(m.enter(_turnA, 4000), isNull);
    expect(m.enter(_open, 500 + 4000)!.windowMs, 4500);
    expect(m.enter(_turnA, 4500 + 900), isNull, reason: 'menos de 1 s: no es prueba de nada');
  });

  test('las identidades ajenas no cuentan y la ventana se acota a 20 min', () {
    final m = _meter()..enter(_open, 0);
    m.speakers({'intruso'}, 0);
    final w = m.enter(null, 30 * 60 * 1000)!;
    expect(w.speechAMs + w.speechBMs, 0);
    expect(w.windowMs, TalkMeter.maxWindowMs);
    expect(w.toJson()['state'], 'part3');
    expect(w.toJson().keys, containsAll(['seg', 'startedAtMs', 'phase', 'paused', 'micA', 'micB', 'overlapMs']));
  });
}
